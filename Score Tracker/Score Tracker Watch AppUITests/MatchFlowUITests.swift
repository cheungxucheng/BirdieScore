import XCTest

@MainActor
final class MatchFlowUITests: XCTestCase {
    private let app = XCUIApplication()
    private let suite = "scoreTracker.uiTests.\(UUID().uuidString)"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        // Remove only this test's isolated data, then close its app instance.
        app.terminate()
        app.launchEnvironment = [
            "SCORE_TRACKER_UI_TEST_SUITE": suite,
            "SCORE_TRACKER_UI_TEST_RESET": "1"
        ]
        app.launch()
        app.terminate()
    }

    func testFormatIsRememberedOnlyAfterStartingMatch() {
        launchFresh()
        expectValue("Selected", on: app.buttons["format.3"])
        tap("format.5")
        relaunch()
        expectValue("Selected", on: app.buttons["format.3"])

        tap("format.1")
        tap("home.newMatch")
        expectScore("teamA", 0)
        tap("score.teamA")
        relaunch()

        expectValue("Selected", on: app.buttons["format.1"])
        tap("home.resume")
        expectScore("teamA", 1)
    }

    func testScoringAndRepeatedUndoReturnToZero() {
        launchFresh()
        tap("home.newMatch")
        expectScore("teamA", 0)
        XCTAssertFalse(app.buttons["score.undo"].isEnabled)

        tap("score.teamA")
        tap("score.teamB")
        expectScore("teamA", 1)
        expectScore("teamB", 1)

        tap("score.undo")
        expectScore("teamA", 1)
        expectScore("teamB", 0)
        tap("score.undo")
        expectScore("teamA", 0)
        XCTAssertFalse(app.buttons["score.undo"].isEnabled)
    }

    func testCancelNewMatchStaysHomeAndPreservesResumedScore() {
        launchFresh()
        tap("home.newMatch")
        tap("score.teamA")
        tap("score.teamB")
        relaunch()

        tap("home.newMatch")
        tap("newMatch.cancel")
        XCTAssertTrue(app.buttons["home.resume"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["score.teamA"].exists)

        // Reload to prove cancellation did not alter the persisted match either.
        relaunch()
        tap("home.resume")
        expectScore("teamA", 1)
        expectScore("teamB", 1)
    }

    func testConfirmedNewMatchReplacesProgressAndRemembersFormat() {
        launchFresh()
        tap("home.newMatch")
        tap("score.teamA")
        relaunch()
        tap("format.5")
        tap("home.newMatch")
        tap("newMatch.confirm")

        expectScore("teamA", 0)
        expectScore("teamB", 0)
        XCTAssertFalse(app.buttons["score.undo"].isEnabled)
        relaunch()
        expectValue("Selected", on: app.buttons["format.5"])
        XCTAssertFalse(app.buttons["home.resume"].exists)
    }

    func testDiscardCancellationPreservesScoreAndConfirmationClearsIt() {
        launchFresh()
        tap("home.newMatch")
        tap("score.teamA")
        tap("match.discard")
        tap("discard.cancel")
        expectScore("teamA", 1)

        tap("match.discard")
        tap("discard.confirm")
        XCTAssertTrue(app.buttons["home.newMatch"].waitForExistence(timeout: 5))
        relaunch()
        XCTAssertFalse(app.buttons["home.resume"].exists)
        tap("home.history")
        XCTAssertTrue(app.staticTexts["history.empty"].waitForExistence(timeout: 5))
    }

    func testCompletionUndoRestoresTheFinalPoint() {
        reachCompletion()
        tap("completion.undo")
        expectScore("teamA", 20)
        expectScore("teamB", 0)
        XCTAssertFalse(app.staticTexts["completion.winner"].exists)

        tap("score.teamA")
        XCTAssertTrue(app.staticTexts["completion.winner"].waitForExistence(timeout: 5))
    }

    func testSaveAndFinishPersistsHistoryWithoutAnActiveMatch() {
        reachCompletion()
        tap("completion.saveAndFinish")
        XCTAssertTrue(app.buttons["home.newMatch"].waitForExistence(timeout: 5))
        relaunch()
        XCTAssertFalse(app.buttons["home.resume"].exists)
        tap("home.history")

        XCTAssertTrue(app.staticTexts["Your Team won"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["21-0"].exists)
        XCTAssertEqual(app.buttons.matching(identifier: "history.delete").count, 1)
    }

    func testSaveAndStartNewResetsScoreAndSavesExactlyOneMatch() {
        reachCompletion()
        tap("completion.saveAndNew")
        expectScore("teamA", 0)
        expectScore("teamB", 0)
        XCTAssertFalse(app.buttons["score.undo"].isEnabled)
        tap("score.teamB")
        relaunch()
        tap("home.resume")
        expectScore("teamB", 1)

        relaunch()
        tap("home.history")
        XCTAssertTrue(app.staticTexts["Your Team won"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "history.delete").count, 1)
    }

    func testDeleteHistoryRecordPersistsAcrossRelaunch() {
        launchFresh(fixture: "history")
        tap("home.history")
        let deletes = app.buttons.matching(identifier: "history.delete")
        XCTAssertTrue(deletes.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(deletes.count, 2)
        deletes.firstMatch.tap()
        relaunch()
        tap("home.history")
        XCTAssertTrue(deletes.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(deletes.count, 1)
        XCTAssertTrue(app.staticTexts["Your Team won"].exists)
    }

    func testClearHistoryCancellationAndConfirmation() {
        launchFresh(fixture: "history")
        tap("home.history")
        tap("history.clear")
        tap("history.cancelClear")
        XCTAssertEqual(app.buttons.matching(identifier: "history.delete").count, 2)

        tap("history.clear")
        tap("history.confirmClear")
        XCTAssertTrue(app.staticTexts["history.empty"].waitForExistence(timeout: 5))
        relaunch()
        tap("home.history")
        XCTAssertTrue(app.staticTexts["history.empty"].waitForExistence(timeout: 5))
    }

    private func launchFresh(fixture: String? = nil) {
        app.launchEnvironment = [
            "SCORE_TRACKER_UI_TEST_SUITE": suite,
            "SCORE_TRACKER_UI_TEST_RESET": "1"
        ]
        app.launchEnvironment["SCORE_TRACKER_UI_TEST_FIXTURE"] = fixture
        app.launch()
        XCTAssertTrue(app.buttons["home.newMatch"].waitForExistence(timeout: 10))
    }

    private func relaunch() {
        app.terminate()
        // Keep the same isolated store, without resetting or reseeding it.
        app.launchEnvironment = ["SCORE_TRACKER_UI_TEST_SUITE": suite]
        app.launch()
        XCTAssertTrue(app.buttons["home.newMatch"].waitForExistence(timeout: 10))
    }

    private func reachCompletion() {
        launchFresh(fixture: "matchPoint")
        tap("home.resume")
        expectScore("teamA", 20)
        tap("score.teamA")
        let winner = app.staticTexts["completion.winner"]
        XCTAssertTrue(winner.waitForExistence(timeout: 5))
        XCTAssertEqual(winner.label, "Your Team Wins")
    }

    private func tap(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        // watchOS renders confirmation actions as native controls without our IDs.
        let dialogLabels = [
            "newMatch.cancel": "Close",
            "newMatch.confirm": "Discard and Start New",
            "discard.cancel": "Close",
            "discard.confirm": "Discard Match",
            "history.cancelClear": "Close",
            "history.confirmClear": "Clear History"
        ]
        let button = app.buttons[dialogLabels[identifier] ?? identifier].firstMatch
        _ = button.waitForExistence(timeout: 5)
        if identifier == "match.discard" || identifier == "history.clear" {
            // Toolbar buttons do not move into view by scrolling the content.
            let attachment = XCTAttachment(string: app.debugDescription)
            attachment.name = "Toolbar before tapping \(identifier)"
            attachment.lifetime = .deleteOnSuccess
            add(attachment)
            button.tap()
            return
        }
        // Watch lists and the completion sheet can require scrolling on smaller screens.
        for _ in 0..<4 {
            if button.exists && button.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(button.waitForExistence(timeout: 5), identifier, file: file, line: line)
        XCTAssertTrue(button.isHittable, identifier, file: file, line: line)
        button.tap()
    }

    private func expectScore(_ team: String, _ score: Int, file: StaticString = #filePath, line: UInt = #line) {
        expectValue("\(score) points", on: app.buttons["score.\(team)"], file: file, line: line)
    }

    private func expectValue(_ value: String, on element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND value == %@", value),
            object: element
        )
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed, file: file, line: line)
    }
}
