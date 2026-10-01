import Foundation
import XCTest
@testable import ScoreTrackerCore

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

final class ScoreTrackerCoreTests: XCTestCase {
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

    func testTwentyOneTwentyContinuesAndTwentyTwoTwentyEnds() {
        var game = makeGame()
        award(20, to: .teamB, in: &game)
        award(21, to: .teamA, in: &game)

        XCTAssertFalse(game.isGameOver)
        XCTAssertTrue(game.completedGames.isEmpty)
        XCTAssertEqual(game.scoreA, 21)
        XCTAssertEqual(game.scoreB, 20)

        game.pointWon(by: .teamA)

        XCTAssertEqual(game.completedGames.last, GameResult(scoreA: 22, scoreB: 20))
    }

    func testTwentyNineAllContinuesAndThirtyTwentyNineEnds() {
        var game = makeGame()
        reachTwentyNineAll(in: &game)

        XCTAssertFalse(game.isGameOver)
        XCTAssertEqual(game.scoreA, 29)
        XCTAssertEqual(game.scoreB, 29)

        game.pointWon(by: .teamA)

        XCTAssertEqual(game.completedGames.last, GameResult(scoreA: 30, scoreB: 29))
    }

    func testThirtyTwentyEightEndsAtTheCap() {
        var game = makeGame()
        reachTie(28, in: &game)
        game.pointWon(by: .teamA)
        game.pointWon(by: .teamA)

        XCTAssertEqual(game.completedGames.last, GameResult(scoreA: 30, scoreB: 28))
    }

    func testTwoZeroMatchAwaitsConfirmationAndBlocksScoring() {
        var game = makeGame()
        winGame(for: .teamA, in: &game)
        winGame(for: .teamA, in: &game)

        XCTAssertEqual(game.gamesWonA, 2)
        XCTAssertEqual(game.gamesWonB, 0)
        XCTAssertEqual(game.matchWinner, .teamA)
        XCTAssertEqual(game.matchPhase, .awaitingConfirmation)
        XCTAssertTrue(game.isMatchOver)

        game.pointWon(by: .teamB)
        XCTAssertEqual(game.scoreB, 0)
    }

    func testTwoOneMatch() {
        var game = makeGame()
        winGame(for: .teamA, in: &game)
        winGame(for: .teamB, in: &game)
        winGame(for: .teamA, in: &game)

        XCTAssertEqual(game.gamesWonA, 2)
        XCTAssertEqual(game.gamesWonB, 1)
        XCTAssertEqual(game.completedGames.count, 3)
        XCTAssertEqual(game.matchWinner, .teamA)
        XCTAssertEqual(game.matchPhase, .awaitingConfirmation)
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

    func testUndoMatchWinningPointRestoresMatchPhase() {
        var game = makeGame()
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
        let persistence = MemoryMatchHistoryPersistence()
        var game = makeGame(persistence: persistence)
        winGame(for: .teamA, in: &game)
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
        XCTAssertEqual(persistence.saveCount, 1)

        XCTAssertNil(game.confirmCompletedMatch())
        XCTAssertEqual(game.matchHistory.count, 1)
        XCTAssertEqual(persistence.saveCount, 1)

        game.undoLastPoint()
        XCTAssertEqual(game.matchHistory.count, 1)
        XCTAssertEqual(game.matchPhase, .completed)
    }

    func testStartingNewMatchPreservesPermanentHistory() {
        let existing = makeRecord(idValue: 1)
        let persistence = MemoryMatchHistoryPersistence(records: [existing])
        var game = makeGame(persistence: persistence)

        game.pointWon(by: .teamA)
        game.startNewMatch()

        XCTAssertEqual(game.scoreA, 0)
        XCTAssertEqual(game.scoreB, 0)
        XCTAssertEqual(game.gameNum, 1)
        XCTAssertEqual(game.matchPhase, .playing)
        XCTAssertFalse(game.canUndo)
        XCTAssertEqual(game.matchHistory, [existing])
    }

    func testHistoryIsLimitedToNewestRecords() {
        let records = [makeRecord(idValue: 1), makeRecord(idValue: 2)]
        let persistence = MemoryMatchHistoryPersistence(records: records)
        var game = makeGame(limit: 2, persistence: persistence)

        winGame(for: .teamB, in: &game)
        winGame(for: .teamB, in: &game)
        let newestID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        game.confirmCompletedMatch(
            at: Date(timeIntervalSince1970: 3),
            id: newestID
        )

        XCTAssertEqual(game.matchHistory.map(\.id), [records[1].id, newestID])
        XCTAssertEqual(persistence.records, game.matchHistory)
    }

    func testDeleteAndClearHistoryPersistChanges() {
        let first = makeRecord(idValue: 1)
        let second = makeRecord(idValue: 2)
        let persistence = MemoryMatchHistoryPersistence(records: [first, second])
        var game = makeGame(persistence: persistence)

        game.deleteHistoryRecord(id: first.id)
        XCTAssertEqual(game.matchHistory, [second])
        XCTAssertEqual(persistence.records, [second])

        game.clearMatchHistory()
        XCTAssertTrue(game.matchHistory.isEmpty)
        XCTAssertTrue(persistence.records.isEmpty)
        XCTAssertEqual(persistence.saveCount, 2)
    }

    func testMatchRecordCodableRoundTrip() throws {
        let record = makeRecord(idValue: 7)
        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(MatchRecord.self, from: data)

        XCTAssertEqual(decoded, record)
    }

    func testUserDefaultsPersistenceHandlesMissingAndCorruptData() {
        let suite = "ScoreTrackerCoreTests.\(UUID().uuidString)"
        let key = "history"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let persistence = UserDefaultsMatchHistoryPersistence(
            defaults: defaults,
            key: key
        )

        XCTAssertTrue(persistence.load().isEmpty)

        defaults.set(Data("not-json".utf8), forKey: key)
        XCTAssertTrue(persistence.load().isEmpty)

        let record = makeRecord(idValue: 9)
        persistence.save([record])
        XCTAssertEqual(persistence.load(), [record])
    }

    private func makeGame(
        limit: Int = 10,
        persistence: MemoryMatchHistoryPersistence =
            MemoryMatchHistoryPersistence()
    ) -> GameState {
        GameState(
            matchHistoryLimit: limit,
            persistence: persistence
        )
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

    private func reachTwentyNineAll(in game: inout GameState) {
        reachTie(29, in: &game)
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
