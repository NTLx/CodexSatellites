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
