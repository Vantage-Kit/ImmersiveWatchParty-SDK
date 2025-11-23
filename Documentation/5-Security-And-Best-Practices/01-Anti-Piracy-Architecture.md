[← Back to Documentation Home](../README.md) | [Next: UUID Spoofing Prevention →](02-UUID-Spoofing-Prevention.md)

### ⚠️ CRITICAL SECURITY: SharePlay Piracy Prevention

**THE PROBLEM: Client-Side Delegate Patching**

SharePlay's trust-based architecture exposes a fundamental vulnerability that your package **cannot** fix. A malicious user can patch your customer's app to bypass content paywalls and access paid content for free via SharePlay.

#### The Vulnerability

The SharePlay flow:

1. **Host** (paid user) starts a SharePlay session with `WatchTogetherActivity(videoID: "premium_content")`
2. **Client** (free user) receives the activity
3. Your package calls the **client app's** `sessionManager(received:)` delegate method
4. The delegate is supposed to verify purchase and return `false` if unauthorized
5. **Attack**: Malicious user patches their app to always return `true`

#### The Attack Vector: Binary Patching

**Attacker's process:**

1. Download your customer's app from App Store
2. Use binary patching tools (Frida, Hopper, LLDB, hex editor)
3. Find the `sessionManager(received:)` function in the binary
4. Patch it to skip purchase verification and always return `true`
5. Join a SharePlay session hosted by a paid user
6. Watch premium content for free

**Original NBA App Code** (intended):

```swift
func sessionManager(
    _ manager: ImmersiveWatchPartyManager,
    received activity: some GroupActivity
) async -> Bool {
    guard let videoActivity = activity as? WatchTogetherActivity else {
        return false
    }

    // ✅ PAYWALL: Check if this user has purchased access
    let hasPurchased = await myAppServer.checkEntitlements(for: videoActivity.videoID)

    if !hasPurchased {
        showAlert("You must purchase this content to join the Watch Party.")
        return false  // ← The critical line
    }

    // User has purchased - allow access
    await appState.loadVideo(id: videoActivity.videoID)
    return true
}
```

**Attacker's Patched Version** (bypasses paywall):

```swift
func sessionManager(
    _ manager: ImmersiveWatchPartyManager,
    received activity: some GroupActivity
) async -> Bool {
    guard let videoActivity = activity as? WatchTogetherActivity else {
        return false
    }

    // ❌ PATCHED: Skip purchase check entirely
    print("🏴‍☠️ Bypassed paywall via binary patch")
    await appState.loadVideo(id: videoActivity.videoID)
    return true  // ← Always returns true
}
```

#### The Impact: One-to-Many Piracy

**Scenario**: NBA Finals Game 7 ($50 pay-per-view)

- **Jane** (Host) purchases the game legitimately
- **10 friends** use patched apps to join her SharePlay session for free
- **Result**: $450 in lost revenue from one session
- **Scale**: If this technique spreads, your customer loses their entire business model

This is the "Netflix password sharing" problem, but worse—the host doesn't even need to share credentials.

#### The Solution: Server-Side Authentication

**⚠️ YOUR PACKAGE CANNOT FIX THIS.** The security must be in your customer's backend server.

**Three-Step Defense:**

**1. Use Video IDs, Never Direct URLs**

```swift
// ❌ INSECURE - URL in GroupActivity
struct WatchTogetherActivity: GroupActivity {
    let videoURL: URL  // ← Attacker can extract and share this
}

// ✅ SECURE - Only ID in GroupActivity
struct WatchTogetherActivity: GroupActivity {
    let videoID: String  // ← Useless without server authentication
}
```

**2. Authenticate Every Request in Delegate**

Your delegate MUST call your backend server to get the streaming URL:

```swift
// ✅ SECURE IMPLEMENTATION
func sessionManager(
    _ manager: ImmersiveWatchPartyManager,
    received activity: some GroupActivity
) async -> Bool {
    guard let videoActivity = activity as? WatchTogetherActivity else {
        return false
    }

    do {
        // CRITICAL: Call YOUR server to authenticate and get URL
        // Even if attacker patches this to always return true,
        // they'll get a 401/403 from YOUR server
        let authenticatedURL = try await myBackend.getStreamingURL(
            videoID: videoActivity.videoID,
            userToken: currentUserAuthToken  // ← Server verifies this
        )

        // Server approved - load the video
        await appState.loadVideo(url: authenticatedURL)
        return true

    } catch AuthenticationError.unauthorized {
        // Server rejected: User hasn't purchased
        print("❌ Access denied: No purchase for \(videoActivity.videoID)")
        showAlert("You must purchase this content to join the Watch Party.")
        return false

    } catch {
        print("❌ Failed to authenticate: \(error)")
        return false
    }
}
```

**3. Server-Side Verification Logic**

Your backend API endpoint (`/api/streaming-url`) must:

```swift
// Backend API (pseudo-code)
func getStreamingURL(videoID: String, userToken: String) async throws -> URL {
    // 1. Validate the user's auth token
    guard let user = try await authenticateUser(token: userToken) else {
        throw AuthenticationError.invalidToken
    }

    // 2. Check if this user has purchased/subscribed to this video
    let hasPurchased = await database.checkPurchase(
        userID: user.id,
        videoID: videoID
    )

    guard hasPurchased else {
        throw AuthenticationError.unauthorized
    }

    // 3. Generate a short-lived, signed streaming URL
    // This prevents URL sharing
    let signedURL = await cdn.generateSignedURL(
        videoID: videoID,
        expiresIn: .minutes(15),  // Short-lived token
        userID: user.id           // Tied to specific user
    )

    return signedURL
}
```

#### Why This Defense Works

Even if the attacker patches the delegate to always return `true`:

1. ✅ The patched delegate still calls `myBackend.getStreamingURL()`
2. ✅ Your backend checks the user's auth token and purchase status
3. ✅ Unpaid user gets `401 Unauthorized` from YOUR server
4. ✅ No streaming URL = no video playback
5. ✅ The `AVPlayer` fails to load (no valid URL)

**The attacker would need to:**

- Patch your backend server (impossible)
- OR steal a legitimate user's auth token AND bypass server-side checks (extremely difficult)
- OR reverse-engineer your CDN's URL signing mechanism (extremely difficult)

This raises the barrier from "5 minutes with Frida" to "sophisticated server compromise."

#### Additional Security Layers

**DRM (Digital Rights Management):**

```swift
// Use FairPlay or other DRM
let asset = AVURLAsset(url: authenticatedURL)
asset.resourceLoader.setDelegate(drmDelegate, queue: DispatchQueue.main)
```

**Time-Limited Tokens:**

```swift
// Server generates URL that expires in 15 minutes
let signedURL = cdn.generateSignedURL(
    videoID: videoID,
    expiresIn: .minutes(15)
)
```

**Device Fingerprinting:**

```swift
// Server ties streaming URL to specific device
let signedURL = cdn.generateSignedURL(
    videoID: videoID,
    deviceID: deviceUUID  // Verified by CDN
)
```

**Watermarking:**

```swift
// Embed user identifier in video stream
let watermarkedURL = cdn.generateWatermarkedURL(
    videoID: videoID,
    watermark: user.email  // Identifies pirated copies
)
```

#### What Your Package Provides vs. What You Must Provide

**ImmersiveWatchParty provides:**

- ✅ Playback synchronization (AVPlayerPlaybackCoordinator)
- ✅ Message passing (GroupSessionMessenger)
- ✅ Immersive space coordination (SystemCoordinator)
- ✅ Participant tracking
- ✅ The "handshake" mechanism

**You MUST provide:**

- 🔒 Content authentication (purchase verification)
- 🔒 Streaming URL generation (server-side)
- 🔒 User authorization (auth tokens)
- 🔒 DRM and content protection
- 🔒 The "ID check at the door"

#### Summary: Defense Checklist

- [ ] GroupActivity contains only video IDs, never direct URLs
- [ ] `sessionManager(received:)` delegate calls YOUR backend for every join
- [ ] Backend verifies user's auth token before returning streaming URL
- [ ] Backend checks purchase/subscription status in database
- [ ] Streaming URLs are short-lived (15-60 minutes) and signed
- [ ] Streaming URLs are tied to specific user/device (prevents sharing)
- [ ] Consider DRM (FairPlay) for additional protection
- [ ] Consider watermarking to identify pirated copies
- [ ] Monitor for suspicious patterns (one host, many joiners)

**Remember**: Your package provides the "handshake" mechanism. It is your application's responsibility to check the "ID at the door." Server-side authentication is the ONLY way to prevent SharePlay piracy.

---



**Also see [UUID Spoofing Prevention](02-UUID-Spoofing-Prevention.md) for message authentication security.**
