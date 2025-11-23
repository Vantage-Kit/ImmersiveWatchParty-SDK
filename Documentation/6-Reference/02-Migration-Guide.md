[← Back to Documentation Home](../README.md) | [← Previous: Troubleshooting](01-Troubleshooting.md) | [Next: Production Checklist →](03-Production-Checklist.md)

# 17. Migration Paths

**For existing apps that already have working video players and need to add SharePlay.**

### If You Have: Working Solo Video Player

**Goal:** Add SharePlay to existing player without breaking solo playback

**Steps:**

1. **Add prerequisites** (capabilities, Info.plist)

   - See Section 2.1 and 2.2

2. **Create GroupActivity** with your video metadata

   - See Section 4.1
   - Include video URL, title, and any settings

3. **Find where AVPlayer is accessible** → Add `registerPlayer()`

   - See Section 8.1 for direct access
   - See Section 9 for wrapped players
   - Add registration in `.onAppear` or player ready callback

4. **Add session monitoring** to App struct

   - See Section 7
   - Add `.task { await monitorSharePlaySessions() }` to WindowGroup

5. **Test solo playback still works**

   - Verify video plays normally without SharePlay
   - Ensure no regressions

6. **Test SharePlay activation**
   - Start FaceTime call
   - Activate SharePlay
   - Verify video syncs

### If You Have: Custom Immersive Space System

**Goal:** Coordinate space entry/exit for SharePlay

**Steps:**

1. **Identify your space open/close methods**

   ```swift
   // Find these in your codebase:
   func openImmersiveSpace(...)
   func closeImmersiveSpace(...)
   ```

2. **Wrap them in action closures**

   ```swift
   @MainActor
   class AppState {
       var immersiveSpaceOpenAction: (() async -> Void)?
       var immersiveSpaceCloseAction: (() async -> Void)?
   }
   ```

3. **Store closures in @MainActor state**

   ```swift
   // In App struct
   appState.immersiveSpaceOpenAction = { [self] in
       await openImmersiveSpace(value: stream)
   }
   ```

4. **Call from SharePlay delegate**

   ```swift
   // In AppState (which conforms to ImmersiveWatchPartyDelegate)
   func sessionManager(...) async -> Bool {
       await openImmersiveSpaceForSharePlay(with: stream)
       return true
   }
   ```

5. **Add session invalidation observer**
   ```swift
   // In session monitoring
   if case .invalidated = state {
       await appState.exitImmersiveSpaceForSharePlay()
   }
   ```

### If You Have: Complex Settings/Preferences

**Goal:** Sync settings across devices

**Steps:**

1. **List all settings that affect viewing**

   - Projection type, FOV, audio tracks, subtitles, etc.
   - See Section 11.5 for what to sync

2. **Create Codable struct for settings**

   ```swift
   struct ProjectionData: Codable {
       let type: String
       let fieldOfView: Int?
       let forceFov: Bool?
   }
   ```

3. **Add to GroupActivity**

   ```swift
   struct WatchTogetherActivity: GroupActivity {
       let projection: ProjectionData  // ✅ Add this
       // ...
   }
   ```

4. **Create conversion helpers**

   ```swift
   func convertProjection(_ data: ProjectionData) -> StreamModel.Projection? {
       // Convert from GroupActivity format to app format
   }
   ```

5. **Apply settings in sessionManager(received:)**
   ```swift
   func sessionManager(...) async -> Bool {
       let projection = convertProjection(activity.projection)
       stream.projection = projection
       // Apply before opening space
   }
   ```

### Migration Checklist

- [ ] Solo playback still works after integration
- [ ] SharePlay activates without errors
- [ ] Video syncs correctly (play/pause/seek)
- [ ] Settings sync correctly for late joiners
- [ ] Immersive space coordination works
- [ ] No performance regressions
- [ ] Error handling is graceful

