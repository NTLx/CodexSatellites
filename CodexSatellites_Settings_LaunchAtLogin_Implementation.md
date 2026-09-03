# CodexSatellites — 紧凑设置条 / 开机启动 / 退出 实施文档

> 目标仓库：`NTLx/CodexSatellites`  
> 基线分支：`main`  
> 基线提交：`4aa105f5850054fea2587d7d10b81f764be8c7f8`  
> 目标：在保持 CodexSatellites 极简 ambient HUD 产品哲学的前提下，为 v0.1 补齐最小必要的应用生命周期控制。  
> 文档状态：**Implementation Ready**

## 0. 完成定义

本任务只增加三件事：

1. 点击刘海任一侧 quota satellite，打开一个位于硬件刘海正下方的紧凑横向设置条。
2. 设置条提供 **Launch at Login** 开关。
3. 设置条提供 **Quit** 按钮。

完成后的交互：

```text
默认：

       ◕       [ hardware notch ]       ◑

Hover：

  72%  ◕       [ hardware notch ]       ◑  41%

点击任一 satellite：

  72%  ◕       [ hardware notch ]       ◑  41%
                    ↓
          ╭──────────────────────╮
          │ Launch at Login  ◉ │ Quit │
          ╰──────────────────────╯
```

设置条必须紧凑，不成为新的 Dashboard；不创建普通 Settings Window、Dock 图标或菜单栏图标；不抢当前应用键盘焦点；不改变现有 Codex quota 数据逻辑；不增加第三方依赖。

**完成后停止。不要顺手加入 Refresh、About、Update、通知、版本号、Provider、主题等其它设置。**

---

# 1. 当前源码审查结论

## 1.1 当前架构健康，不要重写

当前生产职责：

```text
App/
└── CodexSatellitesApp.swift

Models/
└── CodexQuotaSnapshot.swift

Services/
├── CodexUsageClient.swift
└── NotchGeometry.swift

Views/
└── QuotaOrbView.swift

Window/
└── QuotaOverlayController.swift
```

数据流：

```text
Codex auth.json (read-only)
        ↓
CodexUsageClient
        ↓
CodexQuotaSnapshot
        ↓
QuotaOverlayController
        ↓
left NSPanel  /  right NSPanel
        ↓
QuotaOrbView
```

本任务只做外科式扩展，不引入 MVVM、Coordinator、Repository、Provider Registry 或 Settings framework。

## 1.2 当前值得保持的实现

- `CodexAuthReader` 优先 `$CODEX_HOME/auth.json`，fallback `~/.codex/auth.json`，只解析 `access_token` 和可选 `account_id`，不刷新 token、不写回配置。
- quota parser 按 `limit_window_seconds` 判断 5h / weekly，不依赖 primary/secondary 字段位置。
- `SnapshotStateMachine` 区分 unavailable / fresh / stale，网络错误保留 last-good snapshot。
- 左右 satellite 使用两个独立小 `NSPanel`，没有大面积透明 Window。
- display / wake / mouse monitor 都在 `stop()` 清理。

以上全部保持。

---

# 2. 当前必须解决的问题

## P1 — 没有用户可访问的退出路径

当前 App 使用：

```text
LSUIElement = YES
activationPolicy = .accessory
```

因此没有 Dock 常驻入口、普通应用菜单或 menu bar status item。当前正常退出只能依赖外部 kill / Activity Monitor / 开发脚本。

本任务通过 `Quit` 解决。

## P1 — 当前 satellite 无法接收点击

当前：

```swift
panel.ignoresMouseEvents = true
```

这适合 hover-only MVP，但阻止 SwiftUI 接收点击。

正确改法：

```text
left panel     hardware notch     right panel
  clickable      no window          clickable
```

要求：

- `leftPanel.ignoresMouseEvents = false`
- `rightPanel.ignoresMouseEvents = false`
- 保持 `.nonactivatingPanel`
- 不调用 `makeKey()`
- 不调用 `NSApp.activate(...)`
- 不抢当前 active application

不要新增一个覆盖刘海的大透明 click window。

## P2 — Bundle ID 在公开发布前必须冻结

当前 `com.codexsatellites.app` 可以继续用于开发。

但一旦公开发布并使用 `SMAppService.mainApp`，Bundle identity 应视为持久兼容性的一部分。

**本任务不要擅自修改 Bundle ID。**

最终报告提醒 owner：第一次公开分发前选择并冻结最终 Bundle ID。

## P2 — Launch at Login 不能只用 unsigned 开发 bundle 验收

现有 `./script/build_and_run.sh` 使用 `CODE_SIGNING_ALLOWED=NO`。它适合快速开发，但不能作为未来分发形态下 Login Item 行为的唯一验证。

Launch at Login 的最终人工验收应额外使用稳定路径的 `.app`：

```text
/Applications/CodexSatellites.app
```

或：

```text
~/Applications/CodexSatellites.app
```

正式发行阶段再处理 Developer ID + Hardened Runtime + notarization。本任务不实现发行流水线。

## P3 — 无 CI

当前已有 XCTest，但没有 GitHub Actions workflow。这不是本功能 blocker。

**不要在本任务中顺手加 CI。**

## P3 — 小型代码气味

`NotchGeometry.from(...)` 的 `horizontalGap` 目前主要用于 guard，`screenFrame` 也未被核心布局消费。

除非新增 settings geometry 自然需要，否则不要顺手重构。

---

# 3. 产品与交互决策

## 3.1 设置入口

点击任一 satellite 都执行：

```text
toggleSettingsBar()
```

包括 collapsed 和 hover-expanded satellite。

不要区分左右设置，不要右键菜单，不要双击。

## 3.2 Click target

视觉 orb 保持当前极小尺寸，但交互区域不能只等于 ring stroke。

建议：

```text
visual orb ≈ 14 pt
interaction surface ≈ 22–24 pt
```

satellite 整体作为 plain SwiftUI control / content shape；透明 hit target 不改变视觉尺寸。

原则：

> 视觉仍然极小，点击不需要像素级瞄准。

## 3.3 设置条位置

设置条与硬件 notch 对齐：

```text
            [ hardware notch ]
                    ↓ 6 pt
          [ compact settings bar ]
```

水平：

```text
settingsBar.centerX == hardwareNotch.centerX
```

垂直：

```text
settingsBar.top ≈ notchBottom - 6pt
```

在 `NotchGeometry` 增加真实 geometry：

- `notchCenterX`
- `notchBottomEdge`

不要硬编码机型坐标。

## 3.4 设置条尺寸

建议首轮：

```text
width: 232–244 pt
height: 42–46 pt
corner radius: 12–14 pt
notch vertical gap: 6 pt
horizontal padding: 10–12 pt
```

真机允许 ±4 pt 微调，但不要扩张成 300+ pt。

## 3.5 设置内容

正常状态只有：

```text
Launch at Login   [switch]   |   Quit
```

建议英文 copy：

```text
Launch at Login
Quit
```

不要增加 Refresh / About / Version / Update 等任何附加项。

---

# 4. Launch at Login 技术方案

## 4.1 使用 Apple ServiceManagement

当前 Deployment Target 为 macOS 15，直接使用：

```swift
import ServiceManagement

SMAppService.mainApp
```

需要：

```swift
SMAppService.mainApp.status
try SMAppService.mainApp.register()
try SMAppService.mainApp.unregister()
SMAppService.openSystemSettingsLoginItems()
```

不要使用：

- `SMLoginItemSetEnabled`
- 自建 `LaunchAgent.plist`
- `launchctl`
- helper executable
- daemon
- 第三方 LaunchAtLogin package

## 4.2 不用 UserDefaults 保存启动状态

唯一 source of truth：

```text
SMAppService.mainApp.status
```

不要额外存 `UserDefaults.launchAtLogin`，避免系统状态与 App 本地值漂移。

## 4.3 状态模型

新增：

```swift
enum LaunchAtLoginState: Equatable {
    case disabled
    case enabled
    case requiresApproval
    case unavailable
}
```

映射：

```text
.enabled          → enabled
.notRegistered    → disabled
.requiresApproval → requiresApproval
.notFound         → unavailable
@unknown default  → unavailable
```

## 4.4 Toggle

disabled → ON：

```swift
try SMAppService.mainApp.register()
```

完成后重新读取 status，不把 UI 本地值当最终真相。

enabled → OFF：

```swift
try SMAppService.mainApp.unregister()
```

完成后重新读取 status。

关闭开机启动后，当前 CodexSatellites **继续运行**。

## 4.5 requiresApproval

不要伪装成正常 enabled。

紧凑呈现：

```text
Launch at Login   Review…   |   Quit
```

`Review…`：

```swift
SMAppService.openSystemSettingsLoginItems()
```

只打开系统 Login Items 设置，不绕过系统批准。

## 4.6 unavailable

显示 `—` 或 disabled control；不 crash、不循环 register，OSLog 记录；Quit 始终可用。

---

# 5. Quit 行为

使用：

```swift
NSApp.terminate(nil)
```

不要：

- `exit(0)`
- shell kill
- unregister Login Item
- 弹确认框

语义：

```text
Quit now ≠ Disable Launch at Login
```

如果 Launch at Login 已开启，Quit 只结束当前实例，下次登录仍自动启动。

现有 `applicationWillTerminate` 会调用 `overlayController.stop()`，继续复用。

---

# 6. Window 架构

新增第三个 panel：

```text
QuotaOverlayController
├── leftPanel
├── rightPanel
└── settingsPanel
```

不要新建 Settings WindowController 层。

Settings Panel 建议：

```text
NSPanel
styleMask: [.borderless, .nonactivatingPanel]
isOpaque = false
backgroundColor = .clear
hasShadow = false
hidesOnDeactivate = false
isFloatingPanel = true
level = .statusBar
collectionBehavior = [.canJoinAllSpaces, .stationary]
isExcludedFromWindowsMenu = true
ignoresMouseEvents = false
becomesKeyOnlyIfNeeded = false
```

不要调用：

```text
makeKeyAndOrderFront
NSApp.activate
setActivationPolicy(.regular)
```

目标：用户点击 satellite / 设置条时，原前台 App 仍保持 active。

---

# 7. SettingsBarView

新增：

```text
Views/SettingsBarView.swift
```

建议 interface：

```swift
struct SettingsBarView: View {
    let launchAtLoginState: LaunchAtLoginState
    let onSetLaunchAtLogin: (Bool) -> Void
    let onReviewLoginItems: () -> Void
    let onQuit: () -> Void
}
```

View 不直接调用 `SMAppService`。

## 7.1 视觉

优先系统 material：

```swift
.background(
    .regularMaterial,
    in: RoundedRectangle(cornerRadius: 13, style: .continuous)
)
```

可加极弱 semantic border 和 soft shadow。

不要：

- Liquid Glass 专属 API
- glow
- gradient
- black Dynamic Island
- neon
- 常驻鲜红 Quit 按钮

设置条应像临时 macOS utility surface，而不是第三个视觉主体。

Quit 建议使用 `power` SF Symbol + `Quit`，默认 secondary/primary 语义色。

---

# 8. Satellite 点击

给 `QuotaOrbView` 增加：

```swift
let onActivate: () -> Void
```

推荐 satellite 整体为 plain button，而不是只把 `onTapGesture` 挂在 Circle stroke 上。

要求：

- `.buttonStyle(.plain)`
- 无默认蓝色
- 视觉不变
- accessibility role 正确
- collapsed / expanded 都可点击

action：

```text
QuotaOverlayController.toggleSettingsBar()
```

---

# 9. Hover 与 Settings 共存

保持两个概念：

```text
quotaExpanded
settingsVisible
```

推荐规则：

```text
effectiveExpanded = hoverExpanded OR settingsVisible
```

因此设置条打开时，左右百分比保持展开，不会在鼠标移向设置条时突然收起。

如果不想重命名现有 `expanded`，可以保持字段，但 `settingsVisible == true` 时禁止 collapse；隐藏设置条后重新执行一次 hover 判断。

---

# 10. 设置条显示与关闭

Show：

1. refresh Launch at Login state
2. render `SettingsBarView`
3. 根据 notch geometry 算 final frame
4. 从 notch 下缘附近 order front
5. 轻微向下 slide + fade in

Hide 条件：

1. 再次点击任一 satellite
2. 点击设置条和两个 satellite 之外
3. geometry 失效
4. stop / terminate

不要依赖原 3 秒 hover collapse 来关闭 settings。

---

# 11. Click-outside

沿用现有 global/local monitor 模式，新增最小 `.leftMouseDown` monitor。

inside 判断：

```text
leftPanel.frame.contains(point)
OR rightPanel.frame.contains(point)
OR settingsPanel.frame.contains(point)
```

都不是则：

```text
hideSettingsBar()
```

**不要用 `leftPanel.frame.union(rightPanel.frame)` 做 click hit test**，因为 bounding union 会把整个硬件刘海跨度都视为 inside。

local monitor 关闭设置条后必须把原 event 继续返回，让目标 App 正常收到点击。

---

# 12. 动效

Show：

```text
duration ≈ 0.18 s
alpha: 0 → 1
y: finalY + 6 → finalY
```

Hide：

```text
duration ≈ 0.14–0.16 s
alpha: 1 → 0
y: finalY → finalY + 4~6
```

无 spring overshoot / bounce。

读取：

```swift
NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
```

Reduce Motion 开启时禁用 slide，只做极短 fade 或直接 show/hide。

---

# 13. NotchGeometry 最小扩展

新增：

```text
notchBottomEdge
```

`notchCenterX` 可为计算属性：

```text
(notchLeftEdge + notchRightEdge) / 2
```

`notchBottomEdge` 来自真实 auxiliary top area：

```text
topBand.minY
```

不要用固定 menu bar height 推导。

新增单测，保留负 screen origin 覆盖。

---

# 14. LaunchAtLoginService

新增：

```text
Services/LaunchAtLoginService.swift
```

不要 singleton。

为测试保留最小 system seam：

```swift
@MainActor
protocol LoginItemServicing: AnyObject {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

extension SMAppService: LoginItemServicing {}
```

然后：

```swift
@MainActor
final class LaunchAtLoginService {
    private let appService: LoginItemServicing

    init(appService: LoginItemServicing = SMAppService.mainApp) {
        self.appService = appService
    }

    func state() -> LaunchAtLoginState
    func setEnabled(_ enabled: Bool) throws
}
```

`setEnabled` 幂等：

```text
enabled + enable            → no-op
notRegistered + disable     → no-op
notRegistered + enable      → register
enabled + disable           → unregister
requiresApproval + disable  → unregister
requiresApproval + enable   → no duplicate register
```

---

# 15. 文件范围

新增：

```text
Services/LaunchAtLoginService.swift
Views/SettingsBarView.swift
Tests/LaunchAtLoginServiceTests.swift
```

修改：

```text
Services/NotchGeometry.swift
Views/QuotaOrbView.swift
Window/QuotaOverlayController.swift
Tests/NotchGeometryTests.swift
CodexSatellites.xcodeproj/project.pbxproj
```

文档同步：

```text
00_README.md
01_PRODUCT_UX_SPEC.md
02_TECHNICAL_ARCHITECTURE.md
04_TEST_ACCEPTANCE.md
```

如果继续保留 `CodexSatellites-v0.1-COMBINED.md`，最后机械式重新生成，使其与分拆文档一致。

不要改：

```text
Models/CodexQuotaSnapshot.swift
Services/CodexUsageClient.swift
Codex endpoint
auth parsing
quota classification
60s refresh
stale semantics
```

除非回归测试暴露真实 bug。

---

# 16. 原 SPEC 更新规则

原 v0.1 禁止 `Settings 窗口`、`Click-to-pin`、`点击展开 Dashboard`。

本任务只把第一条细化为：

```text
Standalone Settings Window：仍禁止
Compact inline Settings Bar：允许，仅 Launch at Login + Quit
```

Click-to-pin、Dashboard、menu bar、多 Provider、通知、History、Cost 等继续禁止。

---

# 17. 自动化测试

现有测试全部继续通过。

新增 `LaunchAtLoginServiceTests`，使用 fake service，覆盖：

1. enabled → enabled
2. notRegistered → disabled
3. requiresApproval → requiresApproval
4. notFound → unavailable
5. disabled→enable 只 register 一次
6. enabled→enable 不重复 register
7. enabled→disable 只 unregister 一次
8. disabled→disable 不 unregister
9. requiresApproval→disable unregister
10. register/unregister error 能上抛，不 crash

**单测不得真的修改本机 Login Items。**

NotchGeometry 新增 center / bottom edge 测试。

---

# 18. 真机 UI 验收

必须在真实带刘海 MacBook 完成。

### A. 启动
- satellites 位置与现版本一致
- 默认无 settings
- 无 Dock icon
- 无 menu bar status item

### B. Hover
- 任一侧 hover 仍同步展开
- 动画无回归
- 未打开 settings 时离开仍按原规则 collapse

### C. Click
- 点击左右任一 satellite 都能打开 settings
- settings 向下出现
- 原前台 App 仍 active

### D. Click outside
- settings 立即 dismiss
- 原点击仍传递给目标 App
- 不吞点击

### E. Launch at Login
- OFF→ON 后读取真实 status
- ON→OFF 后 App 当前实例继续运行
- requiresApproval 不伪装成 enabled

### F. Quit
- 点击后进程退出
- panels 全部消失
- 如果 Login Item 原本 enabled，不得 unregister

### G. 登录实际验证
用稳定路径 `.app`：

```text
Launch at Login ON
→ logout/login 或 reboot
→ 自动出现

Launch at Login OFF
→ logout/login 或 reboot
→ 不自动出现
```

不要只以 `SMAppService.status` 代替真实登录验证。

---

# 19. Build / Test Gate

实施前记录：

```bash
git status --short
git rev-parse HEAD
```

基线和终态都执行：

```bash
xcodebuild   -project CodexSatellites.xcodeproj   -scheme CodexSatellites   -configuration Debug   build

xcodebuild   -project CodexSatellites.xcodeproj   -scheme CodexSatellites   -destination 'platform=macOS'   test
```

现有开发入口继续使用：

```bash
./script/build_and_run.sh
./script/build_and_run.sh --verify
./script/build_and_run.sh --logs
./script/build_and_run.sh --telemetry
```

如果签名失败，明确区分源码 build/test 与 signing/distribution 问题，不通过关闭安全机制假装发行验证通过。

---

# 20. 实施顺序

1. 基线 build/test + 真机 hover。
2. 先测后改 `NotchGeometry`。
3. 先写 fake tests，再实现 `LaunchAtLoginService`。
4. 实现静态 `SettingsBarView`。
5. 让左右 satellite 接收 click，确认不抢焦点。
6. 添加第三个 `settingsPanel` 与 show/hide 动画。
7. 添加 click-outside。
8. 接入 Launch at Login 与 Quit。
9. 完整回归 + 真实 logout/login。
10. 更新规范文档。

---

# 21. 样式验收

视觉：

- macOS utility surface
- system material
- continuous corner
- 弱边框/阴影
- 无彩色噪声
- 文本和 switch 垂直居中

空间：

- 从 notch 下方自然出现
- 不贴太紧、不漂太远
- satellite 展开不导致 settings 水平漂移

动效：

- click 立即响应
- show 约 180ms
- dismiss 更快
- 无 bounce
- Reduce Motion 正确

交互：

- 不需要精准点 ring stroke
- 不抢焦点
- click outside 自然关闭
- settings 打开时 quota 不闪烁 collapse

---

# 22. 严禁范围扩张

禁止：

```text
普通 Settings Window
SwiftUI Settings scene
MenuBarExtra / NSStatusItem
右键菜单
Refresh
About
版本信息
更新系统
Sparkle
LaunchAgent plist
launchctl
helper / daemon
UserDefaults 保存 Login Item truth
通知
登录 / OAuth / Keychain
多账号 / 多 Provider
Cost / History / Reset Credits
主题 / 动画设置
```

---

# 23. 竞品参考边界

可以借鉴逻辑，不复制代码。

### CodexIsland
参考：
- accessory app 仍提供 Quit / Launch at Login
- `SMAppService.mainApp`
- 控制入口与 notch UI 空间关联

不复制：
- 完整 Settings Window
- Usage/Cost/History
- 具体 Store/View 实现

### NOTCHY LIMIT
参考：
- Quit 用正常 `NSApplication.terminate`
- Login Item 状态来自 ServiceManagement

不复制：
- 完整 Settings window
- menu bar fallback
- onboarding
- Provider/AppState 架构

CodexSatellites 应继续比它们更小。

---

# 24. 最终架构

```text
CodexSatellitesApp
        │
        ▼
QuotaOverlayController
        │
        ├── CodexUsageClient
        ├── LaunchAtLoginService
        ├── leftPanel  → QuotaOrbView
        ├── rightPanel → QuotaOrbView
        └── settingsPanel → SettingsBarView
```

仍然没有 SettingsStore、Settings Window、MenuBar Controller、Router、Coordinator。

---

# 25. Release Gate

全部满足才能完成：

- [ ] quota / auth 行为未修改
- [ ] 现有 tests 全过
- [ ] LaunchAtLoginService tests 全过
- [ ] satellite 外观/位置无回归
- [ ] hover 无回归
- [ ] 任一 satellite 可打开 settings
- [ ] settings 位于 notch 正下方
- [ ] settings 只含 Launch at Login + Quit
- [ ] click outside 正确
- [ ] 不抢 active application
- [ ] Login Item 使用 `SMAppService.mainApp`
- [ ] 不用 UserDefaults 保存系统真相
- [ ] requiresApproval 正确
- [ ] Quit 不 unregister
- [ ] Login ON 经真实 logout/login 或 reboot 验证
- [ ] Login OFF 经真实 logout/login 或 reboot 验证
- [ ] Reduce Motion 下无 slide
- [ ] 无第三方依赖
- [ ] 无 menu bar
- [ ] 无普通 Settings Window
- [ ] 文档同步
- [ ] 无无关重构

---

# 26. Agent 最终汇报格式

```text
## Implemented
- ...

## Files changed
- ...

## Automated validation
- build: PASS/FAIL
- tests: X passed / Y failed

## Manual macOS validation
- satellite click:
- settings animation:
- focus behavior:
- Launch at Login ON:
- Launch at Login OFF:
- Quit:

## Remaining release concerns
- bundle identifier freeze:
- signing/notarization:
- anything not validated:
```

不要声称未实际执行的真机 / logout / reboot 验证已通过。

---

# 27. 参考

Apple：

- https://developer.apple.com/documentation/servicemanagement/smappservice
- https://developer.apple.com/documentation/servicemanagement/smappservice/status-swift.enum/enabled
- https://developer.apple.com/documentation/ServiceManagement/SMAppService/unregister()
- https://developer.apple.com/documentation/appkit/nsworkspace/accessibilitydisplayshouldreducemotion

项目：

- https://github.com/NTLx/CodexSatellites

竞品：

- https://github.com/ericjypark/codex-island
- https://github.com/I-N-SILVA/NOTCHYLIMIT

---

## 最终原则

> **CodexSatellites 仍然首先是两个安静的 quota satellites。设置条只负责让用户掌控“是否随系统启动”和“现在退出”，而不应该成为产品的新中心。**
