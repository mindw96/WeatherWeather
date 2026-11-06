import AppKit
import WeatherCore

/// Reads geometry and owner PID only. Never requests a title, image, or AX access.
enum WindowTracker {
    // shortcut: public window metadata has no corner radius; use an OS-style
    // estimate until a permission-free per-window contour API is available.
    static var estimatedCornerRadius: Double {
        if #available(macOS 26, *) { return 16 }
        return 10
    }

    static func fullScreenPolicy(screen: NSScreen) -> FullScreenPolicy {
        let frame = screen.frame
        let visible = screen.visibleFrame
        let insets = screen.safeAreaInsets
        return FullScreenPolicy(
            width: frame.width, height: frame.height,
            visibleArea: DisplayArea(x: visible.minX - frame.minX,
                                     y: frame.maxY - visible.maxY,
                                     width: visible.width, height: visible.height),
            safeArea: DisplayArea(x: insets.left, y: insets.top,
                                  width: frame.width - insets.left - insets.right,
                                  height: frame.height - insets.top - insets.bottom)
        )
    }

    static func windows(excluding windowIDs: Set<UInt32> = []) -> [WindowGeometry] {
        guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return [] }
        return info.compactMap { row in
            guard let id = row[kCGWindowNumber as String] as? UInt32,
                  !windowIDs.contains(id),
                  let layer = row[kCGWindowLayer as String] as? Int, layer == 0,
                  let alpha = row[kCGWindowAlpha as String] as? Double, alpha > 0.01,
                  let raw = row[kCGWindowBounds as String] as? [String: Any],
                  let rect = CGRect(dictionaryRepresentation: raw as CFDictionary),
                  rect.width >= 80, rect.height >= 50,
                  rect.origin.x.isFinite, rect.origin.y.isFinite else { return nil }
            return WindowGeometry(id: id, x: rect.minX, y: rect.minY, width: rect.width, height: rect.height,
                                  ownerProcessID: (row[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                                  cornerRadius: estimatedCornerRadius)
        }
    }

    /// Permission-free approximation: the frontmost normal window belonging to
    /// the application receiving key events. Does not hide all of that app's windows.
    static func focusedWindowID(in windows: [WindowGeometry]) -> UInt32? {
        FocusedWindowPolicy.focusedWindowID(
            in: windows, frontmostProcessID: NSWorkspace.shared.frontmostApplication?.processIdentifier
        )
    }

    /// Quartz global top-left -> display-local top-left, including displays above/left of primary.
    static func localWindows(_ windows: [WindowGeometry], screen: NSScreen) -> [WindowGeometry] {
        let primaryTop = NSScreen.screens.first?.frame.maxY ?? screen.frame.maxY
        let originX = screen.frame.minX
        let originY = primaryTop - screen.frame.maxY
        return windows.compactMap { window in
            let x = window.x - originX, y = window.y - originY
            guard x < screen.frame.width, x + window.width > 0,
                  y < screen.frame.height, y + window.height > 0 else { return nil }
            return WindowGeometry(id: window.id, x: x, y: y, width: window.width, height: window.height,
                                  ownerProcessID: window.ownerProcessID, cornerRadius: window.cornerRadius)
        }
    }
}
