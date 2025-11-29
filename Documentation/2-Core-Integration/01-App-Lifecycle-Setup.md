[← Back to Documentation Home](../README.md) | [Next: Video Player Sync →](02-Video-Player-Sync.md)

# 4. Required Setup Files

You need to create these files in your app:

### 4.1 GroupActivity Definition

Create a file `WatchTogetherActivity.swift`:

```swift
import GroupActivities
import Foundation

struct WatchTogetherActivity: GroupActivity {
    // REQUIRED: Unique identifier - must be unique across all apps
    static let activityIdentifier = "com.yourapp.watch-together"

    // REQUIRED: Content identifier (e.g., video ID, event ID)
    let videoID: String

    // OPTIONAL: Additional metadata for better UX
    let videoTitle: String?
    let thumbnailURL: URL?

    // REQUIRED: GroupActivity conformance
    var metadata: GroupActivityMetadata {
        var meta = GroupActivityMetadata()
        meta.title = videoTitle ?? "Watch Together"
        meta.type = .watchTogether

        if let thumbnail = thumbnailURL {
            meta.previewImage = thumbnail
        }

        return meta
    }
}
```

**Alternative: Class Wrapper Pattern** (if you need Transferable):

```swift
import GroupActivities
import Foundation
import CoreTransferable

class WatchTogetherActivity: GroupActivity, Transferable {
    private(set) var groupActivity: Activity

    // Convenience initializer for specific content
    init(videoID: String, title: String) {
        self.groupActivity = Activity(videoID: videoID, videoTitle: title)
        self.metadata = groupActivity.metadata
    }

    // Generic initializer for ShareLink creation
    init() {
        self.groupActivity = Activity(videoID: "", videoTitle: nil)
        self.metadata = groupActivity.metadata
    }

    struct Activity: GroupActivity {
        static let activityIdentifier = "com.yourapp.watch-together"

        let videoID: String
        let videoTitle: String?

        var metadata: GroupActivityMetadata {
            var meta = GroupActivityMetadata()
            meta.title = videoTitle ?? "Set Up Watch Party"
            meta.type = .watchTogether
            return meta
        }
    }

    var metadata: GroupActivityMetadata
}
```

### 4.2 Delegate Implementation

**✅ Recommended Pattern: Direct Conformance**

Have your `AppState` conform directly to `ImmersiveWatchPartyDelegate`. This is the modern, SwiftUI-native approach that eliminates unnecessary complexity and potential runtime errors.

The delegate methods will be implemented in an extension on your `AppState` class (see Section 5.1 for the complete example). Here's what the delegate implementation looks like:

```swift
// MARK: - ImmersiveWatchPartyDelegate Conformance
extension AppState: ImmersiveWatchPartyDelegate {

    // REQUIRED: Handle incoming activities when joining a SharePlay session
    func sessionManager(
        _ manager: ImmersiveWatchPartyManager,
        received activity: some GroupActivity
    ) async -> Bool {
        print("🔄 Delegate: Received activity for SharePlay session")

        // PATTERN 1: Simple struct cast
        guard let watchActivity = activity as? WatchTogetherActivity else {
            print("❌ Unknown activity type")
            return false
        }

        // PATTERN 2: Class wrapper cast (if using class pattern)
        // guard let wrapper = activity as? WatchTogetherActivity else {
        //     print("❌ Unknown activity type")
        //     return false
        // }
        // let watchActivity = wrapper.groupActivity

        // Load and launch the shared content
        // NO weak var, NO optional unwrapping - just call your own methods
        do {
            try await loadVideo(id: watchActivity.videoID)
            await openImmersiveSpace()

            print("✅ Successfully loaded content for SharePlay")
            return true
        } catch {
            print("❌ Failed to load content: \(error)")
            return false
        }
    }

    // OPTIONAL: Called when the system coordinator becomes ready
    // This is when you can safely interact with immersive spaces
    func sessionManagerDidBecomeReady(_ manager: ImmersiveWatchPartyManager) {
        print("✅ SharePlay coordinator is ready")
        // You can now safely position RealityKit entities
        // The manager will process any pending activities automatically
    }

    // OPTIONAL: Called when this user becomes the session host
    func sessionManager(_ manager: ImmersiveWatchPartyManager, didHostSession sessionID: String) {
        print("🏠 User is hosting session: \(sessionID)")
        // Track analytics, show host-specific UI, etc.
    }

    // OPTIONAL: Called when a participant joins
    func sessionManager(
        _ manager: ImmersiveWatchPartyManager,
        participantDidJoin participantUUID: UUID
    ) {
        print("👤 Participant joined: \(participantUUID)")
        // Show notification, update participant list, etc.
    }

    // OPTIONAL: Called when a participant leaves
    func sessionManager(
        _ manager: ImmersiveWatchPartyManager,
        participantDidLeave participantUUID: UUID
    ) {
        print("👋 Participant left: \(participantUUID)")
        // Update participant list, check if you're last person, etc.
    }

    // OPTIONAL: Called when local user fails to join due to license restrictions
    // NOTE: JoinFailureReason is a top-level enum - use it directly, not as ImmersiveWatchPartyManager.JoinFailureReason
    func sessionManager(
        _ manager: ImmersiveWatchPartyManager,
        didFailToJoin reason: JoinFailureReason  // ✅ Use directly - requires: import ImmersiveWatchParty
    ) {
        print("⚠️ Failed to join SharePlay session: \(reason)")

        switch reason {
        case .participantLimitExceeded:
            // Free tier: Show "Upgrade to Pro" alert
            // The session continues for other (paid) users - this is LOCAL enforcement only
            showUpgradeAlert(
                title: "Participant Limit Reached",
                message: "Free tier supports up to 2 participants. Upgrade to Pro or Enterprise for unlimited participants."
            )

        case .sessionTimeLimitExceeded:
            // Free tier: 5-minute session time limit reached
            // Show "Upgrade to Pro" alert with time limit context
            showUpgradeAlert(
                title: "Session Time Limit Reached",
                message: "Your free 5-minute preview session has ended. Upgrade to Pro or Enterprise for unlimited session duration."
            )
        }
    }

    // OPTIONAL: Called when the SharePlay session ends
    func sessionManagerDidInvalidate(_ manager: ImmersiveWatchPartyManager) {
        print("🔚 SharePlay session ended")
        // Clean up, return to solo mode, close immersive space, etc.
        Task {
            await cleanupAfterSharePlay()
        }
    }
}
```

**Important Delegate Notes:**

1. **Return `true` from `received:activity`** only if you successfully loaded the content
2. **Return `false`** if loading failed - the manager will handle cleanup
3. The delegate runs on `@MainActor`, so UI updates are safe
4. Don't block - use `async/await` for loading operations
5. **No weak references needed** - since `AppState` is the delegate, there's no risk of nil references

---

### 4.3 Bridging Environment Actions to Delegates

⚠️ **CRITICAL PATTERN**: The `sessionManager(_:received:)` delegate method needs to call `openImmersiveSpace`, but this is a SwiftUI Environment value that only exists inside Views. Your `AppState` class doesn't have direct access to it.

**The Problem:**

```swift
// ❌ This won't work - AppState doesn't have access to openImmersiveSpace
extension AppState: ImmersiveWatchPartyDelegate {
    func sessionManager(
        _ manager: ImmersiveWatchPartyManager,
        received activity: some GroupActivity
    ) async -> Bool {
        // ... load video ...
        await openImmersiveSpace()  // ❌ ERROR: Cannot find 'openImmersiveSpace' in scope
        return true
    }
}
```

**Solution: State Flag Pattern**

Use a boolean flag in your `AppState` that the View observes:

**Step 1: Add flag to AppState**

```swift
@MainActor
@Observable
class AppState {
    let sharePlayManager: ImmersiveWatchPartyManager
    var selectedStream: StreamModel?
    
    // Flag to trigger immersive space opening
    var shouldOpenImmersiveSpace: Bool = false
    
    // ... rest of your state
}
```

**Step 2: Set flag in delegate**

```swift
extension AppState: ImmersiveWatchPartyDelegate {
    func sessionManager(
        _ manager: ImmersiveWatchPartyManager,
        received activity: some GroupActivity
    ) async -> Bool {
        guard let watchActivity = activity as? WatchTogetherActivity else {
            return false
        }
        
        // Load the video
        do {
            try await loadVideo(id: watchActivity.videoID)
            
            // Trigger immersive space opening via state flag
            self.shouldOpenImmersiveSpace = true
            
            return true
        } catch {
            print("❌ Failed to load content: \(error)")
            return false
        }
    }
}
```

**Step 3: Observe flag in your View**

```swift
@main
struct YourApp: App {
    @State private var appState = AppState()
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some Scene {
        WindowGroup(id: "MainWindow") {
            ContentView()
                .environment(appState)
                .environment(\.sharePlayMessenger, appState.sharePlayManager.messenger)
                .groupActivityAssociation(.primary("main-window"))
                // CRITICAL: Observe the flag and trigger space opening
                .onChange(of: appState.shouldOpenImmersiveSpace) { _, shouldOpen in
                    if shouldOpen {
                        if let stream = appState.selectedStream {
                            Task {
                                await openImmersiveSpace(value: stream)
                                appState.shouldOpenImmersiveSpace = false
                                dismissWindow(id: "MainWindow")
                            }
                        }
                    }
                }
                .task {
                    await monitorSharePlaySessions()
                }
        }
        // ... rest of scenes
    }
}
```

**Why This Works:**

1. Delegate (in `AppState`) sets the flag when SharePlay activity arrives
2. View (with access to `openImmersiveSpace`) observes the flag
3. View calls `openImmersiveSpace` when flag becomes `true`
4. View resets the flag to `false` after opening

**Alternative: Closure Pattern**

If you prefer, you can inject the environment action as a closure:

```swift
@Observable
class AppState {
    var immersiveSpaceOpenAction: (() async -> Void)?
    
    // In delegate:
    func sessionManager(...) async -> Bool {
        // ... load video ...
        await immersiveSpaceOpenAction?()
        return true
    }
}

// In App:
.task {
    appState.immersiveSpaceOpenAction = {
        guard let stream = appState.selectedStream else { return }
        await openImmersiveSpace(value: stream)
    }
    await monitorSharePlaySessions()
}
```

Choose the pattern that fits your architecture, but the state flag pattern is generally more SwiftUI-idiomatic and easier to debug.

---

# 5. App Structure & Initialization

### 5.1 Create App State

Your main app state should hold the manager and conform directly to the delegate protocol:

```swift
import SwiftUI
import ImmersiveWatchParty
import AVFoundation

@MainActor
@Observable  // Or use @ObservableObject
class AppState {
    // REQUIRED: The SharePlay manager
    let sharePlayManager: ImmersiveWatchPartyManager

    // Your app's state
    var player: AVPlayer?
    var currentVideoID: String?
    var isImmersiveSpaceOpen = false

    init() {
        // 1. Create manager with a unique local UUID
        // This UUID identifies THIS device in the SharePlay session
        self.sharePlayManager = ImmersiveWatchPartyManager(
            localUUID: UUID()
        )

        // 2. Set the delegate to YOURSELF
        // This is the modern, SwiftUI-native pattern
        self.sharePlayManager.delegate = self

        print("✅ SharePlay initialized")
    }

    func loadVideo(id: String) async throws {
        // Load your video content
        currentVideoID = id
        let url = URL(string: "https://example.com/video/\(id).m3u8")!
        player = AVPlayer(url: url)
    }

    func openImmersiveSpace() async {
        // Your logic to open immersive space
        isImmersiveSpaceOpen = true
    }

    func cleanupAfterSharePlay() async {
        // Your cleanup logic when SharePlay ends
    }
}

// MARK: - ImmersiveWatchPartyDelegate Conformance
extension AppState: ImmersiveWatchPartyDelegate {
    // REQUIRED: Handle incoming activities when joining a SharePlay session
    func sessionManager(
        _ manager: ImmersiveWatchPartyManager,
        received activity: some GroupActivity
    ) async -> Bool {
        print("🔄 Delegate: Received activity for SharePlay session")

        guard let watchActivity = activity as? WatchTogetherActivity else {
            print("❌ Unknown activity type")
            return false
        }

        // Load and launch the shared content
        // NO weak var, NO optional unwrapping - just call your own methods
        do {
            try await loadVideo(id: watchActivity.videoID)
            await openImmersiveSpace()

            print("✅ Successfully loaded content for SharePlay")
            return true
        } catch {
            print("❌ Failed to load content: \(error)")
            return false
        }
    }

    // OPTIONAL: Called when the system coordinator becomes ready
    func sessionManagerDidBecomeReady(_ manager: ImmersiveWatchPartyManager) {
        print("✅ SharePlay coordinator is ready")
    }

    // OPTIONAL: Called when this user becomes the session host
    func sessionManager(_ manager: ImmersiveWatchPartyManager, didHostSession sessionID: String) {
        print("🏠 User is hosting session: \(sessionID)")
    }

    // OPTIONAL: Called when a participant joins
    func sessionManager(
        _ manager: ImmersiveWatchPartyManager,
        participantDidJoin participantUUID: UUID
    ) {
        print("👤 Participant joined: \(participantUUID)")
    }

    // OPTIONAL: Called when a participant leaves
    func sessionManager(
        _ manager: ImmersiveWatchPartyManager,
        participantDidLeave participantUUID: UUID
    ) {
        print("👋 Participant left: \(participantUUID)")
    }

    // OPTIONAL: Called when local user fails to join due to license restrictions
    func sessionManager(
        _ manager: ImmersiveWatchPartyManager,
        didFailToJoin reason: JoinFailureReason
    ) {
        print("⚠️ Failed to join SharePlay session: \(reason)")
        // Show upgrade alert, etc.
    }

    // OPTIONAL: Called when the SharePlay session ends
    func sessionManagerDidInvalidate(_ manager: ImmersiveWatchPartyManager) {
        print("🔚 SharePlay session ended")
        Task {
            await cleanupAfterSharePlay()
        }
    }
}
```

**Alternative: Using SessionController Pattern**

If you have a separate controller for session management:

```swift
@MainActor
class SessionController: ObservableObject {
    let partyManager: ImmersiveWatchPartyManager
    let localUUID: UUID

    @Published var sharePlayEnabled: Bool = false

    init() {
        self.localUUID = UUID()
        self.partyManager = ImmersiveWatchPartyManager(localUUID: localUUID)

        // Set up delegation (self conforms to ImmersiveWatchPartyDelegate)
        self.partyManager.delegate = self

        // Sync manager's @Published state to our @Published property
        setupSharePlayEnabledObserver()
    }

    private func setupSharePlayEnabledObserver() {
        partyManager.$sharePlayEnabled
            .receive(on: DispatchQueue.main)
            .assign(to: &$sharePlayEnabled)
    }
}

extension SessionController: ImmersiveWatchPartyDelegate {
    // Implement delegate methods here
}
```

### 5.2 App Entry Point

**⚠️ CRITICAL**: Proper environment injection and `.groupActivityAssociation()`

In your main `App` file:

```swift
import SwiftUI
import ImmersiveWatchParty

@main
struct YourApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup(id: "MainWindow") {
            ContentView()
                .environment(appState)
                // CRITICAL: Inject SharePlay messenger
                .environment(\.sharePlayMessenger, appState.sharePlayManager.messenger)
                // CRITICAL: Associate this window with GroupActivity sessions
                // This enables SharePlay to coordinate window state across devices
                .groupActivityAssociation(.primary("main-window"))
        }
        .defaultSize(width: 1200, height: 800)

        ImmersiveSpace(id: "ImmersiveSpace") {
            ImmersiveView()
                .environment(appState)
                // CRITICAL: Inject messenger in immersive space too
                .environment(\.sharePlayMessenger, appState.sharePlayManager.messenger)
                // CRITICAL: Associate immersive space with GroupActivity
                // This is what enables spatial synchronization in SharePlay
                .groupActivityAssociation(.primary("immersive-space"))
        }
        .immersionStyle(selection: .constant(.full), in: .full)
    }
}
```

**⚠️ COMMON MISTAKE**: Don't apply `.groupActivityAssociation()` as a modifier on the Scene!

**❌ WRONG** - This will cause compilation errors:

```swift
WindowGroup(id: "MainWindow") {
    ContentView()
        .environment(appState)
}
.modifier(GroupActivityAssociationModifier(id: "main-window"))  // ❌ ERROR!
// Error: 'modifier' is inaccessible due to 'internal' protection level
// Error: Struct 'SceneBuilder' requires that 'GroupActivityAssociationModifier' conform to '_SceneModifier'
```

**✅ CORRECT** - Apply it to the view content inside the Scene:

```swift
WindowGroup(id: "MainWindow") {
    ContentView()
        .environment(appState)
        .groupActivityAssociation(.primary("main-window"))  // ✅ Applied to view
}
.defaultSize(width: 1200, height: 800)  // Scene modifiers go here
```

**Why**: `.groupActivityAssociation()` is a **view modifier**, not a scene modifier. It must be applied to the view content (ContentView, ImmersiveView, etc.), not to the Scene builder itself.

**For ImmersiveSpace with dynamic content**:

```swift
ImmersiveSpace(for: StreamModel.self) { $model in
    if let model = model {
        ImmersivePlayer(selectedStream: model)
            .environment(appState)
            .environment(\.sharePlayMessenger, appState.sharePlayManager.messenger)
            .groupActivityAssociation(.primary("immersive-space"))  // ✅ On the view
    } else {
        Text("No video selected")
            .groupActivityAssociation(.primary("immersive-space"))  // ✅ Even on placeholder
    }
}
.immersionStyle(selection: .constant(.full), in: .full)  // Scene modifiers here
```

**Why `.groupActivityAssociation()` is Critical:**

1. **Enables window/space coordination** across devices in SharePlay
2. **Allows Apple's system to manage** immersive space transitions
3. **Required for spatial audio** and participant positioning
4. **Must be unique** for each window/space in your app
5. **Keeps SharePlay session visible** when transitioning between windows and immersive spaces

**Important Behavior**: When you associate both your `WindowGroup` and `ImmersiveSpace` with the same GroupActivity session:

- **Green handlebar appears** in windows during active SharePlay sessions
- **Session persists** when exiting immersive space - the window still shows the SharePlay indicator
- **Smooth transitions** between window and immersive space maintain SharePlay state
- **Cross-device sync** - all participants see the same window/space state

**Example**: User starts SharePlay in immersive space → exits to window → window still shows green SharePlay handlebar → can re-enter immersive space and SharePlay continues seamlessly.

Without this, SharePlay will work for messages and video sync, but **immersive space coordination will fail** and the green handlebar won't appear in windows.

### 5.3 License Activation

### 5.4 Session Monitoring Setup

**IMPORTANT**: Session monitoring must happen at the **app level**, not in a view.

In your `App` body, add a `.task` modifier:

```swift
var body: some Scene {
    WindowGroup(id: "MainWindow") {
        ContentView()
            .environment(appState)
            .environment(\.sharePlayMessenger, appState.sharePlayManager.messenger)
            .groupActivityAssociation(.primary("main-window"))
            // CRITICAL: Start session monitoring here
        .task {
            await monitorSharePlaySessions()
        }
    }
    // ... rest of scenes
    }

// MARK: - Session Monitoring
    private func monitorSharePlaySessions() async {
    // Monitor for incoming SharePlay sessions
        for await session in WatchTogetherActivity.sessions() {
        print("📱 New SharePlay session detected")

            // Configure the manager with the session
        await appState.sharePlayManager.setupSession(session: session)

        // CRITICAL: Observe participants
            observeParticipants(session: session)

        // CRITICAL: Observe session state
            observeSessionState(session: session)
        }
    }

    private func observeParticipants<A: GroupActivity>(session: GroupSession<A>) {
        Task {
            for await participants in session.$activeParticipants.values {
                let uuids = Set(participants.map { $0.id })
                appState.sharePlayManager.updateParticipants(uuids)
            }
        }
    }

    private func observeSessionState<A: GroupActivity>(session: GroupSession<A>) {
        Task {
            for await state in session.$state.values {
                if case .invalidated = state {
                    appState.sharePlayManager.handleSessionStateChange(isInvalidated: true)
                }
        }
    }
}
```

**Why at App Level:**

- Only the app knows concrete `Participant` types from Apple's APIs
- Avoids `AsyncSequence` consumption conflicts
- Ensures session monitoring survives view rebuilds

---


# 6. GroupActivity Configuration

### 6.1 Starting a SharePlay Session

**Method 1: Using ShareLink (Recommended for visionOS)**

```swift
import SwiftUI
import GroupActivities

struct VideoDetailView: View {
    let video: Video
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack {
            // Your video details

            // ShareLink button - automatically handles SharePlay UI
            ShareLink(
                item: WatchTogetherActivity(
                    videoID: video.id,
                    videoTitle: video.title,
                    thumbnailURL: video.thumbnail
                ),
                preview: SharePreview(
                    video.title,
                    image: Image(video.thumbnail)
                )
            ) {
                Label("Watch Together", systemImage: "shareplay")
            }
        }
    }
}
```

**Method 2: Programmatic Activation**

For custom UI or programmatic control:

```swift
Button("Start Watch Party") {
    Task {
        // Create your activity with current content
        let activity = WatchTogetherActivity(
            videoID: currentVideoID,
            videoTitle: "My Video",
            thumbnailURL: nil
        )

        // Request activation permission from system
        switch await activity.prepareForActivation() {
        case .activationPreferred:
            // System allows activation - proceed
            do {
                _ = try await activity.activate()
                print("✅ SharePlay activated")
            } catch {
                print("❌ Failed to activate: \(error)")
            }

        case .activationDisabled:
            // SharePlay is disabled in Settings
            print("⚠️ SharePlay is disabled")
            showSharePlayDisabledAlert()

        case .cancelled:
            // User cancelled the SharePlay UI
            print("🚫 User cancelled SharePlay")

        @unknown default:
            break
        }
    }
}
```

### 6.2 Registering GroupActivity for ShareLink

If using ShareLink, register your activity in `onAppear`:

```swift
import UIKit
import GroupActivities

func registerGroupActivity() {
    let itemProvider = NSItemProvider()
    itemProvider.registerGroupActivity(WatchTogetherActivity())

    let configuration = UIActivityItemsConfiguration(itemProviders: [itemProvider])
    configuration.metadataProvider = { key in
        guard key == .linkPresentationMetadata else { return Void.self }
        return WatchTogetherActivity().metadata
    }

    // Attach to root view controller
    UIApplication.shared
        .connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first?
        .windows
        .first?
        .rootViewController?
        .activityItemsConfiguration = configuration
}
```

Call this in your app's `onAppear` or during initialization.

### 6.3 Detecting SharePlay Readiness

**⚠️ IMPORTANT**: Before showing SharePlay UI, check if the user is eligible for group sessions (i.e., in a FaceTime call).

#### Using GroupStateObserver

The `GroupActivities` framework provides `GroupStateObserver` to detect if SharePlay is available:

```swift
import SwiftUI
import GroupActivities

struct VideoDetailView: View {
    @StateObject private var groupStateObserver = GroupStateObserver()
    @State private var showSharePlayButton = false

    var body: some View {
        VStack {
            if groupStateObserver.isEligibleForGroupSession {
                // User is in a FaceTime call - show SharePlay button
                ShareLink(
                    item: WatchTogetherActivity(videoID: video.id),
                    preview: SharePreview(video.title)
                ) {
                    Label("Start Watch Party", systemImage: "shareplay")
                }
            } else {
                // User is NOT in a FaceTime call - show solo watch button
                Button("Watch Solo") {
                    startSoloPlayback()
                }
            }
        }
        .onAppear {
            // GroupStateObserver automatically updates when FaceTime status changes
        }
    }
}
```

#### Understanding `isEligibleForGroupSession`

- **`true`**: User is in an active FaceTime call → SharePlay is available
- **`false`**: User is NOT in a FaceTime call → SharePlay unavailable (but can still watch solo)

**Important**: This property updates automatically when FaceTime call status changes.

#### Using `prepareForActivation()` for Detection

Alternatively, you can use `prepareForActivation()` to let the system handle the decision:

```swift
func startWatching() async {
    let activity = WatchTogetherActivity(videoID: currentVideo.id)

    switch await activity.prepareForActivation() {
    case .activationPreferred:
        // User is in FaceTime call - system will show SharePlay prompt
        do {
            _ = try await activity.activate()
            print("✅ SharePlay activated")
        } catch {
            print("❌ Activation failed: \(error)")
            // Fallback to solo playback
            await startSoloPlayback()
        }

    case .activationDisabled:
        // User is NOT in FaceTime call OR chose "Start Only for Me"
        print("▶️ Starting solo playback")
        await startSoloPlayback()

    case .cancelled:
        // User cancelled the prompt
        print("⏹️ User cancelled")
        break

    @unknown default:
        break
    }
}
```

**When to use each approach:**

- **`GroupStateObserver`**: When you need to show different UI based on FaceTime status
- **`prepareForActivation()`**: When you want the system to handle the decision and show appropriate prompts

#### Real-World Pattern: Conditional SharePlay UI

Here's how VantageSpatialSports handles this:

```swift
struct VideoPlayerView: View {
    @StateObject private var groupStateObserver = GroupStateObserver()
    @EnvironmentObject var sessionController: SessionController

var body: some View {
    VStack {
            // Show different button text based on FaceTime status
            if groupStateObserver.isEligibleForGroupSession {
                Button("Start Watch Party") {
                    startSharePlay()
                }
        } else {
                Button("Watch Solo") {
                    startSoloPlayback()
                }

                // Optionally show a hint
                Text("Join a FaceTime call to watch together")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func startSharePlay() async {
        // Only proceed if user is in FaceTime call
        guard groupStateObserver.isEligibleForGroupSession else {
            showFaceTimeRequiredAlert()
            return
        }

        let activity = WatchTogetherActivity(videoID: video.id)
        switch await activity.prepareForActivation() {
        case .activationPreferred:
            _ = try? await activity.activate()
        case .activationDisabled:
            // Fallback to solo
            await startSoloPlayback()
        default:
            break
        }
    }
}
```

#### Checking SharePlay Status After Activation

Once a session is active, check the manager's state:

```swift
// Check if SharePlay is currently active
if sessionController.sharePlayManager.sharePlayEnabled {
    // SharePlay session is active
    Text("Watch Party Active")
    Text("\(sessionController.sharePlayManager.activeParticipantUUIDs.count) participants")
} else {
    // Solo mode
    Text("Solo Mode")
}
```

**Note**: `sharePlayEnabled` is different from `isEligibleForGroupSession`:

- **`isEligibleForGroupSession`**: Can the user start SharePlay? (FaceTime call active)
- **`sharePlayEnabled`**: Is SharePlay currently active? (Session exists)


# 7. Session Monitoring & Participant Observation

**Refer back to section 5.4 for complete implementation.** The key points:

1. **Session monitoring MUST be at app level** (not in views)
2. **Observe both participants AND session state**
3. **Call `setupSession()` when session arrives**
4. **Update participants** via `updateParticipants()`

Refer back to section 4.3 for complete implementation.



### 16.4 Session State Management

Display appropriate UI based on SharePlay state:

```swift
var body: some View {
    VStack {
        if sessionController.sharePlayEnabled {
            // SharePlay active UI
            HStack {
                Image(systemName: "shareplay")
                Text("Watch Party Active")
                Text("\(sessionController.partyManager.activeParticipantUUIDs.count) viewers")
            }
            .foregroundColor(.green)

            Button("Leave Party") {
                sessionController.leaveSharePlay()
            }
        } else {
            // Solo mode UI
            ShareLink(
                item: WatchTogetherActivity(videoID: currentVideo.id),
                preview: SharePreview(currentVideo.title)
            ) {
                Label("Start Watch Party", systemImage: "shareplay")
            }
        }
    }
}
```

