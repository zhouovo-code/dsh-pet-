![dsh-pet 看板娘余额挂件](https://cdn.jsdelivr.net/gh/zhouovo-code/dsh-pet-@main/assets/banner.png)

# dsh-pet · 看板娘余额挂件

**MIT 许可** · **Windows / macOS / Linux** · **DeepSeek Harness 插件** · **零运行时依赖**

> 浮在 **DSH（DeepSeek Harness）Web GUI** 右下角的看板娘小挂件：实时显示 DeepSeek 余额与今日用量，能点、能摸、会换表情、会说话、会趴电脑睡着。

---

## 🚀 一行安装（复制粘贴即可）

**Windows（PowerShell，含下载与解压）：**

```powershell
$z="$env:TEMP\dsh-pet.zip"; iwr "https://github.com/zhouovo-code/dsh-pet-/releases/download/v1.0.0/dsh-pet-v1.0.0.zip" -OutFile $z; Expand-Archive $z "$env:TEMP\dsh-pet" -Force; & "$env:TEMP\dsh-pet\dsh-pet\install.cmd"
```

装好后如果 DSH 已经在运行，安装器会**自动帮你打开 GUI**，你只需要在页面上按一次 `Ctrl + Shift + R` ✓

**macOS / Linux：**

```bash
curl -L -o /tmp/dsh-pet.zip https://github.com/zhouovo-code/dsh-pet-/releases/download/v1.0.0/dsh-pet-v1.0.0.zip \
  && unzip -o /tmp/dsh-pet.zip -d /tmp/dsh-pet && bash /tmp/dsh-pet/dsh-pet/install.sh
```

---

## ✅ 适配版本（重要）

| DSH 版本 | 状态 | 说明 |
| --- | --- | --- |
| **`0.1.5-rc.1`**（npm `latest`） | ✅ **已完整实测** | 推荐；也是当前用户最多的版本（`npx @deepseek-ai/dsh web` 默认装到的就是它） |
| `0.1.5-rc.2`（npm `next`） | ⚠️ 未实测 | 装之前建议先按下面的方法确认 |
| `0.1.5-alpha.*` / `0.1.5-rc.1` 以前的老版本（如 `0.1.0-rc.7`） | ❌ 界面不渲染 | 宿主能加载，但右下角不显示；请换到 `0.1.5-rc.1` |

**怎么看自己的版本：**

```bat
npx @deepseek-ai/dsh --version
```

**版本不匹配怎么办**（不用改代码）：

```bat
npx @deepseek-ai/dsh@0.1.5-rc.1 --profile web
```

**装完自检**（浏览器打开）：`http://127.0.0.1:3080/pet-api/diag` —— `clientEntryPresent` 是 `true` 就说明插件已加载。

如果自检通过但右下角还是空的：双击桌面「启动看板娘」（挂件可能被之前点过的「关闭」记住了，见下文）。

---

## ⚡ 30 秒上手

```
0. 先让 DSH 跑起来         ← 顺序很重要：插件挂在 DSH 上，DSH 没运行就看不到她
1. 解压整个文件夹
2. 双击 安装看板娘.cmd
3. 回到你已打开的 DSH 页面，按一次 Ctrl + Shift + R
```

> 看不到余额？那是**还没配置 DeepSeek API Key**（不配也能用，只是余额区没数据）：`setx DEEPSEEK_API_KEY "sk-..."` 然后重开 DSH。详见 [`快速上手.txt`](快速上手.txt)。

安装脚本会**自动在你的桌面创建两个带图标的快捷方式**：

| 桌面快捷方式 | 作用 |
| --- | --- |
| 😊 启动看板娘 | 打开挂件（默认切回你已打开的 DSH 页面，不会重复开标签） |
| 😴 关闭看板娘 | 彻底关闭挂件（连小圆牌都不显示） |

右下角就会出现她 ✓ 更细的说明见包内 **`快速上手.txt`**。

---

## ✨ 功能

| | 功能 |
| --- | --- |
| 💰 | **余额与用量** 读取 DeepSeek 官方账户接口；今日用量按运行时观察到的余额下降估算（充值不计入） |
| 😊 | **四种表情** 常态 / 慌张 / 偷懒（趴电脑睡着）/ 害羞，随状态自动切换 |
| 👆 | **互动** 单击摸摸、按住抚摸、拖动挪位、双击刷新余额；连点会越来越不耐烦 |
| 💬 | **陪伴感** 闲置会说话、30 秒不管她会睡着、钱包告急会冒汗摊手 |
| 🎈 | **音效与粒子** 心心、星星、音符；可一键静音、可关闭动效 |
| ⏻ | **可彻底关闭** 关闭后连小圆牌都不显示，重启后依然保持；想用时双击启动器即可 |
| 🔒 | **完全本地** 除余额查询外不联网，零运行时依赖、无需构建 |

---

## 🖼 四种表情

> 解压后包内顶层就有一张 `看板娘预览.png`，不想看文档的话直接双击它 ✓


![四种表情](https://cdn.jsdelivr.net/gh/zhouovo-code/dsh-pet-@main/assets/previews-all.png)

| 表情 | 触发条件 |
| --- | --- |
| 😊 常态 | 默认 |
| 😰 慌张 | 余额 < ¥10（3.6 秒）/ < ¥3（5.2 秒）、5 秒内连点 5 下、生气状态全程 |
| 😴 偷懒 | **闲置 30 秒**后睡着（碰一下就惊醒） |
| ☺️ 害羞 | 连点 3 下、被摸醒的瞬间、每抚摸 4 次；或点「表情」按钮直达 |

---

## 📦 安装

### 方式一：一键安装（推荐）

| 系统 | 操作 |
| --- | --- |
| **Windows** | 双击 **`install.cmd`**（纯批处理：只用 `xcopy`/`copy`/`echo`，不调用脚本宿主） |
| **macOS / Linux** | 终端执行 `bash install.sh` |

安装脚本会自动完成三件事：

1. 把插件复制到 `~/.dsh/plugins/dsh-pet/`（Windows：`C:\Users\<你>\.dsh\plugins\dsh-pet\`）
2. 把 dsh-pet 条目写进 `~/.dsh/profiles/web/cordis.patch.yml`（已存在则跳过；改前自动备份）
3. 把启动器放进插件目录，并**在桌面创建「启动看板娘 / 关闭看板娘」两个带图标的快捷方式**

> **可重复运行**：不会重复写配置，也不会删除 `data/` 里的用量记录。
>
> **为什么默认不是 .exe？** 早先版本提供过内嵌脚本的 `install.exe` / 启动器 exe，但那是杀软的经典误报特征（未签名 exe + base64 内嵌脚本 + `-ExecutionPolicy Bypass`），**会被火绒等直接查杀** ✗ 现在全部改成纯批处理 / PowerShell 脚本。
> 想要 exe 可以自己编译：`powershell -File tools\build-exe.ps1`（用系统自带 csc.exe，产物请自行加白名单）。

### 方式二：手动安装

1. 把整个文件夹复制到 `~/.dsh/plugins/dsh-pet/`
2. 编辑 `~/.dsh/profiles/web/cordis.patch.yml`，加入：

```yaml
- insert:
    - id: dsh-pet
      name: 'file:///C:/Users/<你的用户名>/.dsh/plugins/dsh-pet/lib/host.js'
```

> 路径必须是 **`file:///` 开头** 且**全部用正斜杠 `/`**（Windows 也一样）。
> macOS / Linux 示例：`name: 'file:///Users/you/.dsh/plugins/dsh-pet/lib/host.js'`

3. 刷新 Web GUI（`Ctrl + Shift + R`）

### 显示余额（可选）

余额查询需要 DeepSeek API Key。**两种方式，推荐第一种。**

**方式 A：环境变量（最简单，不用改任何文件）**

```powershell
setx DEEPSEEK_API_KEY "sk-你的key"     # 之后重开终端 / 重启 DSH
```

**方式 B：写进 DSH 凭据文件 `~/.dsh/.credentials.yaml`**

这个文件**格式很严格**：DSH 启动时会校验，写错会导致 **DSH 直接起不来** ✗

```yaml
version: 1                     # ← 必须顶格、且是数字 1（不要缩进、不要加引号）
refs:
  DEEPSEEK_API_KEY: sk-你的key  # ← 值必须是非空字符串
```

> ⚠️ **常见坑**：把 `version: 1` 缩进到 `refs:` 下面，DSH 启动会报
> `credentials-local: the value for "version" ... must be a string` 并拒绝启动。
> 顶层只允许 `version` / `refs` / `records` 三个键，其余一律报错。
>
> **起不来了怎么救**：把 `.credentials.yaml` 改名为 `.credentials.yaml.bak`，再启动一次即可恢复（然后改用方式 A）。

**没有 Key 也能用**：挂件照常显示与互动，只是余额区显示错误提示。
想换接口地址（如自建代理）设置 `DEEPSEEK_BASE_URL`，默认 `https://api.deepseek.com`。

---

## ⏻ 关闭与手动打开

挂件**默认是打开的**。想彻底关掉：

| 操作 | 效果 |
| --- | --- |
| 点气泡里的「**关闭**」 | **彻底关闭**：连右下角小圆牌都不再渲染（与「收起」不同——收起还留一个小圆牌） |
| 运行 `stop-pet.cmd` | 同上，从外面关（直接写 `data/enabled.json`） |
| 运行 `start-dsh.cmd` | 重新打开（顺带启动/切换 DSH；**4 秒内挂件出现，无需刷新**） |

开关状态由宿主保存在 `data/enabled.json`，所以**重启 DSH 或电脑后依然保持你上次的选择**。

> 实现：客户端每 4 秒轮询一次很轻的 `GET /pet-api/enabled`，因此从外面开关挂件不需要刷新页面。

---

## 🗑 完整卸载

**回到解压出来的文件夹，双击 `uninstall.cmd`**（卸载入口不占桌面位置），它会：

1. 从 `~/.dsh/profiles/web/cordis.patch.yml` 里**只删掉 dsh-pet 那几行**（其他插件的配置一行不动；改前自动备份 `.bak`）
2. 删除插件目录 `~/.dsh/plugins/dsh-pet`
3. 删除桌面上的 启动看板娘 / 关闭看板娘 两个快捷方式

执行前会列清楚要删什么并让你确认（`uninstall.cmd /y` 可跳过确认）。卸载后刷新一下 DSH 页面（Ctrl + Shift + R）即可；想装回来重新解压并双击「安装看板娘.cmd」就行。

---

## 🎮 互动

| 操作 | 效果 |
| --- | --- |
| 单击小圆牌 | 叫出看板娘（收起状态时） |
| 单击她 | 摸摸 + 弹跳/转圈 + 心心粒子 + 音效 |
| 按住拖动 | 抚摸她 / 挪动位置（位置会被记住） |
| 快速连点 | 3 下兴奋、5 下慌张、6 下生气（生气会持续到冷静） |
| 双击 | 立即刷新余额 |
| 悬停 | 动作节拍加快 |

**气泡按钮**：`刷新` · `音效开/关` · `动效开/关` · `表情` · `玩法` · `关闭` · `收起`

「表情」按钮点一下直接切到**害羞**，再点依次切换：常态 → 慌张 → 偷懒 → 自动。

---

## 🔌 接口一览

宿主半边注册在 Web 服务上，均为本地请求：

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| GET | `/pet-api/state` | 余额 / 今日用量 / 互动计数 / 开关状态 |
| GET | `/pet-api/enabled` | 挂件总开关状态 |
| POST | `/pet-api/enabled` | 开/关挂件（`{"enabled": boolean}`，落盘 `data/enabled.json`） |
| GET | `/pet-api/asset/<name>.png` | 立绘素材（`no-cache`，文件名白名单校验） |
| POST | `/pet-api/refresh` | 强制刷新余额 |
| POST | `/pet-api/event` | 挂件遥测（mount / pet / stroke / move / enabled） |
| GET | `/pet-api/diag` | 自检：客户端资源是否在启动图里、凭据是否就绪 |

数据落盘：`<插件目录>/data/usage.json`（用量估算）、`data/widget.log`（遥测）、`data/enabled.json`（开关）。

---

## 📁 文件结构

```
dsh-pet/
├── 安装看板娘.cmd        ← 双击这个安装（中文入口，杀软友好）
├── 卸载看板娘.cmd        ← 想彻底卸载时双击它（不在桌面放快捷方式）
├── 看板娘预览.png        ← 解压后一眼就能看到她会是什么样
├── 快速上手.txt          ← 不看 README 的人看这个
├── README.md
├── LICENSE
├── plugin/               插件本体：lib/（host.js + client.js）、assets/（立绘与图标）、package.json
├── scripts/              install.sh / uninstall.sh（macOS·Linux）+ 启动、关闭、卸载脚本
└── tools/                立绘处理与发版脚本（普通用户可忽略）
```

> `lib/client.js` 是**已构建产物**：必须以 `window.__ModuleLoader__.load({ id, factory })` 包装形式存在，运行时用 `require("react")`，不使用 JSX。改完客户端代码需刷新浏览器页面才生效。

---

## ❓ 常见问题

**挂件没出现？**
1. 确认 `cordis.patch.yml` 里是 `file:///` + 正斜杠，且文件真实存在
2. 访问 `http://127.0.0.1:<端口>/pet-api/diag`，看 `clientEntryPresent` 是否为 `true`
3. 浏览器 **Ctrl + Shift + R** 强刷（普通 F5 有时会吃缓存）

**改了 `lib/client.js` 但界面没变？**
客户端代码在宿主启动时快照进启动图。把 profile 里的插件条目临时改成 `[]` 保存、再改回来（触发重挂载），然后刷新浏览器。改宿主代码（`lib/host.js`）则**必须换文件名**，因为 Node 会按 URL 缓存 ES 模块。

**余额一直显示错误？** 检查 `DEEPSEEK_API_KEY` 是否可用（`/pet-api/diag` 的 `hasApiKey`）。

**DSH 起不来，报 `cordis.patch.yml` 相关的 YAML 错误？**
最快的自救：删掉这个文件（DSH 会把"文件不存在"当成"没有补丁"，直接正常启动）：`Remove-Item "$env:USERPROFILE\.dsh\profiles\web\cordis.patch.yml" -Force`，然后重新双击「安装看板娘.cmd」让它写一份正确的配置。详见 [`快速上手.txt`](快速上手.txt)。

**dsh web 报 `EADDRINUSE: address already in use 127.0.0.1:3080`？**
说明已经有一个 DSH 在跑（一个端口只能跑一个）：直接用已有实例（浏览器打开 `http://127.0.0.1:3080/`），或换端口 `dsh web --port 3081`，或先 `taskkill` 掉旧的。

**DSH 启动直接失败，报 `credentials-local: ...`？**
这不是本插件的问题，是 `~/.dsh/.credentials.yaml` 的结构错了。三种常见写法与对应报错：

| 写法 | 报错 | 修法 |
| --- | --- | --- |
| `refs:` 里多了 `version: 1` 一行 | `the value for "version" ... must be a string` | 删掉 `refs:` 里那一行（顶层保留） |
| 顶层 `version: "1"` 加了引号 | `declares version "1"; this build reads version 1` | 改成不带引号的数字 `version: 1` |
| 没有顶层 `version`（旧扁平格式） | `uses the pre-release flat layout` | 按提示加 `version: 1`，其余缩进到 `refs:` 下 |

顶层只允许 `version` / `refs` / `records` 三个键，其余一律报错。急着用就先把它改名成 `.credentials.yaml.bak` 让 DSH 起来，余额改用环境变量 `DEEPSEEK_API_KEY`。

**被安全软件拦截？** 本包不含任何 exe，只有批处理与 PowerShell 脚本。脚本只做两件事：复制文件、写一行配置；仍被拦请把插件目录加白名单。

**换了立绘素材？** 素材响应头是 `no-cache`，替换同名文件刷新即可；若仍看到旧图，换个文件名最稳。

**抠图有黑边/白边？** 原图透明背景时透明像素 RGB 常是 `0,0,0`，"白色键控"会把它当成实心黑 → 黑边。正确做法是直接用源图 alpha 通道（`tools/` 里的脚本就是这么做的）。

---

## 🙏 致谢

特别感谢 **栖江**（GitHub：[@wdmailang](https://github.com/wdmailang)）在本项目的测试与调试工作中给予的大力协助：

- 在 DSH `0.1.0-rc.7` 环境下发现了「插件宿主加载正常、界面不渲染」的版本兼容问题，并协助定位到客户端 slot 的版本差异；
- 反复验证安装与卸载流程并及时反馈报错信息，`cordis.patch.yml` 的 `[]` 占位符兼容、非 ASCII 内容保护等问题均因此得以及时发现与修复；
- 提供 Windows 与源码构建两套环境进行交叉验证，使本项目的兼容性结论更具代表性。

同时感谢所有试用本插件并提出宝贵意见的朋友们。

---
## 📄 License

[MIT](LICENSE) © 贡献者

`assets/` 中的角色立绘随本项目一起提供；再分发请保留本说明。
