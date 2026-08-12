# release-kit

Flutter 发布工具库：**版本号自动管理** + **多平台打包**，统一配置入口，可复用给任意 Flutter 项目。

> 独立自 ZShell（ZShell 保持自身现状不动）。Windows + Android 首发，macOS / Linux / iOS 为骨架。

## 特性

- **版本号自动递增**（`bin/bump_version.dart` + pre-commit hook）
  - 分析暂存代码变更智能判定：删源码→major、新增/大改→minor、小改→patch、build +1
  - 支持单仓库（`app/` 子目录）与独立项目（根目录）两种结构
  - `git commit --no-verify` 跳过递增（发布锁定）
- **统一配置**：一份扁平配置，Windows/Android/Linux/macOS/iOS 脚本共用
  - 解析优先级：`<项目>/release-kit.yaml` → `<项目>/config.yaml` → 工具默认
- **多平台打包**：`scripts/publish_*.sh` / `publish_windows.ps1`
  - Windows：zip + 可选加固改名（引擎 DLL 改名 + 导入表补丁）
  - Android：APK + AAB
  - macOS / iOS / Linux：骨架脚本

## 快速开始

```bash
# 1. 复制 release-kit 到你的环境
git clone <release-kit-repo> tools/release-kit
cd /path/to/myapp

# 2. 一键初始化：生成配置模板（release-kit.yaml）+ 安装 hook
./tools/release-kit/release-kit.sh init

# 3. 编辑配置，匹配你的应用
#    release-kit.yaml（放在【你的项目】里，随项目版本管理）

# 4. 一条命令打包任意平台
./tools/release-kit/release-kit.sh publish windows [-Obfuscate]
./tools/release-kit/release-kit.sh publish android
```

- 配置放在**项目内**（`release-kit.yaml`），不再依赖工具目录。
- 每次 `git commit` 自动递增 `pubspec.yaml` 版本（`--no-verify` 跳过）。
- 产物输出到 `dist/<app>-<version>-<platform>`。

### Windows

```powershell
# 相同流程，PowerShell 入口：
.\tools\release-kit\release-kit.ps1 init
.\tools\release-kit\release-kit.ps1 publish windows -Obfuscate
```

### 命令一览

| 命令 | 说明 |
|---|---|
| `release-kit init` | 生成 `release-kit.yaml` 模板 + 安装 hook（一步完成） |
| `release-kit install` | 仅安装 pre-commit hook |
| `release-kit publish <platform>` | 打包（windows / android / macos / linux / ios） |
| `release-kit publish <platform> -p <项目根>` | 从任意目录打包指定项目 |
| `release-kit bump [--build-only]` | 手动递增 pubspec 版本 |

## 目录

```
release-kit.sh / release-kit.ps1   # 统一命令行入口
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
config.yaml               # 默认配置模板
docs/RELEASE.md           # 使用文档
```

## License

MIT
