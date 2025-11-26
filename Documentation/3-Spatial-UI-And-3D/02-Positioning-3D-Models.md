[← Back to Documentation Home](../README.md) | [← Previous: Attachment System](01-Attachment-System.md)

## 12.4 Positioning 3D Models Positioning 3D Models (ModelEntity, etc.)

**⚠️ NEW**: The package now exposes its core transform engine for positioning 3D models directly, not just SwiftUI attachments.

While `handleAttachmentUpdates()` works great for SwiftUI views wrapped in `Attachment(id:)`, you may want to position native RealityKit entities like `ModelEntity`, `Entity`, or custom 3D content. The package provides two methods for this:

#### Method 1: `getTransform(for:)` - One-Time Positioning

Use this when you need a transform calculation once, such as:

- Positioning static 3D models that don't need to update when seats change
- Manual control over when to recalculate transforms
- Custom update logic that you'll implement yourself

**Example: Positioning a Static 3D Model**

```swift
struct ImmersiveView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        RealityView { content, attachments in
            // Create your 3D model
            let statsCube = ModelEntity(mesh: .generateBox(size: 0.2))
            statsCube.components.set(MaterialsComponent())
            content.add(statsCube)

            // Get the transform for a custom position
            Task {
                let statsRole = AttachmentRole.custom(
                    position: SIMD3<Float>(0, 1.2, 0.9), // Higher up
                    rotation: nil
                )
                let transform = await appState.sharePlayManager.getTransform(for: statsRole)
                statsCube.transform = transform
            }
        }
    }
}
```

**When to Use `getTransform(for:)`:**

- ✅ Static 3D models that don't move
- ✅ One-time positioning during setup
- ✅ You want to handle updates manually
- ✅ Custom animation or interpolation logic

#### Method 2: `subscribeToTransformUpdates(for:role:)` - Reactive Positioning

Use this when you want automatic positioning that stays synchronized with SharePlay seat changes. The subscription will:

- Apply the initial transform immediately
- Automatically update the entity's transform when seats change
- Handle both solo and SharePlay modes correctly

**Example: Reactive 3D Model Positioning**

```swift
struct ImmersiveView: View {
    @Environment(AppState.self) private var appState
    @State private var modelPositionTask: Task<Void, Never>?

    var body: some View {
        RealityView { content, attachments in
            // Create your 3D model
            let liveStatsModel = ModelEntity(mesh: .generateBox(size: 0.2))
            liveStatsModel.components.set(MaterialsComponent())
            content.add(liveStatsModel)

            // Subscribe to transform updates
            let statsRole = AttachmentRole.custom(
                position: SIMD3<Float>(0, 1.2, 0.9),
                rotation: simd_quatf.degrees(-15, axis: [1, 0, 0])
            )
            modelPositionTask = appState.sharePlayManager.subscribeToTransformUpdates(
                for: liveStatsModel,
                role: statsRole
            )
        }
        .onDisappear {
            // CRITICAL: Cancel task to prevent memory leaks
            modelPositionTask?.cancel()
            modelPositionTask = nil
        }
    }
}
```

**When to Use `subscribeToTransformUpdates(for:role:)`:**

- ✅ 3D models that should automatically reposition when seats change
- ✅ Live 3D stats or information displays
- ✅ 3D ads or promotional content
- ✅ Any 3D content that needs to stay synchronized with SharePlay

#### Real-World Use Cases

**3D Live Stats Display**

```swift
// Position a 3D stats cube above the control panel
let statsRole = AttachmentRole.custom(
    position: SIMD3<Float>(0, 1.5, 0.8), // Above control panel
    rotation: nil
)
let task = manager.subscribeToTransformUpdates(
    for: statsModelEntity,
    role: statsRole
)
```

**3D Advertisement Placement**

```swift
// Position a 3D ad banner to the side
let adRole = AttachmentRole.custom(
    position: SIMD3<Float>(0.5, 0.8, 0.9), // Right side
    rotation: simd_quatf.degrees(10, axis: [0, 1, 0]) // Slight rotation
)
let task = manager.subscribeToTransformUpdates(
    for: adModelEntity,
    role: adRole
)
```

**Static 3D Environment Elements**

```swift
// Position a static 3D environment element once
Task {
    let environmentRole = AttachmentRole.custom(
        position: SIMD3<Float>(0, 0, 2.0), // Far away
        rotation: nil
    )
    let transform = await manager.getTransform(for: environmentRole)
    environmentModel.transform = transform
    // No subscription needed - it's static
}
```

#### Key Differences: Attachments vs. 3D Models

| Feature      | `handleAttachmentUpdates()`          | `getTransform()` / `subscribeToTransformUpdates()`                     |
| ------------ | ------------------------------------ | ---------------------------------------------------------------------- |
| **Use Case** | SwiftUI views in `Attachment(id:)`   | Native RealityKit entities (`ModelEntity`, `Entity`)                   |
| **Setup**    | Dictionary of attachment IDs → roles | Direct entity reference                                                |
| **Updates**  | Automatic subscription               | `getTransform()` = manual, `subscribeToTransformUpdates()` = automatic |
| **Best For** | 2D UI planes in 3D space             | 3D models, custom entities, native RealityKit content                  |

#### Combining Both Approaches

You can use both attachment positioning and 3D model positioning in the same `RealityView`:

```swift
struct ImmersiveView: View {
    @Environment(AppState.self) private var appState
    @State private var attachmentTask: Task<Void, Never>?
    @State private var modelTask: Task<Void, Never>?

    var body: some View {
        RealityView { content, attachments in
            // 1. Position SwiftUI attachments
            attachmentTask = appState.sharePlayManager.handleAttachmentUpdates(
                for: attachments,
                roles: [
                    "controls": .controlPanel,
                    "notification": .notification
                ]
            )

            // 2. Position 3D models
            let statsModel = ModelEntity(mesh: .generateBox(size: 0.2))
            content.add(statsModel)

            let statsRole = AttachmentRole.custom(
                position: SIMD3<Float>(0, 1.2, 0.9),
                rotation: nil
            )
            modelTask = appState.sharePlayManager.subscribeToTransformUpdates(
                for: statsModel,
                role: statsRole
            )
        } attachments: {
            Attachment(id: "controls") { ControlPanelView() }
            Attachment(id: "notification") { NotificationBannerView() }
        }
        .onDisappear {
            attachmentTask?.cancel()
            modelTask?.cancel()
            attachmentTask = nil
            modelTask = nil
        }
    }
}
```

#### Important Notes

1. **Task Cancellation**: Always cancel tasks returned by `subscribeToTransformUpdates()` in `.onDisappear` to prevent memory leaks.

2. **Same Transform Engine**: Both methods use the same core transform logic as `handleAttachmentUpdates()`, ensuring consistent positioning across all your content.

3. **SharePlay Synchronization**: `subscribeToTransformUpdates()` automatically handles seat changes in SharePlay, just like `handleAttachmentUpdates()`.

4. **Solo Mode Support**: Both methods work correctly in solo mode (no SharePlay session), positioning relative to the origin.

5. **visionOS Version Support**: Works with 26.0+.

#### Troubleshooting 3D Model Positioning

**Model Not Appearing**

- Check that you're calling the method in the `RealityView`'s `make` closure
- Verify the entity is added to the content before subscribing
- Ensure the task is stored and not cancelled prematurely

**Model Positioned Incorrectly**

- Verify the `AttachmentRole` position values (in meters)
- Check that you're using the correct method (`getTransform` vs `subscribeToTransformUpdates`)
- Ensure the task is still active (not cancelled)

**Model Doesn't Update in SharePlay**

- Use `subscribeToTransformUpdates()` instead of `getTransform()` for reactive updates
- Verify the task is stored and not cancelled
- Check that SharePlay is active (`sharePlayEnabled == true`)

---

