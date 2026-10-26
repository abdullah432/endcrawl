import Cocoa
import FlutterMacOS
import UniformTypeIdentifiers

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = NSRect(x: 0, y: 0, width: 1440, height: 900)
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.minSize = NSSize(width: 800, height: 600)
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)
    let exports = FlutterMethodChannel(
      name: "lastreel/export_destination",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    exports.setMethodCallHandler { [weak self] call, result in
      guard call.method == "saveExport" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let self = self,
            let args = call.arguments as? [String: Any],
            let path = args["path"] as? String,
            FileManager.default.fileExists(atPath: path) else {
        result(FlutterError(code: "missing_export", message: "Render the project before saving.", details: nil))
        return
      }
      let source = URL(fileURLWithPath: path)
      let panel = NSSavePanel()
      panel.title = "Save your LastReel export"
      panel.nameFieldStringValue = source.lastPathComponent
      panel.canCreateDirectories = true
      if let type = UTType(filenameExtension: source.pathExtension) {
        panel.allowedContentTypes = [type]
      }
      panel.beginSheetModal(for: self) { response in
        guard response == .OK, let destination = panel.url else {
          result(false)
          return
        }
        guard source.standardizedFileURL != destination.standardizedFileURL else {
          result(true)
          return
        }
        DispatchQueue.global(qos: .userInitiated).async {
          do {
            // Preserve the previous file if copying the new export fails.
            let replacementDirectory = try FileManager.default.url(
              for: .itemReplacementDirectory, in: .userDomainMask,
              appropriateFor: destination, create: true)
            defer { try? FileManager.default.removeItem(at: replacementDirectory) }
            let staging = replacementDirectory.appendingPathComponent(source.lastPathComponent)
            try FileManager.default.copyItem(at: source, to: staging)
            if FileManager.default.fileExists(atPath: destination.path) {
              _ = try FileManager.default.replaceItemAt(destination, withItemAt: staging)
            } else {
              try FileManager.default.moveItem(at: staging, to: destination)
            }
            DispatchQueue.main.async { result(true) }
          } catch {
            DispatchQueue.main.async {
              result(FlutterError(code: "save_failed", message: error.localizedDescription, details: nil))
            }
          }
        }
      }
    }

    super.awakeFromNib()
  }
}
