[← Back to Documentation Home](../README.md) | [Next: Migration Guide →](02-Migration-Guide.md)

### 16.7 Error Handling & Recovery

Handle common SharePlay errors gracefully:

```swift
// Message send failure
do {
    try await messenger.send(message)
} catch {
    if sharePlayManager.sharePlayEnabled {
        // Still in session but message failed - show warning
        showWarning("Unable to sync with others. Your changes may not be visible to them.")
    }
    // If not in session, silently fail (expected behavior)
}

// Session activation failure
switch await activity.prepareForActivation() {
case .activationPreferred:
    do {
        _ = try await activity.activate()
    } catch {
        showError("Unable to start SharePlay. Please check your FaceTime connection.")
    }

case .activationDisabled:
    showError("SharePlay is disabled. Enable it in Settings > FaceTime.")

case .cancelled:
    // User intentionally cancelled - no error needed
    break
}
```



# 19. Troubleshooting

### Debugging Decision Tree

**Use this decision tree to quickly identify what's wrong:**

#### SharePlay Not Activating?

```
├─ Check: Did you add Group Activities capability?
│  → Xcode → Target → Signing & Capabilities → + → Group Activities
├─ Check: Is NSGroupActivitiesUsageDescription in Info.plist?
│  → Key: "NSGroupActivitiesUsageDescription"
│  → Value: "We use SharePlay to watch videos together"
├─ Check: Are you on a real device (not Simulator)?
│  → SharePlay doesn't work in Simulator
├─ Check: Is FaceTime call active?
│  → SharePlay requires active FaceTime call
└─ Check: Console logs - what's the last message you see?
   → Look for "❌" or "Failed" messages
```

#### Player Not Syncing?

```
├─ Check: Did registerPlayer() get called?
│  → Add print("✅ AVPlayer registered") in registration
├─ Check: Is it called BEFORE video starts playing?
│  → Register in .onAppear, not after playback starts
├─ Check: Is sharePlayEnabled true?
│  → Print: appState.sharePlayManager.sharePlayEnabled
└─ Check: Do you see AVPlayerPlaybackCoordinator logs?
   → Look for "coordinator" messages in console
```

#### Green Handlebar Not Appearing?

```
├─ Check: Is .groupActivityAssociation() on VIEW (not Scene)?
│  → WindowGroup { ContentView().groupActivityAssociation(...) } ✅
│  → WindowGroup { ContentView() }.groupActivityAssociation(...) ❌
├─ Check: Did you add it to BOTH WindowGroup and ImmersiveSpace?
│  → Both need the modifier
├─ Check: Are the IDs different for each?
│  → .primary("main-window") vs .primary("immersive-space")
└─ Check: Is .environment(\.sharePlayMessenger) injected?
   → Both scenes need this environment value
```

#### Late Joiners Don't Load Video?

```
├─ Check: Is sessionManager(received:activity) called?
│  → Add print("📱 Received activity") in delegate
├─ Check: Are you returning true from the delegate?
│  → Return false = session rejected
├─ Check: Does your GroupActivity have all necessary data?
│  → Video URL, title, settings, etc.
└─ Check: Does conversion from GroupActivity work?
   → Test createStream(from: activity) separately
```

### Build Errors

#### "Cannot find type 'SharePlayMessenger'"

**Cause**: Wrong package product imported

**Solution**:

- Import `ImmersiveWatchParty` (NOT `ImmersiveWatchPartyCore`)
- In Package.swift: `dependencies: ["ImmersiveWatchParty"]`
- In files: `import ImmersiveWatchParty`

#### "'JoinFailureReason' is not a member type"

**Error:**

```
'JoinFailureReason' is not a member type of class 'ImmersiveWatchPartyCore.ImmersiveWatchPartyManager'
```

**Causes:**

1. Importing `ImmersiveWatchPartyCore` instead of `ImmersiveWatchParty`
2. Trying to access it as a nested type (e.g., `ImmersiveWatchPartyManager.JoinFailureReason`)

**Solution:**

**Step 1: Check your import statement**

```swift
// ❌ WRONG - Don't import ImmersiveWatchPartyCore
import ImmersiveWatchPartyCore

// ✅ CORRECT - Import ImmersiveWatchParty
import ImmersiveWatchParty
```

**Step 2: Use `JoinFailureReason` as a top-level type**

`JoinFailureReason` is a **top-level enum** in the `ImmersiveWatchParty` module, not a nested type. Use it directly:

```swift
// ✅ CORRECT - Use JoinFailureReason directly
extension AppState: ImmersiveWatchPartyDelegate {
    func sessionManager(
        _ manager: ImmersiveWatchPartyManager,
        didFailToJoin reason: JoinFailureReason  // ✅ Direct usage
    ) {
        switch reason {
        case .participantLimitExceeded:
            // Handle participant limit
        case .sessionTimeLimitExceeded:
            // Handle time limit
        case .activationRequired:
            // Handle activation requirement
        }
    }
}
```

**Common Mistakes:**

```swift
// ❌ WRONG - Don't try to access it as nested
func sessionManager(
    _ manager: ImmersiveWatchPartyManager,
    didFailToJoin reason: ImmersiveWatchPartyManager.JoinFailureReason  // ❌
) { }

// ❌ WRONG - Don't use module prefix
func sessionManager(
    _ manager: ImmersiveWatchPartyManager,
    didFailToJoin reason: ImmersiveWatchParty.JoinFailureReason  // ❌ Unnecessary
) { }

// ✅ CORRECT - Just use the type name directly
func sessionManager(
    _ manager: ImmersiveWatchPartyManager,
    didFailToJoin reason: JoinFailureReason  // ✅ Simple and correct
) { }
```

**If you still get errors:**

1. **Verify your import**: Make sure you have `import ImmersiveWatchParty` at the top of your file
2. **Check Package.swift**: Ensure you're depending on `ImmersiveWatchParty`, not `ImmersiveWatchPartyCore`
3. **Clean build**: In Xcode, press `Cmd+Shift+K` to clean, then rebuild
4. **Check module name**: The error message shows which module Xcode thinks you're using. If it says `ImmersiveWatchPartyCore`, you're importing the wrong module

**Complete Example:**

```swift
import SwiftUI
import ImmersiveWatchParty  // ✅ Correct import
import AVFoundation

@MainActor
@Observable
class AppState: ImmersiveWatchPartyDelegate {
    let sharePlayManager: ImmersiveWatchPartyManager

    init() {
        self.sharePlayManager = ImmersiveWatchPartyManager(localUUID: UUID())
        self.sharePlayManager.delegate = self
    }
}

extension AppState {
    func sessionManager(
        _ manager: ImmersiveWatchPartyManager,
        didFailToJoin reason: JoinFailureReason  // ✅ Works because of import ImmersiveWatchParty
    ) {
        switch reason {
        case .participantLimitExceeded:
            showAlert("Participant limit reached. Upgrade to Pro for unlimited participants.")
        case .sessionTimeLimitExceeded:
            showAlert("Session time limit reached. Upgrade to Pro for unlimited duration.")
        case .activationRequired:
            // This case exists but is not currently used by the package
            break
        }
    }
}
```

#### "'Seat' is only available in visionOS 2.0 or newer"

**Cause**: Using systemCoordinator features on visionOS 1.0

**Solution**: Already handled by the package with `@available` checks. Update to latest package version.

#### "Type 'WatchTogetherActivity' does not conform to protocol 'GroupActivity'"

**Cause**: Missing required `metadata` property or `activityIdentifier`

**Solution**:

```swift
struct WatchTogetherActivity: GroupActivity {
    static let activityIdentifier = "com.yourapp.watch"  // REQUIRED

    var metadata: GroupActivityMetadata {  // REQUIRED
        var meta = GroupActivityMetadata()
        meta.title = "Watch Together"
        meta.type = .watchTogether
        return meta
    }
}
```

#### "Conformance crosses into main actor-isolated code" (AVPlayerPlaybackCoordinatorDelegate)

**Full Error**:

```
Conformance of 'MyDelegate' to protocol 'AVPlayerPlaybackCoordinatorDelegate'
crosses into main actor-isolated code and can cause data races
```

**Cause**: Implementing `identifierFor` method in a `@MainActor` class

**Solution**: Don't implement `identifierFor` - it's optional! See section 7.4 for details.

```swift
@MainActor
class VideoPlayer: NSObject, AVPlayerPlaybackCoordinatorDelegate {
    // Don't implement identifierFor!
    // Only implement methods you actually need
}
```

#### "@MainActor Isolation Errors"

**Error 1:**

```
Call to main actor-isolated initializer 'init(localUUID:)' in a synchronous nonisolated context
Main actor-isolated property 'delegate' can not be mutated from a nonisolated context
```

**Cause**: App state class not marked `@MainActor`

**Solution**: Add `@MainActor` to your app state class:

```swift
@Observable
@MainActor  // ✅ Add this
class AppState {
    let sharePlayManager: ImmersiveWatchPartyManager
    // ...
}
```

**Error 2:**

```
Protocol requires function 'sessionManager(_:received:)' with type
'(ImmersiveWatchPartyManager, received: some GroupActivity) async -> Bool'
```

**Cause**: Using `any` instead of `some` in protocol conformance

**Solution**: Use `some GroupActivity`:

```swift
// ❌ WRONG
func sessionManager(
    _ manager: ImmersiveWatchPartyManager,
    received activity: any GroupActivity  // ❌
) async -> Bool

// ✅ CORRECT
func sessionManager(
    _ manager: ImmersiveWatchPartyManager,
    received activity: some GroupActivity  // ✅
) async -> Bool
```

**Error 3:**

```
Sending 'stream' risks causing data races
```

**Cause**: Passing data directly from async delegate to `openImmersiveSpace`

**Solution**: Store in `@MainActor` state first, then open:

```swift
// ❌ WRONG
func sessionManager(...) async -> Bool {
    let stream = createStream(from: activity)
    await openImmersiveSpace(value: stream)  // ❌ Data race!
}

// ✅ CORRECT
// In AppState (which conforms to ImmersiveWatchPartyDelegate)
func sessionManager(...) async -> Bool {
    let stream = createStream(from: activity)
    selectedStream = stream  // Store first
    await openImmersiveSpaceForSharePlay(with: stream)  // Then open
}
```

See section 7.5 for more Swift concurrency patterns.

### SharePlay Not Activating

#### SharePlay Sheet Never Appears

**Checklist:**

1. ✅ Added **Group Activities** capability in Xcode → Target → Signing & Capabilities
2. ✅ Added `NSGroupActivitiesUsageDescription` to Info.plist
3. ✅ Using real device (SharePlay doesn't work in Simulator)
4. ✅ Device is signed into FaceTime
5. ✅ SharePlay is enabled in Settings → FaceTime

#### Activity.prepareForActivation() Returns .activationDisabled

**Cause**: SharePlay disabled in system settings

**Solution**:

- Go to Settings → FaceTime
- Enable SharePlay
- Restart app

#### Session Never Received in `sessions()` Loop

**Cause**: Not monitoring at app level or wrong activity type

**Solution**:

```swift
// MUST be in App struct, not in a view
.task {
    for await session in WatchTogetherActivity.sessions() {
        // Process session
    }
}
```

#### SharePlay Button Always Shows Even When Not in FaceTime Call

**Cause**: Not checking `GroupStateObserver.isEligibleForGroupSession` before showing SharePlay UI

**Solution**: Use `GroupStateObserver` to conditionally show SharePlay button:

```swift
@StateObject private var groupStateObserver = GroupStateObserver()

var body: some View {
    if groupStateObserver.isEligibleForGroupSession {
        // Show SharePlay button
    } else {
        // Show solo watch button
    }
}
```

See section 5.3 for complete implementation.

### Video Sync Issues

#### Video Plays But Not Synced Across Devices

**Cause**: Player not registered with coordination

**Solution**:

```swift
// In .onAppear or RealityView setup
appState.sharePlayManager.registerPlayer(player, delegate: self)

// OR use modifier
.coordinateSharePlay(partyManager: manager, player: player, delegate: self)
```

#### Video Desyncs When Seeking/Resume Position

**Cause**: Manual seek during active SharePlay session

**Solution**:

```swift
// Always check before seeking
if !sharePlayManager.sharePlayEnabled {
    player.seek(to: resumeTime)
} else {
    print("Skipping seek - SharePlay coordinator manages timing")
}
```

#### "Video is ahead/behind other participants"

**Cause**: Network latency or buffering differences

**Solution**: This is expected behavior. The `AVPlayerPlaybackCoordinator` will automatically resync. Implement delegate methods to show waiting UI:

```swift
func playbackCoordinator(
    _ coordinator: AVPlayerPlaybackCoordinator,
    didIssue suspensionReasonsThatTriggerWaiting: [AVCoordinatedPlaybackSuspension.Reason]
) {
    showWaitingIndicator()  // Show "Buffering..." to user
}
```

#### Swift Concurrency Error with AVPlayerPlaybackCoordinatorDelegate

**Error**:

```
Conformance of 'MyDelegate' to protocol 'AVPlayerPlaybackCoordinatorDelegate'
crosses into main actor-isolated code and can cause data races
```

**Cause**: The `identifierFor` method can be called from background threads, but your delegate class is marked `@MainActor`.

**Solution 1** (Recommended): Don't implement `identifierFor` at all - it's optional!

```swift
@MainActor
class VideoPlayer: NSObject, AVPlayerPlaybackCoordinatorDelegate {
    // Just omit the identifierFor method entirely
    // Only implement methods you actually need
}
```

**Solution 2**: If you must implement it, mark it `nonisolated`:

```swift
@MainActor
class VideoPlayer: NSObject, AVPlayerPlaybackCoordinatorDelegate {
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

See section 7.4 for detailed explanation.

### Attachment Positioning Issues

#### Attachments Not Appearing

**Cause**: Task cancelled prematurely or attachment IDs don't match

**Solution**:

```swift
// Store task as @State
@State private var attachmentTask: Task<Void, Never>?

// In RealityView
attachmentTask = manager.handleAttachmentUpdates(
    for: attachments,
    roles: ["controls": .controlPanel]  // ID must match
)

// In attachments block
Attachment(id: "controls") {  // MUST match "controls" above
    ControlPanel()
}
```

#### Attachments Position Correctly First Time But Break on Rejoin

**Cause**: Task not cancelled/restarted properly

**Solution**:

```swift
.onDisappear {
    attachmentTask?.cancel()
    attachmentTask = nil
}

// Task will automatically restart on next appear
```

#### Attachments Positioned Incorrectly in SharePlay

**Cause**: Coordinator not ready when positioning attempted

**Solution**: The package handles this automatically. The task waits for coordinator readiness. If still issues, implement delegate:

```swift
func sessionManagerDidBecomeReady(_ manager: ImmersiveWatchPartyManager) {
    print("✅ Coordinator ready - attachments will now position correctly")
}
```

### Message Handling Issues

#### Messages Sent But Not Received

**Causes & Solutions:**

1. **Not in same session**

   ```swift
   // Verify both devices show:
   if manager.sharePlayEnabled {
       print("✅ In SharePlay session")
       print("Participants: \(manager.activeParticipantUUIDs.count)")
   }
   ```

2. **Message type mismatch**

   ```swift
   // Sender and receiver MUST use identical type names
   struct MyMessage: Codable {  // Exact name matters!
       let data: String
   }
   ```

3. **Listener not registered**

   ```swift
   // Verify listener is set up
   let token = manager.messageManager.listen(for: MyMessage.self) { msg in
       print("📥 Received message")
   }
   // Keep token alive!
   ```

4. **Filtering own messages incorrectly**
   ```swift
   // Don't filter sender-side, filter receiver-side
   .onSharePlayMessage(of: MyMessage.self, messenger: messenger) { msg in
       guard msg.senderUUID != localUUID else { return }
       // Process
   }
   ```

#### Messages Received Multiple Times

**Cause**: Multiple listeners registered for same type

**Solution**:

```swift
// Store tokens and clean up
private var messageTokens: [MessageListenerToken] = []

deinit {
    for token in messageTokens {
        manager.messageManager.removeListener(token)
    }
}
```

### Participant Tracking Issues

#### Participant Count Always Shows 1

**Cause**: Not calling `updateParticipants()` or not observing session

**Solution**:

```swift
// In session monitoring
private func observeParticipants<A: GroupActivity>(session: GroupSession<A>) {
    Task {
        for await participants in session.$activeParticipants.values {
            let uuids = Set(participants.map { $0.id })
            manager.updateParticipants(uuids)  // CRITICAL
        }
    }
}
```

#### Participant UUIDs Don't Match Across Devices

**Cause**: Using device UUID instead of participant UUID

**Solution**:

```swift
// ✅ Correct - use participant UUIDs from session
let uuids = Set(participants.map { $0.id })

// ❌ Wrong - don't use device-generated UUIDs for tracking
let uuid = UUID()  // This will be different on each device
```

### Delegate Method Not Called

#### `sessionManager(received:activity)` Never Called

**Cause**: Coordinator not ready when activity arrives

**Solution**: The manager queues the activity and processes it when ready. Implement `sessionManagerDidBecomeReady`:

```swift
func sessionManagerDidBecomeReady(_ manager: ImmersiveWatchPartyManager) {
    // Pending activity will be processed automatically
}
```

#### `participantDidJoin` Not Firing

**Cause**: Not observing session participants

**Solution**: See "Participant Tracking Issues" above

### Performance Issues

#### App Laggy During SharePlay

**Cause**: Too many message sends or attachment updates

**Solution**:

- Debounce message sends
- Only send messages on significant state changes
- Use `.throttle()` on publishers

```swift
private var lastMessageTime: Date = .distantPast

func sendMessageDebounced(_ message: MyMessage) {
    let now = Date()
    guard now.timeIntervalSince(lastMessageTime) > 0.5 else {
        return  // Skip if sent recently
    }
    lastMessageTime = now
    Task { try? await messenger.send(message) }
}
```

### Integration Issues

#### `.groupActivityAssociation()` Compilation Errors

**Error 1**:

```
'modifier' is inaccessible due to 'internal' protection level
Struct 'SceneBuilder' requires that 'GroupActivityAssociationModifier' conform to '_SceneModifier'
```

**Cause**: Trying to apply `.groupActivityAssociation()` as a modifier on the Scene instead of the view content.

**Solution**: Apply it to the view inside the Scene, not to the Scene itself:

```swift
// ❌ WRONG - Don't do this
WindowGroup(id: "MainWindow") {
    ContentView()
}
.modifier(GroupActivityAssociationModifier(id: "main-window"))  // ❌ ERROR!

// ✅ CORRECT - Apply to view content
WindowGroup(id: "MainWindow") {
    ContentView()
        .groupActivityAssociation(.primary("main-window"))  // ✅ On the view
}
.defaultSize(width: 1200, height: 800)  // Scene modifiers go here
```

**For ImmersiveSpace with dynamic content**:

```swift
ImmersiveSpace(for: StreamModel.self) { $model in
    if let model = model {
        ImmersivePlayer(selectedStream: model)
            .groupActivityAssociation(.primary("immersive-space"))  // ✅ On view
    } else {
        Text("No video")
            .groupActivityAssociation(.primary("immersive-space"))  // ✅ Even placeholder
    }
}
.immersionStyle(selection: .constant(.full), in: .full)  // Scene modifiers here
```

**Why**: `.groupActivityAssociation()` is a view modifier, not a scene modifier. See section 4.2 for detailed explanation.

#### `.groupActivityAssociation()` Causes Crashes

**Cause**: Multiple windows using same association ID

**Solution**:

```swift
// Each window/space MUST have unique ID
WindowGroup(id: "MainWindow") {
    ContentView()
        .groupActivityAssociation(.primary("main-window"))
}

ImmersiveSpace(id: "ImmersiveSpace") {
    ImmersiveView()
        .groupActivityAssociation(.primary("immersive-space"))  // Different ID
}
```

#### Green SharePlay Handlebar Not Appearing in Window After Exiting Immersive Space

**Symptom**: SharePlay works in immersive space, but when you exit to the window, the green SharePlay handlebar doesn't appear.

**Cause**: Missing `.groupActivityAssociation()` on WindowGroup or ImmersiveSpace, or using different association IDs incorrectly.

**Solution**: Ensure BOTH are associated with the same GroupActivity session:

```swift
WindowGroup(id: "MainWindow") {
    ContentView()
        .environment(\.sharePlayMessenger, manager.messenger)
        .groupActivityAssociation(.primary("main-window"))  // ✅ Required
}

ImmersiveSpace(id: "ImmersiveSpace") {
    ImmersiveView()
        .environment(\.sharePlayMessenger, manager.messenger)
        .groupActivityAssociation(.primary("immersive-space"))  // ✅ Required (different ID)
}
```

**Why this works**: `.groupActivityAssociation()` tells the system that both the window and immersive space are part of the same SharePlay session. When you exit immersive space, the system knows to show the green handlebar in the window because they're associated with the same GroupActivity.

**Note**: The association IDs must be **different** for each window/space, but they both participate in the **same** GroupActivity session. See section 4.2 for details.

#### App Works Solo But Crashes in SharePlay

**Causes:**

1. Force unwrapping optionals that are nil during SharePlay
2. Accessing UI from background thread
3. Memory issues from not cancelling tasks

**Solution**: Add logging and test thoroughly in SharePlay mode:

```swift
// Add defensive checks
guard let player = player else {
    print("❌ Player is nil during SharePlay")
    return
}

// Ensure main actor
Task { @MainActor in
    updateUI()
}
```

### Security Considerations

#### Message Authentication

**⚠️ CRITICAL**: The `senderUUID` field in custom messages is **NOT authenticated** by SharePlay.

**Problem**: A malicious user can spoof any UUID and impersonate other participants, including the host.

**Impact**:

- Griefing attacks (fake "exit session" messages)
- Privilege escalation (fake "make me host" messages)
- Unauthorized control (fake admin commands)

**Solution**: See Section 13.4 for detailed mitigation strategies. Key points:

- Never use `senderUUID` alone for security-critical decisions
- Verify all privileged actions through your backend server
- Design your app to minimize privilege-based features
- Use consensus/voting instead of single-user control where possible

**Example of UNSAFE code:**

```swift
// ❌ EXPLOITABLE - Anyone can claim to be the host!
func handleKickUser(_ message: KickUserMessage) {
    if message.senderUUID == hostUUID {
        kickUser(message.targetUserUUID)  // Can be spoofed!
    }
}
```

**Example of SAFE code:**

```swift
// ✅ SECURE - Verify with backend
func handleKickUser(_ message: KickUserMessage) async {
    let authorized = await backend.verifyIsHost(
        sessionID: sessionID,
        userID: message.senderUUID
    )
    guard authorized else {
        print("⚠️ Unauthorized kick attempt")
        return
    }
    kickUser(message.targetUserUUID)
}
```

**Read Section 13.4** for complete details on this critical security issue.

### Console Log Interpretation Guide

**Understanding what console logs mean during SharePlay:**

#### Successful SharePlay Flow

```
✅ SharePlay initialized
📱 New SharePlay session detected
🔄 Delegate: Received activity for SharePlay session
✅ Successfully loaded content for SharePlay
✅ AVPlayer registered for SharePlay coordination
✅ SharePlay coordinator is ready
👥 Participants updated: 2 active
```

**What this means**: Everything is working! SharePlay session is active and syncing.

#### Common Problem Logs

**Log:** `❌ Unknown activity type`

**Meaning:** Your activity cast failed

**Check:**

- Is `WatchTogetherActivity` name correct in cast?
- Does your `GroupActivity` match the one being sent?
- Check: `guard let activity = activity as? WatchTogetherActivity`

**Log:** `⏸️ Waiting for others...`

**Meaning:** Buffering/sync in progress (NORMAL)

**Check:** This is expected behavior. AVFoundation is coordinating playback. Should resolve automatically when all participants are ready.

**Log:** No logs at all

**Meaning:** Session monitoring not running

**Check:**

- Is `.task { await monitorSharePlaySessions() }` on WindowGroup?
- Is the task being cancelled prematurely?
- Check if view is being recreated

**Log:** `❌ Failed to activate SharePlay: [error]`

**Meaning:** SharePlay activation failed

**Check:**

- Is FaceTime call active?
- Is Group Activities capability added?
- Is Info.plist configured?
- Check the specific error message for details

**Log:** `⚠️ Player not registered yet`

**Meaning:** `registerPlayer()` hasn't been called

**Check:**

- Is player registration in `.onAppear`?
- Is it called before video starts?
- Is the player instance available?
