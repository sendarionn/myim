import Testing
@testable import MyIMECore

@Suite
struct InputClientRoleTests {
    @Test
    func externalBrowserDoesNotParticipateInSourceInputLifecycle() {
        let role = InputClientRole.resolve(
            bundleIdentifier: "io.github.sendarionn.myim.external-browser"
        )

        #expect(role == .auxiliaryApplication)
        #expect(!role.participatesInInputSessionLifecycle)
    }

    @Test
    func inputMethodApplicationIsAlsoAuxiliary() {
        #expect(
            InputClientRole.resolve(
                bundleIdentifier: "io.github.sendarionn.inputmethod.myime"
            ) == .auxiliaryApplication
        )
    }

    @Test
    func ordinaryApplicationParticipatesInInputLifecycle() {
        let role = InputClientRole.resolve(
            bundleIdentifier: "com.microsoft.VSCode"
        )

        #expect(role == .sourceApplication)
        #expect(role.participatesInInputSessionLifecycle)
    }
}
