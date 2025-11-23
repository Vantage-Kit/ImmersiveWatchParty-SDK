[← Back to Documentation Home](../README.md) | [← Previous: Custom Player Wrappers](01-Custom-Player-Wrappers.md) | [Next: Settings Sync →](03-Settings-Sync.md)

# 10. Dynamic ImmersiveSpace with Data Models

**⚠️ IMPORTANT**: Most apps use `ImmersiveSpace(for: DataModel.self)` to pass data, not static IDs.

### 10.1 The Challenge

The guide shows:

```swift
ImmersiveSpace(id: "ImmersiveSpace") {  // Static ID
    ImmersiveView()
}
```

But real apps often use:

```swift
ImmersiveSpace(for: StreamModel.self) { $model in  // Dynamic data
    ImmersivePlayer(selectedStream: model!)
}
```

**Problem**: You need to coordinate data between SharePlay delegate and immersive space APIs.

### 10.2 Pattern: Store Data in @MainActor State

**Solution**: Store the data model in `@MainActor`-isolated state, then pass it to `openImmersiveSpace`:

```swift
@MainActor
@Observable
class AppState {
    var selectedStream: StreamModel?  // Store here
    var immersiveSpaceOpenAction: (() async -> Void)?

    // Helper to open space with stored data
    func openImmersiveSpaceForSharePlay(with stream: StreamModel) async {
        self.selectedStream = stream  // Store first
        await immersiveSpaceOpenAction?()  // Then open
    }
}

// In App struct
@main
struct YourApp: App {
    @State private var appState = AppState()
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace

    var body: some Scene {
        // Capture the openImmersiveSpace API
        appState.immersiveSpaceOpenAction = { [self] in
            guard let stream = appState.selectedStream else { return }
            await openImmersiveSpace(value: stream)
        }

        ImmersiveSpace(for: StreamModel.self) { $model in
            if let model = model {
                ImmersivePlayer(selectedStream: model)
                    .environment(appState)
                    .environment(\.sharePlayMessenger, appState.sharePlayManager.messenger)
                    .groupActivityAssociation(.primary("immersive-space"))
            }
        }
    }
}
```

### 10.3 Handling Data in Delegate

**Avoid data races** by storing in `@MainActor` state first:

```swift
// ❌ WRONG - Data race
func sessionManager(
    _ manager: ImmersiveWatchPartyManager,
    received activity: some GroupActivity
) async -> Bool {
    let stream = createStream(from: activity)
    await openImmersiveSpace(value: stream)  // ❌ Data race!
    return true
}

// ✅ CORRECT - Store first, then open
// In AppState (which conforms to ImmersiveWatchPartyDelegate)
func sessionManager(
    _ manager: ImmersiveWatchPartyManager,
    received activity: some GroupActivity
) async -> Bool {
    let stream = createStream(from: activity)

    // Store in @MainActor-isolated state first
    selectedStream = stream
    applyFormatOptions(from: stream)

    // Then open using stored reference
    await openImmersiveSpaceForSharePlay(with: stream)
    return true
}
```

### 10.4 Closing Together

**Pattern**: Store close action and call it when session invalidates:

```swift
@MainActor
class AppState {
    var immersiveSpaceCloseAction: (() async -> Void)?

    func exitImmersiveSpaceForSharePlay() async {
        isImmersiveSpaceOpen = false
        await immersiveSpaceCloseAction?()
    }
}

// In App struct
appState.immersiveSpaceCloseAction = { [self] in
    await dismissImmersiveSpace()
}

// In session state observation
private func observeSessionState<A: GroupActivity>(session: GroupSession<A>) {
    Task {
        for await state in session.$state.values {
            if case .invalidated = state {
                appState.sharePlayManager.handleSessionStateChange(isInvalidated: true)
                await appState.exitImmersiveSpaceForSharePlay()  // Everyone exits
            }
        }
    }
}
```
