# AI Development Plan: ImmersiveWatchParty Integration

> **Instructions for AI**: This file contains the architecture, constraints, and implementation roadmap for integrating the ImmersiveWatchParty SDK. Strictly adhere to the patterns defined below to ensure security, concurrency safety, and proper visionOS support.

**Context**: Integration of synchronized video playback, spatial persona coordination, and message passing.

**Frameworks**: Swift 6, SwiftUI, RealityKit, GroupActivities, AVFoundation

**Target OS**: visionOS 26.0+

---

## 1. Architectural Standards & Rules

### 1.1 State Management Pattern

**Single Source of Truth**: Use a `@MainActor @Observable class AppState`.

**Delegation**: The `AppState` MUST conform directly to `ImmersiveWatchPartyDelegate`. Do not create separate delegate classes unless absolutely necessary.

**Initialization Order**:

1. Call `ImmersiveWatchParty.activate()` in `App.init()` (before state init)
2. Initialize `AppState`
3. Assign `sharePlayManager.delegate = self` inside `AppState.init`

### 1.2 Concurrency & Thread Safety

**Strict Concurrency**: All UI and State updates must occur on `@MainActor`.

**Protocol Conformance**: Use `some GroupActivity` instead of `any GroupActivity` in delegate methods.

**Data Races**: Never pass a data model directly from an async delegate method to a view action.

```swift
// ❌ Bad: Data race
await openImmersiveSpace(value: stream)

// ✅ Good: Store in MainActor state first
self.selectedStream = stream
await openImmersiveSpaceAction?()
```

### 1.3 Security & Anti-Piracy (CRITICAL)

**No Direct URLs**: `GroupActivity` structs must ONLY contain content IDs (e.g., `videoID`).

**Backend Verification**: The `sessionManager(_:received:)` delegate method MUST call a backend service to validate the user's entitlement before loading video.

**UUID Trust**: Do not trust `senderUUID` for privileged actions (kick user, end session). These must be verified server-side.

---

## 2. Implementation Roadmap

### Phase 1: Core Setup & Lifecycle

**Objective**: Establish the `AppState`, Session Monitoring, and Metadata.

**Steps**:

1. **Configure Capabilities**: Add "Group Activities" capability. Add `NSGroupActivitiesUsageDescription` to Info.plist
2. **Define Activity**: Create `WatchTogetherActivity` struct conforming to `GroupActivity`. Include `ProjectionData` struct for settings sync
3. **App Entry Point**:
   - Inject `.environment(\.sharePlayMessenger, ...)` to both `WindowGroup` and `ImmersiveSpace`
   - **CRITICAL**: Apply `.groupActivityAssociation(.primary("id"))` to the content view, not the Scene
4. **Session Loop**: Add `.task { await monitorSharePlaySessions() }` to the main Window
5. **Participant Loop (CRITICAL)**: Inside `monitorSharePlaySessions`, you MUST explicitly iterate over `session.$activeParticipants` and call `manager.updateParticipants(uuids)`. The SDK cannot do this automatically due to type erasure.
   
   ```swift
   // Required pattern:
   for await session in WatchTogetherActivity.sessions() {
       await manager.setupSession(session: session)
       
       // CRITICAL: Participant loop
       Task {
           for await participants in session.$activeParticipants.values {
               let uuids = Set(participants.map { $0.id })
               manager.updateParticipants(uuids)
           }
       }
   }
   ```

6. **Metadata Registration**: In the root view's `.onAppear`, register the activity configuration (`NSItemProvider`) to ensure ShareLinks function correctly

### Phase 2: Video Player Integration

**Objective**: Synchronize `AVPlayer` across devices.

**Steps**:

1. **Player Access**: If using a custom player wrapper, ensure `AVPlayer` is exposed publicly or use the Delegate Pattern
2. **Registration**: Use the `.coordinateSharePlay` modifier
   - **Placement**: Attach this to your `RealityView` (if using `VideoMaterial`) or the root of your Immersive Space
   - **Constraint**: Do not use `AVPlayerViewController` inside Immersive Spaces as it hides Spatial Personas. Use RealityKit `VideoMaterial`
3. **Coordinator Delegate**: Implement `AVPlayerPlaybackCoordinatorDelegate`
   - **Rule**: Do NOT implement `identifierFor` (causes concurrency warnings)

### Phase 3: Immersive Space & RealityKit

**Objective**: Sync spatial context and UI attachments.

**Steps**:

1. **Scene Configuration**: Apply `.immersionStyle(selection: ..., in: .mixed)` (or `.full`) to the `ImmersiveSpace`
2. **Entry/Exit**: Use the "State Flag Pattern" to trigger Immersive Space entry from the Delegate (see [Section 4.3](file:///Users/juyoungkim/Developer/ImmersiveWatchParty-Source/Documentation/2-Core-Integration/01-App-Lifecycle-Setup.md#L207))
3. **UI Positioning**: Use `manager.handleAttachmentUpdates(for:roles:)` in `RealityView`
   - **Rule**: You MUST capture the returned `Task` and cancel it in `.onDisappear` to prevent memory leaks and ghost positioning logic
4. **3D Models**: For non-attachment entities, use `manager.subscribeToTransformUpdates(for:role:)` (also requires cancellation)

### Phase 4: Messaging & State Sync

**Objective**: Sync app-specific data.

**Steps**:

1. **Define Messages**: Create structs conforming to `Codable` and `IdentifiableMessage` (must include `senderUUID`)
2. **Send**: Use `try? await messenger.send(MyMessage(...))`
3. **Receive**: Use the `.onSharePlayMessage(of: ...)` view modifier
4. **Rule**: Always filter out your own messages: `guard message.senderUUID != localUUID else { return }`

---

## 3. Recommended View Modifiers (SwiftUI)

### 3.1 Video Synchronization

**Modifier**: `.coordinateSharePlay(partyManager:player:delegate:)`

**Purpose**: Registers the player and coordinates playback automatically.

**Location**: Apply to your `RealityView` (recommended) or player view.

```swift
// ✅ Recommended Pattern (RealityKit)
RealityView { content in
    // Set up VideoMaterial with AVPlayer
    let videoMaterial = VideoMaterial(avPlayer: player)
    // ... setup entities
}
.coordinateSharePlay(
    partyManager: appState.sharePlayManager,
    player: player,
    delegate: self
)
```

### 3.2 Message Handling

**Modifier**: `.onSharePlayMessage(of:handler:)`

**Purpose**: Listens for custom Codable messages.

**Location**: Apply to any View that needs to react to data.

**Why**: Automatically manages listener tokens and clean up.

```swift
// ✅ Recommended Pattern
.onSharePlayMessage(of: NavigationMessage.self, messenger: messenger) { message in
    guard message.senderUUID != localUUID else { return }
    appState.navigate(to: message.targetID)
}
```

### 3.3 Spatial Coordination

**Modifier**: `.groupActivityAssociation(.primary("id"))`

**Purpose**: Links the window/space to the active session.

**Rule**: Must be unique IDs for Window vs Space (e.g., `"main"` vs `"immersive"`).

**Location**: Content View inside the Scene.

```swift
// ✅ Recommended Pattern
WindowGroup(id: "Main") {
    ContentView()
        .groupActivityAssociation(.primary("main"))
}

ImmersiveSpace(id: "Theater") {
    TheaterView()
        .groupActivityAssociation(.primary("immersive"))
}
```

---

## 4. Common Pitfalls & Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| "Conformance... crosses into main actor" | Implementing `identifierFor` | Delete the `identifierFor` method; it is optional |
| Green Handlebar missing | Modifier applied to Scene | Move `.groupActivityAssociation` inside `WindowGroup { ... }` |
| Video desyncs on seek | Seeking manually during SharePlay | Check `!manager.sharePlayEnabled` before calling `player.seek()` |
| Space won't open | Calling environment from Class | Use the State Flag pattern (Bool in AppState) to trigger View change |
| Attachments drift/duplicate | Task not cancelled | Cancel the `handleAttachmentUpdates` task in `.onDisappear` |
| Participant count is 1 | Missing Participant Loop | Implement `session.$activeParticipants` loop in `monitorSharePlaySessions` |

---

## 5. File References & Templates

- **App Lifecycle**: See [Documentation/2-Core-Integration/01-App-Lifecycle-Setup.md](file:///Users/juyoungkim/Developer/ImmersiveWatchParty-Source/Documentation/2-Core-Integration/01-App-Lifecycle-Setup.md)
- **Video Sync**: See [Documentation/2-Core-Integration/02-Video-Player-Sync.md](file:///Users/juyoungkim/Developer/ImmersiveWatchParty-Source/Documentation/2-Core-Integration/02-Video-Player-Sync.md)
- **Custom Player Wrappers**: See [Documentation/4-Advanced-Patterns/01-Custom-Player-Wrappers.md](file:///Users/juyoungkim/Developer/ImmersiveWatchParty-Source/Documentation/4-Advanced-Patterns/01-Custom-Player-Wrappers.md)
- **Spatial UI**: See [Documentation/3-Spatial-UI-And-3D/01-Attachment-System.md](file:///Users/juyoungkim/Developer/ImmersiveWatchParty-Source/Documentation/3-Spatial-UI-And-3D/01-Attachment-System.md)

---

## 6. Verification Checklist

### Pre-Commit Checks

- [ ] License activated in `App.init()`
- [ ] `.groupActivityAssociation` present on BOTH Window and Space
- [ ] Session monitoring loop includes participant updates
- [ ] `AVPlayer` is registered before playback begins
- [ ] `handleAttachmentUpdates` task is cancelled on disappear
- [ ] Custom messages include `senderUUID` and filter self
- [ ] Backend verification logic is in place (or noted as missing)

### Testing

- [ ] **Solo Mode**: Video plays normally without FaceTime
- [ ] **SharePlay**: Start FaceTime → Activate → Video loads for both users
- [ ] **Sync**: Pause on Device A → Device B pauses instantly
- [ ] **Spatial**: Move seat on Device A → UI stays relative to user (if using `handleAttachmentUpdates`)