# 网速（纯 Swift）

iPhone 实时网速 + 灵动岛。无 CocoaPods、无 Hermes、无 React Native。

## 功能

- 实时上下行（`getifaddrs`）
- 灵动岛 / 锁屏 Live Activity（按设定间隔取均值刷新）
- App 内仪表盘与曲线
- 单位切换、暂停监控、本地日志（上限 10MB）
- Cloudflare 一键测速（可选）

## 打开 / 安装

```bash
cd netspeed
xcodegen generate   # 需要已安装 XcodeGen
open NetSpeed.xcodeproj
```

签名：复制 `Config/Local.xcconfig.example` 为 `Config/Local.xcconfig`，填入你的 Apple Team ID（该文件已 gitignore，不会推送）。  
然后连上 iPhone，在 Xcode 里 Run。  
Bundle ID：`com.local.netspeed` / `com.local.netspeed.widgets`

## 说明

- 需要 iOS 16.2+（Live Activity）
- 系统设置 → 网速 → 允许实时活动
- 数据只在本机；测速仅在你点击时访问 Cloudflare
- 切到后台后灵动岛会尽量续刷；从多任务杀掉 App 后无法再更新（系统限制）
