import * as Lark from '@larksuiteoapi/node-sdk';
import { config } from './config.js';
import { loadState, saveState } from './state.js';
import { CodexRunner } from './codex.js';

const state = loadState(config.initialThreadId);
const runner = new CodexRunner(config, state, saveState);
const client = new Lark.Client({
  appId: config.appId,
  appSecret: config.appSecret,
  appType: Lark.AppType.SelfBuild,
  domain: Lark.Domain.Feishu,
});

const seenMessages = new Set();
let queue = Promise.resolve();

async function sendText(chatId, text, replyTo = null) {
  const chunks = splitText(text, config.maxReplyChars);
  for (const chunk of chunks) {
    const data = { content: JSON.stringify({ text: chunk }), msg_type: 'text' };
    if (replyTo) {
      await client.im.message.reply({ path: { message_id: replyTo }, data });
      replyTo = null;
    } else {
      await client.im.message.create({
        params: { receive_id_type: 'chat_id' },
        data: { receive_id: chatId, ...data },
      });
    }
  }
}

function splitText(text, limit) {
  if (text.length <= limit) return [text];
  const chunks = [];
  let rest = text;
  while (rest.length) {
    let cut = Math.min(limit, rest.length);
    if (cut < rest.length) {
      const newline = rest.lastIndexOf('\n', cut);
      if (newline > limit * 0.6) cut = newline;
    }
    chunks.push(rest.slice(0, cut));
    rest = rest.slice(cut).replace(/^\n/, '');
  }
  return chunks;
}

function extractText(data) {
  if (data.message?.message_type !== 'text') return null;
  try {
    const text = JSON.parse(data.message.content).text || '';
    return text.replace(/@_user_\d+/g, '').trim();
  } catch {
    return null;
  }
}

async function handleCommand(text, chatId, messageId) {
  if (text === '/help') {
    await sendText(chatId,
      '直接发送文字即可续接当前 Codex 任务。\n\n' +
      '/status 查看状态\n/thread 查看当前任务 UUID\n/thread <UUID> 切换任务\n/open 在桌面 Codex 打开当前任务\n/new 新建远程任务\n/stop 中断当前执行', messageId);
    return true;
  }
  if (text === '/status') {
    await sendText(chatId,
      `状态：${runner.active ? '执行中' : '空闲'}\n任务：${state.threadId || '尚未创建'}\n目录：${config.workdir}`,
      messageId);
    return true;
  }
  if (text === '/thread') {
    await sendText(chatId, state.threadId || '尚未绑定任务。', messageId);
    return true;
  }
  if (text.startsWith('/thread ')) {
    const id = text.slice(8).trim();
    if (!/^[0-9a-f]{8}-[0-9a-f-]{27}$/i.test(id)) {
      await sendText(chatId, '任务 UUID 格式不正确。', messageId);
      return true;
    }
    state.threadId = id;
    saveState(state);
    await sendText(chatId, `已切换到任务 ${id}`, messageId);
    return true;
  }
  if (text === '/new') {
    if (runner.active) {
      await sendText(chatId, '当前任务仍在执行，请先等待或 /stop。', messageId);
    } else {
      state.threadId = null;
      saveState(state);
      await sendText(chatId, '下一条消息会在配置的工作目录中新建 Codex 任务。', messageId);
    }
    return true;
  }
  if (text === '/open') {
    await sendText(chatId,
      runner.openThread() ? '已让桌面 Codex 打开当前任务。' : '当前还没有可打开的任务。',
      messageId);
    return true;
  }
  if (text === '/stop') {
    await sendText(chatId, runner.stop() ? '已发送中断信号。' : '当前没有执行中的任务。', messageId);
    return true;
  }
  return false;
}

const dispatcher = new Lark.EventDispatcher({}).register({
  'im.message.receive_v1': async (data) => {
    const messageId = data.message?.message_id;
    const chatId = data.message?.chat_id;
    const openId = data.sender?.sender_id?.open_id;
    if (!messageId || !chatId || seenMessages.has(messageId)) return;
    seenMessages.add(messageId);
    setTimeout(() => seenMessages.delete(messageId), 10 * 60 * 1000).unref();

    if (config.allowedOpenIds.size && !config.allowedOpenIds.has(openId)) {
      console.warn(`拒绝未授权用户：${openId || 'unknown'}`);
      return;
    }
    const text = extractText(data);
    if (!text) {
      await sendText(chatId, '第一版暂时只接受文字消息。', messageId);
      return;
    }
    if (await handleCommand(text, chatId, messageId)) return;

    // 飞书事件要求尽快返回，因此将耗时的 Codex 任务放入本地串行队列。
    queue = queue.then(async () => {
      await sendText(chatId, `已收到，正在续接任务 ${state.threadId || '(新任务)'}…`, messageId);
      try {
        const result = await runner.run(text);
        await sendText(chatId, result);
      } catch (error) {
        await sendText(chatId, `执行失败：\n${error instanceof Error ? error.message : String(error)}`);
      }
    });
  },
});

const wsClient = new Lark.WSClient({
  appId: config.appId,
  appSecret: config.appSecret,
  loggerLevel: Lark.LoggerLevel.info,
});

console.log(`飞书桥接服务启动；当前 Codex 任务：${state.threadId || '新任务模式'}`);
console.log(`工作目录：${config.workdir}`);
if (!config.allowedOpenIds.size) {
  console.warn('警告：ALLOWED_FEISHU_OPEN_IDS 为空，目前应用内任何用户都能发起任务。');
}
await wsClient.start({ eventDispatcher: dispatcher });
