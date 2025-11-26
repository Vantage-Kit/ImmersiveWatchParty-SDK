[← Back to Documentation Home](../README.md) | [← Previous: App Lifecycle Setup](01-App-Lifecycle-Setup.md) | [Next: Immersive Space Coordination →](03-Immersive-Space-Coordination.md)

# 8. Video Player Integration

### 8.1 Coordinate Video Playback

**⚠️ CRITICAL**: AVPlayer coordination is what syncs play/pause/seek across devices.

**Method 1: Using the Modifier (Recommended)**

```swift
struct ImmersiveVideoView: View {
    @Environment(AppState.self) private var appState
    @Binding var videoPlayer: VideoPlayer  // Your custom player wrapper

    var body: some View {
        RealityView { content, attachments in
            // Your RealityKit content
        } attachments: {
            Attachment(id: "video") {
                // Show AVPlayer UI here if needed
            }
        }
        // CRITICAL: Coordinate player with SharePlay
        .coordinateSharePlay(
            partyManager: appState.sharePlayManager,
            player: videoPlayer.player,  // The actual AVPlayer instance
            delegate: videoPlayer  // Your player conforms to AVPlayerPlaybackCoordinatorDelegate
        )
    }
}
```

**Method 2: Manual Registration**

> **Architectural Note**: To ensure correct coordinate space synchronization with Spatial Personas, this SDK is designed for RealityKit. We recommend rendering video using VideoMaterial on a ModelEntity rather than using high-level SwiftUI player views.

```swift
struct VideoPlayerView: View, AVPlayerPlaybackCoordinatorDelegate {
    @Environment(AppState.self) private var appState
    let player: AVPlayer

    var body: some View {
        RealityView { content in
            let root = Entity()
            content.add(root)
            
            // Create a screen mesh (16:9 aspect ratio)
            let screenMesh = MeshResource.generatePlane(width: 1.6, height: 0.9)
            
            // Create video material
            let videoMaterial = VideoMaterial(avPlayer: player)
            let screenEntity = ModelEntity(mesh: screenMesh, materials: [videoMaterial])
            root.addChild(screenEntity)
        }
        .onAppear {
            // Register player for SharePlay coordination
            appState.sharePlayManager.registerPlayer(
                player,
                delegate: self
            )
        }
    }

    // OPTIONAL: Implement delegate methods for notifications
    func playbackCoordinator(
        _ coordinator: AVPlayerPlaybackCoordinator,
        didIssue suspensionReasonsThatTriggerWaiting: [AVCoordinatedPlaybackSuspension.Reason]
    ) {
        print("⏸️ Waiting for other participants...")
        // Show UI indicator that we're waiting
    }

    func playbackCoordinator(
        _ coordinator: AVPlayerPlaybackCoordinator,
        didFinishBufferingForPlayerItem playerItem: AVPlayerItem
    ) {
        print("✅ Buffering complete, synchronized playback resuming")
    }
}
```

### 8.2 Important: Resume Position Handling

**⚠️ WARNING**: Resume position conflicts with SharePlay coordination!

```swift
func openStream(_ stream: StreamModel) {
    let playerItem = AVPlayerItem(url: stream.url)
    player.replaceCurrentItem(with: playerItem)

    // CRITICAL: Only seek if NOT in SharePlay session
    // SharePlay coordinator will handle timing
    if let resumePosition = appState.resumePosition,
       resumePosition > 0,
       !appState.sharePlayManager.sharePlayEnabled {

        // Wait for player to be ready
        var observer: NSKeyValueObservation?
        observer = playerItem.observe(\.status) { item, _ in
            if item.status == .readyToPlay {
                DispatchQueue.main.async {
                    let seekTime = CMTime(seconds: resumePosition, preferredTimescale: 1000)
                    self.player.seek(to: seekTime)
                    observer?.invalidate()
                }
            }
        }
    } else if appState.sharePlayManager.sharePlayEnabled {
        print("🔄 Skipping resume position - SharePlay coordinator will handle timing")
        appState.resumePosition = 0  // Clear it
    }
}
```

**Why this matters:**

- If you seek while SharePlay is active, you desync from other participants
- The `AVPlayerPlaybackCoordinator` manages timing automatically
- Always check `sharePlayEnabled` before manual seeks

### 8.3 Handling Playback Coordinator Delegate Events

Implement these for better UX:

```swift
extension VideoPlayer: AVPlayerPlaybackCoordinatorDelegate {

    // Called when playback is suspended waiting for others
    func playbackCoordinator(
        _ coordinator: AVPlayerPlaybackCoordinator,
        didIssue suspensionReasonsThatTriggerWaiting: [AVCoordinatedPlaybackSuspension.Reason]
    ) {
        Task { @MainActor in
            // Show "Waiting for others..." UI
            self.showWaitingIndicator = true
        }
    }

    // Called when another participant changes rate (play/pause)
    func playbackCoordinator(
        _ coordinator: AVPlayerPlaybackCoordinator,
        rateDidChange rate: Float
    ) {
        let action = rate == 0 ? "paused" : "played"
        print("📺 Another participant \(action) the video")

        // Show notification: "Friend paused the video"
        displayPlaybackAdjustmentNotification(action: action)
    }

    // Called when finished buffering after a seek
    func playbackCoordinator(
        _ coordinator: AVPlayerPlaybackCoordinator,
        didFinishBufferingForPlayerItem playerItem: AVPlayerItem
    ) {
        Task { @MainActor in
            self.showWaitingIndicator = false
        }
    }
}
```



**For advanced concurrency patterns, see [Concurrency Safety](../5-Security-And-Best-Practices/03-Concurrency-Safety.md).**

**For custom player wrappers, see [Custom Player Wrappers](../4-Advanced-Patterns/01-Custom-Player-Wrappers.md).**
