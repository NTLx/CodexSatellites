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

- `01_PRODUCT_UX_SPEC.md`：当前产品边界、交互、视觉、状态与非目标。
- `02_TECHNICAL_ARCHITECTURE.md`：当前真实架构、数据流、Codex usage 解析、窗口与刘海几何。
- `04_TEST_ACCEPTANCE.md`：当前单元、集成、人工 UI 验收与 v0.1 Release Gate。
- `06_RESEARCH_REFERENCES.md`：外部 API、竞品与历史研究背景。

开发或修改功能前，先读取 Product SPEC 与 Technical Architecture；完成修改后按 Test & Acceptance 执行验证。

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
