import Foundation
import Testing
@testable import MyIMECore

@Suite
struct ExternalBrowserCommandDeliveryTests {
    private let page = URL(string: "https://ja.wikipedia.org/wiki/候補")

    @Test
    func notifiesARunningHelperWithoutReopeningIt() {
        #expect(ExternalBrowserCommandDelivery.resolve(
            url: page,
            isHelperRunning: true,
            isLaunching: false
        ) == .notifyRunningHelper)
    }

    @Test
    func launchesTheHelperOnlyWhenItIsNotRunning() {
        #expect(ExternalBrowserCommandDelivery.resolve(
            url: page,
            isHelperRunning: false,
            isLaunching: false
        ) == .launchHelper)
    }

    @Test
    func keepsCommandsWhileTheHelperIsLaunching() {
        #expect(ExternalBrowserCommandDelivery.resolve(
            url: page,
            isHelperRunning: true,
            isLaunching: true
        ) == .waitForLaunch)
        #expect(ExternalBrowserCommandDelivery.resolve(
            url: page,
            isHelperRunning: false,
            isLaunching: true
        ) == .waitForLaunch)
    }

    @Test
    func hidesWithoutLaunchingTheHelper() {
        #expect(ExternalBrowserCommandDelivery.resolve(
            url: nil,
            isHelperRunning: false,
            isLaunching: false
        ) == .notifyRunningHelper)
    }

    @Test
    func discardsNonHTTPSPages() {
        #expect(ExternalBrowserCommandDelivery.resolve(
            url: URL(string: "http://example.com"),
            isHelperRunning: true,
            isLaunching: false
        ) == .discard)
    }
}
