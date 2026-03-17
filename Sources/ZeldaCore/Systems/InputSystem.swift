import Foundation

public actor InputSystem {
    private var currentInput: InputState = .idle

    public init() {}

    public func setInput(_ input: InputState) {
        currentInput = input
    }

    public func consumeInput() -> InputState {
        defer { currentInput = .idle }
        return currentInput
    }
}
