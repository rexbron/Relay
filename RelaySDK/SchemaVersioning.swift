import Foundation
import SwiftData

// MARK: - Schema V1 (Baseline)

/// Captures the current schema as the V1 baseline.
///
/// The nested `@Model` class is a snapshot of ``CachedMessage``'s persisted stored
/// properties at this version. When the schema evolves, add a new `RelaySchemaV2`
/// with updated model definitions and a corresponding migration stage.
enum RelaySchemaV1: VersionedSchema {
    nonisolated(unsafe) static var versionIdentifier: Schema.Version = .init(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [CachedMessage.self]
    }

    @Model
    final class CachedMessage {
        @Attribute(.unique) var eventId: String
        var roomId: String
        var senderID: String
        var senderDisplayName: String?
        var senderAvatarURL: String?
        var body: String
        var timestamp: Date
        var isOutgoing: Bool
        var kindRaw: String
        var reactionsJSON: Data?
        var isHighlighted: Bool
        var replyEventID: String?
        var replySenderID: String?
        var replySenderName: String?
        var replyBody: String?

        init(
            eventId: String,
            roomId: String,
            senderID: String,
            senderDisplayName: String?,
            senderAvatarURL: String?,
            body: String,
            timestamp: Date,
            isOutgoing: Bool,
            kindRaw: String,
            reactionsJSON: Data?,
            isHighlighted: Bool,
            replyEventID: String?,
            replySenderID: String?,
            replySenderName: String?,
            replyBody: String?
        ) {
            self.eventId = eventId
            self.roomId = roomId
            self.senderID = senderID
            self.senderDisplayName = senderDisplayName
            self.senderAvatarURL = senderAvatarURL
            self.body = body
            self.timestamp = timestamp
            self.isOutgoing = isOutgoing
            self.kindRaw = kindRaw
            self.reactionsJSON = reactionsJSON
            self.isHighlighted = isHighlighted
            self.replyEventID = replyEventID
            self.replySenderID = replySenderID
            self.replySenderName = replySenderName
            self.replyBody = replyBody
        }
    }
}

// MARK: - Migration Plan

/// Describes the evolution of Relay's schema and how to migrate between versions.
///
/// When adding a new schema version:
/// 1. Define `RelaySchemaV2` (or V3, etc.) with updated nested model classes.
/// 2. Update the live `@Model` classes to match the latest version.
/// 3. Append the new schema to the `schemas` array.
/// 4. Add a migration stage (`.lightweight` or `.custom`) to `stages`.
enum RelayMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [RelaySchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
