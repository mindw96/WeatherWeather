import Foundation

enum AppIdentity {
    static let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        ?? "Window Weather"
}
