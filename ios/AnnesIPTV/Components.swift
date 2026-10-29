import SwiftUI

enum Theme {
    static let gold = Color(red: 0.914, green: 0.725, blue: 0.286)
    static let goldLight = Color(red: 1.0, green: 0.878, blue: 0.541)
    static let night = Color(red: 0.043, green: 0.055, blue: 0.102)
    static let card = Color(red: 0.043, green: 0.055, blue: 0.102).opacity(0.78)
    static let capsule = LinearGradient(
        colors: [Color(red: 0.09, green: 0.106, blue: 0.2), Color(red: 0.03, green: 0.04, blue: 0.086)],
        startPoint: .top, endPoint: .bottom
    )
}

/// The app backdrop: the user's own picture when one is chosen, else the bundled default.
struct AppBackground: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Theme.night
                if let image = loadImage() {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
                LinearGradient(
                    colors: [Theme.night.opacity(0.50), Theme.night.opacity(0.35), Theme.night.opacity(0.80)],
                    startPoint: .top, endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
    }

    private func loadImage() -> UIImage? {
        _ = store.backgroundVersion // re-read when the picture changes
        if let custom = UIImage(contentsOfFile: AppStore.backgroundFileURL.path) { return custom }
        if let path = Bundle.main.path(forResource: "default_background", ofType: "jpg") {
            return UIImage(contentsOfFile: path)
        }
        return nil
    }
}

extension View {
    func appBackground() -> some View {
        background(AppBackground())
    }

    /// A dark, gold-edged card.
    func goldCard(cornerRadius: CGFloat = 22) -> some View {
        background(Theme.card, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Theme.gold.opacity(0.75), lineWidth: 1)
            )
    }

    /// A frosted glass card for the grid tiles.
    func glassCard(cornerRadius: CGFloat = 18) -> some View {
        background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
    }
}

/// A channel / station logo; a missing or broken one falls back to the initials on a coloured badge.
struct LogoView: View {
    let url: String?
    let name: String

    var body: some View {
        ZStack {
            Color(white: 0.13)
            if let url, let parsed = URL(string: url) {
                AsyncImage(url: parsed) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit().padding(5)
                    default:
                        Monogram(name: name)
                    }
                }
            } else {
                Monogram(name: name)
            }
        }
    }
}

struct Monogram: View {
    let name: String

    private static let palette: [Color] = [
        Color(red: 0.11, green: 0.31, blue: 0.85), Color(red: 0.06, green: 0.46, blue: 0.43),
        Color(red: 0.49, green: 0.23, blue: 0.93), Color(red: 0.71, green: 0.33, blue: 0.04),
        Color(red: 0.75, green: 0.07, blue: 0.24), Color(red: 0.08, green: 0.50, blue: 0.24),
        Color(red: 0.05, green: 0.45, blue: 0.56), Color(red: 0.58, green: 0.20, blue: 0.92)
    ]

    private var initials: String {
        let words = name.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).prefix(2)
        return words.compactMap { $0.first.map { String($0).uppercased() } }.joined()
    }

    private var color: Color {
        var hash = 5381
        for scalar in name.lowercased().unicodeScalars { hash = (hash &* 33) &+ Int(scalar.value) }
        return Monogram.palette[abs(hash % Monogram.palette.count)]
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [color, color.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Text(initials.isEmpty ? "•" : initials)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
                .foregroundColor(.white)
        }
    }
}

/// One bouquet tile: a flag (or a folder for a group label), the name and how many it holds.
struct BouquetCell: View {
    let bouquet: Bouquet
    let name: String
    let unit: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                if resolveCountryCode(bouquet.key) != nil {
                    Text(countryFlag(bouquet.key)).font(.system(size: 40))
                } else {
                    Image(systemName: "folder.fill").font(.system(size: 34)).foregroundColor(Theme.gold)
                        .frame(height: 48)
                }
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: 38)
                HStack(spacing: 3) {
                    Text("\(bouquet.count)")
                    Text(unit)
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .glassCard()
        }
        .buttonStyle(.plain)
    }
}

/// A title with a back button, shown over a grid once a bouquet is open.
struct BouquetHeader: View {
    let name: String
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "chevron.backward")
                    .font(.headline)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
            Text(name).font(.headline).lineLimit(1)
            Spacer()
        }
    }
}

/// Four bars that dance while audio plays and rest low otherwise.
struct Equalizer: View {
    let active: Bool
    var color: Color = Theme.gold

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: !active)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<4, id: \.self) { i in
                    let level = active ? 0.3 + 0.7 * abs(sin(2 * Double.pi * (t / 1.1 + Double(i) * 0.23))) : 0.25
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(active ? 1 : 0.45))
                        .frame(width: 4, height: 18 * level)
                }
            }
            .frame(width: 26, height: 18, alignment: .bottom)
        }
    }
}
