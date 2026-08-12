# release-kit

**[English](README.md) | [简体中文](README.zh.md)**

Flutter 发布工具库：**版本号自动管理** + **多平台打包**，统一配置入口，可复用给任意 Flutter 项目。

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

- 配置放在**你的项目**里（`release-kit.yaml`），`init` 后编辑即可。
- `git commit` 自动递增 `pubspec.yaml`（`--no-verify` 跳过）。
- 产物输出到 `dist/<app>-<version>-<platform>`。

Windows？用 `release-kit.ps1` 代替 `release-kit.sh`：

```powershell
.\tools\release-kit\release-kit.ps1 init
.\tools\release-kit\release-kit.ps1 publish windows -Obfuscate
```

### 命令一览

| 命令 | 说明 |
|---|---|
| `release-kit init` | 生成 `release-kit.yaml` 模板 + 安装 hook（一步完成） |
| `release-kit publish <platform>` | 打包（windows / android / macos / linux / ios） |

两个命令默认作用于当前目录。加 `-p <项目根>`（参数任意位置）可从任意目录指向其他项目：

```bash
release-kit init -p /path/to/myapp
release-kit publish android -Obfuscate -p /path/to/myapp
```

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

## License

MIT
