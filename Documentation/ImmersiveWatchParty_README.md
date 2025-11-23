# ImmersiveWatchParty Documentation

A complete guide for integrating SharePlay and immersive space coordination into your visionOS app.

**Based on production implementations in VantageSpatialSports and OpenImmersive**

---

## Table of Contents

### 1. Getting Started
* [Installation](1-Getting-Started/01-Installation.md) - Package installation via Swift Package Manager
* [Architecture Prerequisites](1-Getting-Started/02-Architecture-Prerequisites.md) - Know your app architecture before integrating
* [Quick Start Guide](1-Getting-Started/03-Quick-Start-Guide.md) - Get up and running quickly with a complete example

### 2. Core Integration
* [App Lifecycle & Session Setup](2-Core-Integration/01-App-Lifecycle-Setup.md) - Required setup files, app structure, GroupActivity configuration, and session monitoring
* [Video Player Sync](2-Core-Integration/02-Video-Player-Sync.md) - Coordinate video playback across devices
* [Immersive Space Coordination](2-Core-Integration/03-Immersive-Space-Coordination.md) - Managing immersive space entry/exit in SharePlay sessions
* [Participant Management](2-Core-Integration/04-Participant-Management.md) - Tracking and observing participants
* [Smart Play Button](2-Core-Integration/05-Smart-Play-Button.md) - Context-aware play button pattern

### 3. Spatial UI & 3D
* [Attachment System](3-Spatial-UI-And-3D/01-Attachment-System.md) - Positioning SwiftUI attachments in RealityKit
* [Positioning 3D Models](3-Spatial-UI-And-3D/02-Positioning-3D-Models.md) - Positioning native RealityKit entities (ModelEntity, etc.)

### 4. Advanced Patterns
* [Custom Player Wrappers](4-Advanced-Patterns/01-Custom-Player-Wrappers.md) - Integrating SharePlay with wrapped AVPlayer instances
* [Dynamic Data Models](4-Advanced-Patterns/02-Dynamic-Data-Models.md) - Passing data to ImmersiveSpace with dynamic content
* [Settings Sync](4-Advanced-Patterns/03-Settings-Sync.md) - Syncing app-specific viewing settings across devices
* [Custom Messaging](4-Advanced-Patterns/04-Custom-Messaging.md) - Implementing custom SharePlay messages

### 5. Security & Best Practices
* [Anti-Piracy Architecture](5-Security-And-Best-Practices/01-Anti-Piracy-Architecture.md) - ⚠️ CRITICAL: Preventing SharePlay piracy through server-side authentication
* [UUID Spoofing Prevention](5-Security-And-Best-Practices/02-UUID-Spoofing-Prevention.md) - ⚠️ CRITICAL: Understanding message authentication limitations
* [Concurrency Safety](5-Security-And-Best-Practices/03-Concurrency-Safety.md) - Swift concurrency patterns and pitfalls

### 6. Reference
* [Troubleshooting](6-Reference/01-Troubleshooting.md) - Debugging decision trees and common issues
* [Migration Guide](6-Reference/02-Migration-Guide.md) - Migrating existing apps to SharePlay
* [Production Checklist](6-Reference/03-Production-Checklist.md) - Pre-launch verification checklist
* [API Reference](6-Reference/04-API-Reference.md) - Quick API method reference

---

## Original Integration Guide

For the complete guide in a single file, see [INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md).

---

**Last Updated:** November 2025  
**Package Version:** 1.0.0  
**Minimum visionOS:** 26.0  
**Recommended visionOS:** 26.0+  
**Production-Tested:** VantageSpatialSports, OpenImmersive

