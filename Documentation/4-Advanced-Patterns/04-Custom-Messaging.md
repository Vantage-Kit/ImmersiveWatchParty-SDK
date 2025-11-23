[← Back to Documentation Home](../README.md) | [← Previous: Settings Sync](03-Settings-Sync.md)

# 13. Custom Message Handling

### 13.1 Define Custom Messages

All custom messages must conform to `Codable` and should include:

- `senderUUID: UUID` - identifies who sent the message
- `timestamp: Date` - for ordering and deduplication
- Your custom data fields

```swift
import Foundation
import ImmersiveWatchParty

// Example: Navigation synchronization message
struct NavigationMessage: Codable, Equatable {
    let eventID: UUID?
    let action: NavigationAction
    let senderUUID: UUID

    enum NavigationAction: String, Codable {
        case push
        case pop
        case pushDetail
    }
}

// Example: Playback control message (for mock SharePlay only)
// NOTE: In real SharePlay, AVPlayerPlaybackCoordinator handles this automatically
struct PlaybackControlMessage: Codable, Equatable {
    enum Action: String, Codable {
        case play
        case pause
        case skipForward15
        case skipBackward15
        case seekToTime
    }

    let action: Action
    let targetTime: Double?
    let senderUUID: UUID
    let timestamp: Date
}

// Example: Participant viewing state tracking
struct VideoViewingStateMessage: Codable, Equatable {
    enum State: String, Codable {
        case started
        case stopped
    }

    let eventID: UUID
    let fightID: UUID
    let state: State
    let senderUUID: UUID
    let timestamp: Date
}

// Example: Group coordination message
struct GroupExitImmersiveSpaceMessage: Codable, Equatable {
    let eventID: UUID
    let senderUUID: UUID
    let timestamp: Date
}
```

**Note**: All messages must conform to `Codable`. Including a `senderUUID: UUID` field is recommended as a best practice to identify message senders and filter out your own messages.

### 13.2 Send Messages

**Method 1: Via Environment (Recommended in Views)**

```swift
struct ControlView: View {
    @Environment(\.sharePlayMessenger) private var messenger
    @Environment(AppState.self) private var appState

    var body: some View {
        Button("Navigate to Event") {
            Task {
                let message = NavigationMessage(
                    eventID: currentEventID,
                    action: .push,
                    senderUUID: appState.localUUID
                )

                do {
                    try await messenger.send(message)
                    print("✅ Message sent")
                } catch {
                    print("❌ Failed to send: \(error)")
                }
            }
        }
    }
}
```

**Method 2: Via Manager (In Controllers/State)**

```swift
class SessionController {
    let partyManager: ImmersiveWatchPartyManager
    let localUUID: UUID

    func sendNavigationMessage(eventID: UUID, action: NavigationAction) {
        let message = NavigationMessage(
            eventID: eventID,
            action: action,
            senderUUID: localUUID
        )

        Task {
            do {
                try await partyManager.messageManager.send(message)
                print("📤 Sent navigation message")
            } catch {
                print("❌ Message send failed: \(error)")
            }
        }
    }
}
```

### 13.3 Receive Messages

**Method 1: Using `.onSharePlayMessage()` Modifier (Recommended)**

```swift
struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            // Your navigation content
        }
        .onSharePlayMessage(
            of: NavigationMessage.self,
            messenger: appState.sharePlayManager.messenger
        ) { message in
            // Handle the navigation message
            await handleNavigationMessage(message)
        }
        .onSharePlayMessage(
            of: VideoViewingStateMessage.self,
            messenger: appState.sharePlayManager.messenger
        ) { message in
            await handleViewingStateMessage(message)
        }
    }

    private func handleNavigationMessage(_ message: NavigationMessage) async {
        guard message.senderUUID != appState.localUUID else {
            // Ignore our own messages
            return
        }

        switch message.action {
        case .push:
            if let eventID = message.eventID {
                // Navigate to event
            }
        case .pop:
            path.removeLast()
        case .pushDetail:
            // Navigate to detail
        }
    }
}
```

**Method 2: Manual Listener Registration**

```swift
class AppState {
    private var messageTokens: [MessageListenerToken] = []

    func setupMessageListeners() {
        // Listen for navigation messages
        let navToken = sharePlayManager.messageManager.listen(
            for: NavigationMessage.self
        ) { [weak self] message in
            await self?.handleNavigationMessage(message)
        }
        messageTokens.append(navToken)

        // Listen for viewing state messages
        let stateToken = sharePlayManager.messageManager.listen(
            for: VideoViewingStateMessage.self
        ) { [weak self] message in
            await self?.handleViewingStateMessage(message)
        }
        messageTokens.append(stateToken)
    }

    // CRITICAL: Remove listeners on cleanup
    deinit {
        for token in messageTokens {
            sharePlayManager.messageManager.removeListener(token)
        }
        messageTokens.removeAll()
    }
}
```

### 13.4 Message Best Practices

**1. Always Include sender UUID**

```swift
// ✅ Good
struct MyMessage: Codable {
    let senderUUID: UUID
    let data: String
}

// ❌ Bad - no way to identify sender
struct MyMessage: Codable {
    let data: String
}
```

**2. Filter Out Your Own Messages**

```swift
.onSharePlayMessage(of: MyMessage.self, messenger: messenger) { message in
    guard message.senderUUID != localUUID else {
        return  // Don't process our own messages
    }
    await handleMessage(message)
}
```

**3. Handle Message Send Failures Gracefully**

```swift
do {
    try await messenger.send(message)
} catch {
    // Show user-friendly error
    showAlert("Unable to sync with others. Check your connection.")
}
```

**4. Avoid Sending Playback Control Messages in Real SharePlay**

```swift
func sendPlaybackControlMessage(action: Action) {
    // Only send manual messages in mock SharePlay
    // Real SharePlay uses AVPlayerPlaybackCoordinator automatically
    guard isUsingMockSharePlay else { return }

    let message = PlaybackControlMessage(
        action: action,
        senderUUID: localUUID,
        timestamp: Date()
    )
    sendMessage(message)
}
```

**5. Use Timestamps for Deduplication**

```swift
private var lastProcessedTimestamp: [UUID: Date] = [:]

func handleMessage(_ message: MyMessage) {
    // Check if we've already processed a newer message from this sender
    if let lastTime = lastProcessedTimestamp[message.senderUUID],
       message.timestamp <= lastTime {
        print("⏭️ Skipping old/duplicate message")
        return
    }

    lastProcessedTimestamp[message.senderUUID] = message.timestamp
    // Process message...
}
```



**⚠️ CRITICAL SECURITY**: For information about UUID spoofing vulnerabilities, see [UUID Spoofing Prevention](../5-Security-And-Best-Practices/02-UUID-Spoofing-Prevention.md).**
