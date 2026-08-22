# Score Tracker

Score Tracker is a SwiftUI Apple Watch app for keeping score during badminton matches. Its score-only interface uses large team buttons for quick input, supports undoing points, and saves completed matches for later review.

## Features

- Tap either team panel to award a point.
- Play best-of-three matches using badminton scoring rules:
  - A game is normally won at 21 points with a two-point lead.
  - Play continues after 20–20 until a team leads by two.
  - At 29–29, the first team to reach 30 wins.
- Undo multiple points, including points that completed a game or match.
- Confirm a completed match before saving it.
- Save and begin another match or return to the home screen.
- Persist the 10 most recent confirmed matches with `UserDefaults`.
- Review, delete, or clear saved match history.
- Receive Watch haptic feedback for points, completed games, completed matches, and undo.
- Use VoiceOver labels, values, and hints for the primary controls.

## Project structure

```text
ScoreTrackerApp.swift                  SwiftUI app and watch interface
ScoreTrackerCore.swift                 Scoring, undo, lifecycle, and persistence logic
Package.swift                          Swift package for the platform-independent core
Tests/ScoreTrackerCoreTests.swift      Core unit tests
Score Tracker/                         Xcode watchOS project and Xcode test targets
```

The scoring model is kept separate from SwiftUI. `GameState` owns the current scores, completed games, match phase, undo snapshots, and saved match records. Match-history persistence is abstracted behind `MatchHistoryPersisting`, allowing tests to use in-memory storage instead of `UserDefaults`.

## Requirements

- A Mac with Xcode
- An Apple Watch simulator or a physical Apple Watch configured for development
- An Apple developer account for signing physical-device builds
- Swift 6.0 or later to run the standalone Swift package tests

The checked-in Xcode project currently has a watchOS 26.5 deployment target. The current interface also uses `NavigationStack` and conditional toolbar content. Lowering the target to watchOS 8 requires replacing those APIs with compatible navigation and toolbar implementations.

## Run the watch app

1. Open `Score Tracker/Score Tracker.xcodeproj` in Xcode.
2. Select the **Score Tracker Watch App** scheme.
3. Choose an Apple Watch simulator or paired physical Watch as the run destination.
4. Under **Signing & Capabilities**, select your development team and use bundle identifiers available to that team.
5. Build and run with **Command-R**.

For a physical Watch, keep the paired iPhone connected to the Mac and ensure Developer Mode is enabled on both devices.

## Run tests

Run the platform-independent model tests from the repository root:

```sh
swift test
```

To run the Xcode unit and UI test targets, open the Xcode project, select a compatible Watch simulator, and use **Product > Test** or **Command-U**.

## Match lifecycle and storage

Scoring a match-winning point moves the match into an awaiting-confirmation state. The user can undo that point, save the completed match and start another, or save it and finish. Only confirmed matches are written to history.

History records conform to `Codable` and are encoded as JSON in `UserDefaults`. Each record contains its identifier, completion date, winning team, and individual game scores. Undo snapshots intentionally exclude match history so undo only affects the active match.
