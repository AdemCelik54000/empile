import SwiftUI

/// Always at the top: pause, the score, the best score ever, and the lives left.
struct ClimbHeader: View {
    let session: GameSession
    /// The best score ever, in points.
    let record: Int
    let onPause: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onPause) {
                Image(systemName: "pause.fill")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel(Text("Pause"))

            HStack {
                Figure(caption: "Points", value: session.score.formatted())
                    .contentTransition(.numericText(value: Double(session.score)))
                    .animation(.spring(duration: 0.4), value: session.score)
                    // Every gain makes the number jump.
                    .keyframeAnimator(initialValue: 1.0, trigger: session.score) { content, scale in
                        content.scaleEffect(scale)
                    } keyframes: { _ in
                        SpringKeyframe(1.22, duration: 0.12)
                        SpringKeyframe(1, duration: 0.35, spring: .bouncy)
                    }
                    .accessibilityLabel(Text("\(session.score) points"))
                Spacer(minLength: 6)
                Figure(caption: "Record", value: record.formatted())
                    .contentTransition(.numericText(value: Double(record)))
                    .animation(.spring(duration: 0.4), value: record)
                    .accessibilityLabel(Text("Record : \(record) points"))
                Spacer(minLength: 6)
                Lives(count: session.lives, maximum: session.maxLives)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: .capsule)
        }
    }
}

/// One heart per life, the lost ones hollow.
private struct Lives: View {
    let count: Int
    let maximum: Int

    var body: some View {
        VStack(spacing: 2) {
            Text("Vies")
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            HStack(spacing: 2) {
                ForEach(0..<max(maximum, count), id: \.self) { index in
                    Image(systemName: index < count ? "heart.fill" : "heart")
                        .foregroundStyle(index < count ? AnyShapeStyle(Color.red) : AnyShapeStyle(.tertiary))
                        .symbolEffect(.bounce, value: index < count)
                }
            }
            .font(.footnote.weight(.bold))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(count) vies"))
    }
}

/// Under the header while perfect placements follow one another: a flame and the current multiplier.
struct ComboBadge: View {
    let combo: Combo

    var body: some View {
        let multiplier = combo.multiplier.formatted(.number.precision(.fractionLength(0...2)))
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.headline)
                .foregroundStyle(LinearGradient(colors: [.yellow, .orange, .red], startPoint: .top, endPoint: .bottom))
                .symbolEffect(.bounce, value: combo.streak)
                .symbolEffect(.breathe, isActive: true)
            Text("Combo ×\(multiplier)")
                .font(.headline)
                .fontDesign(.rounded)
                .monospacedDigit()
                .contentTransition(.numericText(value: combo.multiplier))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .glassEffect(.regular.tint(Color(uiColor: Palette.celebration).opacity(0.25)), in: .capsule)
        .keyframeAnimator(initialValue: 1.0, trigger: combo.streak) { content, scale in
            content.scaleEffect(scale)
        } keyframes: { _ in
            SpringKeyframe(1.25, duration: 0.14)
            SpringKeyframe(1, duration: 0.4, spring: .bouncy)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Combo, multiplicateur \(multiplier)"))
    }
}

/// Pops in under the header when the score beats the best one ever.
struct RecordBanner: View {
    var body: some View {
        Label("Nouveau record !", systemImage: "trophy.fill")
            .font(.headline)
            .fontDesign(.rounded)
            .foregroundStyle(Color(uiColor: Palette.celebration))
            .symbolEffect(.bounce, options: .repeat(2), value: true)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: .capsule)
    }
}

/// Pops in under the header when the tower passes a milestone.
struct MilestoneBanner: View {
    let milestone: Milestone

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "flag.checkered")
                .font(.title3.weight(.bold))
                .foregroundStyle(.tint)
            Text("Palier \(milestone.floors) étages")
                .font(.headline)
                .fontDesign(.rounded)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .capsule)
        .accessibilityElement(children: .combine)
    }
}

/// Under the header while a gust is coming or blowing, pointing the way it blows.
struct WindBanner: View {
    let alert: WindAlert

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wind")
                .font(.headline)
                .symbolEffect(.pulse, isActive: !alert.isBlowing)
            Text(alert.isBlowing ? "Coup de vent" : "Le vent se lève")
                .font(.subheadline.weight(.semibold))
            Image(systemName: alert.direction > 0 ? "arrow.right" : "arrow.left")
                .font(.subheadline.weight(.bold))
        }
        .foregroundStyle(alert.isBlowing ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .capsule)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(alert.direction > 0
            ? (alert.isBlowing ? "Coup de vent vers la droite" : "Le vent se lève, il va souffler vers la droite")
            : (alert.isBlowing ? "Coup de vent vers la gauche" : "Le vent se lève, il va souffler vers la gauche")))
    }
}

/// Shown at the bottom once the last life is lost: continue after an ad (for a few seconds), play again, or go
/// home.
struct GameOverPanel: View {
    /// Ce qu'il faut au bouton « Continuer ».
    struct ContinueState {
        /// La partie peut encore être continuée (`GameSession.canContinue`).
        let canContinue: Bool
        /// Une pub récompensée est prête.
        let isAdReady: Bool
        /// Une pub est à l'écran, ou le joueur quitte déjà le panneau.
        let isBusy: Bool
        let action: () -> Void
    }

    let score: Int
    let record: Int
    let isNewRecord: Bool
    /// `nil` : pas de bouton « Continuer » (la partie a déjà été continuée une fois).
    let continueOffer: ContinueState?
    let onReplay: () -> Void
    let onHome: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Image(systemName: isNewRecord ? "trophy.fill" : "arrow.down.to.line")
                    .font(.largeTitle)
                    .foregroundStyle(isNewRecord ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .symbolEffect(.bounce, value: isNewRecord)
                Text(isNewRecord ? "Nouveau record !" : "Partie terminée")
                    .font(.title2.weight(.bold))
                    .fontDesign(.rounded)
                    .accessibilityAddTraits(.isHeader)
                Text("\(score.formatted()) points. Record : \(record.formatted()) points.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            GlassEffectContainer(spacing: 10) {
                VStack(spacing: 10) {
                    if let continueOffer {
                        ContinueButton(state: continueOffer)
                    }
                    Button(action: onReplay) {
                        Label("Rejouer", systemImage: "arrow.counterclockwise")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.glassProminent)
                    Button(action: onHome) {
                        Text("Accueil")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.glass)
                }
            }
        }
        .padding(20)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
    }
}

/// « Continuer » : une barre remplit tout le bouton en `Tuning.Continue.window` secondes, pendant lesquelles il
/// se touche. Ensuite (ou dès le départ sans pub prête), il devient gris et ne se touche plus.
private struct ContinueButton: View {
    let state: GameOverPanel.ContinueState
    private let offer = ContinueOffer()
    /// Quand le panneau est apparu : le temps pour toucher part de là.
    @State private var shownAt = Date.now
    @State private var isTimeUp = false

    var body: some View {
        TimelineView(.animation(paused: isTimeUp)) { context in
            // Une fois le temps écoulé, l'horloge s'arrête : sa dernière image peut dater d'un poil avant la fin.
            let elapsed = isTimeUp ? offer.window : context.date.timeIntervalSince(shownAt)
            let isAvailable = offer.isAvailable(elapsed: elapsed, canContinue: state.canContinue,
                                                isAdReady: state.isAdReady, isBusy: state.isBusy)
            // Sans pub prête, rien ne se remplit : le bouton est gris d'emblée.
            let progress = state.isAdReady && state.canContinue ? offer.progress(elapsed: elapsed) : 1
            Button(action: state.action) {
                HStack(spacing: 12) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Continuer")
                            .font(.headline)
                        Text("Regarder une pub pour continuer")
                            .font(.caption)
                            .foregroundStyle(isAvailable ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tertiary))
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, minHeight: 56)
                .foregroundStyle(isAvailable ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                .background(alignment: .leading) {
                    GeometryReader { proxy in
                        Rectangle()
                            .fill(isAvailable ? AnyShapeStyle(.tint.opacity(0.45)) : AnyShapeStyle(.gray.opacity(0.25)))
                            .frame(width: proxy.size.width * progress)
                    }
                }
                .clipShape(.capsule)
                .contentShape(.capsule)
            }
            .buttonStyle(.plain)
            .disabled(!isAvailable)
            .glassEffect(isAvailable ? .regular.interactive() : .regular, in: .capsule)
            .saturation(isAvailable ? 1 : 0)
            .accessibilityLabel(Text("Continuer"))
            .accessibilityHint(Text(isAvailable ? "Regarder une pub pour reprendre la partie." : "Plus disponible."))
        }
        .task {
            shownAt = .now
            try? await Task.sleep(for: .seconds(offer.window))
            isTimeUp = true
        }
    }
}

/// A small caption over a rounded number.
private struct Figure: View {
    let caption: LocalizedStringKey
    let value: String

    var body: some View {
        VStack(spacing: 0) {
            Text(caption)
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.bold))
                .fontDesign(.rounded)
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
    }
}
