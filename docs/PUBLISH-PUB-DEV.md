# 需求文档：release-kit 发布到 pub.dev（Dart CLI 包）

> 状态：已确认待实施
> 日期：2026-08-13

## 背景

release-kit 目前是"git clone 即用"的工具库（shell + PowerShell 脚本 + Dart 脚本）。目标是将它改造为**合法的 Dart CLI 包**，可通过 `dart pub publish` 发布到 pub.dev，用户用 `dart pub global activate release_kit` 安装后执行 `release_kit init / publish`。

pub.dev 上已有同类工具先例（publish / flutter_release_x / flutter_release 等），均为纯 Dart CLI。

## 已确认的决策

1. **包名**：`release_kit`（若在 pub.dev 被占用则改 `release_kit_cli`）
2. **实现策略**：核心逻辑保留在现有 ps1/sh 脚本，Dart 只做**调度 + init + bump**
3. **发布范围**：先本地 dry-run + 全局激活验证，确认无误后再真正发布到 pub.dev

## 目标目录结构

```
release-kit/
  pubspec.yaml              # 新增：包清单
  CHANGELOG.md              # 新增（pub.dev 要求）
  lib/
    release_kit.dart        # 公共 API
    src/
      cli.dart              # 命令解析 + 分发（init/publish/bump）
      locate.dart           # 通过 package: URI 定位 lib/assets 资源
      process.dart          # Process.run 调用脚本
    assets/                 # ← 从根目录 git mv 移入
      scripts/              #    publish_*.sh/.ps1, install_hook.*, generate_icons.*, common.sh
      config.yaml           #    默认配置模板
      pre-commit.hook       #    hook 模板
  bin/
    release_kit.dart        # CLI 入口（pub global 命令名 = release_kit）
    bump_version.dart       # 保留（被 CLI 调用）
  release-kit.sh / .ps1     # 保留（git 方式入口，与 pub CLI 共存）
  README.md / README.zh.md / docs/ / LICENSE  # 保留
  .pubignore                # 新增（排除 README.zh.md、docs/ 等）
```

## pubspec.yaml 要点

```yaml
name: release_kit
description: Flutter release toolkit - auto version bump + multi-platform packaging with a unified config.
version: 0.1.0
homepage: https://github.com/jonahzheng/release-kit
repository: https://github.com/jonahzheng/release-kit
environment:
  sdk: '>=3.0.0 <4.0.0'
dependencies:
  args: ^2.4.0
executables:
  release_kit: release_kit
```

## CLI 行为（与现有 release-kit.sh/.ps1 保持一致）

```
release_kit init [-p <project-root>]                    # 复制 config 模板 + 安装 hook
release_kit publish <platform> [flags] [-p <project-root>]  # 调用 scripts/publish_*.sh|.ps1
release_kit bump [--build-only]                         # 调用 bin/bump_version.dart
```

- `-p` 支持任意位置（移植现有提取逻辑）
- 平台参数透传；Windows 显式传 `-Obfuscate:$true` 等开关，避免 `-Obfuscate` 误绑 `-OutputDir`
- 支持 `--no-icons`（跳过图标生成）

## 关键技术点

- **资源定位**：`package:` URI 只能解析 `lib/` 下的文件 → scripts/config/hook 必须移入 `lib/assets/`。Dart 用 `Isolate.resolvePackageUri('package:release_kit/assets/...')` 定位绝对路径，`dart pub global activate` 后依然可靠。
- **脚本自定位**：现有脚本内部用 `dirname $0` / `$PSScriptRoot` 定位自身，移入 lib/assets 后不受影响。
- **init 逻辑 Dart 化**：读 `lib/assets/config.yaml` 模板 → 复制到项目 → 从 `lib/assets/pre-commit.hook` 生成 `.githooks/pre-commit`（替换占位符）→ `git config core.hooksPath`。
- **bump**：`Process.run('dart', ['bin/bump_version.dart', ...])`。

## 验证步骤

1. `dart analyze` 全绿
2. `dart pub publish --dry-run`：确认文件清单含 `lib/assets/scripts/*`、无多余文件；检查包名 `release_kit` 是否被占用
3. `dart pub global activate --source path .` → `release_kit init` / `publish windows -CleanFlutter` 对 Readu 项目完整回归
4. 验证 hook 安装、图标跳过、exe 冒烟测试等与现状一致
5. 全部通过后，再决定是否 `dart pub publish` 真发布

## 文档更新

- README 增加"通过 pub.dev 安装"用法：`dart pub global activate release_kit` → `release_kit init`
- 保留现有 git clone 用法

## 风险与权衡

- **包名冲突**：`release_kit` 可能被占用，需 dry-run 确认，必要时改名。
- **目录移动**：`git mv scripts/` 等保留 git 历史。
- **非 Dart 脚本随包分发**：pub 会发布包根下所有非隐藏文件（含 lib/assets），符合要求。
- **Windows 脚本调用**：ps1 需 powershell；sh 需 git-bash/WSL（与现状一致）。
