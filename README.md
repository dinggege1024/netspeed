# 网速（纯 Swift）

iPhone 实时网速 + 灵动岛。无 CocoaPods、无 Hermes、无 React Native。

## 功能

- 实时上下行（`getifaddrs`）
- 灵动岛 / 锁屏 Live Activity
- App 内仪表盘与 60 秒曲线
- 单位切换、暂停监控
- Cloudflare 一键测速（可选）

## 打开 / 安装

```bash
cd /Users/game-netease/Desktop/workspace/netspeed
xcodegen generate
open NetSpeed.xcodeproj
```

在 Xcode 里选你的 iPhone，点 Run。  
Bundle ID：`com.local.netspeed`（与 todo 同一开发团队）。

## 说明

- 需要 iOS 16.1+（Live Activity）
- 系统设置 → 网速 → 允许实时活动
- 数据只在本机；测速仅在你点击时访问 Cloudflare
