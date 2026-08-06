# 飞书 × Codex 本地桥

通过飞书私聊家里 Mac 上的 Codex，默认续接创建本项目时的桌面任务。模型调用使用本机 Codex 的 ChatGPT 登录和订阅额度，不需要 OpenAI API Key。

## 1. 创建飞书应用

1. 进入[飞书开放平台](https://open.feishu.cn/app)，创建“企业自建应用”。
2. 开启“机器人”能力。
3. 添加权限：接收用户发给机器人的单聊消息，以及以应用身份发送消息。
4. 在“事件与回调”选择“使用长连接接收事件”。
5. 订阅 `im.message.receive_v1`（接收消息 v2.0）。
6. 发布应用，并把机器人添加到可用范围。

长连接不需要公网 IP、域名或内网穿透。

## 2. 配置

```bash
cd "/Users/hansangbai/Documents/New project/feishu-codex-bridge"
cp .env.example .env
```

在 `.env` 填入飞书 `App ID` 和 `App Secret`。`CODEX_THREAD_ID` 已预填当前桌面任务：

```text
019f6636-cbb1-7791-81b7-c122288f40ee
```

首次调试可以暂时把 `ALLOWED_FEISHU_OPEN_IDS` 留空。给机器人发一条消息后，终端会打印发送者 `open_id`；随后务必填入并重启服务。

## 3. 启动

先确认 Codex 使用的是 ChatGPT 订阅登录：

```bash
/Applications/ChatGPT.app/Contents/Resources/codex login status
npm install
npm start
```

飞书中直接发送文字即可。可用命令：

- `/status`：查看是否正在执行
- `/thread`：查看当前 Codex 任务 UUID
- `/thread <UUID>`：切换到另一个已有任务
- `/open`：在桌面 Codex 中打开并刷新当前任务
- `/new`：让下一条消息创建新任务
- `/stop`：中断当前执行

默认在每次飞书任务完成后通过 `codex://threads/<UUID>` 重新打开对应桌面任务，
让外部 CLI 写入的飞书消息和 Codex 回复在窗口中刷新。设置
`OPEN_CODEX_THREAD_AFTER_REPLY=false` 可关闭自动打开。

## 当前任务续接的边界

桥接器通过官方 Codex CLI 的 `exec resume <UUID>` 续接，因此会读取同一任务的历史上下文。不要在桌面端和飞书端同时给同一个任务发送新消息；桥接器内部会串行处理飞书消息，但无法替桌面端排队。

## 安全建议

- 保持 `CODEX_SANDBOX=workspace-write`。
- 设置 `ALLOWED_FEISHU_OPEN_IDS`，不要把机器人开放给所有成员。
- 不要使用 `--dangerously-bypass-approvals-and-sandbox`。
- 家中电脑建议开启磁盘加密，并为机器人使用单独的飞书应用。

## macOS 后台自启动

本项目附带 `com.hansangbai.feishu-codex-bridge.plist`。安装后的常用命令：

```bash
# 查看状态
launchctl print gui/$(id -u)/com.hansangbai.feishu-codex-bridge

# 重启（修改 .env 后执行）
launchctl kickstart -k gui/$(id -u)/com.hansangbai.feishu-codex-bridge

# 查看日志
tail -f bridge.log bridge.error.log
```

另有 `com.hansangbai.keep-awake-while-codex` 服务：Codex 桌面应用运行时阻止
Mac 因空闲进入系统睡眠，退出应用后恢复正常；它不会阻止屏幕自动熄灭。
