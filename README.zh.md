# release-kit

**[English](README.md) | [简体中文](README.zh.md)**

Flutter 发布工具库：**版本号自动管理** + **多平台打包**，统一配置入口，可复用给任意 Flutter 项目。

## 特性

- `git commit` 自动递增版本（智能判定 major/minor/patch + build）
- 一份扁平配置（`release-kit.yaml`）供所有平台脚本共用
- 一条命令打包 Windows / Android / macOS / Linux / iOS
- 配置 `app.logo` 一张源图，自动生成各平台启动图标

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

## 平台参数

| 平台 | 参数 | 说明 |
|---|---|---|
| windows | `-Obfuscate` | Dart 混淆发布构建（符号存 `build/obfuscate_symbols`） |
| | `-SkipBuild` | 复用已有构建产物，只收集并打包 zip |
| | `-NoRename` | 即使启用也跳过加固改名 |
| | `-Harden` | 强制启用加固改名（`flutter_windows.dll → core_engine.dll` + 导入表补丁） |
| | `-CleanFlutter` | 清理产物中所有 Flutter 痕迹（资源目录 + exe 路径 + 插件 DLL），不改源码 |
| | `-SkipVerify` | 跳过打包前的 exe 启动冒烟测试（默认开启验证） |
| | `-OutputDir <路径>` | 自定义产物目录（默认 `<项目>/dist/<binary>`） |
| android | `--apk` / `--aab` | 只构建 APK 或只构建 AAB（默认两者都构建） |
| | `--skip-build` | 复用已有产物，只收集 |
| | `--obfuscate` | Dart 混淆发布构建（符号存 `build/obfuscate_symbols`） |
| linux | `--skip-build` | 复用已有产物，只打包 |
| | `--appimage` | 额外构建 AppImage（需 `linuxdeploy` 在 PATH 中） |
| macos / ios | `--skip-build` | 复用已有产物，只打包 |

所有参数均可与 `-p <项目根>` 组合使用。

> Windows 入口（`release-kit.ps1`）下，`-Obfuscate` 对 android 同样生效（自动映射为 `--obfuscate`），两个最常用平台命令写法统一：`release-kit publish android -Obfuscate`。其他 shell 平台在 Windows 上通过 Git Bash 执行。

> **所有平台**均可加 `--no-icons` 跳过自动图标生成（例如项目 Dart SDK 暂无法解析 `flutter_launcher_icons` 时）：`release-kit publish windows --no-icons`。

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
docs/RELEASE.md           # 使用文档
README.md / README.zh.md  # English / 简体中文
```

## 支持

觉得有用？在 GitHub 上赞助我吧：

[![Sponsor](https://img.shields.io/badge/Sponsor-%E2%9D%A4-GitHub?logo=github&style=for-the-badge&color=ea4aaa)](https://github.com/sponsors/jonahzheng)

## License

MIT
