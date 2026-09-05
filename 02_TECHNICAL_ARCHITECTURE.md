# Codex Satellites v0.1 — Technical Architecture

## 1. 技术目标

在最小复杂度下实现以下闭环：

```text
local Codex auth (read-only)
        ↓
CodexUsageClient
        ↓
Usage response parser
        ↓
CodexQuotaSnapshot
        ↓
QuotaOverlayController
      ↙               ↘
 Left NSPanel       Right NSPanel
     ↓                  ↓
 5h orb            weekly orb
```

架构重点不是扩展性，而是：

- 正确；
- 可测试；
- 不修改 Codex 认证状态；
- 不抢 macOS 前台焦点；
- 刘海 geometry 不硬编码；
- 数据层未来能单点替换为官方 app-server。

---

## 2. 技术栈与项目形态

### 2.1 推荐

- Swift
- SwiftUI：Orb view、数字布局、动画
- AppKit：`NSPanel`、屏幕 geometry、window level / Spaces / mouse behavior
- `URLSession`：usage 请求
- Swift Concurrency：异步 fetch / refresh loop
- XCTest / Swift Testing：按现有工程工具链择一，不为测试框架引入额外依赖

### 2.2 工程形态

优先建立标准 macOS App Xcode project。如果实施环境已有 SwiftPM GUI 模板也可使用，但不要为了“纯 SwiftPM”增加 bundle 复杂度。

推荐 deployment target：**macOS 15.0+**。

原则：v0.1 不使用必须依赖 macOS 26 才存在的 API；刘海识别依赖 AppKit `NSScreen` camera-housing 相关 API。

### 2.3 App 行为

- accessory app；
- 无 Dock icon；
- 无主 Window scene；
- 无 MenuBarExtra；
- overlay 由 AppDelegate / app-level controller 管理。

Launch at Login 由 `SMAppService.mainApp.status` 唯一决定；不使用 UserDefaults 保存副本。

---

## 3. 文件结构

第一版保持小型结构：

```text
CodexSatellites/
├── App/
│   └── CodexSatellitesApp.swift
├── Models/
│   ├── CodexQuotaSnapshot.swift
│   └── QuotaRefreshInterval.swift
├── Services/
│   ├── CodexUsageClient.swift
│   ├── NotchGeometry.swift
│   ├── LaunchAtLoginService.swift
│   └── QuotaRefreshPreference.swift
├── Window/
│   └── QuotaOverlayController.swift
├── Views/
│   ├── QuotaOrbView.swift
│   └── SettingsBarView.swift
├── Tests/
│   ├── CodexUsageClientTests.swift
│   ├── NotchGeometryTests.swift
│   ├── LaunchAtLoginServiceTests.swift
│   └── QuotaRefreshIntervalTests.swift
├── Resources/
│   └── Localizable.xcstrings
├── script/
│   └── build_and_run.sh
└── .codex/environments/environment.toml
```

如果一个 Swift 文件明显承担两个独立职责，可拆文件；不要提前创建：

- Repository；
- Provider protocol；
- Registry；
- Coordinator hierarchy；
- DI framework；
- networking framework。

---

## 4. Domain Model

推荐模型：

```swift
struct QuotaWindow: Equatable, Sendable {
    let remainingPercent: Double
    let windowDurationSeconds: TimeInterval
    let resetsAt: Date?
}

struct CodexQuotaSnapshot: Equatable, Sendable {
    let fiveHour: QuotaWindow?
    let weekly: QuotaWindow?
    let fetchedAt: Date
}
```

UI state 可再包一层：

```swift
enum SnapshotFreshness: Equatable {
    case unavailable
    case fresh(CodexQuotaSnapshot)
    case stale(CodexQuotaSnapshot)
}
```

不要把 raw token、refresh token、HTTP response body 放入 UI model。

---

## 5. Codex Auth 只读契约

### 5.1 Auth path

查找顺序：

1. 如果环境变量 `CODEX_HOME` 非空：`$CODEX_HOME/auth.json`
2. 否则：`~/.codex/auth.json`

如果文件不存在：返回明确的 `.authUnavailable`，不创建目录、不创建文件。

### 5.2 允许读取的字段

仅解析实现请求所必需的最小字段：

```text
tokens.access_token
account_id   // 如果真实 auth schema 中存在且请求需要
```

实现时应对 `account_id` 的实际层级做最小兼容解析，但不要为了未知历史 schema 写大量猜测逻辑。

### 5.3 禁止读取/使用

即使文件里存在，也不要在代码 DTO 中声明：

```text
refresh_token
```

更不要：

- refresh OAuth token；
- 调用 `auth.openai.com/oauth/token`；
- 修改 `last_refresh`；
- 写回新的 access token；
- chmod/chown auth 文件；
- 将 token 保存到 UserDefaults/Keychain/log。

### 5.4 安全日志

任何日志不得包含：

- access token；
- Authorization header；
- auth.json 全文；
- 原始响应中可能携带的敏感字段。

日志只允许输出：

```text
fetch succeeded
HTTP status
window durations detected
fresh/stale state transition
auth file missing / unreadable
```

---

## 6. Usage Request

### 6.1 v0.1 数据源

当前 MVP 使用已经被多个现有 macOS quota 工具验证的 ChatGPT backend usage endpoint：

```text
GET https://chatgpt.com/backend-api/wham/usage
Authorization: Bearer <existing access token>
```

如果 auth 中有明确 account id，可按真实服务端需求附加：

```text
ChatGPT-Account-Id: <account id>
```

### 6.2 重要风险

`/backend-api/wham/usage` 是 **undocumented / 非公开稳定 API**。

因此：

- URL 必须只出现在 `CodexUsageClient` 内部；
- View / window / domain 不得依赖 raw payload；
- 不把 endpoint 结构扩散到多个文件；
- 解析失败应 fail closed，不猜数值。

### 6.3 未来替换路径

OpenAI Codex 官方 app-server 已公开：

```text
account/rateLimits/read
account/rateLimits/updated
```

并提供：

```text
usedPercent
windowDurationMins
resetsAt
```

未来若 `/wham/usage` 失效，只应替换 `CodexUsageClient` 内部实现，UI/domain 不应变化。

v0.1 **不实现 app-server fallback**。

---

## 7. Raw Payload 解析规则

### 7.1 不依赖 primary/secondary 语义

禁止：

```text
primary_window = 5h
secondary_window = weekly
```

因为实际服务端可能只返回一个窗口，并放在 primary。

### 7.2 按 duration 分类

从每个 rate-limit window 的真实 duration 识别语义。

推荐分类规则：

```text
short/session window: duration < 24h
weekly window: duration >= 24h
```

如果能确认具体字段为 `limit_window_seconds`：直接使用秒数。

对于当前 Codex 常见窗口，典型为：

```text
5h     = 18_000 s
weekly = 604_800 s
```

但解析器不要只接受精确的 18_000 / 604_800；服务端产品策略可能变化。

### 7.3 如果返回多个窗口

v0.1 只需要最终归一成：

```text
fiveHour: QuotaWindow?
weekly: QuotaWindow?
```

若多个短窗口：优先选择最接近用户当前主要 Codex session 限制且有明确 duration 的窗口；若无法无歧义判断，返回 nil，而不是猜测。

若出现 additional/model-specific limits：v0.1 忽略。

### 7.4 百分比

```text
remaining = 100 - usedPercent
remaining = min(max(remaining, 0), 100)
```

异常值：

- NaN / infinite → invalid；
- 缺字段 → invalid；
- 数字字符串是否兼容取决于真实 payload；不要无证据扩大 decoder。

### 7.5 reset time

v0.1 model 可以保存 `resetsAt` 供未来扩展或测试，但 UI 不显示。

---

## 8. 网络与缓存状态机

### 8.1 状态

```text
unavailable
   ↓ first success
fresh(snapshot)
   ↓ fetch failure
stale(lastGood)
   ↓ next success
fresh(newSnapshot)
```

### 8.2 401 / 403

- 不 refresh token；
- 不打开浏览器；
- 不写 auth；
- 若有 last-good → stale；
- 若无 last-good → unavailable。

### 8.3 其他网络错误

同上。

### 8.4 HTTP 2xx 但 payload 无法识别

视为 fetch failure，不生成虚假 window。

### 8.5 Timeout

建议 `URLRequest.timeoutInterval` 10–15 秒；不需要复杂 exponential retry。下一次周期刷新即可。

---

## 9. NotchGeometry

### 9.1 官方 API

依赖：

```swift
NSScreen.safeAreaInsets
NSScreen.auxiliaryTopLeftArea
NSScreen.auxiliaryTopRightArea
NSScreen.frame
NSScreen.visibleFrame
```

Apple 明确说明：camera housing 机器的 auxiliary top areas 是刘海左右未遮挡区域，坐标使用 global screen coordinates。

### 9.2 目标屏幕选择

优先选：

```text
safeAreaInsets.top > 0
AND auxiliaryTopLeftArea != nil
AND auxiliaryTopRightArea != nil
```

若多个候选（理论上）：优先 built-in display；必要时根据屏幕 id / `NSScreen.main` 做最小确定性策略。

### 9.3 计算 hardware notch 边界

若：

```text
leftArea.maxX
rightArea.minX
```

则：

```text
notchLeftEdge  = leftArea.maxX
notchRightEdge = rightArea.minX
```

必须验证：

```text
notchRightEdge > notchLeftEdge
```

否则 geometry invalid。

### 9.4 Orb anchor

左 panel 的内侧边缘：

```text
notchLeftEdge - horizontalGap
```

右 panel 的内侧边缘：

```text
notchRightEdge + horizontalGap
```

垂直位置应基于 top auxiliary area / safe-area band 的真实几何计算，而不是假设固定 37pt。

### 9.5 不缓存 geometry

监听：

```text
NSApplication.didChangeScreenParametersNotification
```

并在 wake/resume 时重算。

`visibleFrame` 及相关屏幕数据可能随 Dock、菜单栏和显示设置变化，不应永久缓存。

---

## 10. Window Architecture

### 10.1 三个独立 `NSPanel`

```text
QuotaOverlayController
├── leftPanel
├── rightPanel
└── settingsPanel
```

与竞品常见的“大透明 window + 中央 island”不同，本项目不创建覆盖大面积顶部屏幕的透明容器。

### 10.2 推荐 panel 基线

使用类似：

```swift
NSPanel(
    contentRect: ...,
    styleMask: [.borderless, .nonactivatingPanel],
    backing: .buffered,
    defer: false
)
```

并配置：

```text
isOpaque = false
backgroundColor = .clear
hasShadow = false
hidesOnDeactivate = false
isFloatingPanel = true
level = .statusBar   // 首选，需真机验证
collectionBehavior includes canJoinAllSpaces
```

是否加入 `.fullScreenAuxiliary` 需要根据 v0.1 目标行为决定；如果加入，必须验证不会在系统全屏顶部产生异常遮挡。

Settings panel 与 quota panel 使用相同的 `.borderless, .nonactivatingPanel` 基线；设置条宽约 176pt、高约 44pt，水平居中于 `NotchGeometry.notchCenterX`，其 frame 顶部位于 `notchBottomEdge - 6pt`。所有 panel 均不调用 `makeKey()` 或 `NSApp.activate(...)`。

### 10.3 非激活

Panel 不应成为 key/main window，不应夺取 active app。

### 10.4 尺寸策略

Collapsed：仅 orb + hover hit padding。

Expanded：增加外侧宽度：

- 左 panel：保持右边缘 anchor 不动，修改 `origin.x` 与 width；
- 右 panel：保持左边缘 anchor 不动，只增加 width。

不要让两 panel 跨过 hardware notch。

---

## 11. Mouse Tracking

### 11.1 目标

Hover 保持额度展开；click 只用于打开/关闭设置条及操作设置条内的 Launch at Login、Review Login Items、Quit controls，不支持 drag、pin 或 keyboard interaction。

### 11.2 推荐

可用：

```text
NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved)
NSEvent.addLocalMonitorForEvents(matching: .mouseMoved)
NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown)
NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown)
```

统一调用：

```text
updateHoverState(cursorLocation)
```

当 `settingsVisible` 且 pointer 位于 settings panel 内时，`mouseMoved` 会重置独立的 settings auto-hide task。settings bar 的 task 与 satellite hover 的 `collapseTask` 分离，延迟固定为 3 秒；hide/stop 必须取消它。settings 外部 click 立即 hide，但 local monitor 返回原 event，保证目标应用继续收到点击。

### 11.3 启动边界

如果 App 启动时鼠标已经位于 overlay 区域，可能在第一次 mouseMoved 前状态不正确。

允许：

- 启动时直接查询 `NSEvent.mouseLocation` 一次；
- 不需要长期 polling timer。

### 11.4 Collapse grace

可以用一个很小的 delayed collapse task，离开后 80–150ms 再确认鼠标仍在区域外，以避免边缘 flicker。

必须支持取消前一个 collapse task。

---

## 12. SwiftUI View

`QuotaOrbView` 接收纯输入：

```text
remainingPercent: Double?
freshness: fresh/stale/unavailable
expanded: Bool
side: left/right
onActivate: () -> Void
```

职责：

- 有效数据只绘制白色 remaining progress arc，used 部分完全透明；unavailable 绘制 neutral 高对比 hollow ring；
- 百分比文本；
- 左右布局顺序；
- 百分比从 notch 侧向 orb 横向滑入，orb 随 panel 向外同步移动，并沿原路反向移出；
- 动画。

不允许 View：

- 读文件；
- 发 HTTP；
- 解析 auth；
- 计算 NSScreen；
- 控制 refresh timer。

`SettingsBarView` 只接收 `LaunchAtLoginState`、`QuotaRefreshInterval`、可用 reset count 和 action closures，不直接依赖 `SMAppService` 或 UserDefaults。控件使用 native SwiftUI `.help(...)` 与 localized accessibility labels；除频率值和 reset count 外不渲染常驻文字，reset count control 是只读 indicator，stale 或 unavailable 时显示 `—`。四个 control 都保持圆形背景与描边，Launch at Login 的 inactive 状态与 Quit 使用 neutral treatment。`LaunchAtLoginService` 通过 `LoginItemServicing` seam 映射 `.enabled`、`.notRegistered`、`.requiresApproval` 和 `.notFound`，并对 register/unregister 做幂等处理。`SMAppService.mainApp.status` 是 Launch at Login 唯一 source of truth，UserDefaults 只保存刷新频率。

---

## 13. Refresh Ownership

最简单方案：`QuotaOverlayController` 或 app-level small state object 持有：

- 当前 `SnapshotFreshness`；
- refresh task；
- 当前 `QuotaRefreshInterval` 与 refresh-loop generation；
- last-good snapshot。

不要为 v0.1 创建复杂 Store 层。

刷新伪流程：

```text
launch
  ↓
show unavailable or last in-memory state
  ↓
fetch
  ↓
update fresh/stale
  ↓
sleep selected interval (1m / 5m / 15m)
  ↓
repeat while app alive
```

启动 loop 先立即 fetch；频率切换保存 preference、cancel 旧 task、以新 interval 启动唯一 loop，但不立即 fetch，从切换时刻重新计时。Wake 通过独立的立即 refresh 路径触发，不受当前 interval 延迟影响。loop generation 和取消检查防止旧 task 在切换后继续更新状态。

App 不需要持久化 quota snapshot 到磁盘。

---

## 14. Info.plist / camera housing

Apple 提供 `NSPrefersDisplaySafeAreaCompatibilityMode`。

在确认 overlay 在带 camera housing 的设备上行为正确后，应检查此键的实际默认行为；如果工程需要明确禁用 compatibility mode，可设置：

```text
NSPrefersDisplaySafeAreaCompatibilityMode = false
```

不要在未真机验证前盲目加入。

---

## 15. Build & Run

项目必须提供单一入口：

```bash
./script/build_and_run.sh
```

脚本至少负责：

1. 停止旧 app；
2. build；
3. launch 新 app。

建议支持：

```bash
./script/build_and_run.sh --verify
./script/build_and_run.sh --logs
```

并配置：

```text
.codex/environments/environment.toml
```

让实施 Agent 的 Run action 固定指向该脚本。

不要让 AI Agent 每次手工拼接新的 build/run 命令。

---

## 16. 最关键的架构约束

1. `CodexUsageClient` 是 undocumented remote API 的唯一边界。
2. `NotchGeometry` 是 NSScreen camera-housing 语义的唯一边界。
3. `QuotaOverlayController` 是 AppKit window/mouse 的唯一主要边界。
4. SwiftUI 只负责展示和发出设置条 action。
5. `LaunchAtLoginService` 是系统登录项状态的唯一应用边界，不使用本地状态副本。
6. 不存在第二份 auth source of truth。
7. 不存在 Provider abstraction。
8. 不存在后台持久化数据库。
9. 所有未知都 fail closed。
