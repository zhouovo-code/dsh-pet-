# dsh-pet · DSH 看板娘余额挂件

> 一个浮在 **DSH（DeepSeek Harness）Web GUI** 右下角的看板娘小挂件：实时显示 DeepSeek 余额与今日用量，可以点击、抚摸互动，会换表情、会说话、会睡觉。

![四种表情预览](assets/previews-all.png)

*(左→右：常态 / 慌张 / 偷懒 / 害羞)*

---

## ✨ 功能

- **余额与用量**：读取 DeepSeek 官方账户接口的余额；今日用量按"运行时观察到的余额下降"估算，充值不会被算成用量
- **四种表情**：常态、慌张、偷懒（趴电脑睡着）、害羞，随状态自动切换，也可手动预览
- **互动**：单击摸摸、按住抚摸、拖动挪位置、双击刷新余额；连点会让她越来越不耐烦 😆
- **陪伴感**：闲置会说话、30 秒不管她会睡着、钱包告急会冒汗摊手
- **音效 + 粒子**：可一键静音 / 关闭动效
- **完全本地**：不依赖任何第三方服务，除余额查询外不联网

---

## 📦 安装

### 1. 放到插件目录

下载 Release 里的 `dsh-pet-vX.Y.Z.zip`，解压到 DSH 的插件目录：

| 系统 | 路径 |
| --- | --- |
| Windows | `C:\Users\<你的用户名>\.dsh\plugins\dsh-pet\` |
| macOS / Linux | `~/.dsh/plugins/dsh-pet/` |

解压后应该看到：

```
.dsh/plugins/dsh-pet/
├── package.json
├── lib/
│   ├── host.js      ← 宿主半边（余额查询 + 接口）
│   └── client.js    ← 客户端半边（挂件界面）
└── assets/          ← 立绘素材
```

> 如果你设置了 `DSH_HOME` 环境变量，插件目录是 `$DSH_HOME/plugins/dsh-pet/`（素材路径按插件自身位置解析，放哪都能跑）。

### 2. 在 Web profile 里启用

编辑 `~/.dsh/profiles/web/cordis.patch.yml`，加入：

```yaml
- insert:
    - id: dsh-pet
      name: 'file:///C:/Users/<你的用户名>/.dsh/plugins/dsh-pet/lib/host.js'
```

要点：

- 路径必须是 **`file:///` 开头的 URL**，并且**全部用正斜杠 `/`**（Windows 也一样）
- macOS / Linux 示例：`name: 'file:///Users/you/.dsh/plugins/dsh-pet/lib/host.js'`
- 该 profile 的 `patchReload` 是 `live`，保存后宿主会立即重载；**客户端界面需要刷新浏览器页面**才会更新

### 3. 刷新 Web GUI

浏览器打开 DSH Web GUI 后按 **Ctrl + Shift + R** 强刷，右下角就会出现看板娘。

### 4. 让余额能显示（可选）

余额查询需要 DeepSeek API Key，按以下顺序解析：

1. 环境变量 `DEEPSEEK_API_KEY`
2. DSH 托管凭据文档 `~/.dsh/.credentials.yaml` 的 `refs:` 段

**没有 Key 也能用**：挂件照常显示、照常能互动，只是余额区域会显示错误提示。

> 想换接口地址（例如自建代理），设置环境变量 `DEEPSEEK_BASE_URL` 即可，默认 `https://api.deepseek.com`。

---

## 🎮 互动与表情

### 鼠标

| 操作 | 效果 |
| --- | --- |
| 单击 | 摸摸 + 弹跳/转圈 + 心心粒子 + 音效 |
| 按住拖动 | 抚摸她 / 挪动位置（位置会被记住） |
| 快速连点 | 3 下兴奋、5 下慌张、6 下生气（生气状态会一直持续到冷静） |
| 双击 | 立即刷新余额 |
| 悬停 | 动作节拍加快 |

### 气泡按钮

`刷新` · `音效开/关` · `动效开/关` · `表情` · `玩法` · `收起`

「**表情**」按钮点一下直接切到**害羞**，再点依次切换：常态 → 慌张 → 偷懒 → 自动。

### 表情触发

| 表情 | 触发条件 |
| --- | --- |
| 😊 常态 | 默认 |
| 😰 慌张 | 余额 < ¥10（3.6 秒）/ < ¥3（5.2 秒）、5 秒内连点 5 下、生气状态全程 |
| 😴 偷懒 | **闲置 30 秒**后睡着（鼠标一动就惊醒） |
| ☺️ 害羞 | 连点 3 下、被摸醒的瞬间、每抚摸 4 次；或点「表情」按钮直达 |

优先级：睡眠 > 害羞 > 慌张 > 常态。

---

## 🔌 接口一览

宿主半边注册在 Web 服务上（仅供本挂件使用，均为本地请求）：

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| GET | `/pet-api/state` | 余额 / 今日用量 / 互动计数 / 设置 |
| GET | `/pet-api/asset/<name>.png` | 立绘素材（`no-cache`，文件名做白名单校验） |
| POST | `/pet-api/refresh` | 强制刷新余额 |
| POST | `/pet-api/event` | 挂件遥测（mount / pet / stroke / move / expression） |
| GET | `/pet-api/diag` | 自检：客户端资源是否在启动图里、凭据是否就绪 |

数据落盘位置：`<插件目录>/data/usage.json`（用量估算）、`data/widget.log`（遥测）。

---

## 📁 文件结构

```
dsh-pet/
├── package.json          DSH 插件声明（dsh.client.platform = web）
├── lib/
│   ├── host.js           宿主半边：余额查询、素材服务、遥测落盘
│   └── client.js         客户端半边：单文件 React 组件（无构建步骤）
├── assets/
│   ├── pet20-full.png    常态
│   ├── pet20-panic.png   慌张
│   ├── pet20-sleepy.png  偷懒
│   ├── pet22-shy.png     害羞
│   ├── pet20-avatar.png  收起成小圆牌时的头像
│   └── previews-all.png  预览图
├── tools/                立绘处理脚本（抠图 / 对齐 / 自检，见 tools/README.md）
├── README.md
└── LICENSE
```

> `lib/client.js` 是**已构建产物**：它必须以 `window.__ModuleLoader__.load({ id, factory })` 的包装形式存在，运行时通过 `require("react")` 取 React，不使用 JSX（用 `react.createElement`）。改完客户端代码后，需要刷新浏览器页面才能生效。

---

## ❓ 常见问题

**挂件没出现？**
1. 确认 `cordis.patch.yml` 里的路径是 `file:///` + 正斜杠，且文件真实存在
2. 宿主重载日志里是否有报错；可访问 `/pet-api/diag` 看 `clientEntryPresent` 是否为 `true`
3. 浏览器 **Ctrl + Shift + R** 强刷（普通 F5 有时会吃缓存）

**改了 `lib/client.js` 但界面没变？**
客户端代码是宿主启动时快照进启动图的。把 profile 里的插件条目临时改成 `[]` 保存、再改回来（触发重挂载），然后刷新浏览器。改了宿主代码（`lib/host.js`）则**必须换文件名**再指向新文件，因为 Node 会按 URL 缓存 ES 模块。

**余额一直显示错误？**
检查 `DEEPSEEK_API_KEY` 是否可用（`/pet-api/diag` 里的 `hasApiKey`）。

**换了立绘素材？**
浏览器会缓存同名图片。本插件已把素材响应头设为 `no-cache`，因此替换同名文件后刷新即可；如果仍看到旧图，改用新文件名最稳妥。

**抠图有黑边/白边？**
原图透明背景时，透明像素的 RGB 往往是 `0,0,0`；用"白色键控"会把它们当成实心黑，于是出现黑边。正确做法是直接用源图的 alpha 通道当遮罩（`tools/` 里的脚本就是这么做的）。

---

## 📄 License

[MIT](LICENSE) © 贡献者

`assets/` 中的角色立绘随本项目一起提供；如果你要再分发，请保留本说明。
