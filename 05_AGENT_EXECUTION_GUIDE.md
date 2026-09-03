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
