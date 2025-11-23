[← Back to Documentation Home](../README.md) | [← Previous: UUID Spoofing Prevention](02-UUID-Spoofing-Prevention.md)

### 8.4 Swift Concurrency & AVPlayerPlaybackCoordinatorDelegate

**⚠️ IMPORTANT**: You may encounter concurrency warnings when conforming to `AVPlayerPlaybackCoordinatorDelegate`.

#### Common Error:

```
Conformance of 'MyDelegate' to protocol 'AVPlayerPlaybackCoordinatorDelegate'
crosses into main actor-isolated code and can cause data races
```

#### The Issue:

The `identifierFor` method can be called from non-main-actor contexts, but if your class is marked `@MainActor`, you'll get a data race warning.

#### Solution 1: Don't Implement `identifierFor` (Recommended)

```swift
@MainActor
class VideoPlayer: NSObject, AVPlayerPlaybackCoordinatorDelegate {
    // Don't implement identifierFor - it's OPTIONAL
    // AVFoundation's default implementation works great!

    // Only implement the methods you actually need:
    func playbackCoordinator(
        _ coordinator: AVPlayerPlaybackCoordinator,
        didIssue suspensionReasonsThatTriggerWaiting: [AVCoordinatedPlaybackSuspension.Reason]
    ) {
        // Your custom behavior
    }
}
```

**Why this works**: `identifierFor` is optional and has a sensible default. VantageSpatialSports doesn't implement it.

#### Solution 2: Mark Method `nonisolated` (If You Need Custom Identifiers)

```swift
@MainActor
class VideoPlayer: NSObject, AVPlayerPlaybackCoordinatorDelegate {

    // Mark as nonisolated since it doesn't access mutable state
    nonisolated func playbackCoordinator(
        _ coordinator: AVPlayerPlaybackCoordinator,
        identifierFor playerItem: AVPlayerItem
    ) -> String {
        if let asset = playerItem.asset as? AVURLAsset {
            return asset.url.absoluteString
        }
        return UUID().uuidString
    }
}
```

**When to use this**: Only if you need custom identifiers for your media items. The method doesn't access any mutable state, so it's safe to be `nonisolated`.

### 8.5 Additional Swift Concurrency Pitfalls

**⚠️ IMPORTANT**: Swift 6 strict concurrency checking will catch these issues.

#### Error 1: @MainActor Isolation

**Error:**

```
Call to main actor-isolated initializer 'init(localUUID:)' in a synchronous nonisolated context
Main actor-isolated property 'delegate' can not be mutated from a nonisolated context
```

**Cause**: Your app state class isn't marked `@MainActor`.

**Solution:**

```swift
@Observable
@MainActor  // ✅ Add this
class AppState: ImmersiveWatchPartyDelegate {
    let sharePlayManager: ImmersiveWatchPartyManager

    init() {
        self.sharePlayManager = ImmersiveWatchPartyManager(localUUID: UUID())
        // Set delegate to self (direct conformance pattern)
        self.sharePlayManager.delegate = self
    }

    // Implement delegate methods in extension or in class body
}

extension AppState: ImmersiveWatchPartyDelegate {
    // Delegate methods here
}
```

#### Error 2: Protocol Signature Mismatch

**Error:**

```
Protocol requires function 'sessionManager(_:received:)' with type
'(ImmersiveWatchPartyManager, received: some GroupActivity) async -> Bool'
```

**Cause**: Using `any` instead of `some` in protocol conformance.

**Wrong:**

```swift
func sessionManager(
    _ manager: ImmersiveWatchPartyManager,
    received activity: any GroupActivity  // ❌ Wrong
) async -> Bool
```

**Correct:**

```swift
func sessionManager(
    _ manager: ImmersiveWatchPartyManager,
    received activity: some GroupActivity  // ✅ Correct
) async -> Bool
```

**Why**: `some` is required for protocol conformance with existential types in Swift 6.

#### Error 3: Data Races When Passing Models

**Error:**

```
Sending 'stream' risks causing data races
```

**Cause**: Passing data directly from async delegate to `openImmersiveSpace`.

**Wrong:**

```swift
func sessionManager(
    _ manager: ImmersiveWatchPartyManager,
    received activity: some GroupActivity
) async -> Bool {
    let stream = createStream(from: activity)
    await openImmersiveSpace(value: stream)  // ❌ Data race!
    return true
}
```

**Correct:**

```swift
// In AppState (which conforms to ImmersiveWatchPartyDelegate)
func sessionManager(
    _ manager: ImmersiveWatchPartyManager,
    received activity: some GroupActivity
) async -> Bool {
    let stream = createStream(from: activity)

    // Store in @MainActor-isolated state first
    selectedStream = stream

    // Then open using stored reference
    await openImmersiveSpaceForSharePlay(with: stream)
    return true
}
```

#### Error 4: Capturing Self in Closures

**Error:**

```
Calling mutating 'self' in closure requires explicit use of 'self'
```

**Cause**: Capturing `self` in async closures without explicit capture list.

**Solution:**

```swift
// In App struct
appState.immersiveSpaceOpenAction = { [self] in  // ✅ Explicit capture
    guard let stream = appState.selectedStream else { return }
    await openImmersiveSpace(value: stream)
}
```

