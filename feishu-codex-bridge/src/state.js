import fs from 'node:fs';
import path from 'node:path';
import { root } from './config.js';

const statePath = path.join(root, '.state.json');

export function loadState(initialThreadId) {
  try {
    return { threadId: initialThreadId, ...JSON.parse(fs.readFileSync(statePath, 'utf8')) };
  } catch {
    return { threadId: initialThreadId };
  }
}

export function saveState(state) {
  fs.writeFileSync(statePath, `${JSON.stringify(state, null, 2)}\n`, { mode: 0o600 });
}
