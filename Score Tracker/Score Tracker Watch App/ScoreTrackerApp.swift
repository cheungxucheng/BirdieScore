import SwiftUI

#if os(watchOS)
// Imports WatchKit so the app can use Apple Watch-specific APIs such as haptic feedback.
import WatchKit
#endif

@main
struct ScoreTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            // WindowGroup is a type of scene that manages 1 <= app windows
            // Think of it as a container for the ui
            // Creates and displays the app’s home screen.
            HomeView()
        }
    }
}

// allows for ui preview in xcode
#Preview() {
    HomeView()
}

// Starting screen. Prompts match setup or viewing match history
struct HomeView: View {
    @State private var game = GameState()
    @State private var numsGames: NumGames = .bo3
    @State private var showingMatch = false

    var body: some View {
        NavigationView {
            List {
                if game.hasActiveMatchProgress {
                    Button {
                        showingMatch = true
                    } label: {
                        Label(
                            "Resume Match",
                            systemImage: "play.fill"
                        )
                    }
                }
                
                HStack() {
                    Text("Best Of : ")
                        .font(.body)
                    Spacer()
                    
                    Picker("Best of :", selection: $numsGames) {
                        ForEach(NumGames.allCases) { num in
                            Text("\(num.rawValue)").tag(num)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    .frame(width: 50, height: 50)
                    .clipped()
                }
                
                Button {
                    game.startNewMatch(format: numsGames)
                    showingMatch = true
                } label: {
                    // Creates a label that combines readable text with the named SF Symbol.
                    Label("Start Match", systemImage: "plus.circle.fill")
                }
                .background {
                    NavigationLink(
                        destination: BadmintonView(game: $game),
                        isActive: $showingMatch
                    ) {
                        EmptyView()
                    }
                }

                NavigationLink {
                    MatchHistoryView(game: $game)
                } label: {
                    Label("Match History", systemImage: "clock.arrow.circlepath")
                }
            }
            .navigationTitle("Badminton")
        }
    }
}

struct BadmintonView: View {
    @Binding var game: GameState
    @Environment(\.dismiss) private var dismiss
    @State private var showDiscardConfirmation = false

    private var showMatchCompletion: Binding<Bool> {
        Binding(
            // The binding reads its Boolean value by evaluating this getter closure.
            get: { game.matchPhase == .awaitingConfirmation },
            // The binding requires a setter, but this closure intentionally ignores attempted changes.
            set: { _ in }
        )
    }

    var body: some View {
        ScoreView(game: $game)
            // Hides the standard Back button while a match has progress, preventing accidental abandonment.
            .navigationBarBackButtonHidden(game.hasActiveMatchProgress)
            // Adds controls to the system-managed navigation toolbar.
            .toolbar {
                if game.hasActiveMatchProgress {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            showDiscardConfirmation = true
                        } label: {
                            Image(systemName: "xmark")
                        }
                    }
                }
            }
            // Attaches a confirmation dialog to the view.
            .confirmationDialog(
                "Discard the current match?",
                isPresented: $showDiscardConfirmation,
                titleVisibility: .visible
            ) {
                Button("Discard Match", role: .destructive) {
                    game.discardCurrentMatch()
                    // Asks SwiftUI to close the currently presented or pushed screen.
                    dismiss()
                }

                // Creates a cancel button with an intentionally empty action because dismissal is automatic.
                Button("Keep Playing", role: .cancel) {}
            } message: {
                Text("The unfinished match and its Undo history will be lost.")
            }
            .sheet(isPresented: showMatchCompletion) {
                if let winner = game.matchWinner {
                    // Creates the modal screen used to confirm and save a completed match.
                    MatchCompletionView(
                        winner: winner,
                        games: game.completedGames,
                        canUndo: game.canUndo,
                        undo: {
                            game.undoLastPoint()
                            Haptics.undo()
                        },
                        saveAndStartNew: {
                            game.confirmCompletedMatch()
                            game.startNewMatch(format: game.matchFormat)
                        },
                        saveAndFinish: {
                            game.confirmCompletedMatch()
                            game.startNewMatch(format: game.matchFormat)
                            dismiss()
                        }
                    )
                    .interactiveDismissDisabled()
                }
            }
    }
}

struct ScoreView: View {
    @Binding var game: GameState

    private var completedScores: String {
        game.completedGames
            // Transforms every collection element into the displayed value described by the key path or closure.
            .map(\.displayScore)
            // Combines the transformed strings using the supplied separator.
            .joined(separator: "  ")
    }

    var body: some View {
        // Layers the screen-level Undo wedge above the normal score interface.
        GeometryReader { geometry in
            let compact: Bool = geometry.size.width < 190
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Game \(game.gameNum)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                        
                        if !completedScores.isEmpty {
                            // Adds flexible empty space that pushes neighboring content apart.
                            Spacer(minLength: 2)
                            Text(completedScores)
                                .font(.caption2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.65)
                        }
                    }
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.gray.opacity(0.3))
                    .clipShape(Capsule())
                    .accessibilityElement(children: .combine)
                    
                    VStack(spacing: 2) {
                        scoreButton(
                            team: .teamA,
                            score: game.scoreA,
                            color: .red
                        )
                        .clipShape(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                        )
                        
                        scoreButton(
                            team: .teamB,
                            score: game.scoreB,
                            color: .blue
                        )
                        .clipShape(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.horizontal, 4)
                
                Button {
                    game.undoLastPoint()
                    // Plays tactile confirmation that Undo succeeded.
                    Haptics.undo()
                } label: {
                    ZStack {
                        // Reads the fixed square used to reveal one quarter of the larger circle.
                        GeometryReader { geometry in
                            
                            let x: CGFloat = compact ? geometry.size.width * 1.1 : geometry.size.width
                            let y: CGFloat = compact ? geometry.size.height * 0.85 : geometry.size.height
                            
                            // Draws a circle whose center sits at the square's bottom-right corner.
                            Circle()
                            // Makes the active wedge prominent and the unavailable wedge subdued.
                                .fill(.gray.opacity(game.canUndo ? 1 : 0.9))
                            // Makes the circle twice the width and height of the visible square.
                                .frame(
                                    width: geometry.size.width * 1,
                                    height: geometry.size.height * 1
                                )
                            // Places the circle's center on the screen's lower-right corner.
                                .position(
                                    x: x,
                                    y: y
                                )
                            
                            // Draws the same quarter-circle geometry as a subtle dividing line.
                            Circle()
                                .stroke(.white.opacity(0.25), lineWidth: 1)
                                .frame(
                                    width: geometry.size.width * 1,
                                    height: geometry.size.height * 1
                                )
                                .position(
                                    x: x,
                                    y: y
                                )
                        }
                        
                        // Displays the Undo symbol near the visual center of the wedge.
                        Image(systemName: "arrow.uturn.backward")
                            .font(.title2)
                            .offset(x: compact ? 30 : 25, y: compact ? 10 : 25)
                    }
                    .frame(width: 60, height: 60)
                }
                .buttonStyle(.plain)
                // Lowers the complete circular control so the physical Watch edge clips its bottom.
                .offset(x: -20, y: 10)
                .disabled(!game.canUndo)
                .accessibilityLabel("Undo last point")
                .accessibilityHint("Restores the score before the most recent point")
            }
        }
    }

    private func scoreButton(
        team: Team,
        score: Int,
        color: Color
    ) -> some View {
        Button {
            let completedGameCount = game.completedGames.count
            game.pointWon(by: team)

            // Checks whether scoring this point completed the entire match.
            if game.matchPhase == .awaitingConfirmation {
                Haptics.matchCompleted()
            // Else if completed a game
            } else if game.completedGames.count > completedGameCount {
                Haptics.gameCompleted()
            } else {
                Haptics.pointScored()
            }
        } label: {
            VStack(spacing: 2) {
                Text(team.displayName)
                    .font(.caption2)
                    .fontWeight(.semibold)

                Text("\(score)")
                    .font(.title)
                    .fontWeight(.bold)
                    .monospacedDigit()
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .background(color)
        }
        .buttonStyle(ScorePanelButtonStyle())
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .disabled(game.matchPhase != .playing)
        .accessibilityLabel(team.displayName)
        .accessibilityValue("\(score) points")
        .accessibilityHint("Adds one point")
    }
}

#Preview {
    @Previewable @State var game = GameState()
    ScoreView(game: $game)
}
private struct ScorePanelButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.78 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

private struct MatchCompletionView: View {
    let winner: Team
    let games: [GameResult]
    let canUndo: Bool
    let undo: () -> Void
    let saveAndStartNew: () -> Void
    let saveAndFinish: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "trophy.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)

                Text("\(winner.displayName) Wins")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text(games.map(\.displayScore).joined(separator: "  "))
                    .font(.subheadline)
                    // Uses equal-width digits so changing scores do not make the layout jump.
                    .monospacedDigit()
                    .accessibilityLabel(
                        games
                            .enumerated()
                            .map { "Game \($0.offset + 1), \($0.element.scoreA) to \($0.element.scoreB)" }
                            .joined(separator: ", ")
                    )

                Button("Undo Last Point", action: undo)
                    .disabled(!canUndo)

                Button("Save & Start New Match", action: saveAndStartNew)
                    .buttonStyle(.borderedProminent)

                Button("Save & Finish", action: saveAndFinish)
            }
            .padding()
        }
    }
}

struct MatchHistoryView: View {
    @Binding var game: GameState
    @State private var showClearConfirmation = false

    var body: some View {
        // Groups conditional content without adding its own visible layout container.
        Group {
            // Chooses the empty-state interface when no matches have been saved.
            if game.matchHistory.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title2)
                    Text("No Saved Matches")
                        .font(.headline)
                    Text("Confirmed matches will appear here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                // Creates a vertically scrolling, watchOS-styled list.
                List {
                    // Creates one child row for every saved match, iterating newest records first.
                    ForEach(game.matchHistory.reversed()) { record in
                        MatchHistoryRow(record: record) {
                            game.deleteHistoryRecord(id: record.id)
                        }
                    }
                }
            }
        }
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button {
                    showClearConfirmation = true
                } label : {
                    Image(systemName: "trash")
                }
                .disabled(game.matchHistory.isEmpty)
                .opacity(game.hasActiveMatchProgress ? 0 : 1)
                .accessibilityHidden(game.matchHistory.isEmpty || game.hasActiveMatchProgress)
            }
        }
        .confirmationDialog(
            "Clear all match history?",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear History", role: .destructive) {
                game.clearMatchHistory()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }
}

private struct MatchHistoryRow: View {
    let record: MatchRecord
    let delete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(record.winner.displayName) won")
                    .font(.headline)

                Text(record.games.map(\.displayScore).joined(separator: "  "))
                    .font(.caption)
                    .monospacedDigit()

                Text(record.playedAt, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(role: .destructive, action: delete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete match")
        }
        .accessibilityElement(children: .contain)
    }
}


private enum Haptics {
    static func pointScored() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #endif
    }

    static func gameCompleted() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.directionUp)
        #endif
    }

    static func matchCompleted() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.success)
        #endif
    }

    static func undo() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.directionDown)
        #endif
    }
}
