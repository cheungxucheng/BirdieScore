import Foundation

enum AppLaunchStorage {
    static func makeDefaults() -> UserDefaults {
        #if DEBUG
        // UI tests use a separate domain; release builds always use normal app storage.
        let environment = ProcessInfo.processInfo.environment
        if let suite = environment["SCORE_TRACKER_UI_TEST_SUITE"],
           suite.hasPrefix("scoreTracker.uiTests."),
           let defaults = UserDefaults(suiteName: suite) {
            if environment["SCORE_TRACKER_UI_TEST_RESET"] == "1" {
                defaults.removePersistentDomain(forName: suite)
                seedFixture(environment["SCORE_TRACKER_UI_TEST_FIXTURE"], defaults: defaults)
            }
            return defaults
        }
        #endif
        return .standard
    }

    #if DEBUG
    private static func seedFixture(_ fixture: String?, defaults: UserDefaults) {
        guard fixture == "matchPoint" || fixture == "history" else { return }
        var game = GameState(
            activeStorage: ActiveMatchPersistence(defaults: defaults),
            persistence: UserDefaultsMatchHistoryPersistence(defaults: defaults)
        )
        defaults.set(NumGames.bo1.rawValue, forKey: "scoreTracker.lastMatchFormat")

        if fixture == "matchPoint" {
            game.startNewMatch(format: .bo1)
            for _ in 0..<20 { game.pointWon(by: .teamA) }
        } else {
            for index in 0..<2 {
                game.startNewMatch(format: .bo1)
                let winner: Team = index == 0 ? .teamA : .teamB
                for _ in 0..<21 { game.pointWon(by: winner) }
                game.confirmCompletedMatch(at: Date(timeIntervalSince1970: Double(index + 1)))
            }
        }
    }
    #endif
}
