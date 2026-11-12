import Flutter
import UIKit
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var iosBridge: WhereLogIosBridge?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    iosBridge = WhereLogIosBridge(messenger: engineBridge.applicationRegistrar.messenger())
  }
}

/// WhereLog's own iOS platform channels, registered with the
/// implicit Flutter engine. Kept as one retained object so the
/// folder picker's delegate and any access it is holding survive
/// for the whole call.
final class WhereLogIosBridge: NSObject, UIDocumentPickerDelegate {
  private let directoryChannel: FlutterMethodChannel
  private let clipboardChannel: FlutterMethodChannel
  private let incomingGpxChannel: FlutterMethodChannel
  private let shareDiagChannel: FlutterMethodChannel
  private var directoryResult: FlutterResult?
  private var heldDirectoryURL: URL?

  init(messenger: FlutterBinaryMessenger) {
    directoryChannel = FlutterMethodChannel(
      name: "com.wherelog/directory_access",
      binaryMessenger: messenger
    )
    clipboardChannel = FlutterMethodChannel(
      name: "com.wherelog/clipboard_image",
      binaryMessenger: messenger
    )
    incomingGpxChannel = FlutterMethodChannel(
      name: "com.wherelog/incoming_gpx",
      binaryMessenger: messenger
    )
    shareDiagChannel = FlutterMethodChannel(
      name: "com.wherelog/share_diag",
      binaryMessenger: messenger
    )
    super.init()
    incomingGpxChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "takePendingGpx":
        result(IncomingGpxMailbox.shared.takeContent())
      case "takePendingSharedGpx":
        result(SharedGpxInbox.shared.takeContent())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    shareDiagChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "containerReport":
        result(shareContainerReport())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    let gpxChannel = incomingGpxChannel
    IncomingGpxMailbox.shared.onAvailable = { content in
      gpxChannel.invokeMethod("gpxAvailable", arguments: content)
    }
    clipboardChannel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(
          FlutterError(
            code: "unavailable",
            message: "The iOS bridge is no longer available.",
            details: nil
          )
        )
        return
      }
      switch call.method {
      case "hasImage":
        result(self.clipboardHasImage())
      case "getImage":
        if let data = self.clipboardImageData() {
          result(FlutterStandardTypedData(bytes: data))
        } else {
          result(nil)
        }
      case "describeClip":
        result(self.describeClipboard())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    directoryChannel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(
          FlutterError(
            code: "unavailable",
            message: "The iOS bridge is no longer available.",
            details: nil
          )
        )
        return
      }
      switch call.method {
      case "pickDirectory":
        self.pickDirectory(result: result)
      case "releaseDirectory":
        self.releaseDirectory()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // MARK: - Folder picking with held security-scoped access

  /// Presents the system folder picker. The URL it produces is
  /// security-scoped: the access belongs to that URL, not to its
  /// path, so the bridge starts access on the chosen folder and
  /// HOLDS it. Dart writes the export through the returned path
  /// while the hold is in place, then calls releaseDirectory.
  private func pickDirectory(result: @escaping FlutterResult) {
    if directoryResult != nil {
      result(
        FlutterError(
          code: "already_active",
          message: "A folder picker is already open.",
          details: nil
        )
      )
      return
    }
    guard let presenter = topViewController() else {
      result(
        FlutterError(
          code: "no_presenter",
          message: "There is no screen available to show the folder picker.",
          details: nil
        )
      )
      return
    }
    directoryResult = result
    let picker: UIDocumentPickerViewController
    if #available(iOS 14.0, *) {
      picker = UIDocumentPickerViewController(
        forOpeningContentTypes: [.folder],
        asCopy: false
      )
    } else {
      picker = UIDocumentPickerViewController(
        documentTypes: ["public.folder"],
        in: .open
      )
    }
    picker.delegate = self
    picker.allowsMultipleSelection = false
    presenter.present(picker, animated: true)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    finishDirectoryPick(nil)
  }

  func documentPicker(
    _ controller: UIDocumentPickerViewController,
    didPickDocumentsAt urls: [URL]
  ) {
    guard let url = urls.first else {
      finishDirectoryPick(nil)
      return
    }
    releaseDirectory()
    guard url.startAccessingSecurityScopedResource() else {
      finishDirectoryPick(
        FlutterError(
          code: "access_denied",
          message: "iOS did not grant access to the chosen folder.",
          details: nil
        )
      )
      return
    }
    heldDirectoryURL = url
    finishDirectoryPick(url.path)
  }

  private func finishDirectoryPick(_ value: Any?) {
    let result = directoryResult
    directoryResult = nil
    result?(value)
  }

  private func releaseDirectory() {
    heldDirectoryURL?.stopAccessingSecurityScopedResource()
    heldDirectoryURL = nil
  }

  private func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
    let window = scenes
      .flatMap { $0.windows }
      .first { $0.isKeyWindow } ?? scenes.flatMap { $0.windows }.first
    var top = window?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }

  // MARK: - Clipboard image (mirror of the Android channel)

  /// The button's promise is "paste will succeed", so judge by
  /// the pasteboard's declared image content first, then by the
  /// type list, without reading any image bytes here.
  private func clipboardHasImage() -> Bool {
    let pasteboard = UIPasteboard.general
    if pasteboard.hasImages { return true }
    let imageTypes: Set<String> = [
      "public.image", "public.png", "public.jpeg", "public.heic",
      "public.heif", "com.compuserve.gif", "org.webmproject.webp",
      "public.bmp", "com.microsoft.bmp",
    ]
    for item in pasteboard.items {
      for type in item.keys where imageTypes.contains(type) {
        return true
      }
    }
    return false
  }

  private func isImageHeader(_ data: Data) -> Bool {
    let b = [UInt8](data.prefix(12))
    func u(_ i: Int) -> UInt8 { i < b.count ? b[i] : 0 }
    if b.count >= 3 && u(0) == 0xFF && u(1) == 0xD8 && u(2) == 0xFF { return true } // JPEG
    if b.count >= 4 && u(0) == 0x89 && u(1) == 0x50 && u(2) == 0x4E && u(3) == 0x47 { return true } // PNG
    if b.count >= 4 && u(0) == 0x47 && u(1) == 0x49 && u(2) == 0x46 && u(3) == 0x38 { return true } // GIF8
    if b.count >= 2 && u(0) == 0x42 && u(1) == 0x4D { return true } // BMP "BM"
    if b.count >= 12 && u(0) == 0x52 && u(1) == 0x49 && u(2) == 0x46 && u(3) == 0x46 &&
      u(8) == 0x57 && u(9) == 0x45 && u(10) == 0x42 && u(11) == 0x50 { return true } // RIFF....WEBP
    return false
  }

  /// The image bytes to paste, or nil. Original bytes with a
  /// recognised image header win; otherwise the pasteboard's
  /// decoded image is re-encoded as PNG (JPEG as fallback), so
  /// what Dart receives always begins as an image it accepts —
  /// the same ground-truth rule the Android side follows.
  private func clipboardImageData() -> Data? {
    let pasteboard = UIPasteboard.general
    for item in pasteboard.items {
      for (_, value) in item {
        if let data = value as? Data, isImageHeader(data) {
          return data
        }
      }
    }
    if let image = pasteboard.image {
      return image.pngData() ?? image.jpegData(compressionQuality: 0.92)
    }
    for item in pasteboard.items {
      for (_, value) in item {
        if let image = value as? UIImage {
          return image.pngData() ?? image.jpegData(compressionQuality: 0.92)
        }
      }
    }
    return nil
  }

  /// Diagnostic (long-press the Clipboard button): what the
  /// pasteboard claims to hold, item by item, plus the two
  /// verdicts the button and the paste stand on.
  private func describeClipboard() -> String {
    let pasteboard = UIPasteboard.general
    if pasteboard.numberOfItems == 0 {
      return "Clipboard is empty (no items)."
    }
    var lines: [String] = ["items: \(pasteboard.numberOfItems)"]
    for (index, item) in pasteboard.items.enumerated() {
      var parts: [String] = []
      for (type, value) in item {
        if let data = value as? Data {
          let verdict = isImageHeader(data) ? ", image: YES" : ", image: no"
          parts.append("\(type) [\(data.count) bytes\(verdict)]")
        } else if let text = value as? String {
          let shown = text.count > 60 ? String(text.prefix(60)) + "..." : text
          parts.append("\(type) text(\"\(shown)\")")
        } else if let url = value as? URL {
          parts.append("\(type) link(\(url.scheme ?? "")://\(url.host ?? ""))")
        } else if let image = value as? UIImage {
          parts.append("\(type) image (\(Int(image.size.width))x\(Int(image.size.height)))")
        } else {
          parts.append(type)
        }
      }
      lines.append("#\(index) " + parts.joined(separator: " "))
    }
    lines.append("hasImage verdict: \(clipboardHasImage())")
    if let data = clipboardImageData() {
      lines.append("getImage result: \(data.count) bytes")
    } else {
      lines.append("getImage result: null")
    }
    return lines.joined(separator: "\n")
  }
}

/// Holds a GPX file handed to WhereLog by iOS ("Open with
/// WhereLog" on a .gpx in Files or Mail) until Dart is ready to
/// queue its waypoints. The scene delegate can receive the file
/// before the Flutter engine — and therefore the method channel
/// — exists, so the content waits in a file of its own: Dart
/// takes it on startup, and if the app is already running the
/// mailbox also calls the channel handler straight away.
final class IncomingGpxMailbox {
  static let shared = IncomingGpxMailbox()
  var onAvailable: ((String) -> Void)?

  private var pendingURL: URL {
    let base = FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
    return base.appendingPathComponent("pending-incoming.gpx")
  }

  func store(url: URL) {
    guard url.isFileURL, url.pathExtension.lowercased() == "gpx" else { return }
    let accessing = url.startAccessingSecurityScopedResource()
    defer {
      if accessing { url.stopAccessingSecurityScopedResource() }
    }
    guard let data = try? Data(contentsOf: url),
          let content = String(data: data, encoding: .utf8) else { return }
    do {
      try FileManager.default.createDirectory(
        at: pendingURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      try data.write(to: pendingURL, options: .atomic)
      onAvailable?(content)
    } catch {
      // A GPX that cannot be held is simply not queued; the
      // in-app GPX import remains available.
    }
  }

  func takeContent() -> String? {
    guard let data = try? Data(contentsOf: pendingURL) else { return nil }
    try? FileManager.default.removeItem(at: pendingURL)
    return String(data: data, encoding: .utf8)
  }
}

/// The Share Extension's native .gpx hand-off (2026-11-11): the
/// plugin cannot copy security-scoped files, so the extension
/// copies a shared .gpx into the App Group container itself and
/// records its name in group UserDefaults. The app takes the
/// content from here when the plugin's (empty) share list
/// arrives. Mirrors IncomingGpxMailbox, but the file lives in the
/// shared container, not in Application Support.
final class SharedGpxInbox {
  static let shared = SharedGpxInbox()
  private let fileKey = "WhereLogSharedGpxFile"

  private func groupId() -> String? {
    Bundle.main.object(forInfoDictionaryKey: "AppGroupId") as? String
  }

  func takeContent() -> String? {
    guard let group = groupId(),
          let name = UserDefaults(suiteName: group)?.string(forKey: fileKey),
          let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: group)?
            .appendingPathComponent(name)
    else { return nil }
    // The hand-off is consumed on take, whatever the content
    // turns out to be — a file that cannot be read must not sit
    // in the inbox and queue again on a later share.
    UserDefaults(suiteName: group)?.removeObject(forKey: fileKey)
    defer { try? FileManager.default.removeItem(at: url) }
    guard let data = try? Data(contentsOf: url) else { return nil }
    return String(data: data, encoding: .utf8)
  }
}


/// Share diagnostic (2026-11-10): reports which app-group
/// containers this app can actually resolve on the device, and
/// what is in them. The answer distinguishes a group that was
/// never provisioned (NIL) from one the Share Extension never
/// wrote to (resolves, but empty after shares were sent).
func shareContainerReport() -> String {
  let fm = FileManager.default
  var candidates: [String] = []
  if let fromPlist = Bundle.main.object(forInfoDictionaryKey: "AppGroupId") as? String,
     !fromPlist.isEmpty {
    candidates.append(fromPlist)
  }
  if !candidates.contains("group.org.solutionwise.wherelog") {
    candidates.append("group.org.solutionwise.wherelog")
  }
  var lines: [String] = []
  if let alt = Bundle.main.object(forInfoDictionaryKey: "ALTAppGroups") {
    lines.append("ALTAppGroups (as recorded by AltStore): \(alt)")
  } else {
    lines.append("ALTAppGroups: (not present in the installed app)")
  }
  for group in candidates {
    guard let url = fm.containerURL(forSecurityApplicationGroupIdentifier: group) else {
      lines.append("GROUP \(group) -> NIL")
      continue
    }
    lines.append("GROUP \(group) -> \(url.path)")
    if let entries = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
      if entries.isEmpty {
        lines.append("  (empty)")
      }
      for entry in entries.prefix(30) {
        lines.append("  - \(entry.lastPathComponent)")
        if let sub = try? fm.contentsOfDirectory(at: entry, includingPropertiesForKeys: nil) {
          for s in sub.prefix(20) {
            lines.append("    - \(s.lastPathComponent)")
          }
        }
      }
    }
  }
  return lines.joined(separator: "\n")
}
