# Codex Satellites v0.1 — Research & Reference Notes

> 本文档用于解释设计来源与未来维护边界，不是 v0.1 功能清单。  
> 核验日期：2026-09-03

## 1. 官方 Apple API

### NSScreen.safeAreaInsets

Apple 说明 safe area 会反映部分 Mac 上 camera housing 遮挡区域。

https://developer.apple.com/documentation/appkit/nsscreen/safeareainsets

### NSScreen.auxiliaryTopLeftArea

刘海左侧未遮挡顶部区域，使用 global screen coordinates。

https://developer.apple.com/documentation/appkit/nsscreen/auxiliarytopleftarea-uglc

### NSScreen.auxiliaryTopRightArea

刘海右侧未遮挡顶部区域，使用 global screen coordinates。

https://developer.apple.com/documentation/appkit/nsscreen/auxiliarytoprightarea-gr2n

### NSScreen.visibleFrame

Apple 明确指出不要永久缓存 visibleFrame，因为 UI 设置会变化；camera housing 两侧区域应使用 auxiliary areas。

https://developer.apple.com/documentation/appkit/nsscreen/visibleframe

### NSPrefersDisplaySafeAreaCompatibilityMode

Apple 对 camera housing compatibility mode 的 Info.plist 控制说明。

https://developer.apple.com/documentation/bundleresources/information-property-list/nsprefersdisplaysafeareacompatibilitymode

---

## 2. OpenAI Codex 官方未来数据源

OpenAI Codex app-server 对 ChatGPT rate limit 提供：

```text
account/rateLimits/read
account/rateLimits/updated
```

典型字段：

```text
usedPercent
windowDurationMins
resetsAt
```

官方仓库：

https://github.com/openai/codex

app-server README 路径：

https://github.com/openai/codex/tree/main/codex-rs/app-server

这应视为 `/backend-api/wham/usage` 未来最优替代路径。

v0.1 不采用的原因：需要额外管理本机 `codex app-server` 子进程、binary discovery、stdio JSON-RPC、timeout 与 teardown，超出当前 MVP 的必要复杂度。

---

## 3. 当前 v0.1 使用的 endpoint

已有多个开源工具从本机 Codex OAuth auth.json 读取 access token，并调用：

```text
GET https://chatgpt.com/backend-api/wham/usage
```

该接口不是公开稳定 API，因此只允许封装在 `CodexUsageClient` 内。

原则：

> 使用它，但不要让整个架构依赖它。

---

## 4. CodexIsland 逆向结论

Repo：

https://github.com/ericjypark/codex-island

值得参考：

- notch geometry 使用 `safeAreaInsets` + auxiliary areas；
- 屏幕参数变化重新定位；
- `/wham/usage`；
- 根据 `limit_window_seconds` 区分窗口；
- 现实中已经遇到“只有 weekly 却位于 primary”的后端返回，因此不能假设 primary=5h；
- read-only credential philosophy；
- hover/mouse startup edge case。

不要照搬：

- 一个很大的透明顶部 Window；
- 中央 Dynamic Island；
- Usage / Cost / Overview；
- history；
- settings；
- 多 Provider；
- click / swipe / pin。

产品差异：CodexIsland 把 notch 变成 UI container；本项目让 hardware notch 保持原样，只在两侧附着 quota satellites。

---

## 5. NOTCHY LIMIT 逆向结论

Repo：

https://github.com/I-N-SILVA/NOTCHYLIMIT

值得参考：

- NSPanel floating overlay；
- notch detection；
- Codex account id header 处理；
- provider usage abstraction 的经验教训。

明确不采用：

- 多 Provider；
- OAuth refresh；
- 写回 auth.json；
- mascot / glow / threshold；
- notification；
- click-to-pin；
- menu bar fallback。

对本项目最重要的反例：

> quota observer 不应该成为第二个 Codex credential owner。

---

## 6. Reserve 逆向结论

官网：

https://reservegpt.app/

公开信息能确认：

- 原生 macOS；
- Swift / SwiftUI；
- 聚焦 ChatGPT 5h / weekly limits；
- Mac App Store 分发；
- 产品非常克制。

由于闭源：

- 不把其内部 auth/data architecture 当作已验证事实；
- 只把它当作“单一任务、glanceable”的产品参考。

---

## 7. Quodex 逆向结论

Repo：

https://github.com/hxbib/Quodex

值得参考的原则：

- stale snapshot 不冒充 live；
- unknown 不显示成 0；
- 对数据来源和状态保持诚实。

不采用：

- 自己做 device-code OAuth；
- Keychain 账户；
- multi-account；
- pooled quota；
- notification。

---

## 8. CodexBar 逆向结论

主要项目：

https://github.com/steipete/CodexBar

重点参考文档：

https://github.com/steipete/CodexBar/blob/main/docs/codex.md

其工程价值：

- 同时验证 OAuth `/wham/usage` 与本机 `codex app-server` 两条路径；
- app-server 调用 `account/read`、`account/rateLimits/read`；
- 处理 child-process timeout / teardown；
- 大量 Provider / usage edge cases。

本项目不应照搬其平台级架构。

---

## 9. 竞品对 MVP 的最终启示

| 问题 | 竞品趋势 | v0.1 决策 |
|---|---|---|
| UI | 越来越像 Dashboard/Dynamic Island | 两个 orb，无中央岛 |
| Provider | 越来越多 | Codex only |
| Auth | 自建 OAuth 或 refresh | 只读 Codex existing auth |
| Data | 多窗口、多 credit、多 cost | 只取 5h + weekly |
| Interaction | click/pin/swipe | hover only |
| Distribution | DMG/Homebrew/App Store | v0.1 先开发验证，不把分发当核心功能 |
| Error UX | diagnostics/settings | stale/unavailable，静默 |

---

## 10. 已知风险

### Risk A — `/wham/usage` 变化

影响：真实 quota fetch 失败。

缓解：

- endpoint 单点封装；
- parser fail closed；
- future migration to app-server。

### Risk B — Codex auth.json schema 变化

影响：无法找到 access token。

缓解：

- DTO 最小；
- 明确错误；
- 不自行修复 auth；
- 必要时参考 openai/codex 最新实现。

### Risk C — Apple display behavior 变化

影响：overlay geometry 偏移。

缓解：

- 使用 NSScreen 官方 geometry，而不是机型常量；
- screen change 重新计算；
- 真机验收。

### Risk D — Menu bar / fullscreen interactions

影响：panel 被隐藏或遮挡。

缓解：

- 使用非激活 floating `NSPanel`；
- 真机测试 Spaces/full-screen；
- v0.1 宁可在特殊场景隐藏，也不要引入复杂 window state machine。

---

## 11. v0.2 之后才允许重新评估的事项

只有 v0.1 真实使用证明有必要后，才讨论：

1. 将 data client 从 `/wham/usage` 切换到 `codex app-server`；
2. Launch at Login；
3. reset countdown；
4. signed + notarized distribution；
5. Homebrew Cask；
6. 外接屏 fallback；
7. headroom semantic indicator。

不要现在为这些功能写空架构。
