# 推荐一个 Flutter 发布工具：release-kit

> 版本号自动管理 + 多平台一键打包，一次 `git commit` 自动递增版本，一条命令出 Windows / Android / macOS / Linux / iOS 全部产物。

## 痛点

做过 Flutter 发布的人应该都有同感：

1. **版本号全靠手改**。每次发版手动改 `pubspec.yaml` 的 `version`，忘了改就悲剧，改错了 Git 历史也乱。
2. **每个平台一套流程**。Windows 要 ps1、Android 要签名 keystore、iOS 要 Xcode + 证书、macOS 要 dmg、Linux 要打包 —— 每个平台一套脚本，散落在项目里。
3. **图标各平台各来一遍**。一张 logo 要手工裁成 Android mipmap、iOS AppIcon、Windows ico、macOS icns。

## release-kit 做了什么

一个 Dart CLI 包（已上 pub.dev），核心三件事：

```bash
# 1. 安装
dart pub global activate release_kit

# 2. 进你的 Flutter 项目，一键初始化（生成配置 + 安装 git hook）
cd /path/to/myapp
release-kit init

# 3. 一条命令打包
release-kit publish android
```

### ① git commit 自动递增版本

初始化时装一个 pre-commit hook，之后每次 `git commit` 自动：

- 依据本次改动自动递增：**删源码 → major，新增源码或大改动 → minor，其他 → patch**
- build 号（`+N`）每次都 +1
- 想锁定版本？`git commit --no-verify` 跳过即可

### ② 一份配置驱动所有平台

项目根放一个扁平的 `release-kit.yaml`，所有平台共用：

```yaml
app.name: myapp
app.bundleId: com.example.myapp
app.logo: assets/logo.png          # 一张源图 → 全平台图标
build.dartDefine.SERVER_URL: https://api.example.com
output.dir: dist
```

### ③ 一条命令打包五个平台

```bash
release-kit publish windows    # → dist/xxx-win64.zip
release-kit publish android    # → dist/xxx-android.apk / .aab
release-kit publish ios        # → dist/xxx-ios.ipa
release-kit publish macos      # → dist/xxx-macos.dmg
release-kit publish linux      # → dist/xxx-linux-x64.tar.gz / .deb / .rpm / .AppImage
```

支持常见发布需求：`--obfuscate`（Dart 混淆）、`--skip-build`（复用产物）、
Windows 加固改名、Linux 的 deb/rpm/AppImage、iOS 的 `--export-method` / `--no-codesign` 等。

### ④ 图标自动生成

配置 `app.logo` 后，每次 publish 自动用一张源图生成各平台启动图标：
Android mipmap、iOS/macOS AppIcon、Windows ico、Linux 窗口图标。

## 适合谁

- 个人项目想省去发布重复劳动
- 小团队想统一发布流程、版本号不再靠自觉
- 需要 CI 出包的场景（`--skip-build` / `--no-icons` 配合流水线）

## 快速上手

```bash
dart pub global activate release_kit
cd /path/to/myapp
release-kit init
release-kit publish android
```

## 链接

- pub.dev：https://pub.dev/packages/release_kit
- GitHub：https://github.com/jonahzheng/release-kit
- 完整使用文档：https://github.com/jonahzheng/release-kit/blob/master/docs/GUIDE.md

---

*release-kit 是开源项目（MIT License），欢迎试用、提 issue 或 PR。*
