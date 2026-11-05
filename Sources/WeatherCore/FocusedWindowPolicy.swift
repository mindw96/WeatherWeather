import Foundation

/// Uses the active application's frontmost eligible window as the working
/// window. The host supplies visible normal windows in front-to-back order;
/// this geometry-only approximation does not read accessibility focus state.
public enum FocusedWindowPolicy {
    public static func focusedWindowID(in windows: [WindowGeometry],
                                       frontmostProcessID: Int32?) -> UInt32? {
        guard let frontmostProcessID, frontmostProcessID > 0 else { return nil }
        return windows.first {
            $0.valid && $0.ownerProcessID == frontmostProcessID
        }?.id
    }

    /// Resolves the working window in the current display's local coordinates.
    /// A missing target leaves that display unchanged, rather than hiding a
    /// different window or every window belonging to the active application.
    public static func hiddenWindow(in windows: [WindowGeometry],
                                    focusedWindowID: UInt32?,
                                    showEffectsOnFocusedWindow: Bool) -> WindowGeometry? {
        guard !showEffectsOnFocusedWindow, let focusedWindowID else { return nil }
        return windows.first { $0.id == focusedWindowID && $0.valid }
    }
}
