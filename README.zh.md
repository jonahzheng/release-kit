# release-kit

Flutter 发布工具库：**版本号自动管理** + **多平台打包**，统一配置入口，可复用给任意 Flutter 项目。

> 独立自 ZShell（ZShell 保持自身现状不动）。Windows + Android 首发，macOS / Linux / iOS 为骨架。

## 特性

- **版本号自动递增**（`bin/bump_version.dart` + pre-commit hook）
  - 分析暂存代码变更智能判定：删源码→major、新增/大改→minor、小改→patch、build +1
  - 支持单仓库（`app/` 子目录）与独立项目（根目录）两种结构
  - `git commit --no-verify` 跳过递增（发布锁定）
- **统一配置**：单一 `config.yaml`，Windows/Android/Linux/macOS/iOS 脚本共用
- **多平台打包**：`scripts/publish_*.sh` / `publish_windows.ps1`
  - Windows：zip + 可选加固改名（引擎 DLL 改名 + 导入表补丁）
  - Android：APK + AAB
  - macOS / iOS / Linux：骨架脚本

## 快速开始

### 1. 复制 release-kit 到你的环境

```bash
# 假设你的 Flutter 项目在 /path/to/myapp
git clone <release-kit-repo> /path/to/release-kit
cd /path/to/myapp
```

### 2. 配置

编辑 `release-kit/config.yaml`，设置应用名、图标、bundle id、服务器地址等。

### 3. 安装版本自动递增 hook

```bash
# Windows
powershell -ExecutionPolicy Bypass -File release-kit/scripts/install_hook.ps1 -ProjectRoot .

# macOS / Linux
./release-kit/scripts/install_hook.sh -p .
```

之后每次 `git commit` 自动递增 `pubspec.yaml` 版本。

### 4. 打包

```bash
# Windows（从 Flutter 项目根运行）
powershell -ExecutionPolicy Bypass -File release-kit/scripts/publish_windows.ps1 -Obfuscate

# Android
./release-kit/scripts/publish_android.sh
```

产物输出到 `dist/<app>-<version>-<platform>`。

## 目录

```
bin/
  bump_version.dart       # 版本自动递增（纯 Dart）
  pre-commit.hook         # hook 模板
scripts/
  install_hook.ps1/.sh    # 一键安装 hook
  common.sh               # 共享逻辑
  publish_windows.ps1     # Windows 打包
  publish_android.sh      # Android 打包
  publish_macos.sh        # macOS 骨架
  publish_linux.sh        # Linux 骨架
  publish_ios.sh          # iOS 骨架
config.yaml               # 统一配置
docs/RELEASE.md           # 使用文档
```

## License

MIT
