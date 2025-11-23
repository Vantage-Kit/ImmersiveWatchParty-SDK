[← Back to Documentation Home](../README.md) | [← Previous: Participant Management](04-Participant-Management.md)

## 15. Smart Play Button Pattern

**Goal**: ONE button that's context-aware - automatically starts SharePlay if on FaceTime, otherwise plays solo.

### 15.1 The Problem

The guide shows separate buttons:

- "Start SharePlay" button
- "Watch Solo" button

**Better UX**: One play button that intelligently chooses based on context.

### 15.2 Implementation

**Pattern**: Use `prepareForActivation()` to let the system decide:

```swift
import GroupActivities

struct VideoPlayerView: View {
    @Environment(AppState.self) private var appState
    @StateObject private var groupStateObserver = GroupStateObserver()

    var body: some View {
        // ONE button for everything
        Button("Play") {
            playVideoWithSharePlay(selectedStream)
        }
    }

    private func playVideoWithSharePlay(_ stream: StreamModel) {
        // Extract current app settings
        let projectionData = WatchTogetherActivity.ProjectionData(
            type: appState.projection.rawValue,
            fieldOfView: appState.projection == .equirectangular
                ? appState.fieldOfView
                : nil,
            forceFov: appState.forceFov
        )

        let activity = WatchTogetherActivity(
            videoURL: stream.url,
            videoTitle: stream.title,
            projection: projectionData
        )

        Task {
            // Let the SYSTEM decide
            switch await activity.prepareForActivation() {
            case .activationPreferred:
                // User is on FaceTime - activate SharePlay
                do {
                    _ = try await activity.activate()
                    print("✅ SharePlay activated (FaceTime call detected)")
                    await playVideo(stream)
                } catch {
                    print("❌ Failed to activate SharePlay: \(error)")
                    await playVideo(stream)  // Fallback to solo
                }

            case .activationDisabled:
                // Not on FaceTime OR SharePlay disabled - play solo
                print("ℹ️ SharePlay disabled - playing solo")
                await playVideo(stream)

            case .cancelled:
                // User cancelled the SharePlay prompt
                print("ℹ️ SharePlay cancelled - playing solo")
                await playVideo(stream)

            @unknown default:
                await playVideo(stream)
            }
        }
    }

    private func playVideo(_ stream: StreamModel) async {
        await openImmersiveSpace(value: stream)
    }
}
```

### 15.3 Benefits

1. **Single button** - simpler UI, less cognitive load
2. **Context-aware** - no need to manually check FaceTime status
3. **Graceful fallback** - always works even if SharePlay fails
4. **System-managed prompts** - Apple's UI handles the user flow
5. **Better UX** - users don't need to understand SharePlay mechanics

### 15.4 Optional: Show SharePlay Status

Display active SharePlay status when session is active:

```swift
var body: some View {
    VStack {
        if appState.sharePlayManager.sharePlayEnabled {
            // Show active SharePlay status
            HStack {
                Image(systemName: "shareplay")
                Text("Watch Party Active")
                Text("(\(appState.sharePlayManager.activeParticipantUUIDs.count) viewers)")
            }
            .foregroundColor(.green)
            .padding()
        }

        Button("Play") {
            playVideoWithSharePlay(selectedStream)
        }
    }
}
```

### 15.5 When NOT to Use This Pattern

**Use separate buttons if:**

- You need explicit "Start SharePlay" vs "Watch Solo" choice
- Your app has complex SharePlay requirements
- You want to show SharePlay button only when on FaceTime

**Use smart button if:**

- You want the simplest possible UX
- SharePlay is a "nice to have" feature, not primary
- You trust the system to make the right choice

