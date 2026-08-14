# release-kit 社区推广文案模板

> 各渠道的文案草稿。发布前把标题/正文按渠道再微调，链接统一为：
> - pub.dev: https://pub.dev/packages/release_kit
> - GitHub: https://github.com/jonahzheng/release-kit

---

## 1. V2EX（技术向，中文）

标题：
> Flutter 发布太繁琐？开源了个工具：版本号 git commit 自动递增 + 一条命令打五个平台

正文：

```text
做了个 Flutter 发布工具，已发布到 pub.dev，开源 MIT。

解决三个痛点：
1. 版本号不用手改了 —— 装个 pre-commit hook，git commit 自动递增（删源码→major，新增→minor，其他→patch，build 号每次 +1）
2. 一份 release-kit.yaml 驱动所有平台
3. 一条命令打包 Windows / Android / macOS / Linux / iOS

```bash
dart pub global activate release_kit
cd /path/to/myapp
release-kit init
release-kit publish android
```

支持 --obfuscate、--skip-build、Windows 加固改名、Linux deb/rpm/AppImage、
iOS --export-method / --no-codesign，一张 app.logo 自动生成全平台图标。

pub.dev: https://pub.dev/packages/release_kit
GitHub: https://github.com/jonahzheng/release-kit

欢迎试用，有建议或 bug 直接提 issue。
```

---

## 2. Hacker News（Show HN，英文）

标题：
> Show HN: release-kit – auto version bump + one-command Flutter builds for Windows/Android/macOS/Linux/iOS

正文：

```text
I got tired of doing Flutter releases by hand, so I built a small Dart CLI.

Three things it fixes:
- Version bumping: a pre-commit hook bumps pubspec.yaml automatically
  (deleted source → major, new/changed source → minor, else patch; build number always +1).
- One flat release-kit.yaml drives every platform.
- `release-kit publish <platform>` builds & packages any of the 5 platforms.

```bash
dart pub global activate release_kit
cd myapp
release-kit init
release-kit publish linux
```

Covers the real-world stuff: --obfuscate, --skip-build, Windows hardening rename,
Linux tar.gz/deb/rpm/AppImage, iOS --export-method / --no-codesign, and auto icon
generation from a single source image.

MIT, published on pub.dev:
https://pub.dev/packages/release_kit
https://github.com/jonahzheng/release-kit

Happy to answer questions / take feedback.
```

> HN 注意事项：建议标题直接点明"帮你省时间"，并主动回复评论。发布时段选美东工作日 9-11 点效果较好。

---

## 3. Reddit（r/FlutterDev）

标题：
> [Tool] release-kit – version bump on git commit + one command builds for all 5 Flutter platforms

正文：

```text
Hi r/FlutterDev 👋

I built a small open-source Dart CLI to kill the release chore:

1. Auto version bump — install a pre-commit hook; every commit bumps pubspec.yaml
   (major/minor/patch heuristics + build number). Lock versions with --no-verify.
2. One flat release-kit.yaml drives Windows/Android/macOS/Linux/iOS.
3. One command packages everything:

   dart pub global activate release_kit
   cd myapp && release-kit init
   release-kit publish ios

Also: --obfuscate, --skip-build, Windows hardening, Linux deb/rpm/AppImage,
iOS export-method/no-codesign, auto launcher icons from one logo.

pub.dev: https://pub.dev/packages/release_kit
GitHub: https://github.com/jonahzheng/release-kit

MIT, looking for feedback & PRs.
```

---

## 4. Twitter / X（短推，英文）

推文 1（介绍）：
```text
Flutter releases are a chore. I built release-kit to end it:

• git commit auto-bumps your version (no more manual pubspec edits)
• one release-kit.yaml drives all platforms
• one command builds Windows/Android/macOS/Linux/iOS

Free & MIT → https://pub.dev/packages/release_kit

#Flutter #Dart #DevTools
```

推文 2（配 GIF/截图）：
```text
One logo → every platform icon. One config → every platform. One command → five builds.

release-kit:
https://pub.dev/packages/release_kit
https://github.com/jonahzheng/release-kit

#Flutter #FlutterDev
```

推文 3（干货向）：
```text
Auto version bump on git commit = one less thing to forget.

release-kit installs a pre-commit hook that bumps pubspec.yaml (major/minor/patch
by diff + build number). Lock it with --no-verify when you want.

https://pub.dev/packages/release_kit #Flutter
```

---

## 5. 微信群 / 朋友圈（中文，简短）

```text
开源了个 Flutter 发布工具 release-kit 🚀

- git commit 自动递增版本号，不用再手改 pubspec
- 一份配置驱动所有平台
- 一条命令打包 Windows / Android / macOS / Linux / iOS
- 一张 logo 自动生成全平台图标

```bash
dart pub global activate release_kit
cd myapp && release-kit init
release-kit publish android
```

MIT 开源，欢迎试用：https://pub.dev/packages/release_kit
GitHub：https://github.com/jonahzheng/release-kit
```

---

## 6. 掘金 / CSDN（中文，长文）

直接用 `promo/announcement.zh.md` 的内容发布；发布时注意：
- 掘金建议选「前端」分类，标题可带「Flutter」关键词
- 文首放一张效果图（`docs/social-preview.png`）
- 文末附 GitHub + pub.dev 链接

## 7. LinkedIn（英文，职业向）

```text
Sharing a small open-source project I've been working on: release-kit.

It automates the tedious parts of Flutter releases:
1. Version bumping on git commit (via a pre-commit hook)
2. A single release-kit.yaml config for all platforms
3. One-command packaging for Windows, Android, macOS, Linux, and iOS

If your team ships Flutter apps and wants to spend less time on release chore,
give it a spin:

https://pub.dev/packages/release_kit
https://github.com/jonahzheng/release-kit

MIT licensed — feedback and contributions welcome.
```

---

## 发布节奏建议

| 时间 | 动作 |
|---|---|
| Day 1 | GitHub Release + 仓库优化（topics/about/社交卡片）+ 朋友圈/微信群 |
| Day 2 | 掘金 / CSDN 中文长文（可配合效果图） |
| Day 3-4 | V2EX 帖子（中文）+ 回复互动 |
| Day 5 | HN Show HN + r/FlutterDev + Twitter（英文，配 GIF） |
| 滚动 | 收集反馈 → 修 issue → 提版本 → 顺手再发一帖 |
