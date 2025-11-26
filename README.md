# Vantage-Kit / ImmersiveWatchParty SDK

**The synchronized co-watching engine for Apple Vision Pro.**

[![visionOS 26.0](https://img.shields.io/badge/visionOS-26.0%2B-blue)](https://developer.apple.com/visionos/)
[![Swift 6](https://img.shields.io/badge/Swift-6.0-orange)](https://developer.apple.com/swift/)
[![License](https://img.shields.io/badge/License-Commercial%20%2F%20Restricted-purple)](LICENSE.md)

**ImmersiveWatchParty** provides the synchronization, security, and spatial coordination layer that `AVPlayer` is missing. It enables users to watch immersive (VR180/3D) content side-by-side using Spatial Personas, managing the millisecond-accurate sync required for live events.

> **Architectural Note:** This SDK solves the "Gap" in Apple's native APIs by bridging `AVPlayerPlaybackCoordinator` with RealityKit's coordinate space, ensuring UI attachments remain pinned relative to dynamic SharePlay participants.

## 🚀 Key Features

* **Drop-in Synchronization:** Thread-safe actor model wrapping `AVPlayerPlaybackCoordinator`.
* **Spatial UI Abstraction:** Automatically positions SwiftUI attachments relative to dynamic Spatial Persona "Seat" poses (visionOS 2.0) with fallbacks for visionOS 1.0.
* **Security Hooks:** Built-in delegate patterns for server-side entitlement verification (prevents client-side piracy patching).
* **State Management:** Handles the complex lifecycle of entering/exiting ImmersiveSpaces as a group.

## 📚 Documentation

Full integration guides, architectural diagrams, and API references are available in the **[Documentation Directory](Documentation/ImmersiveWatchParty_README.md)**.

* **[Getting Started](Documentation/1-Getting-Started/)**: Installation & Prerequisites.
* **[Core Integration](Documentation/2-Core-Integration/)**: Lifecycle, Player Sync, and Space Coordination.
* **[Spatial UI & 3D](Documentation/3-Spatial-UI-And-3D/)**: Positioning attachments and 3D models.
* **[Advanced Patterns](Documentation/4-Advanced-Patterns/)**: Custom players, settings sync, and messaging.
* **[Security & Best Practices](Documentation/5-Security-And-Best-Practices/)**: Anti-piracy and concurrency safety.

## 📦 Installation

Add via Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/Vantage-Kit/ImmersiveWatchParty-SDK", from: "1.0.0")
]
```

## 💻 Quick Start

```swift
// 1. Initialize
let manager = ImmersiveWatchPartyManager(localUUID: UUID())
manager.delegate = self

// 2. Register Player (Syncs AVPlayer with SharePlay)
manager.registerPlayer(player, delegate: self)

// 3. Position UI (The "Magic" Function)
// Automatically handles 3D transforms for Solo vs. Shared modes
let task = manager.handleAttachmentUpdates(
    for: attachments,
    roles: ["controls": .controlPanel]
)
```

## 🤖 AI Workflow Recommendations

If using an AI-powered development workflow such as Cursor, Google Antigravity, Claude Code, etc., we recommend dragging the entire **Documentation** directory from the packages section (once added via Swift Package Manager) into your own app's project files section so that the AI can have context.

Have the AI analyze and plan how it can integrate the immersive watch party feature into your video app.

## ⚠️ License & Restrictions

This SDK is **Proprietary Software** (Source Available via Enterprise License).

* **Permitted:** You may use this SDK for commercial applications in Music, Team Sports (NBA/NFL), Meditation, Enterprise, and Education.
* **Restricted:** You may **NOT** use this SDK for Combat Sports applications (MMA, Boxing, Wrestling, etc.) or to build competing middleware.

See [LICENSE.md](LICENSE.md) for full terms and field-of-use restrictions.

---
Built by Juyoung Kim. Currently building immersive experiences for combat sports. 