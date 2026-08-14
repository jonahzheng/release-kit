# release-kit — the Flutter release toolkit you've been missing

> Auto version bump + one-command multi-platform packaging. One `git commit` bumps the version; one command builds Windows / Android / macOS / Linux / iOS.

## The pain

If you ship Flutter apps, you know the drill:

1. **Version bumps by hand.** Edit `pubspec.yaml`'s `version:` every release. Forget → bad history. Mistype → worse.
2. **Every platform has its own flow.** Windows needs a ps1 script, Android needs signing keystores, iOS needs Xcode + certs, macOS needs a DMG, Linux needs packaging — five different scripts scattered around your repo.
3. **Icons, five times over.** One logo has to become Android mipmaps, iOS/macOS AppIcons, a Windows .ico, a Linux window icon.

## What release-kit does

A Dart CLI package (published on pub.dev). Three things, done well:

```bash
# 1. install
dart pub global activate release_kit

# 2. into your Flutter project, one-step setup (config + git hook)
cd /path/to/myapp
release-kit init

# 3. build & package
release-kit publish android
```

### ① Auto version bump on `git commit`

The init step installs a pre-commit hook. Every commit then:

- **Auto-bumps** based on the diff: deleted source → **major**, new source / big changes → **minor**, anything else → **patch**
- **Increments the build number** (`+N`) every time
- Release-lock? `git commit --no-verify`

### ② One flat config drives all platforms

A single `release-kit.yaml` in your project root, shared by every platform:

```yaml
app.name: myapp
app.bundleId: com.example.myapp
app.logo: assets/logo.png          # one source image → all platform icons
build.dartDefine.SERVER_URL: https://api.example.com
output.dir: dist
```

### ③ One command, five platforms

```bash
release-kit publish windows    # → dist/xxx-win64.zip
release-kit publish android    # → dist/xxx-android.apk / .aab
release-kit publish ios        # → dist/xxx-ios.ipa
release-kit publish macos      # → dist/xxx-macos.dmg
release-kit publish linux      # → dist/xxx-linux-x64.tar.gz / .deb / .rpm / .AppImage
```

Real-world publishing needs are covered: `--obfuscate` (Dart obfuscation),
`--skip-build` (reuse artifacts), Windows hardening/rename, Linux deb/rpm/AppImage,
iOS `--export-method` / `--no-codesign`, and more.

### ④ Auto launcher icons

Set `app.logo` and every publish regenerates all platform icons from that one
source image: Android mipmaps, iOS/macOS AppIcons, Windows .ico, Linux window icon.

## Who is this for

- Solo devs who want to stop doing release chores by hand
- Small teams that want a unified release flow (no more "who bumped the version?")
- CI pipelines (pair `--skip-build` / `--no-icons` with your runner)

## Quick start

```bash
dart pub global activate release_kit
cd /path/to/myapp
release-kit init
release-kit publish android
```

## Links

- pub.dev: https://pub.dev/packages/release_kit
- GitHub: https://github.com/jonahzheng/release-kit
- Full usage guide: https://github.com/jonahzheng/release-kit/blob/master/docs/GUIDE.md

---

*release-kit is open source (MIT). Try it, open an issue, or send a PR.*
