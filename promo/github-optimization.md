# release-kit GitHub 仓库优化清单

> 这些设置大部分需要在 github.com 网页上手动操作（本仓库无法通过提交代码完成），
> 这里整理成清单方便照做。仓库内能提交的部分（社交卡片、topic 提示）也已包含。

## 1. About 侧边栏（Repo → About → ⚙️）

- **Description**: `Flutter release toolkit — auto version bump + one-command multi-platform packaging.`
- **Website**: `https://pub.dev/packages/release_kit`
- **Topics**（建议全部打上，提升搜索/推荐曝光）:
  ```
  flutter  dart  release  packaging  cli  devtools
  flutter-plugin  flutter-tools  ci-cd  version-bump
  android  ios  macos  windows  linux
  ```

## 2. GitHub Releases（Tag 页面 → Create release）

按 semver 打 tag 并发布 Release，每个平台都要：
1. 打 tag：
   ```bash
   git tag v0.1.6 && git push origin v0.1.6
   ```
2. GitHub Releases → **Create a new release** → 选 tag `v0.1.6`
3. Title：`release-kit 0.1.6`
4. Body：粘贴 `CHANGELOG.md` 对应版本内容（或下面的精简版）：

```markdown
### v0.1.6

**release-kit** — Flutter 发布工具库：git commit 自动递增版本，一份 `release-kit.yaml`
驱动所有平台，一条命令打包 Windows / Android / macOS / Linux / iOS。

- ✅ 全平台发布：windows(ps1) / android / ios / macos / linux
- ✅ Linux 完整实现：`--obfuscate` / `--deb` / `--rpm` / `--appimage`
- ✅ 图标自动生成：一张 `app.logo` → 各平台启动图标（含 Linux）
- ✅ 安装：`dart pub global activate release_kit`

More: https://pub.dev/packages/release_kit
Docs: https://github.com/jonahzheng/release-kit/blob/master/docs/GUIDE.md
```

## 3. 社交预览卡片（Social preview）

GitHub 在分享链接时自动展示 1280×640 的预览图。README 顶部目前只有徽章，
建议放一张效果图。方案（二选一）：

- **方案 A（推荐，零依赖）**：用任意截图工具把 `release-kit publish` 的运行输出
  截成 1280×640 PNG，命名 `docs/social-preview.png`，放到仓库后：
  Settings → Social preview → Upload
- **方案 B**：用 [socialify](https://socialify.git.ci/jonahzheng/release-kit/png)
  一键生成，下载后上传。

## 4. 固定功能开关

- Settings → Features → 打开 **Discussions**（社区提问/反馈，比 issue 友好）
- 打开 **Wiki**（如需要文档扩展）

## 5. 首页 README 已含内容（无需再动）

- pub.dev 徽章 + 链接 ✅
- 快速开始（pub.dev 安装 + git clone）✅
- 命令表 + 各平台参数表 ✅
- 指向 GUIDE 的详细文档入口 ✅
