[← Back to Documentation Home](../README.md) | [← Previous: Production Checklist](03-Production-Checklist.md)

# 21. Quick API Reference

**Fast lookup for common API methods without scrolling through the guide.**

### ImmersiveWatchPartyManager

```swift
// Initialize
init(localUUID: UUID)

// Register player (REQUIRED for video sync)
func registerPlayer(
    _ player: AVPlayer,
    delegate: AVPlayerPlaybackCoordinatorDelegate
)

// Session setup (called in monitoring loop)
func setupSession<A: GroupActivity>(
    session: GroupSession<A>
) async

// Participant tracking
func updateParticipants(_ uuids: Set<UUID>)

// Session control
func leaveSharePlay()  // Current user exits, session continues
func endSharePlay()    // Terminates session for everyone

// Attachment positioning (SwiftUI attachments)
func handleAttachmentUpdates(
    for attachments: RealityViewAttachments,
    roles: [String: AttachmentRole]
) -> Task<Void, Never>

// 3D model positioning (ModelEntity, Entity, etc.)
func getTransform(for role: AttachmentRole) async -> Transform
func subscribeToTransformUpdates(
    for entity: Entity,
    role: AttachmentRole
) -> Task<Void, Never>

// State properties
@Published var sharePlayEnabled: Bool
var activeParticipantUUIDs: Set<UUID>
var messenger: SharePlayMessenger
```

### ImmersiveWatchPartyDelegate

```swift
// REQUIRED: Handle incoming activity
func sessionManager(
    _ manager: ImmersiveWatchPartyManager,
    received activity: some GroupActivity
) async -> Bool

// REQUIRED: Called when user hosts
func sessionManager(
    _ manager: ImmersiveWatchPartyManager,
    didHostSession sessionID: String
)

// OPTIONAL: Coordinator ready
func sessionManagerDidBecomeReady(
    _ manager: ImmersiveWatchPartyManager
)

// OPTIONAL: Participant events
func sessionManager(
    _ manager: ImmersiveWatchPartyManager,
    participantDidJoin participantUUID: UUID
)

func sessionManager(
    _ manager: ImmersiveWatchPartyManager,
    participantDidLeave participantUUID: UUID
)

// OPTIONAL: User failed to join due to license restrictions
// JoinFailureReason cases:
//   .participantLimitExceeded - Free tier 2-participant limit hit
//   .sessionTimeLimitExceeded - Free tier 5-minute time limit hit
// Note: .activationRequired case exists in enum but is never used.
//       Free Tier works without activation; Pro/Enterprise activation is optional.
func sessionManager(
    _ manager: ImmersiveWatchPartyManager,
    didFailToJoin reason: JoinFailureReason
)

// OPTIONAL: Session ended
func sessionManagerDidInvalidate(
    _ manager: ImmersiveWatchPartyManager
)
```

### SharePlayMessenger

```swift
// Send message
func send<T: Codable>(_ message: T) async throws

// Manual listener registration (advanced)
func addListener<T: Codable>(
    for type: T.Type,
    handler: @escaping (T) async -> Void
) -> UUID

// Remove listener
func removeListener(_ token: UUID)
```

### View Modifiers

```swift
// Inject messenger into environment
.environment(\.sharePlayMessenger, manager.messenger)

// Associate window/space with SharePlay session
.groupActivityAssociation(.primary("window-id"))

// Receive messages (recommended)
.onSharePlayMessage(of: MessageType.self, messenger: messenger) { message in
    // Handle message
}
```

### GroupActivity

```swift
// Required properties
static let activityIdentifier: String
var metadata: GroupActivityMetadata

// Activation
func activate() async throws -> Bool
func prepareForActivation() async -> GroupActivityActivationResult
```

