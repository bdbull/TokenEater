import SwiftUI

// MARK: - macOS 13 backward-compatible onChange modifiers
//
// The 2-parameter onChange(of:) { old, new in } API was introduced in macOS 14.
// These modifiers provide a consistent API surface that works on macOS 13+.

private struct OnChangeModifier<V: Equatable>: ViewModifier {
    let value: V
    let action: (V) -> Void

    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content.onChange(of: value) { _, new in action(new) }
        } else {
            content.onChange(of: value, perform: action)
        }
    }
}

private struct OnChangeTwoParamModifier<V: Equatable>: ViewModifier {
    let value: V
    let action: (V, V) -> Void
    @State private var previous: V

    init(value: V, action: @escaping (V, V) -> Void) {
        self.value = value
        self.action = action
        self._previous = State(initialValue: value)
    }

    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content.onChange(of: value) { old, new in action(old, new) }
        } else {
            content.onChange(of: value) { new in
                action(previous, new)
                previous = new
            }
        }
    }
}

extension View {
    /// onChange compatible with macOS 13+. Receives the new value only.
    func onChangeCompat<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> some View {
        modifier(OnChangeModifier(value: value, action: action))
    }

    /// onChange compatible with macOS 13+. Receives both old and new values.
    /// On macOS 13, old value is tracked via @State (accurate from the second change onward).
    func onChangeCompat<V: Equatable>(of value: V, perform action: @escaping (V, V) -> Void) -> some View {
        modifier(OnChangeTwoParamModifier(value: value, action: action))
    }
}
