#  BirdieScore

BirdieScore is a SwiftUI Apple Watch app for keeping score during badminton matches. Its scoring interface uses large team buttons for quick input, supports undoing points, and saves completed matches in a match history for later review.

## Features

- Tap either team panel to award a point.
- Play best-of-n matches using badminton 21-point scoring rules:
  - A game is normally won at 21 points with a two-point lead.
  - Play continues after 20–20 until a team leads by two.
  - At 29–29, the first team to reach 30 wins.
- Undo multiple points, including points that completed a game or match.
- Confirm a completed match before saving it.
- Save and begin another match or return to the home screen.
- Persist the 10 most recent confirmed matches with `UserDefaults`.
- Review, delete, or clear saved match history.
- Resume previously unfinished matches.

## Requirements

- A Mac with Xcode
- An Apple Watch simulator or a physical Apple Watch configured for development
- An Apple developer account for signing physical-device builds
- Swift 6.0 or later to run the standalone Swift package tests

The Xcode project currently has a watchOS 8.7 deployment target. The current interface also uses `NavigationStack` and conditional toolbar content. Lowering the target to watchOS 8 requires replacing those APIs with compatible navigation and toolbar implementations.

## Run the watch app

1. Open `BirdieScore/BirdieScore.xcodeproj` in Xcode.
2. Select the **BirdieScore Watch App** scheme.
3. Choose an Apple Watch simulator or paired physical Watch as the run destination.
4. Under **Signing & Capabilities**, select your development team and use bundle identifiers available to that team.
5. Build and run with **Command-R**.

For a physical Watch, keep the paired iPhone connected to the Mac and ensure Developer Mode is enabled on both devices.


## Match lifecycle and storage

Scoring a match-winning point moves the match into an awaiting-confirmation state. The user can undo that point, save the completed match and start another, or save it and finish. Only confirmed matches are written to history.

History records conform to `Codable` and are encoded as JSON in `UserDefaults`. Each record contains its identifier, completion date, winning team, and individual game scores. Undo snapshots intentionally exclude match history so undo only affects the active match.
