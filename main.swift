import Cocoa

let delegate = AppDelegate()
let application = NSApplication.shared
application.delegate = delegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
