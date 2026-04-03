// AsyncStreamBridge.swift
// RelayKit
//
// SPDX-License-Identifier: Apache-2.0


/// Creates `AsyncStream` instances from Matrix SDK subscription methods.
///
/// This utility encapsulates the pattern of creating an ``SDKListener``,
/// wiring it to an `AsyncStream.Continuation`, and retaining the
/// ``TaskHandle`` for the stream's lifetime. When the stream is
/// cancelled or the consuming task is terminated, the `TaskHandle`
/// is automatically cancelled.
///
/// ## Usage
///
/// ```swift
/// let stateStream: AsyncStream<SyncServiceState> = AsyncStreamBridge.stream { listener in
///     syncService.state(listener: listener)
/// }
///
/// for await state in stateStream {
///     print("State: \(state)")
/// }
/// ```
///
/// ## Topics
///
/// ### Creating Streams
/// - ``stream(_:)``
/// - ``stream(bufferingPolicy:_:)``
public enum AsyncStreamBridge {
    /// Creates an `AsyncStream` from a Matrix SDK subscription method.
    ///
    /// - Parameter subscribe: A closure that receives an ``SDKListener``
    ///   and returns a ``TaskHandle``. The `TaskHandle` is retained for
    ///   the lifetime of the stream and cancelled on termination.
    /// - Returns: An `AsyncStream` that yields values from the SDK listener.
    public static func stream<T: Sendable>(
        _ subscribe: @escaping @Sendable (SDKListener<T>) -> TaskHandle
    ) -> AsyncStream<T> {
        stream(bufferingPolicy: .bufferingNewest(1), subscribe)
    }

    /// Creates an `AsyncStream` from a Matrix SDK subscription method
    /// with a custom buffering policy.
    ///
    /// - Parameters:
    ///   - bufferingPolicy: The buffering policy for the async stream.
    ///     Defaults to `.bufferingNewest(1)`.
    ///   - subscribe: A closure that receives an ``SDKListener``
    ///     and returns a ``TaskHandle``.
    /// - Returns: An `AsyncStream` that yields values from the SDK listener.
    public static func stream<T: Sendable>(
        bufferingPolicy: AsyncStream<T>.Continuation.BufferingPolicy,
        _ subscribe: @escaping @Sendable (SDKListener<T>) -> TaskHandle
    ) -> AsyncStream<T> {
        // Use nonisolated(unsafe) to allow the TaskHandle to be stored
        // across the Sendable boundary. The handle is only written once
        // and read once (on termination), so this is safe.
        nonisolated(unsafe) var taskHandle: TaskHandle?

        return AsyncStream(bufferingPolicy: bufferingPolicy) { continuation in
            let listener = SDKListener<T> { value in
                continuation.yield(value)
            }
            taskHandle = subscribe(listener)

            continuation.onTermination = { @Sendable _ in
                taskHandle?.cancel()
                taskHandle = nil
            }
        }
    }
}
