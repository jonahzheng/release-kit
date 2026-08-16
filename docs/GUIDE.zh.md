# release-kit 使用文档

**[English](GUIDE.md) | [简体中文](GUIDE.zh.md)**

## 〇、安装与统一入口

两种方式任选：

```bash
# 方式 B：pub.dev 安装（Dart CLI 包）
dart pub global activate release_kit

# 方式 A：git clone 即用（把工具随仓库携带）
git clone <release-kit-repo> tools/release-kit
```

命令入口：

- 方式 B：`release-kit`（全局命令）
- 方式 A：`tools/release-kit/release-kit.sh`（macOS/Linux）或 `release-kit.ps1`（Windows）

```bash
release-kit init                       # 一键初始化（生成配置 + 安装 hook）
release-kit publish <platform> [args]  # 打包（可加 -p <项目根> 从任意目录运行）
```

配置文件放在**项目内**，解析优先级：

1. `<项目>/release-kit.yaml`（推荐，随项目入库）
2. `<项目>/config.yaml`
3. 工具默认 `lib/assets/config.yaml`

两个命令默认作用于当前目录。加 `-p <项目根>`（参数任意位置）可从任意目录指向其他项目：

```bash
# 在任意目录直接操作另一个项目
release-kit init -p /path/to/myapp
release-kit publish android -p /path/to/myapp
release-kit publish windows --obfuscate -p /path/to/myapp
```

### 通用参数（所有平台）

| 参数 | 说明 |
|---|---|
| `-p <项目根>` / `--project <项目根>` | 从任意目录指向另一个 Flutter 项目（可出现在参数任意位置）。默认作用于当前目录。 |
| `--no-icons` | 跳过启动图标重新生成。默认每次 `publish` 都会在 `app.logo` 比现有图标新时重新生成图标（通过 `generate_icons.sh`/`.ps1`）。CI 或未配置 `app.logo` 不想看到提示时用它跳过。 |

## 一、版本号管理

### 递增规则（`bin/bump_version.dart`）

| 代码变更特征 | 递增 | 示例 |
|---|---|---|
| 删除源码文件 | major | `1.0.0 → 2.0.0` |
| 新增源码文件，或源码新增行数 ≥ 40 | minor | `1.0.0 → 1.1.0` |
| 其他（小改动、文档、配置） | patch | `1.1.0 → 1.1.1` |

build 号（`+N`）每次提交 +1。

### 路径兼容

`bump_version.dart` 通过 `--pubspec <path>` 或自动探测定位 pubspec：

- 独立项目：`<root>/pubspec.yaml`
- 单仓库（如 ZShell）：`<root>/app/pubspec.yaml`
- 显式指定：`dart run bin/bump_version.dart --pubspec path/to/pubspec.yaml`

### 手动调用

```bash
release-kit bump                          # 智能递增 + build+1
release-kit bump --build-only             # 仅 build+1（发布锁定）
```

等价直接 Dart 调用（工具为 git clone 方式、非 pub.dev 安装时）：

```bash
dart run bin/bump_version.dart                # 智能递增 + build+1
dart run bin/bump_version.dart --build-only   # 仅 build+1（发布锁定）
```

### hook 安装

```bash
release-kit init
```

效果：复制 `release-kit.yaml` 模板 + `git config core.hooksPath` 指向项目 `.githooks`，每次 `git commit` 自动递增并 stage。

跳过递增（发布锁定版本）：`git commit --no-verify`。

## 二、统一配置

配置放在项目内：`<项目>/release-kit.yaml`（由 `release-kit init` 从工具模板复制而来）。

扁平 `key: value`，点号命名空间，`#` 注释。所有打包脚本读取同一份。

| 键 | 说明 |
|---|---|
| `app.name` | 应用名（zip/产物命名） |
| `app.bundleId` | Android 包名 / iOS bundle id |
| `app.logo` | 启动图标源图（可选，`publish` 时自动生成各平台 icon） |
| `build.dartDefine.*` | `--dart-define` 注入项 |
| `output.dir` | 产物输出目录（默认 `dist`） |
| `hardening.enabled` | Windows 加固改名开关（默认 false） |
| `hardening.engineDll` | 引擎 DLL 新名 |
| `hardening.assetDir` | 资源目录新名 |
| `android.keystore` | keystore 路径 |
| `android.keyAlias` | keystore 别名 |
| `linux.desktopCategories` | `.deb`/`.rpm` 桌面项分类（默认 `Utility;`） |

密钥密码走环境变量，不入库：`ANDROID_KEY_PASSWORD` / `ANDROID_STORE_PASSWORD`。

### 启动图标自动生成

在配置中设置 `app.logo`（一张源图，建议 ≥1024×1024 PNG）：

```yaml
app.logo: assets/logo.png
```

每次 `release-kit publish <platform>` 都会先调用 `lib/assets/scripts/generate_icons.sh`（Windows 用 `.ps1`），基于 `flutter_launcher_icons` 自动生成：

- Android：`android/app/src/main/res/mipmap-*/ic_launcher.png`
- iOS：`ios/Runner/Assets.xcassets/AppIcon.appiconset/`
- macOS：`macos/Runner/Assets.xcassets/AppIcon.appiconset/`
- Windows：`windows/runner/resources/app_icon.ico`
- Linux：`linux/runner/my_icon.png`（ImageMagick 缩放到 512×512，无则原样复制）

未设置 `app.logo` 时跳过；源图缺失时报错提示。首次使用会自动添加 `flutter_launcher_icons` 到 dev_dependencies。

## 三、打包

### Windows

```bash
release-kit publish windows [--obfuscate] [--skip-build] [--no-rename] [--harden] [--clean-flutter] [--skip-verify] [--output-dir <路径>]
```

| 参数 | 说明 |
|---|---|
| `--obfuscate` | Dart 混淆构建（符号存 `build/obfuscate_symbols`） |
| `--skip-build` | 复用现有 `build\windows\x64\runner\Release` 产物，只收集/打包 |
| `--no-rename` | 即使配置了 `hardening.enabled: true` 也强制关闭加固改名 |
| `--harden` | 无视配置强制开启加固改名（`flutter_windows.dll → core_engine.dll`，自动补丁 EXE/插件 DLL 导入表） |
| `--clean-flutter` | 隐含加固；额外清理产物中的 Flutter 痕迹（见下）。与 `--no-rename` 互斥（后者优先） |
| `--skip-verify` | 跳过打包前的 exe 启动冒烟测试（默认开启，构建损坏时提前告警） |
| `--output-dir <路径>` | 覆盖产物暂存/zip 输出目录 |

- 产物：`dist/<app>-<version>-win64.zip` + sha256
- 加固改名（`--harden` 或 `hardening.enabled=true` 时）：`flutter_windows.dll → core_engine.dll`，自动补丁 EXE/插件 DLL 导入表

### 清理 Flutter 痕迹（`--clean-flutter`）

```bash
release-kit publish windows --obfuscate --clean-flutter
```

纯**产物层**处理，**不改动项目源码**（`main.cpp` / CMake / `git status` 均不受影响，`flutter run` 正常）：

1. `data\flutter_assets` → `data\resources`
2. exe 内嵌的 UTF-16 `flutter_assets` 路径字符串 → `resources`（等长 NUL 填充，引擎正常加载）
3. `flutter_windows.dll` → `core_engine.dll` + 导入表补丁
4. 残留的含 `flutter` 插件 DLL（如 `flutter_tts_plugin.dll`、`isar_community_flutter_libs_plugin.dll`）改名 + 引用补丁

产物中不再出现 `flutter` 文件名，且**打包后的 exe 已验证可正常运行**。

> `--clean-flutter` 隐含启用加固改名；与 `--no-rename` 互斥（后者优先）。

### Android

```bash
release-kit publish android [--apk] [--aab] [--skip-build] [--obfuscate]
```

| 参数 | 说明 |
|---|---|
| `--apk` | 只打 APK（关闭 AAB） |
| `--aab` | 只打 AAB（关闭 APK） |
| `--skip-build` | 复用现有构建产物，只收集 |
| `--obfuscate` | Dart 混淆构建（符号存 `build/obfuscate_symbols`） |

默认同时构建 APK + AAB。
- 产物：`dist/<app>-<version>-android.apk / .aab` + sha256
- 签名需在项目 `android/` 配置好 keystore（密码走环境变量）

> 所有平台使用相同的 `--` 双横线长参数，`--obfuscate` 在 Windows、Android、macOS、Linux、iOS 写法完全一致：
> ```powershell
> release-kit publish windows --obfuscate      # Windows 混淆
> release-kit publish android --obfuscate      # Android 混淆
> ```
> 其余非 Windows 平台（macOS/Linux/iOS）在 Windows 上通过 Git Bash 执行 `.sh` 脚本。

### iOS

```bash
release-kit publish ios [--skip-build] [--obfuscate] [--export-method <method>] [--no-codesign]
```

| 参数 | 说明 |
|---|---|
| `--skip-build` | 复用现有构建产物，只收集 `.ipa` |
| `--obfuscate` | Dart 混淆构建（符号存 `build/obfuscate_symbols`） |
| `--export-method <method>` | `ad-hoc` \| `development` \| `enterprise` \| `app-store`（默认 `app-store`） |
| `--no-codesign` | 免签名构建（CI / 本地冒烟测试）；因 Flutter 免签名时不生成 `.ipa`，改收集 `.xcarchive` |

- 需 **macOS + Xcode + iOS 签名**（Apple Developer 证书/描述文件），产物为 `.ipa`（TestFlight / App Store 分发）
- 产物：`dist/<app>-<version>-ios.ipa` + sha256

### macOS

```bash
release-kit publish macos [--skip-build] [--obfuscate]
```

| 参数 | 说明 |
|---|---|
| `--skip-build` | 复用现有构建产物，只把 `.app` 打成 `.dmg` |
| `--obfuscate` | Dart 混淆构建（符号存 `build/obfuscate_symbols`） |

- 需 **macOS + Xcode**；通过 `hdiutil`（UDZO）生成拖拽安装的 `.dmg`
- 注意：正式分发需要 Developer ID 签名配置，否则 `.app` 仅本机可运行（`flutter build macos` 无 `--no-codesign`）
- 产物：`dist/<app>-<version>-macos.dmg` + sha256

### Linux

```bash
release-kit publish linux [--skip-build] [--obfuscate] [--deb] [--rpm] [--appimage]
```

| 参数 | 说明 |
|---|---|
| `--skip-build` | 复用现有构建产物，只打包 |
| `--obfuscate` | Dart 混淆构建（符号存 `build/obfuscate_symbols`） |
| `--deb` | 通过 `dpkg-deb` 打 Debian/Ubuntu 包（含桌面项 + hi-color 图标；需已安装 `dpkg-deb`） |
| `--rpm` | 通过 `rpmbuild` 打 Fedora/RHEL 包（需已安装 `rpmbuild`） |
| `--appimage` | 通过 `linuxdeploy` 打 AppImage（需安装；见 https://github.com/linuxdeploy/linuxdeploy） |

- 需 Linux 主机，Flutter Linux 桌面支持（GTK 工具链）
- 默认始终产出便携 `dist/<app>-<version>-linux-x64.tar.gz`（release bundle）
- 桌面项分类来自 `linux.desktopCategories`（默认 `Utility;`）
- 包内图标来源：`linux/runner/my_icon.png`（由 `app.logo` 自动生成）
- 产物：`dist/<app>-<version>-linux-x64.tar.gz` / `.deb` / `.rpm` + sha256

## 四、常见问题

| 现象 | 原因 | 解决 |
|---|---|---|
| hook 报 `version: line not found` | pubspec 无 `version:` 行 | 在 pubspec 添加 `version: 0.1.0+1` |
| hook 不生效 | `core.hooksPath` 未配置 | 重跑 `release-kit init` |
| Windows 打包 DLL_NOT_FOUND | 加固改名后导入表未补丁 | 用最新脚本重跑（自动补丁） |
| Android 打包签名失败 | keystore 密码未传 | 设置 `ANDROID_KEY_PASSWORD` 等环境变量 |
