# 网速

iOS 优先的手机实时网速显示 App（Expo / React Native）。

通过本机网络接口字节计数（iOS `getifaddrs`）持续采样上下行速率，并提供 Cloudflare 一键测速。

## 功能

- **灵动岛 / 锁屏 Live Activity**：监控开启后，切到别的 App 也能在刘海看到实时上下行
- App 内仪表盘：大数字上下行、60 秒曲线、网络状态、累计流量
- 单位切换（KB/s ↔ Mbps）、开始 / 暂停监控（暂停会结束灵动岛）
- 一键测速：延迟、下载、上传（双端可用）

## 为什么需要 Development Build

实时流量读取是**本地原生模块**（`modules/network-speed`），**Expo Go 不可用**。

| 平台 | 实时监控 | 灵动岛 | 一键测速 |
|------|----------|--------|----------|
| iOS  | `getifaddrs` | Live Activity（需 iPhone 灵动岛机型） | Cloudflare |
| Android | `TrafficStats` | 无（系统无灵动岛） | Cloudflare |
| Web / Expo Go | 不可用 | 不可用 | 可用 |

> 灵动岛由 `expo-widgets` Live Activity 驱动（`widgets/NetworkSpeedActivity.tsx`）。改过原生 / 插件配置后需重新 `npx expo run:ios`。

## 环境要求

- Node.js 20+（推荐 22）
- Xcode（跑 iOS 真机 / 模拟器）
- CocoaPods

若本机默认 Node 过旧，可临时：

```bash
export PATH="$HOME/.local/node/bin:$PATH"
```

## 快速开始（iOS）

```bash
npm install
npx expo prebuild --platform ios
npx expo run:ios
```

首次改动原生模块后需要重新 `run:ios`；纯 JS/TS 改动可用 Fast Refresh。

仅预览 JS（无实时流量，可测速）：

```bash
npx expo start
```

## 项目结构

```
src/app/                      # Expo Router 页面
src/components/               # 仪表盘 UI
src/hooks/                    # 网速采样、灵动岛同步
widgets/NetworkSpeedActivity.tsx  # 灵动岛 / 锁屏 Live Activity
modules/network-speed/        # iOS getifaddrs 原生流量模块
```

## 权限说明

- 实时网速：读取本机接口计数，不抓包、不上传流量明细
- 测速：仅在你点击时向 Cloudflare 公开测速端点收发数据，结果只存在本机
- iOS 上读取已连接 Wi‑Fi SSID 可能需要定位权限（系统限制）；未授权时仍显示「Wi‑Fi / 已连接」

## 脚本

| 命令 | 说明 |
|------|------|
| `npm start` | 启动 Metro |
| `npm run ios` | 构建并运行 iOS 开发版 |
| `npm run typecheck` | TypeScript 检查 |
| `npm run prebuild` | 生成原生工程 |
