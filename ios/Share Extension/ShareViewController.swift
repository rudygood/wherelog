//
//  ShareViewController.swift
//  Share Extension
//

import Foundation
import receive_sharing_intent

class ShareViewController: RSIShareViewController {

    // Return false to show the built-in compose UI (Cancel / Send buttons,
    // an editable message field and a media preview) instead of redirecting
    // automatically. Return true to skip the UI and jump straight to the app.
    override func shouldAutoRedirect() -> Bool {
        return false
    }

    // Optionally customise the built-in compose UI:
    override var placeholder: String { "Add a caption…" }
    override var sendButtonTitle: String { "Send to WhereLog" }

    // GPX file hand-off (2026-11-11): the plugin's extension code
    // copies shared files without claiming security-scoped access,
    // so a .gpx shared from Files arrives in Dart as an empty list.
    // This override copies a shared .gpx into the App Group
    // container itself (holding scoped access for the copy) and
    // records it in group UserDefaults; the app takes it from there
    // when the plugin's empty list arrives. Map shares are
    // untouched — only .gpx files take this path. The plugin's own
    // Send flow still runs afterwards (finishPost).
    override func didSelectPost() {
        guard let provider = firstFileAttachmentProvider() else {
            super.didSelectPost()
            return
        }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { [weak self] item, _ in
            if let url = item as? URL, url.pathExtension.lowercased() == "gpx" {
                self?.stashSharedGpx(url: url)
            }
            DispatchQueue.main.async { [weak self] in
                self?.finishPost()
            }
        }
    }

    /// The plugin's Send flow, run after the file hand-off above.
    /// Kept as its own method because a super call cannot sit
    /// inside the loadItem completion closure.
    private func finishPost() {
        super.didSelectPost()
    }

    /// The first file attachment in the share, if any.
    private func firstFileAttachmentProvider() -> NSItemProvider? {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return nil }
        for item in items {
            guard let attachments = item.attachments else { continue }
            for provider in attachments where provider.hasItemConformingToTypeIdentifier("public.file-url") {
                return provider
            }
        }
        return nil
    }

    /// Copies a shared .gpx into the App Group container and
    /// records its name in group UserDefaults, so the app can take
    /// it when the plugin's (empty) share list arrives.
    private func stashSharedGpx(url: URL) {
        guard let groupId = Bundle.main.object(forInfoDictionaryKey: "AppGroupId") as? String,
              let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupId)
        else { return }
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }
        let destination = container.appendingPathComponent("incoming-share.gpx")
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: url, to: destination)
            UserDefaults(suiteName: groupId)?.set("incoming-share.gpx", forKey: "WhereLogSharedGpxFile")
        } catch {
            // The copy failed; the plugin path (empty list) and the
            // in-app GPX import remain. Nothing to report from here.
        }
    }
}
