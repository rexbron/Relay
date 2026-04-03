// TimelineItemProvider.swift
// RelayKit
//
// SPDX-License-Identifier: Apache-2.0

import Observation

/// Maintains a live array of `TimelineItem` values by applying timeline diffs.
///
/// Subscribe to the ``items`` property from SwiftUI to display the
/// current timeline state. The provider uses ``DiffEngine`` internally
/// to efficiently apply incremental updates from the SDK.
///
/// ```swift
/// struct TimelineView: View {
///     let provider: TimelineItemProvider
///
///     var body: some View {
///         ScrollView {
///             LazyVStack {
///                 ForEach(0..<provider.items.count, id: \.self) { index in
///                     TimelineItemRow(item: provider.items[index])
///                 }
///             }
///         }
///         .task {
///             await provider.observeUpdates()
///         }
///     }
/// }
/// ```
///
/// ## Topics
///
/// ### State
/// - ``items``
///
/// ### Observing
/// - ``observeUpdates()``
@Observable
public final class TimelineItemProvider: @unchecked Sendable {
    private let timelineProxy: TimelineProxyProtocol

    /// The current array of timeline items.
    public private(set) var items: [TimelineItem] = []

    /// Creates a timeline item provider.
    ///
    /// - Parameter timelineProxy: The timeline proxy to observe.
    public init(timelineProxy: any TimelineProxyProtocol) {
        self.timelineProxy = timelineProxy
    }

    /// Starts observing timeline updates and applying diffs.
    ///
    /// This method runs indefinitely until the task is cancelled.
    /// Typically called from a SwiftUI `.task` modifier.
    public func observeUpdates() async {
        for await diffs in timelineProxy.timelineUpdates {
            let operations = diffs.map { diff -> DiffOperation<TimelineItem> in
                timelineDiffToOperation(diff)
            }
            items = DiffEngine.applyBatch(operations, to: items)
        }
    }
}

/// Converts a `TimelineDiff` to a ``DiffOperation``.
///
/// - Parameter diff: The SDK timeline diff.
/// - Returns: The corresponding diff operation.
private func timelineDiffToOperation(_ diff: TimelineDiff) -> DiffOperation<TimelineItem> {
    switch diff {
    case .append(let values):
        return .append(values)
    case .clear:
        return .clear
    case .pushFront(let value):
        return .pushFront(value)
    case .pushBack(let value):
        return .pushBack(value)
    case .popFront:
        return .popFront
    case .popBack:
        return .popBack
    case .insert(let index, let value):
        return .insert(Int(index), value)
    case .set(let index, let value):
        return .set(Int(index), value)
    case .remove(let index):
        return .remove(Int(index))
    case .truncate(let length):
        return .truncate(Int(length))
    case .reset(let values):
        return .reset(values)
    }
}
