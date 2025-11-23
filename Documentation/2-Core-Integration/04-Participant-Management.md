[← Back to Documentation Home](../README.md) | [← Previous: Immersive Space Coordination](03-Immersive-Space-Coordination.md) | [Next: Smart Play Button →](05-Smart-Play-Button.md)

## 14. Participant Tracking

### 14.1 Observe Participants

The manager automatically tracks participants. Access them via:

```swift
@Environment(AppState.self) private var appState

var body: some View {
    VStack {
        Text("Participants: \(appState.sharePlayManager.activeParticipantUUIDs.count)")

        ForEach(Array(appState.sharePlayManager.activeParticipantUUIDs), id: \.self) { uuid in
            Text("Participant: \(uuid.uuidString)")
        }
    }
}
```

### 14.2 Track Join/Leave Events via Delegate

The join/leave events are handled automatically in the delegate methods (shown earlier in section 3.2):

```swift
// These are already part of ImmersiveWatchPartyDelegate
func sessionManager(
    _ manager: ImmersiveWatchPartyManager,
    participantDidJoin participantUUID: UUID
) {
    print("👤 \(participantUUID) joined")
    // Show notification, update UI, track analytics
}

func sessionManager(
    _ manager: ImmersiveWatchPartyManager,
    participantDidLeave participantUUID: UUID
) {
    print("👋 \(participantUUID) left")
    // Update participant list, check if last person
}
```



### 16.3 Participant Viewing State Tracking

**Use case**: Track which users are watching which videos.

```swift
// State tracking in SessionController
@Published var participantsViewingState: [UUID: ViewingState?] = [:]

struct ViewingState: Equatable {
    let eventID: UUID
    let fightID: UUID
}

// Send when entering video
func sendVideoViewingStateMessage(
    eventID: UUID,
    fightID: UUID,
    state: VideoViewingStateMessage.State
) {
    let message = VideoViewingStateMessage(
        eventID: eventID,
        fightID: fightID,
        state: state,
        senderUUID: localUUID,
        timestamp: Date()
    )

    Task {
        try? await messenger.send(message)
    }
}

// Handle received messages
.onSharePlayMessage(
    of: VideoViewingStateMessage.self,
    messenger: messenger
) { message in
    if message.state == .started {
        participantsViewingState[message.senderUUID] = ViewingState(
            eventID: message.eventID,
            fightID: message.fightID
        )
    } else {
        participantsViewingState[message.senderUUID] = nil
    }
}

// Check if anyone is watching a specific video
func isAnyoneWatchingVideo(eventID: UUID, fightID: UUID) -> Bool {
    return participantsViewingState.contains { _, viewingState in
        guard let state = viewingState else { return false }
        return state.eventID == eventID && state.fightID == fightID
    }
}
```


### 16.6 Analytics Integration

Track SharePlay usage for insights:

```swift
// In delegate methods
func sessionManager(_ manager: ImmersiveWatchPartyManager, didHostSession sessionID: String) {
    AnalyticsManager.shared.logWatchPartySessionStarted(
        sessionId: sessionID,
        hostUserId: getCurrentUserId()
    )
}

func sessionManager(
    _ manager: ImmersiveWatchPartyManager,
    participantDidJoin participantUUID: UUID
) {
    guard let sessionId = manager.sharePlaySessionID?.uuidString else { return }

    AnalyticsManager.shared.logUserJoinedParty(
        partyId: sessionId,
        joiningUserId: participantUUID.uuidString,
        totalParticipants: manager.activeParticipantUUIDs.count
    )
}

func sessionManagerDidInvalidate(_ manager: ImmersiveWatchPartyManager) {
    guard let sessionId = manager.sharePlaySessionID?.uuidString,
          let startTime = manager.sessionStartTime else { return }

    let duration = Int(Date().timeIntervalSince(startTime))
    let peakCount = manager.peakParticipantCount

    AnalyticsManager.shared.logWatchPartySessionEnded(
        sessionId: sessionId,
        sessionDurationSeconds: duration,
        peakParticipantCount: peakCount
    )
}
```
