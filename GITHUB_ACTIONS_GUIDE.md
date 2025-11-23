# GitHub Actions 配置指南

为了让 GitHub Actions 能够成功编译并发布你的 Android 应用，你需要配置以下 Secret。

## 1. 准备 Keystore

你的项目使用了 `android/app/upload-keystore.jks` 进行签名。由于这个文件包含敏感信息，不应直接提交到代码仓库（虽然目前可能已经在本地），我们需要将其转换为 Base64 字符串存储在 GitHub Secrets 中。

### Windows (PowerShell) 生成 Base64

在项目根目录下运行以下命令：

```powershell
$content = Get-Content -Path "android/app/upload-keystore.jks" -Encoding Byte
$base64 = [Convert]::ToBase64String($content)
Set-Clipboard -Value $base64
Write-Host "Base64 字符串已复制到剪贴板"
```

## 2. 添加 GitHub Secrets

1. 打开你的 GitHub 仓库页面。
2. 点击 **Settings** (设置) -> **Secrets and variables** -> **Actions**。
3. 点击 **New repository secret**。
4. 添加以下 Secret:

   * **Name**: `ANDROID_KEYSTORE_BASE64`
   * **Value**: (粘贴刚才复制的 Base64 字符串)

## 3. 关于 iOS 构建

目前的配置包含 iOS 构建任务，但仅执行 `flutter build ios --release --no-codesign`。这意味着：

* 它会检查代码是否能在 iOS 环境下编译通过。
* 它 **不会** 生成可安装的 `.ipa` 文件。

要生成 `.ipa` 文件，你需要：

1. Apple Developer Program 账号 ($99/年)。
2. 导出发布证书 (.p12) 和描述文件 (.mobileprovision)。
3. 在 GitHub Secrets 中配置这些证书，并在 Workflow 中添加签名步骤。

## 4. 触发构建

* **自动构建**: 每次推送到 `main` 分支时，会自动触发构建（生成 Artifact，但不发布 Release）。
* **发布版本**: 当你推送一个以 `v` 开头的标签时（例如 `v1.0.0`），会自动构建并创建一个 GitHub Release，附件中包含 `app-release.apk`。

### 如何推送标签

```bash
git add .
git commit -m "Prepare release v1.0.0"
git push origin main
git tag v1.0.0
git push origin v1.0.0
```
