import AppKit

private let portName = "myim-selection-service"
let application = NSApplication.shared
application.setActivationPolicy(.accessory)
private let provider = SelectionServiceProvider()
NSRegisterServicesProvider(provider, portName)

withExtendedLifetime(provider) {
    application.run()
}
