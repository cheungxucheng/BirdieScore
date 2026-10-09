// Imports Foundation types used here, including Date, UUID, UserDefaults, and JSON encoders.
import Foundation

// indicates the match format and required games to win
enum NumGames: Int, CaseIterable, Identifiable, Codable{
    case bo1 = 1
    case bo3 = 3
    case bo5 = 5
    
    var id: Int {self.rawValue}
    var gamesNeededToWin: Int {(rawValue / 2) + 1}
}

enum Team: String, Codable, CaseIterable, Equatable {
    case teamA
    case teamB

    var displayName: String {
        switch self {
        case .teamA:
            return "Your Team"
        case .teamB:
            // Returns the display text for Team B.
            return "Opponent Team"
        }
    }
}

// Match Lifecycle: playing -> awaitingConfirmation -> completed
enum MatchPhase: Equatable, Codable { // ...exactly what you think it means
    case playing // an ongoing match
    case awaitingConfirmation // a match that just got completed and is now awaiting completion confirmation
    case completed // a completed match
}

struct GameResult: Codable, Equatable {
    let scoreA: Int
    let scoreB: Int

    var winner: Team {
        scoreA > scoreB ? .teamA : .teamB
    }

    var displayScore: String {
        "\(scoreA)-\(scoreB)"
    }
}

struct MatchRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let playedAt: Date
    let games: [GameResult]
    let winner: Team
}

// stores current match information necessary for resuming in case of an exit
struct ActiveMatchRecord: Codable {
    let phase: MatchPhase
    let format: NumGames
    let completedGames: [GameResult]
    let scoreA: Int
    let scoreB: Int
    let gameNum: Int
    let gamesWonA: Int
    let gamesWonB: Int
}

final class ActiveMatchPersistence {
    private let defaults: UserDefaults
    private let key = "scoreTracker.activeMatch"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func save(_ match: ActiveMatchRecord) {
        // try encoding the active match record, if fails return
        guard let data = try? JSONEncoder().encode(match) else {
            return
        }

        defaults.set(data, forKey: key)
    }
    // load returns an optional ActiveMatchRecord
    func load() -> ActiveMatchRecord? {
        // check if defaults at that key exists otherwise return nil
        guard let data = defaults.data(forKey: key) else {
            return nil
        }

        // try decoding the data from the key into an ActiveMatchRecord
        return try? JSONDecoder().decode( 
            ActiveMatchRecord.self,
            from: data
        )
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}

// Defines the interface that any match-history storage implementation must provide.
protocol MatchHistoryPersisting {
    // Requires conforming storage types to load and return all saved match records.
    func load() -> [MatchRecord]
    // Requires conforming storage types to save the supplied record array; `_` omits the external argument label.
    func save(_ records: [MatchRecord])
}

// Declares a non-subclassable reference type that stores match history in UserDefaults.
final class UserDefaultsMatchHistoryPersistence: MatchHistoryPersisting {
    // Stores the UserDefaults database used by this persistence object.
    private let defaults: UserDefaults
    // Stores the dictionary key under which encoded history data is saved.
    private let key: String

    init(
        // Declares an injectable UserDefaults parameter whose default is the app’s standard database.
        defaults: UserDefaults = .standard,
        key: String = "scoreTracker.matchHistory"
    ) {
        self.defaults = defaults
        self.key = key
    }

    // Requires conforming storage types to load and return all saved match records.
    func load() -> [MatchRecord] {
        guard
            // Attempts to read previously encoded Data from UserDefaults using the storage key.
            let data = defaults.data(forKey: key),
            // Attempts JSON decoding and converts any thrown error into nil with `try?`.
            let records = try? JSONDecoder().decode(
                // Passes the MatchRecord-array type itself so JSONDecoder knows the desired output type.
                [MatchRecord].self,
                // Supplies the stored bytes that JSONDecoder should decode.
                from: data
            )
        else {
            return []
        }

        return records
    }

    // Requires conforming storage types to save the supplied record array; `_` omits the external argument label.
    func save(_ records: [MatchRecord]) {
        // Attempts to encode the records as JSON Data and enters the failure branch if encoding fails.
        guard let data = try? JSONEncoder().encode(records) else {
            return
        }

        // Writes the encoded bytes into UserDefaults under the configured key.
        defaults.set(data, forKey: key)
    }
}

private struct GameSnapshot {
    let scoreA: Int
    let scoreB: Int
    let gameNum: Int
    let completedGames: [GameResult]
    let gamesWonA: Int
    let gamesWonB: Int
    let matchPhase: MatchPhase
}

struct GameState {
    private(set) var scoreA = 0
    private(set) var scoreB = 0
    private(set) var gameNum = 1
    private(set) var matchFormat: NumGames = .bo3
    private(set) var completedGames: [GameResult] = []
    private(set) var gamesWonA = 0
    private(set) var gamesWonB = 0
    private(set) var matchPhase: MatchPhase = .playing
    private(set) var matchHistory: [MatchRecord]

    private var undoHistory: [GameSnapshot] = []
    private let matchHistoryLimit: Int
    private let persistence: any MatchHistoryPersisting
    private let activeStorage: ActiveMatchPersistence

    init(
        activeStorage: ActiveMatchPersistence = ActiveMatchPersistence()
        matchHistoryLimit: Int = 10,
        // Declares injectable storage through the protocol type, allowing tests or alternatives.
        persistence: any MatchHistoryPersisting =
            UserDefaultsMatchHistoryPersistence()
    ) {
        
        if let saved = activeStorage.load() {
            scoreA = saved.scoreA
            scoreB = saved.scoreB
            gameNum = saved.gameNum
            matchFormat = saved.format
            completedGames = saved.completedGames
            gamesWonA = saved.gamesWonA
            gamesWonB = saved.gamesWonB
            matchPhase = saved.matchPhase
        }

        self.matchHistoryLimit = max(1, matchHistoryLimit)
        self.persistence = persistence
        self.matchHistory = Array(
            persistence.load().suffix(max(1, matchHistoryLimit))
        )
    }

    var isGameOver: Bool {
        let leadingScore = max(scoreA, scoreB)
        return leadingScore == 30 ||
            (leadingScore >= 21 && abs(scoreA - scoreB) >= 2)
    }

    var isMatchOver: Bool {
        gamesWonA == matchFormat.gamesNeededToWin || gamesWonB == matchFormat.gamesNeededToWin
    }

    var matchWinner: Team? {
        if gamesWonA == matchFormat.gamesNeededToWin {
            return .teamA
        }

        if gamesWonB == matchFormat.gamesNeededToWin {
            return .teamB
        }

        return nil
    }

    var canUndo: Bool {
        !undoHistory.isEmpty && matchPhase != .completed
    }

    var hasActiveMatchProgress: Bool {
        scoreA > 0 || scoreB > 0 || !completedGames.isEmpty
    }

    mutating func pointWon(by winningTeam: Team) {
        guard matchPhase == .playing else {
            return
        }

        saveSnapshot()
        incrementScore(for: winningTeam)

        saveRecord()
        if isGameOver {
            finishGame()
        }
    }

    mutating func undoLastPoint() {
        guard let previous = undoHistory.popLast() else {
            return
        }

        scoreA = previous.scoreA
        scoreB = previous.scoreB
        gameNum = previous.gameNum
        completedGames = previous.completedGames
        gamesWonA = previous.gamesWonA
        gamesWonB = previous.gamesWonB
        matchPhase = previous.matchPhase

        saveRecord()
    }

    // Allows callers to ignore this method’s returned record without receiving a compiler warning.
    @discardableResult
    mutating func confirmCompletedMatch(
        at date: Date = Date(),
        id: UUID = UUID()
    // Declares an optional return because confirmation can fail when the match is not ready.
    ) -> MatchRecord? {
        guard
            matchPhase == .awaitingConfirmation,
            let winner = matchWinner
        else {
            return nil
        }

        let record = MatchRecord(
            id: id,
            playedAt: date,
            games: completedGames,
            winner: winner
        )

        matchHistory.append(record)
        trimMatchHistory()
        persistence.save(matchHistory)

        undoHistory.removeAll()
        matchPhase = .completed
        activeStorage.clear()
        return record
    }

    mutating func startNewMatch(format: NumGames) {
        scoreA = 0
        scoreB = 0
        gameNum = 1
        completedGames = []
        gamesWonA = 0
        gamesWonB = 0
        undoHistory = []
        matchPhase = .playing
        
        matchFormat = format
    }

    mutating func discardCurrentMatch() {
        activeStorage.clear()
        startNewMatch(format: matchFormat)
    }

    mutating func deleteHistoryRecord(id: UUID) {
        matchHistory.removeAll { $0.id == id }
        persistence.save(matchHistory)
    }

    mutating func clearMatchHistory() {
        matchHistory.removeAll()
        persistence.save(matchHistory)
    }

    private mutating func saveSnapshot() {
        undoHistory.append(
            GameSnapshot(
                scoreA: scoreA,
                scoreB: scoreB,
                gameNum: gameNum,
                completedGames: completedGames,
                gamesWonA: gamesWonA,
                gamesWonB: gamesWonB,
                matchPhase: matchPhase
            )
        )
    }

    private mutating func incrementScore(for team: Team) {
        switch team {
        case .teamA:
            scoreA += 1
        case .teamB:
            scoreB += 1
        }
    }

    private mutating func finishGame() {
        let result = GameResult(scoreA: scoreA, scoreB: scoreB)
        completedGames.append(result)

        switch result.winner {
        case .teamA:
            gamesWonA += 1
        case .teamB:
            gamesWonB += 1
        }

        scoreA = 0
        scoreB = 0

        if isMatchOver {
            // Stops scoring and asks the UI to present match confirmation.
            matchPhase = .awaitingConfirmation
        } else {
            gameNum += 1
        }
    }

    private mutating func trimMatchHistory() {
        // Calculates how many records exceed the configured limit.
        let overflow = matchHistory.count - matchHistoryLimit
        if overflow > 0 {
            matchHistory.removeFirst(overflow)
        }
    }

    private mutating func saveRecord() {
        activeStorage.save(
            ActiveMatchRecord(
                scoreA: scoreA,
                scoreB: scoreB,
                gameNum: gameNum,
                matchFormat: matchFormat,
                completedGames: completedGames,
                gamesWonA: gamesWonA,
                gamesWonB: gamesWonB,
                matchPhase: matchPhase
            )
        )
    }
}
