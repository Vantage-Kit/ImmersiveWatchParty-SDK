//
//  Protocols.swift
//  ImmersiveWatchParty
//
//  Public protocol definitions for app developers to implement
//

import Foundation
import GroupActivities

/// Protocol that apps must implement to define their SharePlay activity
///
/// This protocol wraps GroupActivity and allows apps to define their own
/// activity types with custom metadata and content identifiers.
public protocol SharePlayActivity: GroupActivity {
    /// Unique identifier for this activity type
    static var activityIdentifier: String { get }
    
    /// Activity metadata for SharePlay UI
    var metadata: GroupActivityMetadata { get }
}

/// Protocol for loading content when a SharePlay activity is received
///
/// Apps implement this to handle loading their specific content model
/// when participants join a SharePlay session.
public protocol SharePlayContentLoader {
    /// Load content for the given activity
    /// - Parameter activity: The SharePlay activity containing content identifiers
    /// - Returns: `true` if content was successfully loaded, `false` otherwise
    func loadContent(for activity: some SharePlayActivity) async -> Bool
}

/// Protocol for access control checks
///
/// Apps implement this to enforce their business rules for SharePlay access
/// (e.g., subscription status, purchase requirements, premiere windows)
public protocol SharePlayAccessControl {
    /// Check if the user can start a SharePlay session for the given activity
    /// - Parameter activity: The SharePlay activity to check
    /// - Returns: `true` if the user can start SharePlay, `false` otherwise
    func canStartSharePlay(for activity: some SharePlayActivity) -> Bool
    
    /// Check if the user can join a SharePlay session for the given activity
    /// - Parameter activity: The SharePlay activity to check
    /// - Returns: `true` if the user can join SharePlay, `false` otherwise
    func canJoinSharePlay(for activity: some SharePlayActivity) -> Bool
}

/// Protocol for analytics integration (optional)
///
/// Apps can implement this to track SharePlay events with their analytics provider
public protocol SharePlayAnalytics {
    /// Log when a SharePlay session starts
    /// - Parameters:
    ///   - sessionId: Unique identifier for the session
    ///   - hostUserId: Identifier for the session host
    func logSessionStarted(sessionId: String, hostUserId: String)
    
    /// Log when a SharePlay session ends
    /// - Parameters:
    ///   - sessionId: Unique identifier for the session
    ///   - duration: Session duration in seconds
    ///   - peakParticipants: Maximum number of participants during the session
    func logSessionEnded(sessionId: String, duration: Int, peakParticipants: Int)
    
    /// Log when a participant joins a session
    /// - Parameters:
    ///   - sessionId: Unique identifier for the session
    ///   - userId: Identifier for the joining user
    ///   - totalParticipants: Total number of participants after join
    func logParticipantJoined(sessionId: String, userId: String, totalParticipants: Int)
    
    /// Log when a message is sent
    /// - Parameter messageType: Type name of the message
    func logMessageSent(messageType: String)
    
    /// Log when a message is received
    /// - Parameter messageType: Type name of the message
    func logMessageReceived(messageType: String)
}

/// Base protocol for messages that can be sent via SharePlay
///
/// All custom message types should conform to this protocol
public protocol IdentifiableMessage: Codable {
    /// Unique identifier for the sender
    var senderUUID: UUID { get }
}

