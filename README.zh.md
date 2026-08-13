<h1 align="center">release-kit</h1>

<h3 align="center">Flutter 发布工具库 — 版本号自动管理 + 多平台打包，统一配置入口，可复用给任意 Flutter 项目。</h3>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-2DBCF2.svg?logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Platform-Windows%20Android%20macOS%20Linux%20iOS-blue.svg" alt="Platform">
  <img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License">
</p>

<p align="center">
  <a href="README.md">English</a> | <strong>简体中文</strong>
</p>

<p align="center">
  <a href="https://github.com/sponsors/jonahzheng">
    <img src="https://img.shields.io/badge/%E2%9D%A4%EF%B8%8F%20Sponsor%20me%20on%20GitHub-EA4AAA?style=for-the-badge&logo=github&logoColor=white" alt="Sponsor me on GitHub">
  </a>
</p>

---

> **release-kit** 是一个 Flutter 发布工具库：`git commit` 自动递增版本，一份扁平 `release-kit.yaml` 驱动所有平台，一条命令打包 Windows / Android / macOS / Linux / iOS。

---

## 特性

- **版本自动递增** — `git commit` 自动递增 `pubspec.yaml`（智能判定 major/minor/patch + build）
- **一份扁平配置** — `release-kit.yaml` 供所有平台脚本共用
- **一条命令打包** — Windows / Android / macOS / Linux / iOS
- **自动生成图标** — 配置 `app.logo` 一张源图，自动生成各平台启动图标

---

## 快速开始

```bash
git clone <release-kit-repo> tools/release-kit   # 1. 获取工具
cd /path/to/myapp                                 # 2. 你的 Flutter 项目

tools/release-kit/release-kit.sh init             # 3. 一键初始化：配置 + hook
tools/release-kit/release-kit.sh publish android  # 4. 一条命令打包
```

Windows？用 `release-kit.ps1` 代替 `release-kit.sh`：

```powershell
.\tools\release-kit\release-kit.ps1 init
.\tools\release-kit\release-kit.ps1 publish windows -Obfuscate
```

`init` 后编辑项目里的 `release-kit.yaml`。然后：

- `git commit` 自动递增 `pubspec.yaml`（`--no-verify` 跳过）
- 产物输出到 `dist/<app>-<version>-<platform>`

---

## 命令一览

| 命令 | 说明 |
|---|---|
| `release-kit init` | 生成 `release-kit.yaml` 模板 + 安装 hook（一步完成） |
| `release-kit publish <platform>` | 打包（windows / android / macos / linux / ios） |

命令默认作用于当前目录。加 `-p <项目根>`（参数任意位置）可从任意目录指向其他项目：

```bash
release-kit init -p /path/to/myapp
release-kit publish android --obfuscate -p /path/to/myapp
```

---

## 版本号管理

### 递增规则

| 代码变更特征 | 递增 | 示例 |
|:---|:---:|:---:|
| 删除源码文件 | major | `1.0.0 → 2.0.0` |
| 新增源码文件，或源码新增行数 ≥ 40 | minor | `1.0.0 → 1.1.0` |
| 其他（小改动、文档、配置） | patch | `1.1.0 → 1.1.1` |

build 号（`+N`）每次提交 +1。

### 跳过递增

`git commit --no-verify`（发布锁定版本）。

### 手动递增

```bash
dart run bin/bump_version.dart                # 智能递增 + build+1
dart run bin/bump_version.dart --build-only   # 仅 build+1（发布锁定）
```

---

## 统一配置

`release-kit init` 会把 `release-kit.yaml` 模板复制到项目内。扁平 `key: value`（点号命名空间、`#` 注释），所有打包脚本读取同一份：

| 键 | 说明 |
|---|---|
| `app.name` | 应用名（产物命名） |
| `app.bundleId` | Android 包名 / iOS bundle id |
| `app.logo` | 启动图标源图（可选） |
| `build.dartDefine.*` | `--dart-define` 注入项 |
| `output.dir` | 产物输出目录（默认 `dist`） |
| `hardening.enabled` | Windows 加固改名开关（默认 false） |
| `hardening.engineDll` | 引擎 DLL 新名 |
| `hardening.assetDir` | 资源目录新名 |
| `android.keystore` | keystore 路径 |
| `android.keyAlias` | keystore 别名 |

密钥密码走环境变量，不入库：`ANDROID_KEY_PASSWORD` / `ANDROID_STORE_PASSWORD`。

### 启动图标自动生成

配置 `app.logo`（一张源图，建议 ≥1024×1024 PNG）：

```yaml
app.logo: assets/logo.png
```

每次 `release-kit publish <platform>` 都会先基于 `flutter_launcher_icons` 自动生成该平台图标（Android mipmap、iOS/macOS appicon、Windows `.ico`）。可用 `--no-icons` 跳过。

---

## 平台参数

| 平台 | 参数 | 说明 |
|---|---|---|
| **windows** | `-Obfuscate` | Dart 混淆发布构建（符号存 `build/obfuscate_symbols`） |
| | `-SkipBuild` | 复用已有构建产物，只收集并打包 zip |
| | `-NoRename` | 即使启用也跳过加固改名 |
| | `-Harden` | 强制启用加固改名（`flutter_windows.dll → core_engine.dll` + 导入表补丁） |
| | `-CleanFlutter` | 清理产物中所有 Flutter 痕迹（资源目录 + exe 路径 + 插件 DLL），不改源码 |
| | `-SkipVerify` | 跳过打包前的 exe 启动冒烟测试（默认开启验证） |
| | `-OutputDir <路径>` | 自定义产物目录（默认 `<项目>/dist/<binary>`） |
| **android** | `--apk` / `--aab` | 只构建 APK 或只构建 AAB（默认两者都构建） |
| | `--skip-build` | 复用已有产物，只收集 |
| | `--obfuscate` | Dart 混淆发布构建（符号存 `build/obfuscate_symbols`） |
| **linux** | `--skip-build` | 复用已有产物，只打包 |
| | `--appimage` | 额外构建 AppImage（需 `linuxdeploy` 在 PATH 中） |
| **macos / ios** | `--skip-build` | 复用已有产物，只打包 |

所有参数均可与 `-p <项目根>` 组合使用。

### Android 打包说明

```bash
release-kit publish android [--apk] [--aab] [--skip-build] [--obfuscate]
```

- 默认构建并收集 **APK + AAB 两者**
- 单独给 `--apk` → 只打 APK；单独给 `--aab` → 只打 AAB；两者同给 → 都打
- `--skip-build` → 复用已有 Gradle 产物，只收集
- 签名：在项目 `android/` 里配置好 keystore，密码走 `ANDROID_KEY_PASSWORD` / `ANDROID_STORE_PASSWORD`
- 产物：`dist/<app>-<version>-android.apk` 与 `.aab`（+ sha256）

> **注意：** Windows 入口（`release-kit.ps1`）下，`-Obfuscate` 对 android 同样生效（自动映射为 `--obfuscate`），两个最常用平台命令写法统一：`release-kit publish android -Obfuscate`。其他 shell 平台在 Windows 上通过 Git Bash 执行。

> **注意：** **所有平台**均可加 `--no-icons` 跳过自动图标生成（例如项目 Dart SDK 暂无法解析 `flutter_launcher_icons` 时）：`release-kit publish windows --no-icons`。

---

## 目录

```
release-kit.sh / release-kit.ps1   # 统一命令行入口
bin/
  bump_version.dart       # 版本自动递增（纯 Dart）
  pre-commit.hook         # hook 模板
scripts/
  generate_icons.sh/.ps1  # 自动生成启动图标（app.logo）
  install_hook.ps1/.sh    # 一键安装 hook
  common.sh               # 共享逻辑
  publish_windows.ps1     # Windows 打包
  publish_android.sh      # Android 打包
  publish_macos.sh        # macOS 打包
  publish_linux.sh        # Linux 打包
  publish_ios.sh          # iOS 打包
config.yaml               # 默认配置模板
docs/RELEASE.md           # 详细使用文档
README.md / README.zh.md  # English / 简体中文
```

---

## License

MIT License — 详见 [LICENSE](LICENSE)。
