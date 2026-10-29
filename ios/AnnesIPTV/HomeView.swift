import SwiftUI

/// Home: the gold launcher. A tall Live TV card, News / Religious / Radio / Favorites around it, and
/// (on wide screens) the brand panel with three round actions. Upright phones stack the same cards.
struct HomeView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 16) {
                    header
                    if geo.size.width >= 600 {
                        wideLayout(width: geo.size.width - 32)
                    } else {
                        stackedLayout
                    }
                }
                .padding(16)
            }
        }
        .appBackground()
        .navigationBarHidden(true)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image("AppLogo").resizable().scaledToFit().frame(height: 64)
            Text("Annes IPTV").font(.title2.weight(.bold))
            Spacer()
            NavigationLink(value: Route.settings) {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(Theme.gold)
                    .frame(width: 46, height: 46)
                    .goldCard(cornerRadius: 23)
            }
        }
    }

    private var stackedLayout: some View {
        VStack(spacing: 12) {
            card("nav_live_tv", symbol: "tv", route: .liveTV(topic: nil), hero: true).frame(height: 150)
            HStack(spacing: 12) {
                card("nav_news", symbol: "newspaper", route: .liveTV(topic: "news"))
                card("nav_religious", symbol: "moon.stars", route: .liveTV(topic: "religious"))
            }
            .frame(height: 120)
            HStack(spacing: 12) {
                card("nav_radio", symbol: "dot.radiowaves.left.and.right", route: .radio)
                card("nav_favorites", symbol: "heart.fill", route: .favorites)
            }
            .frame(height: 120)
            NavigationLink(value: Route.settings) {
                HStack(spacing: 10) {
                    Image(systemName: "text.badge.plus").foregroundColor(Theme.gold)
                    Text("add_playlist").font(.subheadline.weight(.semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 60)
                .goldCard(cornerRadius: 20)
            }
        }
    }

    private func wideLayout(width: CGFloat) -> some View {
        let gap: CGFloat = 12
        let unit = (width - gap * 2) / 4.3
        let rowHeight: CGFloat = 130
        return HStack(alignment: .top, spacing: gap) {
            card("nav_live_tv", symbol: "tv", route: .liveTV(topic: nil), hero: true)
                .frame(width: unit, height: rowHeight * 2 + gap)
            VStack(spacing: gap) {
                HStack(spacing: gap) {
                    card("nav_news", symbol: "newspaper", route: .liveTV(topic: "news"))
                    card("nav_religious", symbol: "moon.stars", route: .liveTV(topic: "religious"))
                }
                .frame(height: rowHeight)
                HStack(spacing: gap) {
                    card("nav_radio", symbol: "dot.radiowaves.left.and.right", route: .radio)
                    card("nav_favorites", symbol: "heart.fill", route: .favorites)
                }
                .frame(height: rowHeight)
            }
            .frame(width: unit * 2)
            VStack(spacing: gap) {
                Image("AppLogo").resizable().scaledToFit().padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .goldCard(cornerRadius: 24)
                HStack(spacing: gap) {
                    squareAction("gearshape.fill", route: .settings)
                    squareAction("text.badge.plus", route: .settings)
                }
                .frame(height: 56)
            }
            .frame(width: unit * 1.3, height: rowHeight * 2 + gap)
        }
    }

    private func card(_ title: LocalizedStringKey, symbol: String, route: Route, hero: Bool = false) -> some View {
        NavigationLink(value: route) {
            VStack(spacing: 12) {
                Spacer(minLength: 0)
                Image(systemName: symbol)
                    .font(.system(size: hero ? 34 : 26, weight: .semibold))
                    .foregroundColor(Theme.goldLight)
                    .frame(width: hero ? 72 : 56, height: hero ? 72 : 56)
                    .background(
                        RoundedRectangle(cornerRadius: hero ? 22 : 17, style: .continuous)
                            .fill(Theme.gold.opacity(0.14))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: hero ? 22 : 17, style: .continuous)
                            .stroke(Theme.gold.opacity(0.55), lineWidth: 1)
                    )
                Text(title)
                    .font(hero ? .title3.weight(.bold) : .headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .goldCard(cornerRadius: 24)
        }
        .buttonStyle(.plain)
    }

    private func squareAction(_ symbol: String, route: Route) -> some View {
        NavigationLink(value: route) {
            Image(systemName: symbol)
                .foregroundColor(Theme.goldLight)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .goldCard(cornerRadius: 16)
        }
    }
}
