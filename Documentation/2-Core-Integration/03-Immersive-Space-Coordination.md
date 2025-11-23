[← Back to Documentation Home](../README.md) | [← Previous: Video Player Sync](02-Video-Player-Sync.md) | [Next: Participant Management →](04-Participant-Management.md)

### 16.1 Leave vs. End Session

**Important distinction:**

- **Leave**: Current user exits, session continues for others
- **End**: Session terminates for everyone

```swift
class SessionController {
    func leaveSharePlay() {
        partyManager.leaveSharePlay()
        print("📤 Left SharePlay (local user only)")
    }

    func endSharePlay() {
        partyManager.endSharePlay()
        print("🛑 Ended SharePlay for everyone")
    }
}

// In your UI
Button("Leave Watch Party") {
    sessionController.leaveSharePlay()
}

Button("End for All") {
    sessionController.endSharePlay()
}
.foregroundColor(.red)
```


### 16.2 Group Exit Coordination

**Problem**: When one user exits immersive space during SharePlay, others should too.

**Solution**: Send a group exit message:

```swift
// Message definition
struct GroupExitImmersiveSpaceMessage: Codable, Equatable {
    let eventID: UUID
    let senderUUID: UUID
    let timestamp: Date
}

// Sending the message
func initiateGroupExit(eventID: UUID) {
    let message = GroupExitImmersiveSpaceMessage(
        eventID: eventID,
        senderUUID: localUUID,
        timestamp: Date()
    )

    // CRITICAL: Pause video immediately in real SharePlay
    // This ensures video stops before space disappears
    if isUsingRealSharePlay, let videoPlayer = videoPlayer, !videoPlayer.paused {
        videoPlayer.pause()
    }

    Task {
        try? await messenger.send(message)
    }
}

// Receiving the message
.onSharePlayMessage(
    of: GroupExitImmersiveSpaceMessage.self,
    messenger: messenger
) { message in
    guard message.senderUUID != localUUID else { return }

    // Another participant is exiting - we should too
    await dismissImmersiveSpace()
}
```


### 16.5 Handling Immersive Space Rejoin

**Problem**: Resume position conflicts with SharePlay when rejoining video.

**Solution**: Skip resume position during active SharePlay:

```swift
func openStream(_ stream: StreamModel) {
    let playerItem = AVPlayerItem(url: stream.url)
    player.replaceCurrentItem(with: playerItem)

    // Check if we should seek to resume position
    if let resumePosition = appState.resumePosition,
       resumePosition > 0 {

        // Only seek if NOT in SharePlay
        if !sharePlayManager.sharePlayEnabled {
            // Safe to seek - no coordination needed
            seekToResumePosition(resumePosition, for: playerItem)
        } else {
            print("🔄 Skipping resume - SharePlay coordinator manages timing")
            appState.resumePosition = 0  // Clear it
        }
    }
}
```

