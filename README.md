# 抖音解析工具 (FKDouyin Flutter)

一款基于 Flutter 的短视频解析与下载工具，支持移动端（Android/iOS）与 Web（PWA）平台。目标是提供稳定的无水印下载、清晰度选择、历史管理和便捷的更新体验。

## ✨ 主要功能

- 无水印视频解析与下载（多清晰度）
- 解析历史：Web 使用浏览器 LocalStorage（通过 `shared_preferences`），移动端使用本地文件保存
- 多平台支持：Android、iOS、Web（含 PWA 支持）
- 自动更新检测（移动端使用 GitHub Releases，Web 端可触发强制刷新以获取最新资源）
- 后端代理支持：为了解决视频源的 CORS 问题，Web 端会通过后端代理（如 Cloudflare Worker / Hono）来完成重定向与下载

## 📱 截图

<div align="center">

  <img src="https://tc.liyunfei.eu.org/v2/XOkFFAF.jpeg" width="300" alt="Home Page">

  <img src="https://tc.liyunfei.eu.org/v2/NdaDMDN.jpeg" width="300" alt="Home Page">

</div>

## 🚀 本地开发

1. 环境要求

   - Flutter SDK >= 3.3.0
   - Dart SDK 与 Flutter 版本匹配

2. 克隆并安装依赖

   ```powershell
   git clone https://github.com/42419/flutter-fkdouyin.git
   cd flutter-fkdouyin
   flutter pub get
   ```

3. 运行（移动/桌面）

   ```powershell
   flutter run
   ```

4. 运行 Web（Chrome）

   ```powershell
   flutter run -d chrome
   ```

## 🌐 部署到 Netlify（Web）

本项目已提供 `netlify.toml`，自动在 Netlify 构建期间下载 Flutter SDK 并构建 Web 产物。

自动部署（推荐）

1. 在 Netlify 创建站点并连接 GitHub 仓库 `flutter-fkdouyin`。
2. Netlify 会自动读取仓库中的 `netlify.toml` 并执行构建命令，发布目录为 `build/web`。

如果 Netlify 构建报错（例如 `_flutter` 目录已存在导致 clone 失败），`netlify.toml` 已内置检测逻辑：只有当 `_flutter` 目录不存在时才执行 `git clone`，从而避免重复 clone 错误。

手动构建并部署

1. 本地构建：

   ```powershell
   flutter build web --release
   ```

2. 将 `build/web` 文件夹上传到 Netlify（拖拽上传）。

## 🔄 版本号同步注意事项

- Flutter Web 的显示版本来自仓库根目录的 `pubspec.yaml` 中的 `version` 字段。每次发布新版本请务必更新并推送该文件：

  ```powershell
  git add pubspec.yaml
  git commit -m "更新版本号至 x.y.z"
  git push
  ```

- 推送后，Netlify 会基于最新代码重建并将 Web 版本更新为 `pubspec.yaml` 中指定的版本。

## ⚠️ 常见问题

- CORS 导致无法直接从浏览器请求视频资源：
  - 解决方案：Web 端通过后端代理 API（`/api/redirect`、`/api/download`）来获取真实视频 URL 或二进制流，避免跨域问题。

- Netlify 构建错误（`git clone` 目标已存在）：
  - 我们在 `netlify.toml` 中加入了目录存在检测并跳过 clone，从而兼容 Netlify 缓存。

- Web 更新后仍看到旧资源（浏览器缓存）：
  - 项目在 Web 端的更新提示中，点击“立即更新”会触发页面强制刷新（`window.location.reload()`），以便加载最新资源。对于 PWA，用户可能需要清除应用缓存或卸载后重新安装。

## 🗄️ 解析历史（Web）

- Web 端使用 `shared_preferences`（在浏览器上映射到 LocalStorage）保存历史，键名为 `history_data`。
- 数据以 JSON 格式保存，刷新或重启浏览器（非无痕）后数据仍然存在。

## 🔧 其他小技巧

- 生成 Web 与移动端图标：

  ```powershell
  flutter pub run flutter_launcher_icons
  ```

- 在 Netlify 中跳过 GitHub Actions（如果需要），可在提交信息中加入 `[skip actions]` 或 `[ci skip]` 等关键词。

## 🤝 贡献与联系方式

欢迎提交 Issue / PR。如需帮助或协作，请在仓库 Issue 中联系。

---

最后更新：请确保在发布新版本时同时更新 `pubspec.yaml` 中的 `version` 字段以保持移动端与 Web 端一致。
