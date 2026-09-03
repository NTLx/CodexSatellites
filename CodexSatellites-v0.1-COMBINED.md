# Codex Satellites v0.1 — Combined Handoff


---

<!-- BEGIN 00_README.md -->

# Codex Satellites v0.1 — 文档索引

> 项目名：**Codex Satellites**  
> 目标版本：**v0.1 MVP**  
> 文档状态：Implementation Ready  
> 最后核验：2026-09-03

## 1. 项目一句话定义

一个原生 macOS ambient HUD：在带刘海的 MacBook 内置屏幕上，**刘海左侧用一个极小圆环表示 Codex 5 小时剩余额度，右侧用一个极小圆环表示周剩余额度；鼠标悬浮时，两侧分别向外横向展开并显示剩余百分比；点击任一 satellite 可打开仅含 Launch at Login 与 Quit 的紧凑设置条。**

它不是 Dynamic Island Dashboard，不是菜单栏工具，不是多 Provider usage center。

## 2. v0.1 的核心原则

1. **只做 Codex quota。**
2. **只读本机已有 Codex 登录状态。**
3. **不实现任何授权、登录、刷新 token、账号切换或凭据写回。**
4. **默认状态只显示两个圆环，不显示数字。**
5. **Hover 才显示百分比。**
6. **硬件刘海本身保持硬件，不绘制中央软件“岛”。**
7. **未知数据不伪装成 0%。**
8. **能用简单方案解决的问题，不提前引入复杂抽象。**
9. **只提供紧凑 inline Settings Bar，不创建独立 Settings Window。**

## 3. 文档结构

- `01_PRODUCT_UX_SPEC.md`：产品边界、交互、视觉、状态与非目标。
- `02_TECHNICAL_ARCHITECTURE.md`：代码结构、数据流、Codex usage 解析、窗口与刘海几何。
- `03_IMPLEMENTATION_PLAN.md`：面向实施 AI Agent 的逐阶段开发计划、每阶段完成条件。
- `04_TEST_ACCEPTANCE.md`：单元、集成、人工 UI 验收、异常路径及 v0.1 Release Gate。
- `05_AGENT_EXECUTION_GUIDE.md`：AI Agent 执行约束、修改纪律、验证命令、禁止事项。
- `06_RESEARCH_REFERENCES.md`：竞品逆向结论、官方 API、外部接口风险及未来迁移路径。
- `CodexSatellites_Settings_LaunchAtLogin_Implementation.md`：本次紧凑设置条、开机启动和退出功能的实施约束。
- `CodexSatellites-v0.1-COMBINED.md`：上述全部正文的单文件合集，方便一次性提供给 Agent。

## 4. 建议给实施 Agent 的使用方式

最优顺序：

1. 先读 `01_PRODUCT_UX_SPEC.md`，理解“不做什么”。
2. 再读 `02_TECHNICAL_ARCHITECTURE.md`，确认实现边界。
3. 严格按 `03_IMPLEMENTATION_PLAN.md` 的垂直切片执行。
4. 每完成一阶段，立即跑 `04_TEST_ACCEPTANCE.md` 对应验证。
5. 全程遵守 `05_AGENT_EXECUTION_GUIDE.md`。
6. 遇到 undocumented endpoint、刘海几何或竞品实现疑问时再看 `06_RESEARCH_REFERENCES.md`。

## 5. 成功定义

当且仅当以下事实同时成立，v0.1 才算完成：

- 带刘海的 MacBook 内屏上正确出现左右两个 quota orb；
- 左边可靠表示 5h remaining，右边可靠表示 weekly remaining；
- Hover 时两边分别向外展开百分比；
- 点击任一 satellite 可打开紧凑设置条，Launch at Login 使用系统状态，Quit 结束当前实例；
- App 不执行任何 Codex 授权行为，也不修改任何 Codex 文件；
- 网络失败、token 失效、窗口缺失等情况不会显示错误额度；
- 构建、测试、运行验证全部通过；
- 没有加入 v0.1 非目标功能。


<!-- END 00_README.md -->

---

<!-- BEGIN 01_PRODUCT_UX_SPEC.md -->

# Codex Satellites v0.1 — Product & UX SPEC

## 1. 产品目标

### 1.1 用户问题

Codex 的 5 小时额度与周额度会直接影响 AI Agent 工作连续性，但用户不需要一个长期占据注意力的 Dashboard。真正需要的是：

> 在不打断当前工作的前提下，随时能知道“我现在还有多少 Codex 工作余量”。

### 1.2 产品回答

利用 MacBook 摄像头刘海左右原本较难利用的顶部区域，以两个极小、低干扰的 quota orb 持续表达剩余额度：

```text
        5h                              weekly
         ◕       [ hardware notch ]       ◑
```

默认只看形状，不看数字；只有用户主动把鼠标移到该区域时才展开：

```text
   72%  ◕       [ hardware notch ]       ◑  41%
   ←                                              →
```

### 1.3 产品定位

v0.1 是：

> **Codex quota ambient HUD**

不是：

- Dynamic Island；
- Usage Dashboard；
- 菜单栏 App；
- ChatGPT 全部额度监控；
- 多 AI Provider 监控；
- Codex 登录或账号管理工具。

---

## 2. v0.1 范围

### 2.1 必须实现

1. 自动识别带摄像头 housing 的 MacBook 内置显示器。
2. 计算 hardware notch 左右安全区域及中心边界。
3. 左侧显示 5h remaining 圆环。
4. 右侧显示 weekly remaining 圆环。
5. 默认 collapsed：仅圆环，无百分比数字。
6. Hover 任一侧或定义的 notch 邻近触发区：两侧同时展开。
7. 左侧向左展开，右侧向右展开。
8. 展开态仅显示百分比数字，例如 `72%`、`41%`。
9. 鼠标离开后自动收起。
10. 从 `$CODEX_HOME/auth.json` 或默认 `~/.codex/auth.json` 只读获取本机已有 Codex auth。
11. 使用现有 access token 请求 Codex/ChatGPT usage 数据。
12. 从服务端真实 window duration 识别 5h 与 weekly，而不是依赖 primary/secondary 字段位置。
13. 自动定时刷新。
14. 网络暂时失败时保留最近一次有效数据，并明确呈现 stale 状态。
15. 无有效数据时显示 unavailable，而不是 0%。
16. 点击任一 satellite 打开紧凑 inline Settings Bar，提供 Launch at Login 与 Quit。

### 2.2 明确不实现

v0.1 禁止加入：

- 登录页面；
- `codex login` 引导 UI；
- OAuth；
- device-code flow；
- refresh token 调用；
- 写回 `auth.json`；
- Keychain 自建凭据；
- 多账号；
- ChatGPT 普通聊天额度；
- Reset Credits；
- reset countdown；
- Cost / token / history；
- Claude / Gemini / Cursor / OpenRouter 等 Provider；
- Provider abstraction / registry；
- 独立 Settings 窗口；
- 除 Launch at Login 与 Quit 外的其它设置项；
- 菜单栏 status item；
- 通知；
- 阈值告警；
- 绿色/黄色/红色风险配色；
- glow / pulse / breathing / mascot；
- Click-to-pin；
- 点击展开 Dashboard；
- swipe / page / chart；
- 自动更新框架；
- analytics / telemetry；
- 云同步；
- 外接普通显示器 fallback UI。

如果实现过程中发现“顺手可以加”，也不应加入。

---

## 3. 信息语义

### 3.1 圆环表示 remaining，而不是 used

服务端通常返回 `used_percent`。

产品显示值：

```text
remainingPercent = clamp(100 - usedPercent, 0 ... 100)
```

理由：圆环越满 = 可用能力越多，符合“油量/电量”直觉。

### 3.2 左右固定语义

- **左：5-hour remaining**
- **右：weekly remaining**

绝不根据服务器 primary/secondary 顺序决定左右。

### 3.3 Unknown ≠ 0

如果无法获得某个窗口：

- 圆环显示 hollow / unavailable 状态；
- Hover 展开数字显示 `—`；
- 不显示 `0%`。

`0%` 仅可表示服务端明确返回“已用 100%”。

---

## 4. 视觉规范

### 4.1 总体原则

- 黑色 hardware notch 不被软件重绘。
- App UI 只存在于左右两侧安全区域。
- 使用系统语义前景色与透明度，不采用固定风险颜色。
- 不创建常驻“第三个视觉主体”；设置条只在用户点击后临时出现。
- 不使用 Liquid Glass；设置条使用系统 regular material utility surface。

### 4.2 Collapsed Orb

建议初始设计 token：

| 参数 | 建议值 | 说明 |
|---|---:|---|
| 外径 | 8–10 pt | 先以 9 pt 实现，可根据真机微调 |
| ring line width | 1.5–2 pt | 默认 1.75 pt |
| 与 notch 水平间距 | 8–12 pt | 默认 10 pt |
| 垂直中心 | 与 camera housing top band 视觉中心对齐 | 从真实 screen geometry 推导 |
| opacity（fresh） | 0.85–1.0 | 默认 0.9 |
| opacity（stale） | fresh 的约 55% | 不增加颜色 |
| unavailable | hollow ring + secondary opacity | 不显示错误数值 |

这些尺寸属于可调 UI constant，不属于业务规则。真机视觉优先。

### 4.3 Expanded State

左侧：

```text
[72%  ◕]   [notch]
← expand
```

右侧：

```text
[notch]   [◑  41%]
                     expand →
```

约束：

- 左 panel 的靠 notch 边缘位置保持稳定，只增加向左宽度；
- 右 panel 的靠 notch 边缘位置保持稳定，只增加向右宽度；
- 数字使用 tabular / monospaced digit 能力，避免 `9%` → `100%` 时跳动；
- 文本只包含 `0%...100%` 或 `—`；
- 不显示 `5h`、`weekly` 标签；左右空间关系本身已经表达语义。

建议展开宽度：40–52 pt，具体以字体和 100% 宽度为准。

### 4.4 动画

目标：快速、安静、可逆。

建议：

- expand：约 160–220 ms；
- collapse：约 140–200 ms；
- spring 可用，但不能有明显 bounce；
- 环形额度变化可做轻微 interpolation，但不是 MVP 必需。

验收标准不是某个固定 duration，而是：

> Hover 后无明显延迟；离开后迅速恢复；动画不会引起注意力抢占。

---

## 5. Hover 交互

### 5.1 触发

任一以下区域命中都进入 expanded：

- 左 quota panel；
- 右 quota panel；
- 为减少“难以命中”而定义的极小邻接 hover hit region。

不要求用户精确命中 9pt 圆环。

### 5.2 同步展开

Hover 左侧时，左右都展开；Hover 右侧时，左右也都展开。

理由：一次 glance 同时读取两个额度，无需两次移动鼠标。

### 5.3 收起

鼠标离开整体交互区域后收起。

鼠标离开整体交互区域后，保持展开 3 秒，再沿原路径平滑收起；但不做 pin 状态。

### 5.4 紧凑设置条

点击任一 collapsed 或 expanded satellite 都切换设置条，不区分左右，也不支持右键或双击。

设置条与硬件 notch 水平居中，在 notch 下方约 6pt 出现，内容严格限定为：

```text
Launch at Login   [switch]   |   Quit
```

当系统状态为 requires approval 时，switch 显示为 `Review…` 并打开系统 Login Items 设置；不可用时显示 `—`。再次点击任一 satellite、点击三块 panel 之外的区域或 geometry 失效时关闭设置条。设置条出现期间 quota 两侧保持 expanded，但不改变前台应用或键盘焦点。

### 5.5 不抢焦点

Hover 与显示变化不得：

- 激活 App；
- 抢当前 app 键盘焦点；
- 改变当前 active application；
- 拦截无关区域点击。

---

## 6. 生命周期与刷新体验

### 6.1 启动

- App 以 accessory / background utility 形态运行；
- 无 Dock icon；
- 无主窗口；
- 不创建独立 Settings Window；
- 找到带 notch 的目标内屏后显示；
- 首次 usage fetch 异步执行，不阻塞 UI。

### 6.2 推荐刷新节奏

v0.1 默认：**每 60 秒**。

额外即时刷新时机：

- App 启动；
- Mac wake；
- 网络从不可用恢复（若实现成本低）；
- display configuration 改变不要求额外 fetch，只重算 geometry。

不要低于 30 秒频繁轮询。

### 6.3 Fresh / Stale / Unavailable

- `fresh`：最近一次请求成功；正常 opacity。
- `stale`：曾成功，但最近请求失败；继续显示 last-good snapshot，同时降低 opacity。
- `unavailable`：从未得到该窗口有效数据，或明确失效且没有可信缓存；hollow + `—`。

v0.1 不需要弹 toast 或 error dialog。

---

## 7. 屏幕范围

### 7.1 v0.1 只支持

- MacBook 内置显示器；
- `safeAreaInsets.top > 0`；
- `auxiliaryTopLeftArea` 与 `auxiliaryTopRightArea` 可用于识别 camera housing。

### 7.2 外接显示器

v0.1：**不显示任何 fallback UI。**

如果机器当前没有可识别的 notch display，则 App 安静运行但不画 overlay。

### 7.3 屏幕变化

必须响应：

- 显示器连接/断开；
- 分辨率/缩放变化；
- 主屏切换；
- 睡眠唤醒后 geometry 变化。

禁止缓存一次 geometry 后永久使用。

---

## 8. 可访问性与可用性

v0.1 不需要复杂 VoiceOver workflow，但应做到：

- 不依赖仅颜色区分状态；
- 百分比文本可读；
- Reduce Motion 时应禁用/缩短弹性动画；
- UI 不应影响系统菜单栏使用。

---

## 9. 产品验收场景

### 场景 A：正常额度

服务端：5h used=28，weekly used=59。

用户看到：

```text
◕ [notch] ◑
```

Hover：

```text
72% ◕ [notch] ◑ 41%
```

### 场景 B：只有 weekly

服务端只有一个 604800s window。

显示：

```text
○ [notch] ◕
```

Hover：

```text
— ○ [notch] ◕ 53%
```

### 场景 C：网络失败，有旧数据

继续显示旧额度，但整体减弱 opacity；不得归零。

### 场景 D：access token 无效

如果无 last-good 数据：两个 unavailable orb；不触发授权。

### 场景 E：无 Codex auth

两个 unavailable orb 或整个 overlay 保持最小 unavailable 状态；不弹登录 UI。

---

## 10. v0.1 产品停止条件

只要本 SPEC 的 Must-have 已满足，并通过验收，不继续加功能。

v0.2 及以后可能讨论：

- 官方 `codex app-server` 数据源；
- reset time；
- 外接屏 fallback；
- signed/notarized release；
- adaptive warning semantics。

这些都不是 v0.1 实施内容。


<!-- END 01_PRODUCT_UX_SPEC.md -->

---

<!-- BEGIN 02_TECHNICAL_ARCHITECTURE.md -->

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
│   └── CodexQuotaSnapshot.swift
├── Services/
│   ├── CodexUsageClient.swift
│   ├── NotchGeometry.swift
│   └── LaunchAtLoginService.swift
├── Window/
│   └── QuotaOverlayController.swift
├── Views/
│   ├── QuotaOrbView.swift
│   └── SettingsBarView.swift
├── Tests/
│   ├── CodexUsageClientTests.swift
│   ├── NotchGeometryTests.swift
│   └── LaunchAtLoginServiceTests.swift
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

Settings panel 与 quota panel 使用相同的 `.borderless, .nonactivatingPanel` 基线；设置条宽约 240pt、高约 44pt，水平居中于 `NotchGeometry.notchCenterX`，其 frame 顶部位于 `notchBottomEdge - 6pt`。所有 panel 均不调用 `makeKey()` 或 `NSApp.activate(...)`。

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

Hover 保持额度展开；click 只用于打开/关闭设置条及操作设置条内的 Launch at Login、Review…、Quit，不支持 drag、pin 或 keyboard interaction。

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

- 圆形 track；
- progress arc；
- 百分比文本；
- 左右布局顺序；
- 动画。

不允许 View：

- 读文件；
- 发 HTTP；
- 解析 auth；
- 计算 NSScreen；
- 控制 refresh timer。

`SettingsBarView` 只接收 `LaunchAtLoginState` 和 action closures，不直接依赖 `SMAppService`。`LaunchAtLoginService` 通过 `LoginItemServicing` seam 映射 `.enabled`、`.notRegistered`、`.requiresApproval` 和 `.notFound`，并对 register/unregister 做幂等处理。

---

## 13. Refresh Ownership

最简单方案：`QuotaOverlayController` 或 app-level small state object 持有：

- 当前 `SnapshotFreshness`；
- refresh task；
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
sleep 60s
  ↓
repeat while app alive
```

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


<!-- END 02_TECHNICAL_ARCHITECTURE.md -->

---

<!-- BEGIN 03_IMPLEMENTATION_PLAN.md -->

# Codex Satellites v0.1 — Implementation Plan

## 1. 给实施 AI Agent 的总体策略

采用**垂直切片 + 每阶段立即验证**。

禁止一次性写完整 App 后再调试。

正确顺序：

```text
工程骨架
→ mock 双 orb
→ notch geometry
→ hover 动画
→ usage parser fixture
→ read-only auth + HTTP
→ refresh/stale
→ 真机回归
→ release gate
```

每一阶段只有在对应测试通过后才能进入下一阶段。

---

## Phase 0 — 仓库与基线

### 目标

建立可重复 build/run 的最小 macOS 工程。

### 操作

1. 检查当前目录是否已经在 Git repo：
   ```bash
   git rev-parse --is-inside-work-tree
   ```
2. 如果不是，再在项目根执行 `git init`；禁止在已有父 repo 中创建嵌套 repo。
3. 建立标准 macOS App target。
4. 创建本文档约定目录。
5. 添加 `.gitignore`。
6. 创建 `script/build_and_run.sh`。
7. 创建 `.codex/environments/environment.toml`，Run 指向脚本。
8. 建立最小测试 target。

### 完成条件

- clean build；
- `./script/build_and_run.sh --verify` 可构建、启动并确认进程存在；
- 无业务代码。

---

## Phase 1 — Mock 双 Orb UI

### 目标

先证明视觉模型，不接网络、不读 Codex。

### 实现

1. `QuotaOrbView`。
2. App 启动后用固定 mock：
   ```text
   5h remaining = 72
   weekly remaining = 41
   ```
3. 创建左右两个透明非激活 panel。
4. 暂时允许用屏幕中心附近的固定测试 anchor，仅限该阶段。

### 必验

- 两 panel 不抢焦点；
- 默认只显示 orb；
- 无背景 pill；
- 没有 Dock icon；
- panel 外区域不拦截点击。

### 禁止

此阶段不得接 Codex auth 或 `/wham/usage`。

---

## Phase 2 — Notch Geometry

### 目标

完全删除测试用硬编码 anchor。

### 实现

1. 新增 `NotchGeometry`。
2. 从：
   ```text
   safeAreaInsets
   auxiliaryTopLeftArea
   auxiliaryTopRightArea
   ```
   推导 hardware notch 左右边界。
3. 将左 panel 锚定在 notch 左侧，右 panel 锚定在 notch 右侧。
4. 加 `NSApplication.didChangeScreenParametersNotification`。
5. 对无 notch display 返回 nil，不显示 overlay。

### 单元测试

将 geometry calculation 核心写成纯函数，传入 synthetic rect fixture。

至少测试：

- 标准 notch；
- 非零 screen origin（多显示器）；
- left/right area 缺失；
- rightEdge <= leftEdge；
- 缩放后不同尺寸 rect。

### 真机验收

- orb 与物理 notch 间距视觉对称；
- 不盖住摄像头区域；
- 修改显示缩放后重新定位；
- 外接屏切换后不漂移。

---

## Phase 3 — Hover Interaction

### 目标

完成最终核心交互。

### 实现

1. 监听 mouse moved。
2. 定义左右 panel + 邻接 padding 的 hover region。
3. 任一侧命中 → `expanded = true`。
4. 左 panel 向左增加宽度；右 panel 向右增加宽度。
5. 展示 `72%`、`41%`。
6. 离开后 collapse。
7. 启动时读取一次 `NSEvent.mouseLocation`。
8. 可加入极短 collapse grace 防 flicker。

### 验收

- Hover 左 orb → 两侧同时展开；
- Hover 右 orb → 两侧同时展开；
- 左不向 notch 内扩；
- 右不向 notch 内扩；
- 当前前台应用不变化；
- 快速左右移动无明显闪烁；
- 100% 三位数不会造成布局抖动。

---

## Phase 4 — Usage Parser（先测试，后网络）

### 目标

在完全不接真实账号的前提下验证 quota 语义。

### 建议 fixture

创建 test-only JSON fixture 或 inline Data，不提交真实账号数据。

至少覆盖：

#### Fixture A：primary=5h, secondary=weekly

```text
primary duration = 18000s, used = 28
secondary duration = 604800s, used = 59
```

期望：

```text
fiveHour.remaining = 72
weekly.remaining = 41
```

#### Fixture B：只有 weekly 放在 primary

```text
primary duration = 604800s, used = 47
secondary = null
```

期望：

```text
fiveHour = nil
weekly.remaining = 53
```

#### Fixture C：百分比边界

```text
used = -1 / 0 / 100 / 101
```

合理处理：合法数值 clamp，明显无法解析值 fail closed。

#### Fixture D：字段缺失

期望对应 window nil，不 crash。

#### Fixture E：未知 additional/model-specific limits

忽略，不影响 5h/weekly。

### 完成条件

Parser tests 全绿后，才能接真实 HTTP。

---

## Phase 5 — Read-only Codex Auth + Real Fetch

### 目标

连接本机已有 Codex 登录，不引入任何 auth lifecycle。

### 实现

1. 解析 `$CODEX_HOME` fallback `~/.codex`。
2. 只读 `auth.json`。
3. DTO 只声明 access token + 必需 account id。
4. 构建 `/backend-api/wham/usage` 请求。
5. token 仅存在请求构建所需内存中。
6. 解析成 `CodexQuotaSnapshot`。

### 必须做的负向验证

测试或代码审计确认：

```bash
grep -R "refresh_token" Sources Tests
```

预期：生产 Sources 中没有 refresh-token 使用逻辑；如果测试 fixture 为验证忽略未知字段而出现字符串，也不得被生产 DTO 使用。

再检查：

```bash
grep -R "oauth/token\|device.*code\|codex login" Sources
```

预期：没有实现。

### 文件不可变验证

在开发机可做：

```bash
shasum -a 256 ~/.codex/auth.json
# 启动并刷新若干次
shasum -a 256 ~/.codex/auth.json
```

两个 hash 应相同（前提是期间 Codex CLI 自己没有刷新文件）。

如果 Codex 自身同时运行会修改 auth，则用文件系统审计/测试替身证明 App 只用 read API，不调用 write。

---

## Phase 6 — Refresh / Freshness

### 目标

让长期运行行为可靠，但不做复杂 retry 系统。

### 实现

1. 启动立即 fetch。
2. 60s 周期 refresh。
3. 成功：fresh(newSnapshot)。
4. 失败且有 last-good：stale(lastGood)。
5. 失败且无 last-good：unavailable。
6. stale 时降低 opacity。
7. App termination 时取消 task。

### 测试

使用 dependency seam 注入 fake fetch closure 或 fake URLProtocol，不必引入 DI framework。

覆盖：

```text
success → fresh
success → failure → stale(old)
failure first → unavailable
stale → success → fresh(new)
```

---

## Phase 7 — System Lifecycle

### 目标

处理 macOS 长期运行关键事件。

### 实现/核验

- display parameters change → recalc geometry；
- wake → recalc geometry + immediate usage refresh；
- target notch display disappear → hide panels；
- target return → show panels；
- panel 始终不成为 normal app window。

不要新增 Settings。

---

## Phase 8 — Visual Polish

只允许调整：

- orb size；
- line width；
- notch gap；
- percentage typography；
- expand width；
- animation curve；
- fresh/stale opacity；
- hover hit padding。

不允许趁 polish 加功能。

建议把这些集中成一个很小的 constants namespace，例如：

```text
OverlayMetrics
```

不要做完整 Theme System。

---

## Phase 9 — Final Verification

严格执行 `04_TEST_ACCEPTANCE.md`。

最终至少：

```bash
./script/build_and_run.sh --verify
```

运行单元测试和静态审计。

输出终态报告：

```text
Build: PASS/FAIL
Tests: N passed / N failed
Auth read-only audit: PASS/FAIL
Notch geometry manual test: PASS/FAIL
Hover manual test: PASS/FAIL
No-scope-creep audit: PASS/FAIL
Known limitations: ...
```

---

## 10. 实施中遇到问题的处理优先级

### 问题：刘海位置不准

优先检查真实 `NSScreen` rect 输出，不猜机型常量。

### 问题：Hover 不稳定

先检查 panel frame / global coordinate / hit region；不要立刻上持续高频 polling。

### 问题：403/401

不要加 refresh OAuth。确认当前 Codex CLI 本身登录是否有效；App 保持 stale/unavailable 即可。

### 问题：`primary_window` 看起来是 weekly

按 duration 分类，不按字段名硬编码。

### 问题：非刘海显示器

v0.1 直接隐藏，不做 menu bar fallback。

### 问题：想加“顺手”的设置或告警

拒绝，记录到 future ideas，不实施。


<!-- END 03_IMPLEMENTATION_PLAN.md -->

---

<!-- BEGIN 04_TEST_ACCEPTANCE.md -->

# Codex Satellites v0.1 — Test & Acceptance Plan

## 1. 测试目标

本项目最主要的风险不是算法复杂度，而是四类边界：

1. **额度语义解析错误**；
2. **误修改 Codex auth**；
3. **macOS 刘海/多屏 geometry 错误**；
4. **浮动窗口干扰正常桌面交互**。

测试优先覆盖这四类风险。

---

## 2. 自动化测试

### 2.1 Usage parser

必须测试：

| Case | 输入 | 期望 |
|---|---|---|
| 标准双窗口 | 5h + weekly | 两侧正确 |
| 只有 weekly | 604800s window 位于 primary | fiveHour=nil, weekly valid |
| 只有 5h | short window | weekly=nil |
| 顺序互换 | weekly 在 primary, 5h 在 secondary | 按 duration 归类 |
| used=0 | | remaining=100 |
| used=100 | | remaining=0 |
| 缺 used | | window invalid |
| 缺 duration | | 不猜 window 类型 |
| malformed JSON | | error，不 crash |
| extra limits | | v0.1 忽略 |

### 2.2 Auth path

测试：

- `CODEX_HOME` 设置时优先；
- 未设置时 fallback `~/.codex`；
- 文件不存在；
- unreadable；
- JSON malformed；
- access token 缺失。

测试使用临时目录，绝不修改开发机真实 `~/.codex`。

### 2.3 Read-only contract

生产代码静态审计：

- 无 `refresh_token` 使用；
- 无 `oauth/token`；
- 无 device login；
- 无写 `auth.json`；
- 无 Keychain credential store。

如果定义文件访问 helper，应只有 read path。

### 2.4 Freshness state machine

覆盖：

```text
initial + success → fresh
initial + fail → unavailable
fresh + fail → stale(lastGood)
stale + fail → stale(same)
stale + success → fresh(new)
```

### 2.5 Geometry pure tests

不要依赖真实 `NSScreen` 才能测试核心算法。

fixture 至少覆盖：

- screen origin `(0,0)`；
- screen origin 非零/负数；
- left/right auxiliary areas；
- invalid / overlapping areas；
-不同 screen widths；
- notch width 变化；
- horizontal gap 输出。

### 2.6 Launch at Login service

使用 `LoginItemServicing` mock 覆盖：

- `.notRegistered` → disabled；`.enabled` → enabled；`.requiresApproval` → requiresApproval；`.notFound` → unavailable；
- disabled → enable 只 register 一次；enabled → disable 只 unregister 一次；
- requiresApproval → enable 不重复 register，→ disable 可 unregister；
- unavailable 不循环 register/unregister；
- 不使用 UserDefaults 保存启动状态。

---

## 3. 网络集成测试

### 3.1 不在 CI 使用真实 token

CI 不依赖真实 OpenAI/Codex 账号。

HTTP integration 使用：

- `URLProtocol` stub；或
- 很小的 injectable transport closure。

不要为了测试引入大型 HTTP mocking dependency。

### 3.2 测试状态码

- 200 valid；
- 200 malformed；
- 401；
- 403；
- 429；
- 500；
- timeout；
- offline error。

期望：所有失败都不会触发 auth refresh，也不会丢掉 last-good。

---

## 4. 真机 UI 验收

必须在**真实带刘海的 MacBook 内屏**验证；截图或模拟 rect 不能代替最终验收。

### 4.1 启动

- [ ] App 无 Dock icon。
- [ ] 无普通主窗口。
- [ ] 左右 orb 正确出现在物理刘海两侧。
- [ ] 与 notch 间距左右一致。
- [ ] 没有覆盖摄像头 housing。
- [ ] 默认没有任何数字。
- [ ] 点击任一 collapsed satellite 打开紧凑设置条。
- [ ] 设置条位于硬件 notch 正下方并水平居中，尺寸保持约 240×44pt。
- [ ] 设置条只有 Launch at Login 与 Quit。

### 4.2 Hover

- [ ] Hover 左侧，两边同时展开。
- [ ] Hover 右侧，两边同时展开。
- [ ] 左边向左展开。
- [ ] 右边向右展开。
- [ ] 不向刘海中央扩张。
- [ ] 离开后可靠收起。
- [ ] 鼠标离开整体交互区域后保持展开约 3 秒，再沿原路径平滑收起。
- [ ] 展开/收起时当前 app 不失焦。

### 4.3 设置条

- [ ] 点击任一 expanded satellite 可关闭设置条。
- [ ] 设置条打开期间两侧百分比保持展开。
- [ ] Launch at Login 开关反映 `SMAppService.mainApp.status`，关闭后当前 App 继续运行。
- [ ] requires approval 显示 `Review…`，只打开系统 Login Items 设置。
- [ ] unavailable 显示 `—` 或 disabled control，Quit 仍可用。
- [ ] 点击左右 satellite、设置条之外关闭设置条，且原点击继续送达目标 App。
- [ ] 点击 Quit 只终止当前实例，不 unregister Login Item。
- [ ] Reduce Motion 开启时无 slide/bounce。

### 4.4 数字

人工注入 mock 或真实数据验证：

- [ ] 0%
- [ ] 9%
- [ ] 10%
- [ ] 99%
- [ ] 100%
- [ ] unavailable `—`

三位数不得改变 notch 内侧 anchor。

### 4.5 Fresh/Stale

- [ ] fresh 正常显示。
- [ ] 断网后保留原百分比。
- [ ] stale opacity 明显但克制地降低。
- [ ] 不出现错误 toast。
- [ ] 恢复网络后更新为 fresh。

---

## 5. macOS 屏幕行为验收

### 5.1 Display settings

- [ ] 修改缩放/分辨率后重新定位。
- [ ] 显示器参数改变不需要重启 App。

### 5.2 外接屏

- [ ] 接入普通外屏后，内屏 overlay 仍与内屏 notch 对齐。
- [ ] 若内屏不再可用/关闭，overlay 隐藏。
- [ ] 不在普通外屏顶部创建 fallback pill。

### 5.3 Sleep / Wake

- [ ] Wake 后 geometry 正确。
- [ ] Wake 后尽快 refresh usage。
- [ ] 不出现 duplicate panels。

### 5.4 Spaces / Full Screen

需要明确测试最终 panel collection behavior：

- [ ] 普通 Space 可见。
- [ ] 切换 Space 不复制/漂移。
- [ ] 全屏 App 场景符合实现决策。
- [ ] 不遮挡系统警告/安全对话框。

如果 full-screen overlay 行为不稳定，v0.1 可选择不在 full-screen space 显示；不要为此增加复杂状态系统。

---

## 6. Auth 安全验收

### 6.1 源码审计

必须确认不存在：

```text
refresh token exchange
OAuth login
device-code login
browser launch for auth
Keychain auth store
auth.json write
```

### 6.2 日志审计

运行 `--logs` 后检查：

- [ ] 没有 access token；
- [ ] 没有 Authorization header；
- [ ] 没有 auth.json 全文；
- [ ] 没有 raw credential dump。

### 6.3 文件写入审计

App 本身不应在 `~/.codex` 下创建或修改任何文件。

---

## 7. 性能与长期运行

v0.1 不需要复杂 benchmark，但至少人工检查：

- [ ] idle 时 CPU 长期接近 0，不存在 25Hz/60Hz 永久 polling；
- [ ] 没有 runaway timer；
- [ ] 60s refresh 不叠加 concurrent request；
- [ ] app termination 能取消 refresh task / event monitor；
- [ ] memory 无明显持续增长。

可用 Activity Monitor + Instruments 的基本检查；无需为 v0.1 建性能基准系统。

---

## 8. Scope Creep Audit

Release 前检查源码/界面确认没有：

- [ ] 独立 Settings Window；
- [ ] MenuBarExtra；
- [ ] notification；
- [ ] history；
- [ ] cost；
- [ ] reset credit；
- [ ] reset countdown；
- [ ] provider registry；
- [ ] Claude/Gemini 等其它 provider；
- [ ] OAuth；
- [ ] update framework；
- [ ] analytics。

允许且仅允许一个临时 compact Settings Bar，内容为 Launch at Login、requires approval 时的 Review… 和 Quit。

如果有，应删除或明确证明它是满足本 SPEC 的必要最小实现。

---

## 9. Release Gate

v0.1 只有在以下全部为 PASS 时才可标记完成：

```text
[PASS] Build
[PASS] Automated tests
[PASS] Usage window classification
[PASS] Auth read-only audit
[PASS] Real MacBook notch geometry
[PASS] Hover interaction
[PASS] No focus stealing
[PASS] Fresh/stale behavior
[PASS] Display-change behavior
[PASS] Compact settings bar behavior
[PASS] Launch at Login state mapping
[PASS] Scope-creep audit
```

任何一项 FAIL：不发布完成结论。

---

## 10. 最终 Agent 报告模板

```markdown
## v0.1 Verification

- Build: PASS / FAIL
- Tests: X passed / Y failed
- Real notch geometry: PASS / FAIL / NOT TESTED
- Hover behavior: PASS / FAIL / NOT TESTED
- Auth read-only audit: PASS / FAIL
- `~/.codex` write audit: PASS / FAIL
- Fresh/stale network behavior: PASS / FAIL
- Display-change behavior: PASS / FAIL / NOT TESTED
- Compact settings bar: PASS / FAIL / NOT TESTED
- Launch at Login: PASS / FAIL / NOT TESTED
- Scope audit: PASS / FAIL

### Changed files
- ...

### Known limitations
- ...

### Evidence / commands
- `...`
```

Agent 不得把 `NOT TESTED` 写成 PASS。


<!-- END 04_TEST_ACCEPTANCE.md -->

---

<!-- BEGIN 05_AGENT_EXECUTION_GUIDE.md -->

# Codex Satellites v0.1 — AI Agent Execution Guide

## 1. 你的任务

实现 `Codex Satellites v0.1`，严格遵循同目录 SPEC。

首要目标不是“功能多”，而是：

> 用尽可能少、可验证、原生的代码，把两个 Codex quota orb 稳定地放在 MacBook 硬件刘海两侧。

---

## 2. 执行优先级

发生冲突时按以下顺序：

1. 数据正确性；
2. 不破坏 Codex auth；
3. 不干扰 macOS 正常交互；
4. 刘海几何正确；
5. UI 克制；
6. 代码简洁；
7. 未来扩展性。

未来扩展性排最后。

---

## 3. 开始前必须做

1. 阅读全部文档，至少 `01`–`05`。
2. 检查 repo / project shape。
3. 检查工作区是否干净：
   ```bash
   git status --short
   ```
4. 检查已有代码与约定，不重写无关部分。
5. 建立稳定 build/run 入口，再写业务代码。

---

## 4. 开发方法

### 4.1 垂直切片

一次只推进一个可观察结果。

例如：

```text
先显示 mock orb
而不是
先写完整 UsageProvider + AuthManager + SettingsStore
```

### 4.2 先失败测试，再最小实现

数据 parser 与 geometry 核心逻辑优先 test-first。

Window 视觉行为无法完全自动化时，至少：

- 把计算逻辑抽成纯函数测试；
- 真机人工验证 UI。

### 4.3 修改范围

每个改动必须能映射到 SPEC 条目。

禁止顺手：

- 重构无关代码；
- 大范围格式化；
- 改名；
- 引入第三方依赖；
- 做未来 feature scaffold。

---

## 5. 明确禁止的技术行为

### 5.1 Auth

绝不：

```text
POST auth.openai.com/oauth/token
使用 refresh_token
执行 device login
执行 codex login
打开浏览器授权
写 ~/.codex/auth.json
创建自己的 OpenAI Keychain credential
```

这是硬约束，不是建议。

### 5.2 数据

绝不：

```text
primary == 5h
secondary == weekly
```

必须按真实 window duration 分类。

绝不把未知显示成 0%。

### 5.3 UI

绝不加入：

```text
central pill
Dynamic Island panel
settings
menu bar item
history
cost
notifications
provider switcher
click-to-expand
```

### 5.4 系统行为

绝不：

- 使用大面积透明窗口覆盖整段菜单栏，除非证据证明两个小 panel 无法满足；
- 永久高频 polling 鼠标；
- 激活 App 抢焦点；
- 硬编码某款 MacBook 屏幕像素值。

---

## 6. 发生同类错误两次时

停止随机修改。

必须：

1. 收集真实证据：log、frame、HTTP fixture、build error；
2. 明确错误属于：
   - parser；
   - coordinate space；
   - NSPanel；
   - event monitor；
   - auth；
   - network；
3. 查当前 Apple / OpenAI 官方文档或参考竞品源码；
4. 比较最小修复；
5. 修改后重跑原失败场景。

---

## 7. 推荐观察日志

使用 `Logger`/os_log，日志保持结构化且不含秘密。

建议 category：

```text
app
usage
geometry
window
```

允许示例：

```text
usage fetch status=200
usage windows durations=[18000,604800]
geometry screen=BuiltIn valid=true
window expanded=true
usage state=stale reason=http401
```

禁止：

```text
access_token=...
Authorization=Bearer ...
auth_json=...
```

---

## 8. Build / Run 纪律

一旦 `script/build_and_run.sh` 建立，后续默认都用它。

至少支持：

```bash
./script/build_and_run.sh
./script/build_and_run.sh --verify
```

如加入：

```bash
./script/build_and_run.sh --logs
```

则确保它是真实可用的，而不是文档占位。

每次声明“修好了”前，先 build/test/verify。

---

## 9. 外部资料使用规则

优先级：

1. Apple Developer Documentation；
2. OpenAI 官方 `openai/codex`；
3. CodexIsland / CodexBar 等成熟开源参考；
4. NOTCHY / Quodex 等其它实现。

不要直接复制大段竞品代码。

如果复用 MIT 代码片段而不是只采用思想，需要依法保留 attribution/license。

---

## 10. 推荐参考点

### Apple

重点查：

```text
NSScreen.safeAreaInsets
NSScreen.auxiliaryTopLeftArea
NSScreen.auxiliaryTopRightArea
NSScreen.visibleFrame
NSPrefersDisplaySafeAreaCompatibilityMode
NSPanel
```

### OpenAI Codex

未来迁移参考：

```text
codex app-server
account/rateLimits/read
account/rateLimits/updated
```

### CodexIsland

只重点参考：

```text
NotchInfo / screen geometry
UsageFetcher / window duration classification
read-only credential philosophy
mouse tracking edge cases
```

不要复制其 Usage/Cost/Overview 产品结构。

---

## 11. Agent 必须保留的简洁性

如果你准备创建下面任何东西，先证明为什么 v0.1 必需：

```text
protocol UsageProvider
class AuthManager
class Repository
class DependencyContainer
class SettingsStore
class ThemeManager
SQLite / SwiftData
WebSocket
retry framework
```

默认答案应是“不创建”。

---

## 12. 完成时的自检问题

在最终回复前逐条问自己：

- 我是否真的验证了 5h / weekly 分类？
- 我是否可能写了 Codex auth？
- 我是否把 unknown 当成了 0？
- 我是否在真机验证过 notch？
- 我是否确认没有抢焦点？
- 我是否引入了 SPEC 外功能？
- 我是否能删除任何抽象而不损失功能？
- 所有声称 PASS 的项目是否有真实证据？

如果答案不确定，明确写成 limitation，而不是猜。


<!-- END 05_AGENT_EXECUTION_GUIDE.md -->

---

<!-- BEGIN 06_RESEARCH_REFERENCES.md -->

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


<!-- END 06_RESEARCH_REFERENCES.md -->
