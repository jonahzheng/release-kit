# release-kit 使用文档

## 〇、统一入口

所有操作通过 `release-kit.sh`（macOS/Linux）或 `release-kit.ps1`（Windows）完成：

```bash
release-kit init                       # 一键初始化（生成配置 + 安装 hook）
release-kit install                    # 仅安装 hook
release-kit publish <platform> [args]  # 打包（可加 -p <项目根> 从任意目录运行）
release-kit bump [--build-only]        # 手动递增版本
```

配置文件放在**项目内**，解析优先级：

1. `<项目>/release-kit.yaml`（推荐，随项目入库）
2. `<项目>/config.yaml`
3. 工具默认 `config.yaml`

所有命令默认作用于当前目录。用 `-p <项目根>` 可从任意目录指向其他项目：

```bash
# 在任意目录直接打包另一个项目
release-kit publish android -p /path/to/myapp
release-kit publish windows -Obfuscate -p /path/to/myapp
```

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
release-kit bump                # 智能递增 + build+1
release-kit bump --build-only   # 仅 build+1（发布锁定）
```

### hook 安装

```bash
release-kit install
# 或 init（生成配置 + 安装 hook，一步完成）
```

效果：`git config core.hooksPath` 指向项目 `.githooks`，每次 `git commit` 自动递增并 stage。

跳过递增（发布锁定版本）：`git commit --no-verify`。

## 二、统一配置

配置放在项目内：`<项目>/release-kit.yaml`（由 `release-kit init` 从工具模板复制而来）。

扁平 `key: value`，点号命名空间，`#` 注释。所有打包脚本读取同一份。

| 键 | 说明 |
|---|---|
| `app.name` | 应用名（zip/产物命名） |
| `app.displayName` | 显示名 |
| `app.version` | 版本（由 bump_version 维护） |
| `app.icon` | 图标路径 |
| `app.bundleId` | Android 包名 / iOS bundle id |
| `build.dartDefine.*` | `--dart-define` 注入项 |
| `output.dir` | 产物输出目录（默认 `dist`） |
| `hardening.enabled` | Windows 加固改名开关（默认 false） |
| `hardening.engineDll` | 引擎 DLL 新名 |
| `hardening.assetDir` | 资源目录新名 |
| `android.keystore` | keystore 路径 |
| `android.keyAlias` | keystore 别名 |

密钥密码走环境变量，不入库：`ANDROID_KEY_PASSWORD` / `ANDROID_STORE_PASSWORD`。

## 三、打包

### Windows

```bash
release-kit publish windows [-Obfuscate] [-SkipBuild] [-NoRename]
```

- `-Obfuscate`：Dart 混淆构建（符号存 `build/obfuscate_symbols`）
- 产物：`dist/<app>-<version>-win64.zip` + sha256
- 加固改名（`hardening.enabled=true` 时）：`flutter_windows.dll → core_engine.dll`、`data/flutter_assets → data/resources`，自动补丁 EXE/插件 DLL 导入表

### Android

```bash
release-kit publish android [--apk] [--aab] [--skip-build]
```

- 默认构建 APK + AAB
- 产物：`dist/<app>-<version>-android.apk / .aab` + sha256
- 签名需在项目 `android/` 配置好 keystore（密码走环境变量）

### macOS / iOS / Linux（骨架）

脚本含配置读取 + `flutter build` 命令 + 产物路径，但**尚未在对应环境验证**，需按需完善：

- macOS：`.app` → dmg（`hdiutil`）
- iOS：`flutter build ipa` → `.ipa`（需 Xcode 签名）
- Linux：bundle → tar.gz / AppImage

## 四、常见问题

| 现象 | 原因 | 解决 |
|---|---|---|
| hook 报 `version: line not found` | pubspec 无 `version:` 行 | 在 pubspec 添加 `version: 0.1.0+1` |
| hook 不生效 | `core.hooksPath` 未配置 | 重跑 `release-kit install` |
| Windows 打包 DLL_NOT_FOUND | 加固改名后导入表未补丁 | 用最新脚本重跑（自动补丁） |
| Android 打包签名失败 | keystore 密码未传 | 设置 `ANDROID_KEY_PASSWORD` 等环境变量 |
