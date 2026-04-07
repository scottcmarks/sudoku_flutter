import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Match Flutter's warm parchment bg so the window doesn't flash black on launch.
    self.backgroundColor = NSColor(red: 0.961, green: 0.941, blue: 0.910, alpha: 1.0)

    super.awakeFromNib()
  }
}
