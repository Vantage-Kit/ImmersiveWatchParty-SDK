[← Back to Documentation Home](../README.md) | [← Previous: Migration Guide](02-Migration-Guide.md) | [Next: API Reference →](04-API-Reference.md)

# 20. Production Integration Checklist

**Use this expanded checklist for real-world apps with custom architectures.**

### Architecture Discovery

- [ ] Located where `AVPlayer` is accessible in your codebase
- [ ] Identified your immersive space opening pattern (static ID vs data model)
- [ ] Listed all app-specific settings that affect viewing experience
- [ ] Determined where player registration should happen in your lifecycle
- [ ] Identified if you use custom player wrappers or third-party libraries

### License Activation (Pro/Enterprise)

- [ ] Obtained license key from email (if using Pro or Enterprise tier)
- [ ] Verified license key is for correct bundle ID
- [ ] Shared license key with all developers on the team (one key per app, unlimited developers)
- [ ] Each developer has added `ImmersiveWatchParty.activate(withLicenseKey:)` to their local build
- [ ] Activation follows the pattern in Section 5.3: called in `App.init()` BEFORE `AppState` initialization
- [ ] Activation happens BEFORE session monitoring starts
- [ ] Tested console shows successful activation message
- [ ] Verified unlimited participants work (Pro/Enterprise)
- [ ] Verified unlimited session duration works (Pro/Enterprise)
- [ ] No Free tier warnings appear in console (if licensed)
- [ ] Understand that the license is per-app (bundle ID), not per-developer

### Custom Player Integration

- [ ] Verified `AVPlayer` is publicly accessible from wrapper
- [ ] Created `AVPlayerPlaybackCoordinatorDelegate` conformance (without `identifierFor`)
- [ ] Found or created hook to register player when instance is available
- [ ] Tested player registration happens before video playback starts
- [ ] Verified registration only happens once per player instance

### Data Model Integration

- [ ] Extended `GroupActivity` with all necessary app-specific settings
- [ ] Implemented conversion helpers (GroupActivity data → App data)
- [ ] Verified settings are applied before opening immersive space
- [ ] Tested that late joiners see identical viewing experience
- [ ] All settings that affect viewing are synced (projection, FOV, etc.)

### Immersive Space Coordination

- [ ] Created action closures for opening/closing immersive space
- [ ] Stored closures in `@MainActor`-isolated state
- [ ] Implemented helper methods that avoid data races
- [ ] Added session state observation for group exit coordination
- [ ] Tested everyone enters together
- [ ] Tested everyone exits together
- [ ] `.groupActivityAssociation()` applied to WindowGroup VIEW content (not Scene)
- [ ] `.groupActivityAssociation()` applied to ImmersiveSpace VIEW content (not Scene)
- [ ] Different IDs for each window/space

### Smart Play Button (Optional)

- [ ] Removed separate SharePlay button (if using smart pattern)
- [ ] Implemented `prepareForActivation()` pattern
- [ ] Added graceful fallback to solo playback
- [ ] Tested on FaceTime call (should activate SharePlay)
- [ ] Tested without FaceTime call (should play solo)

### Swift Concurrency Safety

- [ ] All state classes marked `@MainActor` where appropriate
- [ ] Delegate methods use `some GroupActivity` not `any GroupActivity`
- [ ] No data races when passing models to async functions
- [ ] No `identifierFor` implementation in `AVPlayerPlaybackCoordinatorDelegate`
- [ ] Explicit capture lists in closures (`[self]`)

### UI/UX Polish

- [ ] Show SharePlay status indicator when active
- [ ] Show participant count
- [ ] Add "Leave Party" button (local exit)
- [ ] Add "End for All" button (terminate session)
- [ ] Hide SharePlay controls when session inactive
- [ ] Green handlebar appears in window during SharePlay
- [ ] Green handlebar persists after exiting immersive space

### Testing Matrix

- [ ] Solo playback works (no FaceTime)
- [ ] SharePlay activation works (on FaceTime)
- [ ] Late joiner sees same video with same settings
- [ ] Video sync works (play/pause/seek)
- [ ] Immersive space enters together
- [ ] Immersive space exits together
- [ ] Green handlebar appears in window during SharePlay
- [ ] Green handlebar persists after exiting immersive space
- [ ] Leave vs End session behavior correct
- [ ] Session survives app moving to background
- [ ] Clean shutdown when session invalidates
- [ ] Settings sync correctly (projection, FOV, etc.)
- [ ] Resume position doesn't conflict with SharePlay

