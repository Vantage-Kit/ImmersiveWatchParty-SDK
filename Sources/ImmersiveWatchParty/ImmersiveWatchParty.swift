//
//  ImmersiveWatchParty.swift
//  ImmersiveWatchParty
//
//  Main entry point for the ImmersiveWatchParty package
//

/// ImmersiveWatchParty - A turnkey solution for immersive SharePlay experiences on visionOS
///
/// This package provides a complete, production-ready implementation of SharePlay
/// with immersive space coordination for visionOS applications.
///
/// ## Overview
///
/// ImmersiveWatchParty handles the complex coordination between GroupActivities sessions
/// and visionOS immersive spaces, including:
/// - Session lifecycle management
/// - SystemCoordinator configuration for group immersive spaces
/// - Message passing infrastructure
/// - Participant tracking and state management
/// - Playback coordination with AVFoundation
///
/// ## Getting Started
///
/// 1. Implement the `SharePlayActivity` protocol for your content model
/// 2. Implement the `SharePlayContentLoader` protocol to handle content loading
/// 3. Configure the `ImmersiveWatchPartyManager` with your implementations
/// 4. Start using SharePlay in your app
///
/// ## Example
///
/// ```swift
/// let manager = ImmersiveWatchPartyManager()
/// manager.configure(
///     contentLoader: MyContentLoader(),
///     accessControl: MyAccessControl()
/// )
/// ```
///
/// - Note: The core implementation is provided by `ImmersiveWatchPartyCore`
@_exported import ImmersiveWatchPartyCore

// Re-export key types for convenience (these are at module level, not inside ImmersiveWatchPartyCore struct)
// They're already exported via @_exported import ImmersiveWatchPartyCore
