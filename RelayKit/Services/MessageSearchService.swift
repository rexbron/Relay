// Copyright 2026 Link Dupont
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import os
import RelayInterface

/// Full-text message search via the Matrix `POST /_matrix/client/v3/search` endpoint.
///
/// This service makes direct HTTP calls to the homeserver, bypassing the
/// Matrix Rust SDK (which does not yet expose the search API). When the SDK
/// adds native search support, this implementation can be replaced with an
/// SDK-delegating one without changing the ``MessageSearchServiceProtocol``
/// contract.
private let logger = Logger(subsystem: "app.subpop.Relay", category: "MessageSearch")

@Observable
public final class MessageSearchService: MessageSearchServiceProtocol {
    public private(set) var results: [MessageSearchResult] = []
    public private(set) var isSearching = false
    public private(set) var hasMore = false
    public private(set) var totalCount: Int?

    private let client: ClientProxyProtocol
    private var nextBatch: String?
    private var lastTerm: String?
    private var lastFilter: MessageSearchFilter?

    init(client: ClientProxyProtocol) {
        self.client = client
    }

    // MARK: - MessageSearchServiceProtocol

    public func search(term: String, filter: MessageSearchFilter?) async throws {
        cancel()
        results = []
        nextBatch = nil
        totalCount = nil
        hasMore = false
        lastTerm = term
        lastFilter = filter

        isSearching = true
        defer { isSearching = false }

        let response = try await performSearch(term: term, filter: filter, nextBatch: nil)
        guard !Task.isCancelled else { return }
        results = response.results
        nextBatch = response.nextBatch
        totalCount = response.totalCount
        hasMore = response.nextBatch != nil
    }

    public func loadMore() async throws {
        guard let nextBatch, let lastTerm, !isSearching else { return }

        isSearching = true
        defer { isSearching = false }

        let response = try await performSearch(
            term: lastTerm,
            filter: lastFilter,
            nextBatch: nextBatch
        )
        guard !Task.isCancelled else { return }
        results.append(contentsOf: response.results)
        self.nextBatch = response.nextBatch
        totalCount = response.totalCount
        hasMore = response.nextBatch != nil
    }

    public func cancel() {
        isSearching = false
        results = []
        nextBatch = nil
        totalCount = nil
        hasMore = false
    }

    // MARK: - HTTP

    private struct SearchResponse {
        let results: [MessageSearchResult]
        let nextBatch: String?
        let totalCount: Int?
    }

    private func performSearch(
        term: String,
        filter: MessageSearchFilter?,
        nextBatch: String?
    ) async throws -> SearchResponse {
        let session = try client.session()

        // Build URL with optional pagination token.
        var urlString = "\(client.homeserver)_matrix/client/v3/search"
        if let nextBatch {
            let encoded = nextBatch.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? nextBatch
            urlString += "?next_batch=\(encoded)"
        }
        guard let url = URL(string: urlString) else {
            throw MessageSearchError.invalidURL
        }

        // Build request body.
        let body = SearchRequestBody(term: term, filter: filter)
        let bodyData = try JSONEncoder().encode(body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        logger.debug("Searching for '\(term)' at \(url)")

        let (data, httpResponse) = try await URLSession.shared.data(for: request)

        let statusCode = (httpResponse as? HTTPURLResponse)?.statusCode ?? 0
        if statusCode != 200 {
            let responseBody = String(data: data, encoding: .utf8) ?? "(non-UTF8)"
            logger.error("Search failed with status \(statusCode): \(responseBody)")
            throw MessageSearchError.httpError(statusCode: statusCode)
        }

        logger.debug("Search returned \(data.count) bytes")

        let decoded: SearchResponseBody
        do {
            decoded = try JSONDecoder().decode(SearchResponseBody.self, from: data)
        } catch {
            let responseBody = String(data: data, encoding: .utf8) ?? "(non-UTF8)"
            logger.error("Failed to decode search response: \(error)\n\(responseBody)")
            throw error
        }
        let roomEvents = decoded.searchCategories.roomEvents

        let highlights = roomEvents?.highlights ?? []
        let mappedResults = (roomEvents?.results ?? []).compactMap { result -> MessageSearchResult? in
            guard let event = result.result else { return nil }
            let body = (event.content["body"] as? String) ?? ""
            let timestamp = Date(
                timeIntervalSince1970: TimeInterval(event.originServerTs) / 1000.0
            )
            // Try to extract sender profile from event context.
            let profile = result.context?.profileInfo?[event.sender]

            return MessageSearchResult(
                eventId: event.eventId,
                roomId: event.roomId,
                roomName: nil,
                sender: event.sender,
                senderDisplayName: profile?.displayname,
                senderAvatarURL: profile?.avatarUrl,
                body: body,
                timestamp: timestamp,
                rank: result.rank,
                highlights: highlights
            )
        }

        return SearchResponse(
            results: mappedResults,
            nextBatch: roomEvents?.nextBatch,
            totalCount: roomEvents?.count
        )
    }

}

// MARK: - Errors

enum MessageSearchError: LocalizedError {
    case invalidURL
    case httpError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid search URL."
        case .httpError(let statusCode):
            "Search failed with status \(statusCode)."
        }
    }
}

// MARK: - Request/Response Codable Types

/// These types model the Matrix `POST /_matrix/client/v3/search` request
/// and response. They are private implementation details.

private struct SearchRequestBody: Encodable {
    let searchCategories: SearchCategories

    init(term: String, filter: MessageSearchFilter?) {
        searchCategories = SearchCategories(
            roomEvents: RoomEventsCriteria(term: term, filter: filter)
        )
    }

    enum CodingKeys: String, CodingKey {
        case searchCategories = "search_categories"
    }

    struct SearchCategories: Encodable {
        let roomEvents: RoomEventsCriteria

        enum CodingKeys: String, CodingKey {
            case roomEvents = "room_events"
        }
    }

    struct RoomEventsCriteria: Encodable {
        let searchTerm: String
        let orderBy: String
        let keys: [String]
        let filter: EventFilter
        let eventContext: EventContext

        init(term: String, filter: MessageSearchFilter?) {
            self.searchTerm = term
            self.orderBy = filter?.orderBy.rawValue ?? "recent"
            self.keys = ["content.body"]
            self.eventContext = EventContext(beforeLimit: 0, afterLimit: 0, includeProfile: true)
            self.filter = EventFilter(
                rooms: filter?.roomIds,
                senders: filter?.senderIds
            )
        }

        enum CodingKeys: String, CodingKey {
            case searchTerm = "search_term"
            case orderBy = "order_by"
            case keys
            case filter
            case eventContext = "event_context"
        }

        struct EventFilter: Encodable {
            let rooms: [String]?
            let senders: [String]?
        }

        struct EventContext: Encodable {
            let beforeLimit: Int
            let afterLimit: Int
            let includeProfile: Bool

            enum CodingKeys: String, CodingKey {
                case beforeLimit = "before_limit"
                case afterLimit = "after_limit"
                case includeProfile = "include_profile"
            }
        }
    }
}

private struct SearchResponseBody: Decodable {
    let searchCategories: ResultCategories

    enum CodingKeys: String, CodingKey {
        case searchCategories = "search_categories"
    }

    struct ResultCategories: Decodable {
        let roomEvents: RoomEventsResult?

        enum CodingKeys: String, CodingKey {
            case roomEvents = "room_events"
        }
    }

    struct RoomEventsResult: Decodable {
        let count: Int?
        let highlights: [String]?
        let nextBatch: String?
        let results: [SearchResult]?

        enum CodingKeys: String, CodingKey {
            case count
            case highlights
            case nextBatch = "next_batch"
            case results
        }
    }

    struct SearchResult: Decodable {
        let rank: Double?
        let result: ClientEvent?
        let context: EventContext?
    }

    struct ClientEvent: Decodable {
        let eventId: String
        let type: String
        let content: [String: Any]
        let sender: String
        let roomId: String
        let originServerTs: Int64

        enum CodingKeys: String, CodingKey {
            case eventId = "event_id"
            case type
            case content
            case sender
            case roomId = "room_id"
            case originServerTs = "origin_server_ts"
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            eventId = try container.decode(String.self, forKey: .eventId)
            type = try container.decode(String.self, forKey: .type)
            sender = try container.decode(String.self, forKey: .sender)
            roomId = try container.decode(String.self, forKey: .roomId)
            originServerTs = try container.decode(Int64.self, forKey: .originServerTs)

            // Decode content as a generic dictionary.
            let rawContent = try container.decode(AnyCodable.self, forKey: .content)
            content = rawContent.value as? [String: Any] ?? [:]
        }
    }

    struct EventContext: Decodable {
        let profileInfo: [String: UserProfileInfo]?

        enum CodingKeys: String, CodingKey {
            case profileInfo = "profile_info"
        }
    }

    struct UserProfileInfo: Decodable {
        let displayname: String?
        let avatarUrl: String?

        enum CodingKeys: String, CodingKey {
            case displayname
            case avatarUrl = "avatar_url"
        }
    }
}

/// A lightweight type-erased container for decoding arbitrary JSON values.
private struct AnyCodable: Decodable {
    let value: Any

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues(\.value)
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map(\.value)
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if container.decodeNil() {
            value = NSNull()
        } else {
            value = [String: Any]()
        }
    }
}
