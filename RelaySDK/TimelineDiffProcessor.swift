import MatrixRustSDK

/// Maintains an ordered list of raw SDK timeline items by applying incremental diffs
/// from the Matrix Rust SDK.
///
/// ``TimelineDiffProcessor`` owns the mutable ``timelineItems`` array and encapsulates
/// the switch-based diff application logic. This keeps the view model free from low-level
/// array mutation bookkeeping, and makes diff handling independently testable.
final class TimelineDiffProcessor {
    /// The current ordered list of timeline items after all applied diffs.
    private(set) var timelineItems: [TimelineItem] = []

    /// Applies a batch of timeline diffs to the internal item list.
    ///
    /// Each diff is applied sequentially in the order received. Out-of-bounds
    /// indices are silently ignored to avoid crashes from stale SDK state.
    ///
    /// - Parameter diffs: The timeline diffs to apply.
    func applyDiffs(_ diffs: [TimelineDiff]) {
        for diff in diffs {
            switch diff {
            case .reset(let values):
                timelineItems = values
            case .append(let values):
                timelineItems.append(contentsOf: values)
            case .pushBack(let value):
                timelineItems.append(value)
            case .pushFront(let value):
                timelineItems.insert(value, at: 0)
            case .insert(let index, let value):
                let i = Int(index)
                if i <= timelineItems.count {
                    timelineItems.insert(value, at: i)
                }
            case .set(let index, let value):
                let i = Int(index)
                if i < timelineItems.count {
                    timelineItems[i] = value
                }
            case .remove(let index):
                let i = Int(index)
                if i < timelineItems.count {
                    timelineItems.remove(at: i)
                }
            case .clear:
                timelineItems.removeAll()
            case .popBack:
                if !timelineItems.isEmpty { timelineItems.removeLast() }
            case .popFront:
                if !timelineItems.isEmpty { timelineItems.removeFirst() }
            case .truncate(let length):
                timelineItems = Array(timelineItems.prefix(Int(length)))
            }
        }
    }
}
