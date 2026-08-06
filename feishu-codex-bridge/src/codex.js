import { spawn } from 'node:child_process';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';

export class CodexRunner {
  constructor(config, state, saveState) {
    this.config = config;
    this.state = state;
    this.saveState = saveState;
    this.active = null;
  }

  stop() {
    if (!this.active) return false;
    this.active.kill('SIGINT');
    return true;
  }

  openThread() {
    if (!this.state.threadId) return false;
    const child = spawn('/usr/bin/open', [`codex://threads/${this.state.threadId}`], {
      detached: true,
      stdio: 'ignore',
    });
    child.unref();
    return true;
  }

  async run(prompt) {
    if (this.active) throw new Error('已有任务正在执行，请等待完成或发送 /stop。');

    const outputPath = path.join(os.tmpdir(), `feishu-codex-${process.pid}-${Date.now()}.txt`);
    const args = this.state.threadId
      ? ['exec', 'resume', this.state.threadId, '-', '--json', '-o', outputPath]
      : [
          'exec', '-', '--json', '-o', outputPath,
          '-C', this.config.workdir,
          '--sandbox', this.config.sandbox,
          '--skip-git-repo-check',
        ];

    const child = spawn(this.config.codexBin, args, {
      cwd: this.config.workdir,
      env: process.env,
      stdio: ['pipe', 'pipe', 'pipe'],
    });
    this.active = child;
    child.stdin.end(prompt);

    let stdout = '';
    let stderr = '';
    child.stdout.setEncoding('utf8');
    child.stderr.setEncoding('utf8');
    child.stdout.on('data', (chunk) => { stdout += chunk; });
    child.stderr.on('data', (chunk) => { stderr += chunk; });

    const exitCode = await new Promise((resolve, reject) => {
      child.once('error', reject);
      child.once('close', resolve);
    }).finally(() => { this.active = null; });

    for (const line of stdout.split(/\r?\n/)) {
      try {
        const event = JSON.parse(line);
        const threadId = event.thread_id || event.threadId ||
          (event.type === 'thread.started' ? event.thread_id : null);
        if (threadId && threadId !== this.state.threadId) {
          this.state.threadId = threadId;
          this.saveState(this.state);
        }
      } catch {}
    }

    let answer = '';
    try { answer = (await fs.readFile(outputPath, 'utf8')).trim(); } catch {}
    await fs.rm(outputPath, { force: true });

    if (exitCode !== 0) {
      const detail = stderr.trim() || stdout.trim() || `Codex 退出码 ${exitCode}`;
      throw new Error(detail.slice(-4000));
    }
    if (this.config.openThreadAfterReply) this.openThread();
    return answer || '任务已完成，但 Codex 没有返回文本结果。';
  }
}
