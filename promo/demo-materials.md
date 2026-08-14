# release-kit 演示素材制作指南

> 目标：给宣传文章 / README / 社交分享提供一张「一张图看懂」的效果图和一段终端 GIF。
> 全程在本机完成，不需要付费工具。

## 1. 效果图（1280×640，社交卡片 + 文章头图）

推荐素材：`release-kit publish` 一次运行的真实输出。

步骤：
1. 准备一个真实 Flutter 项目（任意项目即可，甚至可加 `--skip-build` 快速出图）。
2. 终端执行（Windows PowerShell）：
   ```powershell
   .\tools\release-kit\release-kit.ps1 publish android --skip-build
   ```
   macOS/Linux：
   ```bash
   tools/release-kit/release-kit.sh publish android --skip-build
   ```
3. 终端配色建议（深色背景 + 高对比字体，如 Windows Terminal / iTerm2 默认深色）。
4. 截图保存为 `docs/social-preview.png`（1280×640）。
5. 上传：GitHub Settings → Social preview → Upload。

> 提示：脚本输出含 `==> artifact:` 与 sha256，天然适合展示。

## 2. 终端演示 GIF（文章/推文用）

工具：任何 GIF 录屏（推荐 **ScreenToGif**（Windows，免费）或 **Kap**（macOS，免费））。

建议演示流程（10-20 秒，三幕）：

```
第 1 幕：release-kit init            → 生成 release-kit.yaml + 安装 hook
第 2 幕：git add . && git commit     → 版本自动递增（version 0.1.0+1 → 0.1.1+2）
第 3 幕：release-kit publish linux --skip-build  → 出 tar.gz 产物 + sha256
```

要点：
- 每幕之间停留 1-2 秒，字幕/光标引导。
- 顶部可以加一行标题：`release-kit — one command, five platforms`。
- GIF 控制在 5MB 内（文章页加载快）。

## 3. 纯文本演示（无截图时的降级方案）

文章/推文中直接贴代码块即可，如：

```bash
# 一键初始化：配置 + hook
dart pub global activate release_kit
cd /path/to/myapp
release-kit init

# 一条命令打包
release-kit publish android
```

## 4. 产物文件清单（建议随宣传文章附上）

| 素材 | 用途 | 存放 |
|---|---|---|
| `docs/social-preview.png` | GitHub 社交卡片 / 文章头图 | 仓库 |
| `promo/demo.gif` | 推文 / 文章动图 | 本地，按需上传图床 |
| `promo/announcement.zh.md` | 中文发布公告 | 仓库（已生成） |
| `promo/announcement.en.md` | 英文发布公告 | 仓库（已生成） |
