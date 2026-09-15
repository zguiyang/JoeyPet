import Foundation

enum DebugStateInjector {
    static func injectedPetState() -> PetState? {
        #if DEBUG
        let prefix = "-JoeyPetDebugState"
        guard let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(prefix) }) else {
            return nil
        }

        let value: String
        if argument == prefix, let next = nextArgument(after: prefix) {
            value = next
        } else if argument.hasPrefix("\(prefix)=") {
            value = String(argument.dropFirst(prefix.count + 1))
        } else {
            value = String(argument.dropFirst(prefix.count))
        }

        return PetState(rawValue: value.trimmingCharacters(in: .whitespacesAndNewlines))
        #else
        return nil
        #endif
    }

    #if DEBUG
    private static func nextArgument(after prefix: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: prefix), index + 1 < args.count else {
            return nil
        }
        return args[index + 1]
    }
    #endif
}
