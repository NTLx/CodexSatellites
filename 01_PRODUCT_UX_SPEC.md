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
