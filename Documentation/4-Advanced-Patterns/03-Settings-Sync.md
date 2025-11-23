[← Back to Documentation Home](../README.md) | [← Previous: Dynamic Data Models](02-Dynamic-Data-Models.md) | [Next: Custom Messaging →](04-Custom-Messaging.md)

# 11. Syncing App-Specific Settings

**⚠️ CRITICAL**: Any setting that affects viewing experience MUST be synced via GroupActivity.

### 11.1 The Problem

The guide shows basic GroupActivity with just a `videoID`:

```swift
struct WatchTogetherActivity: GroupActivity {
    let videoID: String  // Basic
}
```

But real apps have settings that MUST match:

- Video projection type (Equirectangular, Spatial, AIVU)
- Field of view settings
- Audio settings
- Subtitle preferences
- Playback speed

**Without syncing**: Participants see different viewing experiences! 🤦

### 11.2 Embedding Settings in GroupActivity

**Solution**: Add a nested `Codable` struct for your settings:

```swift
struct WatchTogetherActivity: GroupActivity {
    static let activityIdentifier = "com.yourapp.watch-together"

    let videoURL: URL
    let videoTitle: String
    let projection: ProjectionData  // ✅ Custom settings

    // Nested Codable struct for settings
    struct ProjectionData: Codable {
        let type: String  // "Equirectangular", "Spatial", "AIVU"
        let fieldOfView: Int?
        let forceFov: Bool?
    }

    var metadata: GroupActivityMetadata {
        var meta = GroupActivityMetadata()
        meta.title = "Watch: \(videoTitle)"
        meta.type = .watchTogether
        return meta
    }
}
```

### 11.3 Creating Activity with Settings

**Extract your app's current settings** when creating the activity:

```swift
func playVideoWithSharePlay(_ stream: StreamModel) {
    // Extract current app settings
    let projectionData = WatchTogetherActivity.ProjectionData(
        type: appState.projection.rawValue,  // "Equirectangular"
        fieldOfView: appState.projection == .equirectangular
            ? appState.fieldOfView
            : nil,
        forceFov: appState.forceFov
    )

    let activity = WatchTogetherActivity(
        videoURL: stream.url,
        videoTitle: stream.title,
        projection: projectionData  // ✅ Include settings
    )

    // Activate SharePlay...
}
```

### 11.4 Applying Settings When Receiving

**Convert received settings** to your app's format:

```swift
func sessionManager(
    _ manager: ImmersiveWatchPartyManager,
    received activity: some GroupActivity
) async -> Bool {
    guard let watchActivity = activity as? WatchTogetherActivity else {
        return false
    }

    // Convert received settings to your app's format
    let projection = convertProjection(watchActivity.projection)

    let stream = StreamModel(
        title: watchActivity.videoTitle,
        url: watchActivity.videoURL,
        projection: projection  // ✅ Apply same settings
    )

    selectedStream = stream
    applyFormatOptions(from: stream)  // Update UI state

    await openImmersiveSpaceForSharePlay(with: stream)
    return true
}

// Helper to convert custom data
private func convertProjection(_ data: WatchTogetherActivity.ProjectionData) -> StreamModel.Projection? {
    switch data.type {
    case "Equirectangular":
        let fov = Float(data.fieldOfView ?? 180)
        let force = data.forceFov ?? false
        return .equirectangular(fieldOfView: fov, force: force)
    case "Spatial":
        return .rectangular
    case "AIVU":
        return .appleImmersive
    default:
        return .equirectangular(fieldOfView: 180, force: false)
    }
}
```

### 11.5 Settings to Sync

**Always sync:**

- ✅ Video projection/format settings
- ✅ Playback speed (if custom)
- ✅ Audio track selection
- ✅ Subtitle preferences
- ✅ Any setting that changes what users see/hear

**Don't sync:**

- ❌ UI preferences (control panel position, etc.)
- ❌ Personal settings (volume, brightness)
- ❌ Device-specific settings

**Rule of thumb**: If changing a setting would make participants see different content, sync it.

