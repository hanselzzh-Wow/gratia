const schemaInitializations = new WeakMap<D1Database, Promise<void>>();

const schemaStatements = [
  `CREATE TABLE IF NOT EXISTS wishes (
    id TEXT PRIMARY KEY NOT NULL,
    public_code TEXT NOT NULL UNIQUE,
    requester_name TEXT NOT NULL,
    contact TEXT NOT NULL,
    city TEXT NOT NULL,
    landmark TEXT NOT NULL,
    occasion TEXT NOT NULL,
    message TEXT NOT NULL,
    delivery_type TEXT NOT NULL,
    deadline_text TEXT NOT NULL,
    reward_fen INTEGER NOT NULL DEFAULT 1800,
    publish_fee_fen INTEGER NOT NULL DEFAULT 500,
    status TEXT NOT NULL DEFAULT 'pending_review',
    moderation_note TEXT,
    source TEXT NOT NULL DEFAULT 'web',
    user_id TEXT,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
  )`,
  `CREATE TABLE IF NOT EXISTS providers (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    contact TEXT NOT NULL UNIQUE,
    city TEXT NOT NULL,
    landmarks TEXT NOT NULL,
    availability_note TEXT,
    status TEXT NOT NULL DEFAULT 'available',
    completed_count INTEGER NOT NULL DEFAULT 0,
    last_assigned_at INTEGER,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
  )`,
  `CREATE TABLE IF NOT EXISTS assignments (
    id TEXT PRIMARY KEY NOT NULL,
    wish_id TEXT NOT NULL,
    provider_id TEXT,
    provider_name TEXT NOT NULL,
    provider_contact TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'offered',
    note TEXT,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    accepted_at INTEGER,
    delivered_at INTEGER,
    FOREIGN KEY (wish_id) REFERENCES wishes(id) ON DELETE CASCADE,
    FOREIGN KEY (provider_id) REFERENCES providers(id) ON DELETE SET NULL
  )`,
  `CREATE TABLE IF NOT EXISTS deliverables (
    id TEXT PRIMARY KEY NOT NULL,
    wish_id TEXT NOT NULL,
    assignment_id TEXT,
    kind TEXT NOT NULL,
    url TEXT NOT NULL,
    storage_key TEXT,
    access_token TEXT,
    note TEXT,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (wish_id) REFERENCES wishes(id) ON DELETE CASCADE,
    FOREIGN KEY (assignment_id) REFERENCES assignments(id) ON DELETE SET NULL
  )`,
  `CREATE TABLE IF NOT EXISTS wish_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
    wish_id TEXT NOT NULL,
    event_type TEXT NOT NULL,
    from_status TEXT,
    to_status TEXT,
    actor TEXT NOT NULL,
    note TEXT,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (wish_id) REFERENCES wishes(id) ON DELETE CASCADE
  )`,
  `CREATE TABLE IF NOT EXISTS wish_responses (
    id TEXT PRIMARY KEY NOT NULL,
    wish_id TEXT NOT NULL,
    responder_name TEXT NOT NULL,
    responder_contact TEXT NOT NULL,
    note TEXT,
    status TEXT NOT NULL DEFAULT 'pending',
    user_id TEXT,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    FOREIGN KEY (wish_id) REFERENCES wishes(id) ON DELETE CASCADE
  )`,
  `CREATE TABLE IF NOT EXISTS rate_limits (
    fingerprint TEXT NOT NULL,
    action TEXT NOT NULL,
    window_start INTEGER NOT NULL,
    count INTEGER NOT NULL DEFAULT 1,
    updated_at INTEGER NOT NULL,
    PRIMARY KEY (fingerprint, action)
  )`,
  `CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY NOT NULL,
    created_at INTEGER NOT NULL,
    deleted_at INTEGER
  )`,
  `CREATE TABLE IF NOT EXISTS account_identities (
    id TEXT PRIMARY KEY NOT NULL,
    user_id TEXT NOT NULL,
    provider TEXT NOT NULL,
    provider_subject TEXT NOT NULL,
    refresh_token TEXT,
    created_at INTEGER NOT NULL,
    deleted_at INTEGER,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT
  )`,
  `CREATE TABLE IF NOT EXISTS account_sessions (
    id TEXT PRIMARY KEY NOT NULL,
    user_id TEXT NOT NULL,
    token_hash TEXT NOT NULL UNIQUE,
    expires_at INTEGER NOT NULL,
    created_at INTEGER NOT NULL,
    revoked_at INTEGER,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  )`,
  "CREATE INDEX IF NOT EXISTS wishes_status_created_idx ON wishes(status, created_at)",
  "CREATE INDEX IF NOT EXISTS wishes_city_status_idx ON wishes(city, status)",
  "CREATE INDEX IF NOT EXISTS providers_city_status_idx ON providers(city, status)",
  "CREATE INDEX IF NOT EXISTS assignments_wish_created_idx ON assignments(wish_id, created_at)",
  "CREATE INDEX IF NOT EXISTS deliverables_wish_created_idx ON deliverables(wish_id, created_at)",
  "CREATE INDEX IF NOT EXISTS wish_events_wish_created_idx ON wish_events(wish_id, created_at)",
  "CREATE UNIQUE INDEX IF NOT EXISTS wish_responses_wish_contact_unique ON wish_responses(wish_id, responder_contact)",
  "CREATE INDEX IF NOT EXISTS wish_responses_wish_created_idx ON wish_responses(wish_id, created_at)",
  "CREATE UNIQUE INDEX IF NOT EXISTS account_identities_provider_subject_unique ON account_identities(provider, provider_subject)",
  "CREATE INDEX IF NOT EXISTS account_sessions_user_expires_idx ON account_sessions(user_id, expires_at)",
  `CREATE TABLE IF NOT EXISTS wish_messages (
    id TEXT PRIMARY KEY NOT NULL,
    wish_id TEXT NOT NULL,
    response_id TEXT NOT NULL,
    sender_user_id TEXT NOT NULL,
    body TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    deleted_at INTEGER,
    FOREIGN KEY (wish_id) REFERENCES wishes(id) ON DELETE CASCADE,
    FOREIGN KEY (response_id) REFERENCES wish_responses(id) ON DELETE CASCADE,
    FOREIGN KEY (sender_user_id) REFERENCES users(id) ON DELETE CASCADE
  )`,
  "CREATE INDEX IF NOT EXISTS wish_messages_response_created_idx ON wish_messages(response_id, created_at)",
  `CREATE TABLE IF NOT EXISTS abuse_reports (
    id TEXT PRIMARY KEY NOT NULL,
    reporter_user_id TEXT NOT NULL,
    wish_id TEXT,
    response_id TEXT,
    reported_user_id TEXT,
    reason TEXT NOT NULL,
    detail TEXT,
    status TEXT NOT NULL DEFAULT 'open',
    created_at INTEGER NOT NULL
  )`,
  "CREATE INDEX IF NOT EXISTS abuse_reports_status_created_idx ON abuse_reports(status, created_at)",
  `CREATE TABLE IF NOT EXISTS user_blocks (
    blocker_user_id TEXT NOT NULL,
    blocked_user_id TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    PRIMARY KEY (blocker_user_id, blocked_user_id)
  )`,
] as const;

async function addCompatibilityColumns(db: D1Database) {
  const assignmentColumns = await db
    .prepare("PRAGMA table_info(assignments)")
    .all<{ name: string }>();
  if (!assignmentColumns.results.some((column) => column.name === "provider_id")) {
    await db
      .prepare(
        "ALTER TABLE assignments ADD COLUMN provider_id TEXT REFERENCES providers(id) ON DELETE SET NULL",
      )
      .run();
  }

  const deliverableColumns = await db
    .prepare("PRAGMA table_info(deliverables)")
    .all<{ name: string }>();
  if (!deliverableColumns.results.some((column) => column.name === "storage_key")) {
    await db.prepare("ALTER TABLE deliverables ADD COLUMN storage_key TEXT").run();
  }
  if (!deliverableColumns.results.some((column) => column.name === "access_token")) {
    await db.prepare("ALTER TABLE deliverables ADD COLUMN access_token TEXT").run();
  }

  const wishColumns = await db.prepare("PRAGMA table_info(wishes)").all<{ name: string }>();
  if (!wishColumns.results.some((column) => column.name === "user_id")) {
    await db.prepare("ALTER TABLE wishes ADD COLUMN user_id TEXT").run();
  }

  const identityColumns = await db.prepare("PRAGMA table_info(account_identities)").all<{ name: string }>();
  if (!identityColumns.results.some((column) => column.name === "refresh_token")) {
    await db.prepare("ALTER TABLE account_identities ADD COLUMN refresh_token TEXT").run();
  }

  const responseColumns = await db.prepare("PRAGMA table_info(wish_responses)").all<{ name: string }>();
  if (!responseColumns.results.some((column) => column.name === "user_id")) {
    await db.prepare("ALTER TABLE wish_responses ADD COLUMN user_id TEXT").run();
  }
  // 帮助者响应时的内容授权记录：选择帮助即同意其提交的文字与影像由需求方
  // 支配，包括公开分享的权利。
  if (!responseColumns.results.some((column) => column.name === "content_license_agreed_at")) {
    await db.prepare("ALTER TABLE wish_responses ADD COLUMN content_license_agreed_at INTEGER").run();
  }

  // 一次「完成帮助」可含一段文字与最多 9 个文件，同组共享 group_id 并按 position 排序。
  if (!deliverableColumns.results.some((column) => column.name === "group_id")) {
    await db.prepare("ALTER TABLE deliverables ADD COLUMN group_id TEXT").run();
  }
  if (!deliverableColumns.results.some((column) => column.name === "position")) {
    await db.prepare("ALTER TABLE deliverables ADD COLUMN position INTEGER NOT NULL DEFAULT 0").run();
  }

  // 故事公开由需求方在完成后单独决定，默认不公开。
  if (!wishColumns.results.some((column) => column.name === "story_published_at")) {
    await db.prepare("ALTER TABLE wishes ADD COLUMN story_published_at INTEGER").run();
  }
  if (!wishColumns.results.some((column) => column.name === "story_nickname")) {
    await db.prepare("ALTER TABLE wishes ADD COLUMN story_nickname TEXT").run();
  }

  // 用户资料：昵称与头像会出现在私聊、响应列表与公开故事里，属于公开可见的
  // 用户生成内容，必须先审后可见。approved_* 是当前对他人可见的版本。
  const userColumns = await db.prepare("PRAGMA table_info(users)").all<{ name: string }>();
  const userAdds: Array<[string, string]> = [
    ["display_name", "TEXT"],
    ["avatar_key", "TEXT"],
    ["approved_display_name", "TEXT"],
    ["approved_avatar_key", "TEXT"],
    ["profile_status", "TEXT NOT NULL DEFAULT 'approved'"],
    ["profile_note", "TEXT"],
    ["profile_updated_at", "INTEGER"],
  ];
  for (const [column, definition] of userAdds) {
    if (!userColumns.results.some((existing) => existing.name === column)) {
      await db.prepare(`ALTER TABLE users ADD COLUMN ${column} ${definition}`).run();
    }
  }

  await db.batch([
    db.prepare("CREATE INDEX IF NOT EXISTS wishes_user_created_idx ON wishes(user_id, created_at)"),
    db.prepare("CREATE INDEX IF NOT EXISTS wish_responses_user_created_idx ON wish_responses(user_id, created_at)"),
  ]);
}

export function ensureWishSchema(db: D1Database) {
  const existing = schemaInitializations.get(db);
  if (existing) return existing;

  const initialization = db
    .batch(schemaStatements.map((statement) => db.prepare(statement)))
    .then(() => addCompatibilityColumns(db))
    .catch((error) => {
      schemaInitializations.delete(db);
      throw error;
    });
  schemaInitializations.set(db, initialization);
  return initialization;
}
