[← Back to Documentation Home](../README.md) | [← Previous: Architecture Prerequisites](02-Architecture-Prerequisites.md)

# Quick Start Guide

This guide will get you up and running quickly with a complete working example. For detailed explanations, see the [Core Integration](../2-Core-Integration/) section.

---

## License Activation

**Free Tier (Default)**: The package works out of the box with no activation required. Free Tier includes:

- Up to 5 Spatial Participants (capped by FaceTime itself)
- No time limit
- Full immersive capabilities

**Pro/Enterprise Tiers**: License activation is required to unlock unlimited participants and session duration.

### Free Tier Usage

The Free Tier is the default mode and requires **no activation code**. Simply integrate the package and start using it:

```swift
import SwiftUI
import ImmersiveWatchParty

@main
struct YourApp: App {
    @State var appState: AppState

    init() {
        // No activation needed for Free Tier!
        // Just initialize your app state
        self._appState = State(wrappedValue: AppState())
    }

    var body: some Scene {
        // ... your app code
    }
}
```

The Free Tier works immediately with:

- Up to 2 participants per session
- 5-minute session duration limit
- All immersive capabilities enabled

If you need more participants or longer sessions, see the activation instructions below.

### Understanding License Tiers

The package operates in three tiers:

**Free Tier** (no license key or activation required):
<!-- 
- Maximum 2 participants
- 5-minute session limit
- Full immersive capabilities
- **Default mode** - works out of the box without calling `activate()`

**Pro Tier** (per-app perpetual license):

- ✅ Unlimited participants
- ✅ Unlimited session duration
- ✅ Perpetual license with 1 year of updates
- ✅ Full immersive capabilities
- ✅ **Licensed per bundle ID** - unlimited developers can use the same key for your app -->

**Enterprise Tier** (per-app annual subscription):

- ✅ Everything in Pro
- ✅ Annual subscription model
- ✅ Priority support
- ✅ Custom features
- ✅ **Licensed per bundle ID** - unlimited developers can use the same key for your app

### How Licensing Works: Per-App, Not Per-Seat

**⚠️ IMPORTANT**: ImmersiveWatchParty licenses are sold **per app** (bundle ID), not per developer or per seat.

**What This Means:**

- ✅ **One license per app**: Purchase one license for each app you're building (identified by bundle ID)
- ✅ **Unlimited developers**: Your entire team can use the same license key for that app
- ✅ **Team sharing**: Commit the license key to your repo or share it via secure channels with your team
- ✅ **All environments**: Works on all developer machines, CI/CD, and production builds

**Examples:**

- **Scenario 1**: You have a team of 10 developers building one visionOS app (`com.yourcompany.app`)

  - **Cost**: One Pro license ($2,000) - all 10 developers use the same key
  - **Savings**: Compared to per-seat pricing, you save $18,000

- **Scenario 2**: You're building 3 different visionOS apps
  - **Cost**: Three Pro licenses ($6,000) - one per app
  - **Each team**: Uses their app's specific license key (unlimited developers per app)

**Security Enforcement:**

- License keys are cryptographically tied to your bundle ID
- A key for `com.yourcompany.app1` will NOT work for `com.yourcompany.app2`
- All developers on the same app can share the same key
- No phone-home or seat tracking - offline validation only

### Where to Activate

**License activation MUST happen BEFORE your AppState is initialized.** The `activate()` function is `@MainActor` isolated, so it will automatically run on the MainActor even when called from `init()`.

**⚠️ CRITICAL PATTERN**: You must activate the license in your `App` struct's `init()` **before** initializing `@State var appState`.

### Activation Code

**✅ CORRECT - Activate in App.init() before AppState initialization:**

```swift
import SwiftUI
import ImmersiveWatchParty

@main
struct YourApp: App {
    // 1. Declare the state property (don't initialize yet)
    @State var appState: AppState
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    init() {
        // 2. FIRST: Activate the license (runs on MainActor automatically)
        let proLicenseKey = "YOUR_LICENSE_KEY_HERE"
        ImmersiveWatchParty.activate(withLicenseKey: proLicenseKey)

        // 3. THEN: Initialize your app state
        // This ensures the manager sees the activated license
        self._appState = State(wrappedValue: AppState())
    }

    var body: some Scene {
        WindowGroup(id: "MainWindow") {
            ContentView()
                .environment(appState)
                .environment(\.sharePlayMessenger, appState.sharePlayManager.messenger)
                .groupActivityAssociation(.primary("main-window"))
            .task {
                // Set up session monitoring
                appState.immersiveSpaceOpenAction = { [self] in
                    guard let stream = appState.selectedStream else { return }
                    await openImmersiveSpace(value: stream)
                }

                // Monitor SharePlay sessions
                await monitorSharePlaySessions()
            }
        }
        .defaultSize(width: 800, height: 850)
        .environment(appState)

        // ... rest of scenes
    }
}
```

**Why This Pattern?**

1. `activate()` is marked `@MainActor`, so Swift automatically runs it on the MainActor
2. Activation happens **before** `AppState` (which contains `ImmersiveWatchPartyManager`) is created
3. When `setupSession()` is called later, the license is already activated
4. This prevents the "must call activate() first" error

**Note on Activation:**

- Activation is **OPTIONAL** - the package defaults to Free Tier if not activated
- Free Tier works without any license key or activation call
- Call `activate()` only if you have a Pro or Enterprise license key to unlock paid features

### Using Your License Key

When you purchase a Pro or Enterprise license, you'll receive a license key via email. The key looks like this:

```
eyJ0aWVyIjoicHJvIiwiY3VzdG9tZXJJRCI6InlvdXJAZW1haWwuY29tIiwidXBkYXRlc1Vu...
```

**Replace the placeholder** with your actual license key:

```swift
// ❌ DON'T use placeholder
let proLicenseKey = "YOUR_LICENSE_KEY_HERE"

// ✅ Use your actual license key
let proLicenseKey = "eyJ0aWVyIjoicHJvIiwiY3VzdG9tZXJJRCI6InlvdXJAZW1haWwuY29tIi..."
ImmersiveWatchParty.activate(withLicenseKey: proLicenseKey)
```

### What Happens During Activation

When you call `activate(withLicenseKey:)`, the package:

1. ✅ Verifies the cryptographic signature
2. ✅ Checks the license is for your bundle ID
3. ✅ Validates the license tier and expiration date
4. ✅ Unlocks Pro/Enterprise features if valid
5. ⚠️ Falls back to Free tier if invalid

### Console Output

**Successful Activation:**

```
============================================================
🔐 ImmersiveWatchParty License Activation
============================================================
📱 Bundle ID: com.yourcompany.yourapp
🔍 Verifying license key...
   ✓ License key format validated
   ✓ Cryptographic signature verified
   ✓ License data decoded
   ✓ Bundle ID verified
   ✓ Pro license covers this version

✅ License verification SUCCESSFUL!

📊 License Details:
   • Tier: PRO
   • Customer: your@email.com
   • Bundle ID: com.yourcompany.yourapp
   • Valid Until: Nov 12, 2026 at 1:09 AM
   • Type: Perpetual + 1 Year Updates
   • Build Date: Nov 12, 2024 at 2:15 PM
   • Licensing: Per-App (Unlimited Developers)

🎉 ImmersiveWatchParty is now active with PRO features!

🔓 Unlocked Features:
   ✓ Unlimited participants
   ✓ Unlimited session duration
   ✓ Full immersive capabilities
============================================================
```

**Failed Activation (Falls back to Free Tier):**

```
============================================================
🔐 ImmersiveWatchParty License Activation
============================================================
📱 Bundle ID: com.yourcompany.yourapp
🔍 Verifying license key...
❌ License verification FAILED
⚠️  Error: Bundle ID mismatch. This license is for 'com.other.app', not 'com.yourcompany.yourapp'.

📋 Status: Running in FREE TIER mode
   • Maximum 2 participants
   • 5-minute session limit

💡 Tip: To unlock all features, purchase a Pro or Enterprise license
============================================================
```

### Important Notes

**Timing:**

- ✅ Activate in `App.init()` **before** initializing `AppState`
- ✅ The `activate()` function is `@MainActor` isolated and runs safely from `init()`
- ✅ Must happen before any SharePlay sessions start
- ❌ Don't activate after `AppState` is created (too late)

**Security:**

- License keys are tied to your app's bundle ID (e.g., `com.yourcompany.yourapp`)
- Keys cannot be shared between different apps (different bundle IDs)
- All developers on your team can use the same key for your app
- Each device validates the license independently (offline validation)
- No network connection required for validation
- One license covers unlimited developers working on the same app

<!-- **Free Tier Enforcement:**

If you don't activate a license or activation fails, the package runs in Free tier mode with these limits:

- **Participant Limit**: When a free user tries to join a session with 3+ participants, that user will fail to join locally (other participants continue unaffected)
  - Triggers `didFailToJoin(reason: .participantLimitExceeded)` delegate callback
- **Time Limit**: After 5 minutes, the free user will automatically leave the session (other participants continue unaffected)
  - Triggers `didFailToJoin(reason: .sessionTimeLimitExceeded)` delegate callback
- **Local Enforcement**: These limits only affect the free-tier user. Paid users (Pro/Enterprise) are never impacted by free users' restrictions
- **Delegate Callback**: The `didFailToJoin` delegate method is called when limits are hit, allowing you to show "Upgrade to Pro" alerts
- Console warnings will appear before enforcement occurs

**Important Security Note**: Free tier enforcement is LOCAL-ONLY. A free-tier user cannot disrupt or terminate sessions for paid users. This prevents DoS attacks where a malicious free user could otherwise kick paid customers out of their sessions.

**Pro/Enterprise Benefits:**

With a valid license, these limits are removed and you get:

- ✅ Unlimited participants (tested with 10+)
- ✅ Unlimited session duration (hours of continuous use) -->

### Troubleshooting License Activation

**"Bundle ID mismatch"**

Your license key is tied to a specific bundle ID (one license per app). Make sure you're using the license key that was generated for your app's bundle ID:

1. Check your app's bundle ID: Xcode → Target → General → Bundle Identifier
2. Verify it matches the bundle ID in your license email
3. If they don't match, contact support to update the bundle ID or purchase a license for your actual bundle ID

**Note**: Each app (bundle ID) requires its own license. If you're building multiple apps, you'll need a separate license for each. However, all developers working on the same app can share the same license key.

**"License expired"**

- **Pro licenses**: Check if your build date is after the "Valid Until" date. You need to renew for updates.
- **Enterprise licenses**: Your subscription has expired. Renew your subscription.

**"Invalid cryptographic signature"**

The license key is corrupted or modified. Copy the key from your email again, ensuring:

- No extra spaces at the beginning or end
- No line breaks in the middle of the key
- The complete key is copied (they're usually very long)

**License not activating / No console output**

Make sure you're calling `activate()` in the right place and order:

```swift
// ✅ CORRECT - In App.init() BEFORE AppState
@main
struct YourApp: App {
    @State var appState: AppState  // Declare, don't initialize

    init() {
        // 1. Activate FIRST
        ImmersiveWatchParty.activate(withLicenseKey: "YOUR_LICENSE_KEY")

        // 2. THEN initialize state
        self._appState = State(wrappedValue: AppState())
    }

    var body: some Scene { ... }
}

// ❌ WRONG - Activating after AppState is created
@main
struct YourApp: App {
    @State private var appState = AppState()  // Already created!

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // TOO LATE - AppState (with manager) already exists
                    ImmersiveWatchParty.activate(withLicenseKey: "...")
                }
        }
    }
}
```

**Still on Free tier after activation**

Check the console output carefully. If you see "License verification FAILED", read the error message to understand why. Common issues:

- Wrong bundle ID
- Expired license
- Corrupted key

### Getting a License Key

To purchase a Pro or Enterprise license:

1. Visit the ImmersiveWatchParty website
2. Select your tier (Pro or Enterprise)
3. Provide your app's bundle ID (e.g., `com.yourcompany.yourapp`)
4. Complete the purchase (one license per app, unlimited developers)
5. You'll receive your license key via email
6. Share the key with your entire development team - all developers working on your app can use it
7. Each developer adds the key to their local development environment

**Pricing Model**: Licenses are sold **per app (bundle ID)**, not per developer. One license covers your entire development team working on that specific app.

**Enterprise customers**: Contact sales for multi-app packages and custom licensing options.

---

## Complete Example

Here's a minimal but complete integration:

### App.swift

```swift
import SwiftUI
import ImmersiveWatchParty

@main
struct WatchPartyApp: App {
    @State private var appState = AppState()
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(\.sharePlayMessenger, appState.sharePlayManager.messenger)
                // Observe flag to trigger immersive space opening
                .onChange(of: appState.shouldOpenImmersiveSpace) { _, shouldOpen in
                    if shouldOpen {
                        Task {
                            await openImmersiveSpace(id: "theater")
                            appState.shouldOpenImmersiveSpace = false
                        }
                    }
                }
        }

        ImmersiveSpace(id: "theater") {
            TheaterView()
                .environment(appState)
                .environment(\.sharePlayMessenger, appState.sharePlayManager.messenger)
        }
    }
}
```

### AppState.swift

```swift
import ImmersiveWatchParty
import AVFoundation
import SwiftUI

@MainActor
@Observable
class AppState {
    let sharePlayManager: ImmersiveWatchPartyManager

    var player: AVPlayer?
    var currentVideoID: String?
    
    // Flag to trigger immersive space opening
    var shouldOpenImmersiveSpace: Bool = false

    init() {
        self.sharePlayManager = ImmersiveWatchPartyManager(localUUID: UUID())
        // Set delegate to self (direct conformance pattern)
        self.sharePlayManager.delegate = self
    }

    func loadVideo(id: String) async throws {
        currentVideoID = id
        let url = URL(string: "https://example.com/video/\(id).m3u8")!
        player = AVPlayer(url: url)
    }
}

// MARK: - ImmersiveWatchPartyDelegate Conformance
extension AppState: ImmersiveWatchPartyDelegate {
    func sessionManager(
        _ manager: ImmersiveWatchPartyManager,
        received activity: some GroupActivity
    ) async -> Bool {
        guard let watchActivity = activity as? WatchTogetherActivity else {
            return false
        }

        do {
            try await loadVideo(id: watchActivity.videoID)
            self.shouldOpenImmersiveSpace = true  // ← Trigger immersive space opening
            return true
        } catch {
            print("Failed to load video: \(error)")
            return false
        }
    }

    // Implement other optional delegate methods as needed
    func sessionManagerDidBecomeReady(_ manager: ImmersiveWatchPartyManager) {}
    func sessionManager(_ manager: ImmersiveWatchPartyManager, didHostSession sessionID: String) {}
    func sessionManager(_ manager: ImmersiveWatchPartyManager, participantDidJoin participantUUID: UUID) {}
    func sessionManager(_ manager: ImmersiveWatchPartyManager, participantDidLeave participantUUID: UUID) {}
    func sessionManager(_ manager: ImmersiveWatchPartyManager, didFailToJoin reason: JoinFailureReason) {}
    func sessionManagerDidInvalidate(_ manager: ImmersiveWatchPartyManager) {}
}
```

### ContentView.swift

```swift
import SwiftUI
import GroupActivities

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openImmersiveSpace) private var openSpace

    var body: some View {
        VStack {
            Button("Open Theater") {
                Task {
                    await openSpace(id: "theater")
                }
            }

            Button("Start SharePlay") {
                startSharePlay()
            }
        }
        .task {
            await monitorSharePlaySessions()
        }
    }

    private func startSharePlay() {
        Task {
            let activity = WatchTogetherActivity(
                videoID: "video123",
                videoTitle: "Demo Video",
                thumbnailURL: nil
            )
            _ = try? await activity.activate()
        }
    }

    private func monitorSharePlaySessions() async {
        for await session in WatchTogetherActivity.sessions() {
            appState.sharePlayManager.setupSession(session: session)
            observeParticipants(session: session)
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
}
```

### TheaterView.swift

```swift
import SwiftUI
import RealityKit

struct TheaterView: View, AVPlayerPlaybackCoordinatorDelegate {
    @Environment(AppState.self) private var appState
    @State private var updateTask: Task<Void, Never>?

    var body: some View {
        RealityView { content, attachments in
            let root = Entity()
            content.add(root)

            // Create a screen mesh (16:9 aspect ratio)
            let screenMesh = MeshResource.generatePlane(width: 1.6, height: 0.9)
            
            // Create video material if player exists
            if let player = appState.player {
                // NOTE: We use VideoMaterial (RealityKit) instead of AVPlayerViewController
                // to ensure Spatial Personas remain visible in the shared space.
                let videoMaterial = VideoMaterial(avPlayer: player)
                let screenEntity = ModelEntity(mesh: screenMesh, materials: [videoMaterial])
                root.addChild(screenEntity)
            }

            // Start attachment positioning
            updateTask = appState.sharePlayManager.handleAttachmentUpdates(
                for: attachments,
                roles: ["controls": .controlPanel]
            )

        } attachments: {
            Attachment(id: "controls") {
                // Controls overlay (play/pause, etc)
                // Note: We don't use VideoPlayer here to ensure
                // proper immersive rendering with personas
                VStack {
                    if let player = appState.player {
                        // Custom controls would go here
                        Text("Now Playing")
                            .font(.caption)
                            .padding()
                            .glassBackgroundEffect()
                    }
                }
            }
        }
        .onAppear {
            if let player = appState.player {
                appState.sharePlayManager.registerPlayer(player, delegate: self)
            }
        }
        .onDisappear {
            updateTask?.cancel()
            updateTask = nil
        }
    }
}
```

---

**Next Steps**: See [App Lifecycle & Session Setup](../2-Core-Integration/01-App-Lifecycle-Setup.md) for detailed explanations of each component.

