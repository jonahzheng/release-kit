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

> **release-kit** — pub.dev 上的 Dart CLI 工具包：`git commit` 自动递增版本，一份 `release-kit.yaml` 驱动所有平台，一条命令打包 Windows / Android / macOS / Linux / iOS。

> 完整使用手册：[docs/GUIDE.zh.md](docs/GUIDE.zh.md)

---

## 特性

- **版本自动递增** — `git commit` 自动递增 `pubspec.yaml`
- **一份扁平配置** — `release-kit.yaml` 供所有平台共用
- **一条命令打包** — Windows / Android / macOS / Linux / iOS
- **自动生成图标** — 一张 `app.logo` 源图 → 各平台图标

---

## 快速开始

```bash
# 1. 安装（pub.dev 的 Dart CLI）
dart pub global activate release_kit

# 2. 你的 Flutter 项目
cd /path/to/myapp

# 3. 一键初始化：配置 + hook
release-kit init

# 4. 一条命令打包
release-kit publish android
```

备选 — git clone 方式（把工具随仓库携带）：

```bash
git clone <release-kit-repo> tools/release-kit
tools/release-kit/release-kit.sh init
tools/release-kit/release-kit.sh publish android
```

Windows？用 `release-kit.ps1` 代替 `release-kit.sh`：

```powershell
.\tools\release-kit\release-kit.ps1 init
.\tools\release-kit\release-kit.ps1 publish windows -Obfuscate
```

---

## 命令

| 命令 | 说明 |
|---|---|
| `release-kit init` | 生成 `release-kit.yaml` 模板 + 安装 hook |
| `release-kit publish <platform>` | 打包（windows / android / macos / linux / ios） |

加 `-p <项目根>`（参数任意位置）可从任意目录指向其他项目：

```bash
release-kit publish android --obfuscate -p /path/to/myapp
```

### 常用参数

| 平台 | 参数 |
|---|---|
| windows | `-Obfuscate` `-SkipBuild` `-Harden` `-CleanFlutter` `-SkipVerify` `-OutputDir` |
| android | `--apk` / `--aab` `--skip-build` `--obfuscate` |
| linux | `--skip-build` `--appimage` |
| ios | `--skip-build` `--obfuscate` `--export-method` `--no-codesign` |
| macos | `--skip-build` `--obfuscate` `--no-codesign` |

> Windows 入口下，`-Obfuscate` 对 android 同样生效（自动映射为 `--obfuscate`）。所有平台均可加 `--no-icons`。

---

## License

MIT License — 详见 [LICENSE](LICENSE)。
