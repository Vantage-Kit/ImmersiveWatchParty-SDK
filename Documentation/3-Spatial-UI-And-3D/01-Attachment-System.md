[← Back to Documentation Home](../README.md) | [Next: Positioning 3D Models →](02-Positioning-3D-Models.md)

# 12. RealityKit Attachment Positioning

### 12.1 The Value: Automatic Solo & Shared 3D Positioning

This is one of the most valuable and complex features of the package.

Manually calculating the 3D position (the simd_float4x4 matrix) for a SwiftUI attachment is difficult. It's exponentially harder to make that position work for both a solo user (relative to the device origin) and all participants in a SharePlay session (relative to their dynamic Seat pose).

The handleAttachmentUpdates function solves this entire problem. You provide a simple dictionary of desired positions, and the package handles all the complex 3D math, state observation, and visionOS API differences for you.

### 12.2 What This Function Automates (The "Magic")

When you call handleAttachmentUpdates, you are replacing 100+ lines of manual, bug-prone code. The package automatically:

✅ Handles Both Solo & Shared Modes: It intelligently detects if the user is in a SharePlay session or not.

✅ Manages Solo Positioning: For a solo user, it correctly calculates the transform relative to the origin (including flipping the Z-axis so the UI appears in front of them).

✅ Manages SharePlay Positioning: For a shared session, it automatically subscribes to SystemCoordinator updates.

✅ Supports visionOS 2.0+ Seat Poses: It uses the seat.pose matrix from the coordinator to place your UI relative to the participant's dynamic Spatial Persona position.

✅ Supports visionOS 1.0 Fallback: It provides a stable, shared fallback position for users on the older OS.

✅ Waits for Readiness: It automatically waits for the SystemCoordinator to be ready before applying any positions, preventing your UI from appearing at (0,0,0).

You do not need to write separate positioning logic for solo/mock mode. The package handles both from the same roles dictionary.

### 12.3 Implementation: Before vs. After

Let's say you want to add a "Fight Stats Live" UI above your controls.

❌ Before (Manual Code You Would Have to Write)

```swift
// You would need to build all this logic manually...

struct ImmersiveView: View {
    @State private var attachmentTask: Task<Void, Never>?

    var body: some View {
        RealityView { content, attachments in
            // ... setup ...

            // 1. Manually check if we are in SharePlay
            if appState.sharePlayManager.sharePlayEnabled,
               let coordinator = await appState.sharePlayManager.systemCoordinator {

                // 2. Manually subscribe to participant updates
                attachmentTask = Task {
                    for try await state in coordinator.localParticipantStates {
                        if #available(visionOS 2.0, *) {
                            // 3. Manually get the seat pose
                            let seatTransform = Transform(matrix: simd_float4x4(state.seat.pose))

                            // 4. Manually do complex 3D matrix math for SHARED position
                            let statsPosition = SIMD3<Float>(-0.3, 0.9, 0.8)
                            // ... more math to combine with seatTransform ...

                            attachments.entity(for: "FightStatsLive")?.transform = ...
                        } else {
                            // 5. Manually calculate fallback for v1
                        }
                    }
                }
            } else {
                // 6. Manually calculate transform for SOLO position
                let soloPosition = SIMD3<Float>(-0.3, 0.9, -0.8) // Note Z is flipped!
                // ... more math ...
                attachments.entity(for: "FightStatsLive")?.transform = ...
            }
        } attachments: {
            Attachment(id: "FightStatsLive") { ... }
        }
        .onDisappear {
            // 7. Manually cancel the task
            attachmentTask?.cancel()
        }
    }
}
```

✅ After (Using This Package)

You delete all of that and replace it with this:

```swift
struct ImmersiveView: View {
    @Environment(AppState.self) private var appState

    // 1. Store the task (package handles cancellation)
    @State private var attachmentTask: Task<Void, Never>?

    var body: some View {
        RealityView { content, attachments in
            // ... setup ...

            // 2. Call the ONE package function
            attachmentTask = appState.sharePlayManager.handleAttachmentUpdates(
                for: attachments,
                roles: [
                    "controls": .controlPanel,
                    "notification": .notification,

                    // 3. JUST DECLARE YOUR CUSTOM UI POSITION
                    "FightStatsLive": .custom(
                        position: SIMD3<Float>(-0.3, 0.9, 0.8), // Left, above, same depth
                        rotation: simd_quatf(angle: Float(Angle(degrees: -15).radians), axis: [1, 0, 0])
                    )
                ]
            )

        } attachments: {
            // 4. Define your attachments
            Attachment(id: "controls") { ControlPanelView() }
            Attachment(id: "notification") { NotificationBannerView() }

            Attachment(id: "FightStatsLive") {
                FightStatsLiveView() // Your custom SwiftUI view
            }
        }
        .onDisappear {
            // 5. Cancel the task
            attachmentTask?.cancel()
            attachmentTask = nil
        }
    }
}
```

That's it. The package handles all logic from the 'Before' example automatically. You just declare where you want your UI, and the package handles the how for all modes (Solo, SharePlay v1, and SharePlay v2).



**For positioning 3D models (ModelEntity, etc.), see [Positioning 3D Models](02-Positioning-3D-Models.md).**
