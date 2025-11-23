[← Back to Documentation Home](../README.md) | [Next: Quick Start Guide →](03-Quick-Start-Guide.md)

# Architecture Prerequisites

## 0. Before You Start: Know Your App

**⚠️ CRITICAL**: Answer these questions BEFORE integrating SharePlay. Understanding your app's architecture will save hours of debugging.

### Video Player

- [ ] I know where `AVPlayer` is instantiated in my code
- [ ] I can access `AVPlayer.player` (it's public/internal accessible)
- [ ] I understand when my player is created in the lifecycle
- [ ] I know if I use a custom wrapper or direct `AVPlayer`
- [ ] I've identified where player registration should happen

**If you can't check these**: Review your video player architecture first. See [Custom Player Wrappers](../4-Advanced-Patterns/01-Custom-Player-Wrappers.md) for custom wrappers.

### Immersive Space

- [ ] I know how I currently open immersive space
- [ ] I've identified if I use static ID (`ImmersiveSpace(id: "space")`) or pass data (`ImmersiveSpace(for: Model.self)`)
- [ ] I can explain how my current open/close flow works
- [ ] I know where immersive space state is managed

**If you use dynamic data**: See [Dynamic Data Models](../4-Advanced-Patterns/02-Dynamic-Data-Models.md) for the pattern.

### Settings & State

- [ ] I've listed all settings that affect video viewing (projection, FOV, audio tracks, etc.)
- [ ] I know where these settings are stored
- [ ] I understand which settings MUST be synced for SharePlay (anything that changes what users see/hear)
- [ ] I know how to convert my settings to/from `Codable` format

**If you have complex settings**: See [Settings Sync](../4-Advanced-Patterns/03-Settings-Sync.md) for syncing patterns.

### State Management

- [ ] I know if I use `@Observable`, `@ObservableObject`, or other
- [ ] I know where my main app state lives
- [ ] I understand my app's actor isolation (`@MainActor` usage)
- [ ] I know how to avoid data races when passing data to async functions

**If you're unsure**: See [Concurrency Safety](../5-Security-And-Best-Practices/03-Concurrency-Safety.md) for Swift concurrency patterns.

### Time Investment

**If you can't check all boxes above:**

- Spend 30 minutes reviewing your architecture
- Draw a diagram of your player lifecycle
- Map your immersive space flow
- List all viewing-related settings

**This upfront work will save 4+ hours of debugging later.**

---

## 2. Critical Prerequisites

**⚠️ IMPORTANT: Complete these steps BEFORE integrating the package**

### 2.1 Xcode Capabilities

Enable **Group Activities** capability:

1. Select your target in Xcode
2. Go to **Signing & Capabilities**
3. Click **+ Capability**
4. Add **Group Activities**

Without this, SharePlay sessions will fail silently.

### 2.2 Info.plist Configuration

Add the Group Activities usage description:

```xml
<key>NSGroupActivitiesUsageDescription</key>
<string>Watch videos together with friends in SharePlay</string>
```

Or in the Info tab:

- Key: `Privacy - Group Activities Usage Description`
- Value: Your custom message

### 2.3 App Architecture Requirements

This package works best with:

- **@Observable** or **@ObservableObject** app state
- **AVPlayer** for video playback (not custom players)
- **RealityKit** for immersive content positioning
- **visionOS 1.0+** (some features require visionOS 2.0+)

### 2.4 Architecture Assumptions

**⚠️ IMPORTANT**: This guide makes some assumptions about your app architecture:

**Basic Assumptions (Sections 1-7):**

- Direct access to `AVPlayer` instance
- Static `ImmersiveSpace(id: "space")` with no data passing
- Simple GroupActivity with just video ID
- Basic app state structure

**If your app differs, see these sections:**

- **Custom player wrappers?** → [Custom Player Wrappers](../4-Advanced-Patterns/01-Custom-Player-Wrappers.md)
- **Dynamic ImmersiveSpace with data?** → [Dynamic Data Models](../4-Advanced-Patterns/02-Dynamic-Data-Models.md)
- **Complex app settings to sync?** → [Settings Sync](../4-Advanced-Patterns/03-Settings-Sync.md)
- **Want context-aware play button?** → [Smart Play Button](../2-Core-Integration/05-Smart-Play-Button.md)

**Real-world apps often need:**

- Custom Wrappers - Most production apps wrap AVPlayer
- Dynamic Spaces - Most apps pass data to ImmersiveSpace
- Settings Sync - Any setting affecting viewing must be synced

**Time estimate:**

- Basic integration (following guide 1-7): ~2-3 hours
- Production integration (with custom architecture): ~4-8 hours

### 2.5 Understanding GroupActivity Patterns

**CRITICAL**: There are two patterns for defining GroupActivities:

**Pattern 1: Simple Struct (Basic)**

```swift
struct WatchTogetherActivity: GroupActivity {
    static let activityIdentifier = "com.yourapp.watch"
    let videoID: String
    // ...
}
```

**Pattern 2: Class Wrapper (Advanced - Required for Transferable)**

```swift
class WatchPartyActivity: GroupActivity, Transferable {
    private(set) var groupActivity: Activity

    struct Activity: GroupActivity {
        static let activityIdentifier = "com.yourapp.watch"
        let eventID: UUID
        let fightID: UUID
        // ...
    }

    init(event: Event, fight: Fight) {
        self.groupActivity = Activity(eventID: event.id, fightID: fight.id)
    }
}
```

**When to use Pattern 2:**

- You need `Transferable` conformance for ShareLink
- You have complex initialization logic
- You need to wrap multiple pieces of content

**Important**: If using Pattern 2, your delegate must cast correctly:

```swift
// In sessionManager(received:activity)
guard let wrapper = activity as? WatchPartyActivity else { return false }
let actualActivity = wrapper.groupActivity
// Use actualActivity to extract videoID, eventID, etc.
```

---

## 3. Architecture Discovery Flowchart

**Use this flowchart to determine which sections you need to read based on your app's architecture.**

```
START: Planning SharePlay Integration
│
├─ Q1: Do you have direct AVPlayer access?
│  ├─ YES → Go to Video Player Sync
│  └─ NO → Ask: Is it in a custom wrapper?
│     ├─ YES → Go to Custom Player Wrappers
│     └─ NO → You need to expose AVPlayer first
│
├─ Q2: What's your ImmersiveSpace pattern?
│  ├─ Static ID (ImmersiveSpace(id: "space"))
│  │  → Go to App Lifecycle Setup
│  └─ Dynamic Data (ImmersiveSpace(for: Model.self))
│     → Go to Dynamic Data Models
│
├─ Q3: Do you have app-specific viewing settings?
│  ├─ YES (projection, FOV, audio tracks, etc.)
│  │  → Go to Settings Sync
│  └─ NO → Use basic GroupActivity from App Lifecycle Setup
│
└─ Q4: What's your state management?
   ├─ @Observable → Examples use this (App Lifecycle Setup)
   ├─ @ObservableObject → Adapt examples (similar pattern)
   └─ Other → May need custom approach (see Concurrency Safety)
```

### Quick Decision Guide

**If your app matches this pattern:**

- Direct `AVPlayer` access
- Static `ImmersiveSpace(id: "space")`
- No complex viewing settings
- `@Observable` app state

**Then follow:** Core Integration sections (basic integration)

**If your app has:**

- Custom player wrapper → **See Custom Player Wrappers**
- Dynamic ImmersiveSpace → **See Dynamic Data Models**
- Complex settings → **See Settings Sync**
- Custom state management → **Review Concurrency Safety**

### Common Architecture Patterns

**Pattern A: Library-Based Video Player**

```
// Like OpenImmersive - player in external library
// Challenge: Finding registration point
// Solution: CustomAttachment or library callback
// See: Custom Player Wrappers (Pattern 2: Custom Attachment Hook)
```

**Pattern B: App-Owned AVPlayer**

```
// AVPlayer directly in your view/state
// Challenge: None - straightforward
// Solution: .onAppear registration
// See: Video Player Sync
```

**Pattern C: ViewModel-Wrapped Player**

```
// AVPlayer in ViewModel/ObservableObject
// Challenge: Timing and lifecycle
// Solution: Init or didSet registration
// See: Custom Player Wrappers (Pattern 3: Delegate Pattern)
```

---
