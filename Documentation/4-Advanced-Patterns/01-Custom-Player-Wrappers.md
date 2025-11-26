[← Back to Documentation Home](../README.md) | [Next: Dynamic Data Models →](02-Dynamic-Data-Models.md)

# 9. Custom Video Player Wrappers

**⚠️ IMPORTANT**: Most production apps wrap `AVPlayer` in custom classes. This section covers integrating SharePlay with wrapped players.

> **⚠️ Architectural Requirement: RealityKit Rendering**
>
> If your existing custom player wrapper uses `AVPlayerViewController` or SwiftUI `VideoPlayer`, you must modify it for immersive watch parties.
>
> To maintain shared coordinate space with Spatial Personas, you cannot use the system's high-level player views. Your wrapper must expose the underlying `AVPlayer` instance so it can be assigned to a RealityKit `VideoMaterial` on a 3D mesh.

### 9.1 The Challenge

The guide assumes direct access to `AVPlayer`, but real apps often use:

- Custom player wrappers (e.g., `VideoPlayer`, `MediaPlayer`, `StreamPlayer`)
- Third-party player libraries
- Player instances created deep in view hierarchies

**Problem**: You need to register the underlying `AVPlayer` with SharePlay, but it's hidden inside a wrapper.

### 9.2 Finding Your AVPlayer

**Step 1: Check if your wrapper exposes AVPlayer**

```swift
// Inspect your custom player class
public class VideoPlayer: ObservableObject {
    public let player: AVPlayer  // ✅ If this exists, you're good!
    // ... other properties ...
}
```

**Step 2: If AVPlayer is public, use it directly:**

```swift
// In your view or controller
if let avPlayer = customVideoPlayer.player {
    sharePlayManager.registerPlayer(avPlayer, delegate: self)
}
```

**Step 3: If AVPlayer is private, make it public:**

```swift
// In your player wrapper class
public class VideoPlayer {
    public let player: AVPlayer  // Change from private/let to public let

    init() {
        self.player = AVPlayer()
        // ...
    }
}
```

**Step 4: If you don't control the library:**

- Fork the library and expose `AVPlayer`
- Use runtime introspection (not recommended, fragile)
- Contact library maintainers to expose `AVPlayer`

**⚠️ CRITICAL: Never Use Key-Value Coding (KVC)**

**DO NOT use `value(forKey:)` to access private properties - this will crash with `SIGABRT`:**

```swift
// ❌ CRASHES - Don't use KVC!
if let directPlayer = (videoPlayer as? AnyObject)?.value(forKey: "player") as? AVPlayer {
    player = directPlayer  // SIGABRT crash here!
}
```

**Why it crashes:**

- `value(forKey:)` requires the property to be KVC-compliant (must be `@objc` and accessible)
- Private/internal properties are not KVC-compliant
- The runtime throws an exception when accessing non-existent or non-compliant keys
- This exception becomes a `SIGABRT` crash

**Safer Alternative: Mirror Reflection (If You Must Access Private Properties)**

If you absolutely cannot modify the library and need to access a private `AVPlayer`, use Swift's `Mirror` reflection instead of KVC. This is safer but still fragile:

```swift
// ✅ SAFER - Uses Mirror reflection (no crashes, but still fragile)
func findAVPlayer(in videoPlayer: Any) -> AVPlayer? {
    let mirror = Mirror(reflecting: videoPlayer)

    // Try common property names
    let propertyNames = ["player", "avPlayer", "_player", "_avPlayer"]

    for child in mirror.children {
        if let label = child.label,
           propertyNames.contains(label),
           let player = child.value as? AVPlayer {
            return player
        }
    }

    // Fallback: search for any AVPlayer property
    for child in mirror.children {
        if child.value is AVPlayer {
            return child.value as? AVPlayer
        }
    }

    // Debug: print available properties if not found
    print("⚠️ AVPlayer not found in VideoPlayer")
    print("Available properties: \(mirror.children.map { $0.label ?? "unnamed" })")

    return nil
}

// Usage
if let player = findAVPlayer(in: videoPlayer) {
    sharePlayManager.registerPlayer(player, delegate: delegate)
} else {
    print("❌ Could not find AVPlayer in VideoPlayer wrapper")
}
```

**Why Mirror is safer than KVC:**

- ✅ No crashes - returns `nil` if property doesn't exist
- ✅ Works with any property visibility (private, internal, public)
- ✅ Can inspect all properties to find the right one
- ✅ Provides debug information when property isn't found

**Still, the best solutions are (in order of preference):**

1. **Make the property public** (if you control the library)
2. **Add a public accessor method** (if you control the library)
3. **Contact library maintainers** to expose `AVPlayer`
4. **Fork the library** (if open source)
5. **Use Mirror reflection** (last resort - fragile, may break with library updates)

### 9.3 Registering Wrapped Players

**Pattern 1: Direct Access (Simplest)**

If your wrapper exposes `AVPlayer` and you have access in your view:

```swift
struct ImmersiveView: View {
    @Environment(AppState.self) private var appState
    let videoPlayer: VideoPlayer  // Your custom wrapper

    var body: some View {
        RealityView { content, attachments in
            // Your content
        }
        .onAppear {
            // Register the underlying AVPlayer
            appState.sharePlayManager.registerPlayer(
                videoPlayer.player,  // Extract AVPlayer from wrapper
                delegate: playbackDelegate
            )
        }
    }
}
```

**Pattern 2: Custom Attachment Hook (For Library Players)**

If your player is created inside a library component (like OpenImmersive's `ImmersivePlayer`), use a custom attachment:

```swift
// Library gives you access to player via attachment callback
let sharePlayAttachment = CustomAttachment(
    id: "SharePlayCoordinator",
    body: { $videoPlayer in  // Library provides player here
        Color.clear  // Invisible view
            .frame(width: 0, height: 0)
            .onAppear {
                // NOW we can access the player
                appState.sharePlayManager.registerPlayer(
                    videoPlayer.player,  // Extract AVPlayer
                    delegate: playbackDelegate
                )
                print("✅ AVPlayer registered for SharePlay")
            }
    },
    position: [0, 0, 0],
    orientation: simd_quatf(angle: 0, axis: [1, 0, 0]),
    relativeToControlPanel: false
)

// Pass to library component
ImmersivePlayer(
    selectedStream: stream,
    customAttachments: [sharePlayAttachment]
)
```

**Pattern 3: Delegate Pattern**

If your player wrapper has a delegate system:

```swift
// In your player wrapper
protocol VideoPlayerDelegate: AnyObject {
    func playerDidBecomeReady(_ player: AVPlayer)
}

class VideoPlayer {
    weak var delegate: VideoPlayerDelegate?
    private let avPlayer: AVPlayer

    init() {
        self.avPlayer = AVPlayer()
        // Notify when ready
        DispatchQueue.main.async {
            self.delegate?.playerDidBecomeReady(self.avPlayer)
        }
    }
}

// In your view/controller
extension AppState: VideoPlayerDelegate {
    func playerDidBecomeReady(_ player: AVPlayer) {
        sharePlayManager.registerPlayer(player, delegate: playbackDelegate)
    }
}
```

### 9.4 Required: AVPlayerPlaybackCoordinatorDelegate

**⚠️ CRITICAL**: You MUST provide a delegate when registering the player.

**Error you'll see:**

```
Missing argument for parameter 'delegate' in call
```

**Minimal implementation:**

```swift
@MainActor
class PlaybackCoordinatorDelegate: NSObject, AVPlayerPlaybackCoordinatorDelegate {
    // All methods are optional - empty class works!
    // AVFoundation handles sync automatically

    // Optional: Show waiting UI
    func playbackCoordinator(
        _ coordinator: AVPlayerPlaybackCoordinator,
        didIssue suspensionReasonsThatTriggerWaiting: [AVCoordinatedPlaybackSuspension.Reason]
    ) {
        print("⏸️ Waiting for other participants...")
        // Show "Buffering..." UI if desired
    }
}

// Use it when registering
let playbackDelegate = PlaybackCoordinatorDelegate()
sharePlayManager.registerPlayer(player, delegate: playbackDelegate)
```

**Important**: Don't implement `identifierFor` - it's optional and causes concurrency warnings (see section 7.4).

### 9.5 Registration Timing

**When to register:**

1. **Before playback starts** - Register in `.onAppear` or when player is ready
2. **After player item is set** - Don't register before `AVPlayerItem` is assigned
3. **Once per player instance** - Don't re-register if player is reused

**Example lifecycle:**

```swift
struct ImmersiveView: View {
    @State private var playerRegistered = false

    var body: some View {
        RealityView { content, attachments in
            // Setup
        }
        .onAppear {
            if !playerRegistered, let player = videoPlayer.player {
                sharePlayManager.registerPlayer(player, delegate: delegate)
                playerRegistered = true
            }
        }
    }
}
```

### 9.6 Common Pitfalls

**Pitfall 1: Registering too early**

```swift
// ❌ WRONG - Player item not set yet
let player = AVPlayer()
sharePlayManager.registerPlayer(player, delegate: delegate)
player.replaceCurrentItem(with: playerItem)  // Too late!

// ✅ CORRECT - Register after item is set
let player = AVPlayer()
player.replaceCurrentItem(with: playerItem)
sharePlayManager.registerPlayer(player, delegate: delegate)
```

**Pitfall 2: Re-registering on every view update**

```swift
// ❌ WRONG - Registers multiple times
var body: some View {
    RealityView { content, attachments in
        sharePlayManager.registerPlayer(player, delegate: delegate)  // Called every update!
    }
}

// ✅ CORRECT - Register once
var body: some View {
    RealityView { content, attachments in
        // Setup
    }
    .onAppear {
        sharePlayManager.registerPlayer(player, delegate: delegate)  // Once
    }
}
```

**Pitfall 3: Forgetting the delegate parameter**

```swift
// ❌ WRONG - Missing delegate
sharePlayManager.registerPlayer(player)  // Compiler error!

// ✅ CORRECT - Include delegate
let delegate = PlaybackCoordinatorDelegate()
sharePlayManager.registerPlayer(player, delegate: delegate)
```



**For basic video player integration, see [Video Player Sync](../2-Core-Integration/02-Video-Player-Sync.md).**
