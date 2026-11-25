import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit

extension NSColor {
    static var systemGroupedBackground: NSColor { .windowBackgroundColor }
    static var secondarySystemGroupedBackground: NSColor { .controlBackgroundColor }
    static var systemBackground: NSColor { .textBackgroundColor }
}
#endif

extension Notification.Name {
    static var plantaoWillEnterForeground: Notification.Name {
        #if os(iOS)
        UIApplication.willEnterForegroundNotification
        #else
        NSApplication.didBecomeActiveNotification
        #endif
    }
}

extension View {
    @ViewBuilder func decimalEntryKeyboard() -> some View {
        #if os(iOS)
        keyboardType(.decimalPad)
        #else
        self
        #endif
    }
    @ViewBuilder func sentenceEntryCapitalization() -> some View {
        #if os(iOS)
        textInputAutocapitalization(.sentences)
        #else
        self
        #endif
    }
    @ViewBuilder func wordEntryCapitalization() -> some View {
        #if os(iOS)
        textInputAutocapitalization(.words)
        #else
        self
        #endif
    }
    @ViewBuilder func inlineNavigationTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
    @ViewBuilder func editorWindowSize() -> some View {
        #if os(macOS)
        frame(minWidth: 560, idealWidth: 620, minHeight: 620, idealHeight: 740)
        #else
        self
        #endif
    }
}
