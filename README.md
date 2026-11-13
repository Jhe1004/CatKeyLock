<div align="center">

<img src="assets/cover.png" alt="CatKeyLock 防猫锁键封面" width="100%" />

<br /><br />

# 🐾 CatKeyLock（防猫锁键）

**猫主子跳上键盘的一瞬间，0.3 秒开启物理防猫结界；外接鼠标与远程桌面照常丝滑工作！**

<p>
  <img src="https://img.shields.io/badge/Platform-macOS%2014%2B-1e3a5f?style=for-the-badge&logo=apple&logoColor=white" alt="macOS 14+" />
  <img src="https://img.shields.io/badge/Language-Swift%20%26%20SwiftUI-F05138?style=for-the-badge&logo=swift&logoColor=white" alt="Swift & SwiftUI" />
  <img src="https://img.shields.io/badge/Cat--Proof-100%25%20Certified-f97316?style=for-the-badge" alt="Cat-Proof Certified" />
  <img src="https://img.shields.io/badge/License-MIT-22c55e?style=for-the-badge" alt="MIT License" />
</p>

</div>

---

## 🚨 案发现场：为什么会有这个项目？

每一个有猫的深夜程序员 / 科研人，都经历过类似的人生至暗时刻：

- 刚刚调试好一段代码正准备保存，12 斤重的英短蓝猫突然一个信仰之跃空降 MacBook 键盘，顺手给老板 / 导师发出了一串极具后现代主义风格的乱码 `asdfghjkl;'`；
- 终端里跑了三天的任务，被主子用精准的肉垫踩出 `Control + C`，功亏一篑；
- 更离谱的是：你想用外接鼠标把它推开，或者躺在床上通过 **ToDesk / UU 远程 / 屏幕共享** 继续操作电脑，结果猫爪还在键盘上持续输出 `Shift` / `Command` 组合技，把远程桌面里的每一个窗口都搅得天翻地覆……

> **痛点核心**：市面上的传统锁键盘工具一锁全锁，连你自己的**外接鼠标**和**远程控制输入**一起封印；而真正需要的，是一个**只对猫爪结界生效、却给人类留后门**的精准防御系统。

于是 **CatKeyLock** 诞生了——主子在你的键盘上把笔记本踩成 45°C 高级电热毯，你照样在旁边用外接鼠标或被窝里的远程桌面淡定干活。

---

## 📜 喵星人与铲屎官的不平等条约

按下锁定暗号（默认 **`⌃⌥⌘L`**）后，系统立即进入 **「只防猫、不防人」** 的精准结界状态：

| 输入来源 | 锁定后待遇 | 说明 |
| :--- | :---: | :--- |
| 🐱 **笔记本内置键盘**（字母 / 空格 / 回车 / 修饰键） | ❌ **全数没收** | 猫踩任意键均被直接吞掉，连 `⌘Q` 也踩不出来，后台小本本还会记账「本次已拦截猫踩 N 次」 |
| 🐱 **顶部系统功能键**（音量 / 亮度 / 媒体播放） | ❌ **全数没收** | 防止半夜猫爪把电脑音量拉到 100% 吓飞全家人 |
| 🐱 **内置触控板**（可选开关，建议开启） | ❌ **精准封印** | 屏蔽触控板移动、轻点/按压点击、双指滚动与多指手势，彻底告别猫屁股乱点桌面 |
| 🖱️ **外接物理鼠标**（有线 / 蓝牙 / 2.4G 接收器） | ✅ **完全放行** | 猫又不会跳到鼠标上去！移动、左右键点击、拖拽、滚轮全程丝滑正常 |
| 📱 **远程控制输入**（ToDesk / UU 远程 / macOS 屏幕共享） | ✅ **100% 放行** | 远控端键盘打字、快捷键、鼠标操作全部不受任何影响 |
| 🔑 **解锁暗号**（再次按下 `⌃⌥⌘L`） | 🔓 **唯一钥匙** | 猫瞎踩一万次也绝对解不开；只有人类双手再次按下同一组暗号才能解除封印（菜单栏亦保留鼠标应急按钮） |

---

## ✨ 界面实拍与状态展示

采用原生 **SwiftUI** 构建，静默驻留右上角菜单栏（不占 Dock 栏），提供浅色 / 深色模式自适应与不抢焦点的毛玻璃顶部悬浮 HUD 提示。

<div align="center">
<table>
  <tr>
    <td align="center" width="50%">
      <strong>⌨️ 浅色模式 · 待命状态</strong><br /><br />
      <img src="assets/ui-light.png" alt="CatKeyLock 浅色待命界面" width="100%" />
    </td>
    <td align="center" width="50%">
      <strong>🔒 深色模式 · 防猫锁定中</strong><br /><br />
      <img src="assets/ui-dark-locked.png" alt="CatKeyLock 深色锁定界面" width="100%" />
    </td>
  </tr>
  <tr>
    <td colspan="2" align="center">
      <strong>✨ 顶部毛玻璃 HUD 悬浮通知（<code>nonactivatingPanel</code> 绝不抢占当前输入框焦点）</strong><br /><br />
      <img src="assets/ui-hud.png" alt="CatKeyLock 悬浮 HUD 提示" width="460" />
    </td>
  </tr>
</table>
</div>

### 更多贴心细节
- **立体键帽可视化录制**：支持自定义任何顺手的组合键，内置防冲突检测，自动拒绝 `⌘Q`、`⌃⌘Q`（系统锁屏）、`⌘W`、`⌘Tab`、`⌘Space` 等危险热键。
- **反卡键护盾**：按 `⌃⌥⌘L` 锁定的瞬间，系统会智能放行用户松开 `⌃⌥⌘` 直到修饰键归零的 `flagsChanged` 事件，防止 `Command` 键卡在按住状态；归零后猫再踩任何修饰键都会被直接拦截。
- **防长按连发 & 0.35s 防抖**：长按组合键触发 `autorepeat` 不会导致锁了又解、解了又锁的鬼畜闪烁。
- **开机自启动 & 音效反馈**：基于 macOS 原生 `SMAppService` 实现一键开机自启，锁定时清脆 `"Tink"` 提示音、解锁时柔和 `"Purr"` 呼噜音效。

---

## 🛠️ 硬核技术原理（一本正经的底层黑科技）

CatKeyLock 在 macOS 最底层的 `kCGHIDEventTap`（`.headInsertEventTap`）挂载全局事件过滤器，通过两个核心字段实现精确外科手术级分流：

1. **区分「本地物理硬件」与「远程控制软件」：`eventSourceUnixProcessID`**
   - 来自真实物理键盘和内置触控板的硬件事件，由 IOHID 驱动直接发出，其 `CGEventField.eventSourceUnixProcessID` 恒等于 **`0`**。
   - **ToDesk**、**UU 远程**、**macOS 屏幕共享 (`ScreensharingAgent`)** 等远程桌面软件通过 `CGEventPost` 注入的事件，CoreGraphics 会自动写入注入进程的 Unix PID（**`> 0`**）。
   - 因此，凡是 `sourcePID != 0` 的事件在锁定期间**无条件放行**，真正做到“本地封印，远控自由”。

2. **区分「内置触控板」与「外接物理鼠标」：`mouseEventSubtype` & 滚动相位**
   - 内置触控板产生的指针移动与点击事件携带 `mouseEventSubtype == 3`（即 `NX_SUBTYPE_MOUSE_TOUCH`），触控滚动带有连续像素与触控相位标识（`scrollWheelEventIsContinuous != 0` 且存在 `ScrollPhase` / `MomentumPhase`），多指手势与 Force Touch 则归属于专属手势事件号（`18, 19, 20, 29~34, 37`）。
   - 外接物理鼠标事件携带 `mouseEventSubtype == 0`（`NX_SUBTYPE_DEFAULT`），滚轮不带触控相位——**全部精准放行**！

---

## 🚀 快速安装与食用指南

### 方式一：直接下载成品（推荐）

1. 前往本仓库右侧 [**Releases**](https://github.com/Jhe1004/CatKeyLock/releases) 下载最新 `CatKeyLock-v1.0.0-macOS-arm64.zip`。
2. 解压后将 `CatKeyLock.app` 拖入 `/Applications` 或 `~/Applications`。
3. 首次打开若遇到 macOS 提示“无法验证开发者”（因为没有花 \$99/年 买苹果开发者签名 😅），只需右键点击 App 选择「打开」，或在终端运行一次：
   ```bash
   xattr -cr /Applications/CatKeyLock.app
   ```

### 方式二：源码一键编译安装（需要 Xcode Command Line Tools）

```bash
git clone https://github.com/Jhe1004/CatKeyLock.git
cd CatKeyLock
bash build.sh
open "$HOME/Applications/CatKeyLock.app"
```

> `build.sh` 会自动先跑完全部 8 项核心状态机单元测试，再生成应用图标、编译 `CatKeyLock.app` 并安装至 `~/Applications/`。

### 首次使用唯一授权

启动后按界面引导前往 **「系统设置 → 隐私与安全性 → 辅助功能」**，打开 **`CatKeyLock`** 开关即可。开启后**无需重启应用**，后台会在 1 秒内自动完成监听挂载。

*(注：若你自己修改源码并重新编译覆盖了 `.app`，由于 ad-hoc 签名哈希会变化，点击界面上的 **「重置记录」** 按钮或在终端运行 `tccutil reset Accessibility com.jianhe.CatKeyLock` 后重开一次开关即可。)*

---

## ⚠️ 严正免责声明

> 本软件仅从操作系统底层拦截猫爪制造的物理键盘与触控板信号，**不对以下连带后果承担任何法律或精神赔偿责任**：
> - 猫主子因发现键盘踩上去居然没反应而发出的高频喵喵抗议；
> - 用尾巴怒甩你脸、咬电源线、或把桌上的绿杯子推下桌的报复性行为；
> - 猫咪直接一屁股坐在键盘中央挡住你半块屏幕导致无法看清代码。

---

## 📄 License

本项目基于 [MIT License](LICENSE) 开源。祝所有铲屎官都能保住自己写到一半的代码与论文！🐾
