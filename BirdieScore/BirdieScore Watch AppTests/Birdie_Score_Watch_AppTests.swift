import Foundation
import XCTest
@testable import BirdieScore_Watch_App

final class MemoryMatchHistoryPersistence: MatchHistoryPersisting {
    var records: [MatchRecord]
    private(set) var saveCount = 0

    init(records: [MatchRecord] = []) {
        self.records = records
    }

    func load() -> [MatchRecord] {
        records
    }

    func save(_ records: [MatchRecord]) {
        self.records = records
        saveCount += 1
    }
}

final class BirdieScoreCoreTests: XCTestCase {
    private var defaultsSuites: [String] = []

    override func tearDown() {
        for suite in defaultsSuites {
            UserDefaults.standard.removePersistentDomain(forName: suite)
        }
        defaultsSuites.removeAll()
        super.tearDown()
    }

    func testOrdinaryPointAndRepeatedUndo() {
        var game = makeGame()

        game.pointWon(by: .teamA)
        game.pointWon(by: .teamB)
        game.pointWon(by: .teamA)

        XCTAssertEqual(game.scoreA, 2)
        XCTAssertEqual(game.scoreB, 1)
        XCTAssertTrue(game.canUndo)

        game.undoLastPoint()
        XCTAssertEqual(game.scoreA, 1)
        XCTAssertEqual(game.scoreB, 1)

        game.undoLastPoint()
        XCTAssertEqual(game.scoreA, 1)
        XCTAssertEqual(game.scoreB, 0)

        game.undoLastPoint()
        XCTAssertEqual(game.scoreA, 0)
        XCTAssertEqual(game.scoreB, 0)
        XCTAssertFalse(game.canUndo)
    }

    func testBestOfOneEndsAfterOneGame() {
        var game = makeGame(format: .bo1)

        winGame(for: .teamA, in: &game)

        XCTAssertEqual(game.gamesWonA, 1)
        XCTAssertEqual(game.matchWinner, .teamA)
        XCTAssertEqual(game.matchPhase, .awaitingConfirmation)
    }

    func testBestOfThreeRequiresTwoGameWins() {
        var game = makeGame(format: .bo3)

        winGame(for: .teamA, in: &game)
        XCTAssertEqual(game.matchPhase, .playing)
        XCTAssertNil(game.matchWinner)

        winGame(for: .teamA, in: &game)
        XCTAssertEqual(game.matchWinner, .teamA)
        XCTAssertEqual(game.matchPhase, .awaitingConfirmation)
    }

    func testBestOfFiveRequiresThreeGameWins() {
        var game = makeGame(format: .bo5)

        winGame(for: .teamB, in: &game)
        winGame(for: .teamB, in: &game)
        XCTAssertEqual(game.matchPhase, .playing)
        XCTAssertNil(game.matchWinner)

        winGame(for: .teamB, in: &game)
        XCTAssertEqual(game.matchWinner, .teamB)
        XCTAssertEqual(game.matchPhase, .awaitingConfirmation)
    }

    func testTwentyOneNineteenEndsGame() {
        var game = makeGame()
        award(19, to: .teamB, in: &game)
        award(21, to: .teamA, in: &game)

        XCTAssertEqual(game.completedGames, [
            GameResult(scoreA: 21, scoreB: 19)
        ])
        XCTAssertEqual(game.gamesWonA, 1)
        XCTAssertEqual(game.gameNum, 2)
        XCTAssertEqual(game.scoreA, 0)
        XCTAssertEqual(game.scoreB, 0)
    }

    func testDeuceRequiresTwoPointLead() {
        var game = makeGame()
        award(20, to: .teamB, in: &game)
        award(21, to: .teamA, in: &game)

        XCTAssertFalse(game.isGameOver)
        XCTAssertTrue(game.completedGames.isEmpty)

        game.pointWon(by: .teamA)

        XCTAssertEqual(
            game.completedGames.last,
            GameResult(scoreA: 22, scoreB: 20)
        )
    }

    func testThirtyPointCapEndsGameWithoutTwoPointLead() {
        var game = makeGame()
        reachTie(29, in: &game)

        XCTAssertFalse(game.isGameOver)

        game.pointWon(by: .teamA)

        XCTAssertEqual(
            game.completedGames.last,
            GameResult(scoreA: 30, scoreB: 29)
        )
    }

    func testUndoGameWinningPointRestoresActiveGame() {
        var game = makeGame()
        award(19, to: .teamB, in: &game)
        award(21, to: .teamA, in: &game)

        game.undoLastPoint()

        XCTAssertEqual(game.scoreA, 20)
        XCTAssertEqual(game.scoreB, 19)
        XCTAssertEqual(game.gameNum, 1)
        XCTAssertTrue(game.completedGames.isEmpty)
        XCTAssertEqual(game.gamesWonA, 0)
        XCTAssertEqual(game.matchPhase, .playing)
    }

    func testUndoMatchWinningPointRestoresPlayingPhase() {
        var game = makeGame(format: .bo3)
        winGame(for: .teamA, in: &game)
        award(19, to: .teamB, in: &game)
        award(21, to: .teamA, in: &game)

        XCTAssertEqual(game.matchPhase, .awaitingConfirmation)

        game.undoLastPoint()

        XCTAssertEqual(game.matchPhase, .playing)
        XCTAssertEqual(game.scoreA, 20)
        XCTAssertEqual(game.scoreB, 19)
        XCTAssertEqual(game.gameNum, 2)
        XCTAssertEqual(game.gamesWonA, 1)
        XCTAssertEqual(game.completedGames.count, 1)
    }

    func testConfirmationSavesExactlyOnceAndCreatesUndoBoundary() {
        let history = MemoryMatchHistoryPersistence()
        var game = makeGame(format: .bo1, persistence: history)
        winGame(for: .teamA, in: &game)

        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let record = game.confirmCompletedMatch(at: date, id: id)

        XCTAssertEqual(record?.id, id)
        XCTAssertEqual(record?.playedAt, date)
        XCTAssertEqual(record?.winner, .teamA)
        XCTAssertEqual(game.matchHistory.count, 1)
        XCTAssertEqual(game.matchPhase, .completed)
        XCTAssertFalse(game.canUndo)
        XCTAssertEqual(history.saveCount, 1)

        XCTAssertNil(game.confirmCompletedMatch())
        XCTAssertEqual(game.matchHistory.count, 1)
        XCTAssertEqual(history.saveCount, 1)
    }

    func testStartingNewMatchResetsPlayButPreservesHistory() {
        let existing = makeRecord(idValue: 1)
        let history = MemoryMatchHistoryPersistence(records: [existing])
        var game = makeGame(format: .bo3, persistence: history)

        game.pointWon(by: .teamA)
        game.startNewMatch(format: MatchFormat(bestOf: .bo5, points: .p21))

        XCTAssertEqual(game.scoreA, 0)
        XCTAssertEqual(game.scoreB, 0)
        XCTAssertEqual(game.gameNum, 1)
        XCTAssertEqual(game.matchFormat.bestOf, .bo5)
        XCTAssertEqual(game.matchFormat.points, .p21)
        XCTAssertEqual(game.matchPhase, .playing)
        XCTAssertFalse(game.canUndo)
        XCTAssertEqual(game.matchHistory, [existing])
    }

    func testHistoryIsLimitedToNewestRecords() {
        let records = [makeRecord(idValue: 1), makeRecord(idValue: 2)]
        let history = MemoryMatchHistoryPersistence(records: records)
        var game = makeGame(
            format: .bo1,
            limit: 2,
            persistence: history
        )

        winGame(for: .teamB, in: &game)
        let newestID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        game.confirmCompletedMatch(
            at: Date(timeIntervalSince1970: 3),
            id: newestID
        )

        XCTAssertEqual(game.matchHistory.map(\.id), [records[1].id, newestID])
        XCTAssertEqual(history.records, game.matchHistory)
    }

    func testDeleteAndClearHistoryPersistChanges() {
        let first = makeRecord(idValue: 1)
        let second = makeRecord(idValue: 2)
        let history = MemoryMatchHistoryPersistence(records: [first, second])
        var game = makeGame(persistence: history)

        game.deleteHistoryRecord(id: first.id)
        XCTAssertEqual(game.matchHistory, [second])
        XCTAssertEqual(history.records, [second])

        game.clearMatchHistory()
        XCTAssertTrue(game.matchHistory.isEmpty)
        XCTAssertTrue(history.records.isEmpty)
        XCTAssertEqual(history.saveCount, 2)
    }

    func testActiveMatchPersistenceRoundTripAndClear() {
        let defaults = makeDefaults()
        let storage = ActiveMatchPersistence(defaults: defaults)
        let saved = ActiveMatchRecord(
            phase: .playing,
            format: MatchFormat(bestOf: .bo5, points: .p21),
            completedGames: [GameResult(scoreA: 21, scoreB: 18)],
            scoreA: 7,
            scoreB: 4,
            gameNum: 2,
            gamesWonA: 1,
            gamesWonB: 0
        )

        storage.save(saved)
        let loaded = storage.load()

        XCTAssertEqual(loaded?.phase, saved.phase)
        XCTAssertEqual(loaded?.format.bestOf, saved.format.bestOf)
        XCTAssertEqual(loaded?.format.points, saved.format.points)
        XCTAssertEqual(loaded?.completedGames, saved.completedGames)
        XCTAssertEqual(loaded?.scoreA, saved.scoreA)
        XCTAssertEqual(loaded?.scoreB, saved.scoreB)
        XCTAssertEqual(loaded?.gameNum, saved.gameNum)
        XCTAssertEqual(loaded?.gamesWonA, saved.gamesWonA)
        XCTAssertEqual(loaded?.gamesWonB, saved.gamesWonB)

        storage.clear()
        XCTAssertNil(storage.load())
    }

    func testActiveMatchPersistenceHandlesMissingAndCorruptData() {
        let defaults = makeDefaults()
        let storage = ActiveMatchPersistence(defaults: defaults)

        XCTAssertNil(storage.load())

        defaults.set(
            Data("not-json".utf8),
            forKey: "birdieScore.activeMatch"
        )

        XCTAssertNil(storage.load())
    }

    func testGameStateRestoresPersistedActiveMatch() {
        let defaults = makeDefaults()
        let activeStorage = ActiveMatchPersistence(defaults: defaults)
        let history = MemoryMatchHistoryPersistence()
        var original = GameState(
            activeStorage: activeStorage,
            persistence: history
        )
        original.startNewMatch(format: MatchFormat(bestOf: .bo5, points: .p21))
        winGame(for: .teamA, in: &original)
        original.pointWon(by: .teamA)
        original.pointWon(by: .teamB)
        original.pointWon(by: .teamA)

        let restored = GameState(
            activeStorage: activeStorage,
            persistence: history
        )

        XCTAssertEqual(restored.matchFormat.bestOf, .bo5)
        XCTAssertEqual(restored.matchFormat.points, .p21)
        XCTAssertEqual(restored.completedGames, [
            GameResult(scoreA: 21, scoreB: 19)
        ])
        XCTAssertEqual(restored.gamesWonA, 1)
        XCTAssertEqual(restored.gamesWonB, 0)
        XCTAssertEqual(restored.gameNum, 2)
        XCTAssertEqual(restored.scoreA, 2)
        XCTAssertEqual(restored.scoreB, 1)
        XCTAssertEqual(restored.matchPhase, .playing)
        XCTAssertTrue(restored.hasActiveMatchProgress)

        // Undo snapshots are intentionally in-memory only and are not restored.
        XCTAssertFalse(restored.canUndo)
    }

    func testUndoingOnlyPointClearsPersistedActiveMatch() {
        let defaults = makeDefaults()
        let activeStorage = ActiveMatchPersistence(defaults: defaults)
        var game = GameState(
            activeStorage: activeStorage,
            persistence: MemoryMatchHistoryPersistence()
        )
        game.startNewMatch(format: MatchFormat(bestOf: .bo3, points: .p21))
        game.pointWon(by: .teamA)
        XCTAssertNotNil(activeStorage.load())

        game.undoLastPoint()

        XCTAssertNil(activeStorage.load())
        XCTAssertFalse(game.hasActiveMatchProgress)
    }

    func testConfirmingMatchClearsActivePersistenceAndPersistsHistory() {
        let defaults = makeDefaults()
        let activeStorage = ActiveMatchPersistence(defaults: defaults)
        let history = UserDefaultsMatchHistoryPersistence(
            defaults: defaults,
            key: "test.matchHistory"
        )
        var game = GameState(
            activeStorage: activeStorage,
            persistence: history
        )
        game.startNewMatch(format: MatchFormat(bestOf: .bo1, points: .p21))
        winGame(for: .teamA, in: &game)
        XCTAssertNotNil(activeStorage.load())

        let savedRecord = game.confirmCompletedMatch()

        XCTAssertNotNil(savedRecord)
        XCTAssertNil(activeStorage.load())
        XCTAssertEqual(history.load(), game.matchHistory)
    }

    func testMatchHistoryPersistenceRoundTrip() {
        let defaults = makeDefaults()
        let history = UserDefaultsMatchHistoryPersistence(
            defaults: defaults,
            key: "test.matchHistory"
        )
        let records = [makeRecord(idValue: 4), makeRecord(idValue: 5)]

        history.save(records)

        XCTAssertEqual(history.load(), records)
    }

    func testMatchHistoryPersistenceHandlesMissingAndCorruptData() {
        let defaults = makeDefaults()
        let key = "test.matchHistory"
        let history = UserDefaultsMatchHistoryPersistence(
            defaults: defaults,
            key: key
        )

        XCTAssertTrue(history.load().isEmpty)

        defaults.set(Data("not-json".utf8), forKey: key)

        XCTAssertTrue(history.load().isEmpty)
    }

    func testGameStateLoadsOnlyNewestHistoryRecords() {
        let defaults = makeDefaults()
        let records = [
            makeRecord(idValue: 1),
            makeRecord(idValue: 2),
            makeRecord(idValue: 3)
        ]
        let history = UserDefaultsMatchHistoryPersistence(
            defaults: defaults,
            key: "test.matchHistory"
        )
        history.save(records)

        let game = GameState(
            activeStorage: ActiveMatchPersistence(defaults: defaults),
            matchHistoryLimit: 2,
            persistence: history
        )

        XCTAssertEqual(game.matchHistory, Array(records.suffix(2)))
    }

    func testMatchRecordCodableRoundTrip() throws {
        let record = makeRecord(idValue: 7)

        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(MatchRecord.self, from: data)

        XCTAssertEqual(decoded, record)
    }

    private func makeGame(
        format: NumGames = .bo3,
        limit: Int = 10,
        persistence: MemoryMatchHistoryPersistence =
            MemoryMatchHistoryPersistence()
    ) -> GameState {
        let activeStorage = ActiveMatchPersistence(defaults: makeDefaults())
        var game = GameState(
            activeStorage: activeStorage,
            matchHistoryLimit: limit,
            persistence: persistence
        )
        game.startNewMatch(format: MatchFormat(bestOf: format, points: .p21))
        return game
    }

    private func makeDefaults() -> UserDefaults {
        let suite = "BirdieScoreCoreTests.\(UUID().uuidString)"
        defaultsSuites.append(suite)
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private func award(
        _ points: Int,
        to team: Team,
        in game: inout GameState
    ) {
        for _ in 0..<points {
            game.pointWon(by: team)
        }
    }

    private func winGame(
        for winner: Team,
        in game: inout GameState
    ) {
        let loser: Team = winner == .teamA ? .teamB : .teamA
        award(19, to: loser, in: &game)
        award(21, to: winner, in: &game)
    }

    private func reachTie(
        _ score: Int,
        in game: inout GameState
    ) {
        award(20, to: .teamA, in: &game)
        award(20, to: .teamB, in: &game)

        if score > 20 {
            for _ in 21...score {
                game.pointWon(by: .teamA)
                game.pointWon(by: .teamB)
            }
        }
    }

    private func makeRecord(idValue: Int) -> MatchRecord {
        let id = UUID(
            uuidString: String(
                format: "00000000-0000-0000-0000-%012d",
                idValue
            )
        )!

        return MatchRecord(
            id: id,
            playedAt: Date(timeIntervalSince1970: TimeInterval(idValue)),
            games: [GameResult(scoreA: 21, scoreB: 18)],
            winner: .teamA
        )
    }
}
