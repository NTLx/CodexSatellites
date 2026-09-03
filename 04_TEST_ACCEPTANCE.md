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
