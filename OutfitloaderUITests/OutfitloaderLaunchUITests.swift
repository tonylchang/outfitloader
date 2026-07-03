import XCTest

final class OutfitloaderLaunchUITests: XCTestCase {
    func testAppLaunchesToOnboardingOrMainShell() {
        let app = XCUIApplication()

        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))

        let onboardingAction = app.buttons["Take a Full-Body Selfie"]
        let tryOnTab = app.tabBars.buttons["Try On"]
        XCTAssertTrue(
            onboardingAction.waitForExistence(timeout: 3) || tryOnTab.waitForExistence(timeout: 3),
            "Expected the app to show first-run onboarding or the main tab shell."
        )
    }
}
