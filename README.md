# Fnyun 独立客户端（Flutter 源码）

基于 V2Board 1.7.x Passport/User API 和 `flutter_vless` 1.1.7。界面仅包含登录/注册、连接状态和节点列表，不含全球地图。

## 当前实现
- 从 OSS `configt.json` 动态读取 `domains`，按顺序请求 `/api/v1/guest/comm/config`，不可达时自动尝试下一个站点。
- V2Board 邮箱/密码登录，安全存储 `auth_data`。
- 注册页只做邮箱格式和密码长度检查；注册请求不提交邮箱验证码。
- 登录后读取 `/api/v1/user/getSubscribe`，下载 `subscribe_url`，用 `FlutterVless.parseMany` 解析节点。
- 可逐节点测速并按延迟排序，自动选择最快节点；也可点选节点连接。

## 重要：V2Board 注册设置
若站点后台开启了“注册邮箱验证”，V2Board 会要求 `email_code`，本客户端按你的要求不发送验证码，因此注册会被服务器拒绝。需要在 V2Board 后台关闭注册邮箱验证码要求；如果你想保留邮箱验证码，则需要增加“发送验证码/输入验证码”流程。

## 初始化与构建
需安装 Flutter stable、Android SDK；Windows 桌面包需 Windows 构建机；macOS 包需 macOS + Xcode。

```bash
./tool/bootstrap.sh
flutter run -d windows   # 或 android / macos
./tool/build_all.sh
```

`bootstrap.sh` 会生成 Flutter 官方平台 runner。Android APK 输出在 `build/app/outputs/flutter-apk/app-release.apk`；Windows 输出在 `build/windows/x64/runner/Release/`；macOS 输出在 `build/macos/Build/Products/Release/`。

## 平台说明
- Android：`flutter_vless` 使用 Android VpnService；首次连接需用户确认 VPN 权限。
- Windows：插件文档要求打包本地 Xray runtime/helper 文件；请按 flutter_vless 的 Windows 平台指南补齐 `xray.exe` 等运行时资产。
- macOS：VPN 隧道需要 Network Extension / Packet Tunnel、App Group 和 Apple Team 签名；当前脚本仅执行插件提供的 prepare-only 元数据准备，正式发布仍需在 Xcode 配置签名及扩展能力。

## 注意事项
- 由于运行环境无法访问 GitHub 且未安装 Flutter SDK，本交付为 Flutter 应用源码工程，不是已编译、已真机验证的 APK/EXE/DMG。
- 当前 OSS 域名清单已读取为 `newusuzmxm.fnyunus1.shop`、`newusuzmxm.fnyunus2.shop`、`newusuzmxm.fnyunus3.shop`；运行时仍以 OSS 文件最新内容为准。
- `flutter_vless` 是第三方 MIT 开源项目，遵守其 NOTICE / LICENSE / TRADEMARKS 要求。
