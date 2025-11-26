[← Back to Documentation Home](../README.md)

# Package Installation

### Swift Package Manager

Add the package to your Xcode project:

1. In Xcode, go to **File → Add Package Dependencies**
2. Enter the repository URL (or local path)
3. Select **ImmersiveWatchParty** as the product (NOT ImmersiveWatchPartyCore)
4. Add to your visionOS target

### Package.swift (for SPM projects)

```swift
dependencies: [
    .package(url: "https://github.com/Vantage-Kit/ImmersiveWatchParty-SDK", from: "1.0.0")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: ["ImmersiveWatchParty"]
    )
]
```

---
