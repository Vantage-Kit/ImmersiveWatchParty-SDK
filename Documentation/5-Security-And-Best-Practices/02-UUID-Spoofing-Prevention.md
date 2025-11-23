[← Back to Documentation Home](../README.md) | [← Previous: Anti-Piracy Architecture](01-Anti-Piracy-Architecture.md) | [Next: Concurrency Safety →](03-Concurrency-Safety.md)

### ⚠️ CRITICAL SECURITY WARNING: UUID Spoofing Vulnerability

**The `senderUUID` field is for Identification, NOT Authentication**

The `senderUUID` field inside your message structs is set by the client and is **not cryptographically verified by SharePlay**. Apple's `GroupSessionMessenger` is a trust-based system that does not authenticate message payloads.

**The Vulnerability:**

A malicious user can easily "spoof" this ID and impersonate any other participant in the session by manually creating messages with a fake `senderUUID`:

```swift
// Malicious code - attacker impersonating the host
let spoofedMessage = GroupExitImmersiveSpaceMessage(
    eventID: currentEventID,
    senderUUID: hostParticipantUUID,  // ❌ SPOOFED! Attacker claims to be host
    timestamp: Date()
)
try? await messenger.send(spoofedMessage)
```

**Potential Attacks:**

1. **Griefing/Denial of Service**: Attacker sends spoofed "exit immersive space" messages claiming to be the host, kicking everyone out of the session
2. **Impersonation**: Attacker spoofs host identity to gain unauthorized control (kick users, change settings, etc.)
3. **Privilege Escalation**: Attacker sends spoofed "make me host" or "grant admin" messages

**DO NOT Trust `senderUUID` For Security-Critical Logic:**

❌ **NEVER use `senderUUID` for:**

- Host-only controls (e.g., kicking users, ending the session)
- Admin privileges or role-based access control
- Purchase or entitlement verification
- Any "moderator" or "admin" level features
- Content access control decisions

✅ **ONLY use `senderUUID` for:**

- Displaying participant names in UI
- Filtering out your own messages (`message.senderUUID != localUUID`)
- Non-critical UI state synchronization
- Analytics and logging

**The Solution: Backend Verification**

Any security-critical actions MUST be verified by your own backend server:

```swift
// ✅ CORRECT - Verify with backend before allowing privileged action
func handleKickUserMessage(_ message: KickUserMessage) async {
    // Don't trust the senderUUID - verify with backend
    let isAuthorized = await yourBackend.verifyUserIsHost(
        sessionID: currentSessionID,
        userID: message.senderUUID
    )

    guard isAuthorized else {
        print("⚠️ Unauthorized kick attempt from \(message.senderUUID)")
        return
    }

    // Now safe to execute
    kickUser(message.targetUserUUID)
}

// ❌ WRONG - Trusting client-provided senderUUID
func handleKickUserMessage(_ message: KickUserMessage) {
    // Anyone can claim to be the host!
    if message.senderUUID == hostUUID {
        kickUser(message.targetUserUUID)  // ❌ EXPLOITABLE!
    }
}
```

**Best Practice: Design Messages Without Privilege Requirements**

The safest approach is to design your SharePlay experience so that most messages don't require privileged actions:

- Use Apple's `AVPlayerPlaybackCoordinator` for playback control (automatic, no messages needed)
- Make "exit immersive space" a local decision, not a group command
- Implement "vote to skip" instead of "host skips"
- Use consensus-based coordination where possible

**Summary:**

- SharePlay messages are **unauthenticated** and can be spoofed
- Never trust `senderUUID` for security decisions
- Use backend verification for any privileged actions
- Design your app to minimize privilege-based features

---



**Also see [Anti-Piracy Architecture](01-Anti-Piracy-Architecture.md) for content protection strategies.**
