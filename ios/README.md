# Annes IPTV — iOS

SwiftUI app for iPhone and iPad, the counterpart of the Android app in `app/`. Same ideas: bouquets
by country or group, the gold launcher, the side channel list with a bouquet drop-down, a full-screen
radio player and mini player, favorites, and Arabic / French / English with right-to-left layout.

## What it is made of

| Piece | File |
|---|---|
| App entry, navigation | `AnnesIPTV/AnnesIPTVApp.swift` |
| Home launcher | `HomeView.swift` |
| Live TV, bouquets, specialty menu | `LiveTVView.swift` |
| Channel player (AVPlayer) and its side list | `ChannelPlayerView.swift`, `Players.swift` |
| Radio (bouquets, mini player, full-screen player, background audio) | `RadioViews.swift`, `Players.swift` |
| Favorites, settings | `FavoritesView.swift`, `SettingsView.swift` |
| M3U parsing, country / language / bouquet rules | `M3UParser.swift`, `ChannelRules.swift` |
| Playlist, favorites, logos | `AppStore.swift`, `LogoCatalog.swift` |
| Texts (ar / fr / en) | `*.lproj/Localizable.strings` |
| Verified radio stations (209) | `Resources/radio_stations.json` (generated from `tools/radio`) |

The Xcode project is **not** committed: `project.yml` describes it and
[XcodeGen](https://github.com/yonaskolb/XcodeGen) generates `AnnesIPTV.xcodeproj`.

## Building without a Mac

`.github/workflows/ios-build.yml` runs on a GitHub macOS runner: it installs XcodeGen, generates the
project and builds for the iOS Simulator. Push to `develop` (or run the workflow by hand) and read the
result under the repository's **Actions** tab; the build log is attached as an artifact.

## Putting it on a phone (TestFlight)

1. Enrol in the **Apple Developer Program** (99 USD / year).
2. In App Store Connect create an app with bundle id `com.annes.iptv.ios` (change it in `project.yml`
   if you prefer another).
3. Create an App Store Connect API key and a distribution certificate + provisioning profile.
4. Add them as repository secrets and extend the workflow with an archive + upload step
   (`xcodebuild archive`, `xcodebuild -exportArchive`, `xcrun altool`/`fastlane pilot`), or use a
   service such as Codemagic that does this from a few clicks.
5. Testers install through the TestFlight app (up to 10,000 people).

## Differences from the Android app

- No over-the-air APK updates: iOS updates come through TestFlight / the App Store.
- The Algerian live-page resolver (`LiveStreamResolver`) and the bundled Algerian / sports / French
  playlist supplement are not ported yet; iOS loads the iptv-org list and any playlist you add.
- The app icon is the Android launcher icon scaled up: replace `Assets.xcassets/AppIcon` with a
  proper 1024 px icon before a store release.
- **App Review:** the app downloads a public channel list on first launch. Apple has rejected IPTV
  apps over content rights; if that happens, ship without the built-in list and let users add their
  own playlist (Settings → Playlists).
