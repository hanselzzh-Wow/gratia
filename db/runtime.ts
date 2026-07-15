let schemaInitialization: Promise<void> | null = null;

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
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
  )`,
  `CREATE TABLE IF NOT EXISTS assignments (
    id TEXT PRIMARY KEY NOT NULL,
    wish_id TEXT NOT NULL,
    provider_name TEXT NOT NULL,
    provider_contact TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'offered',
    note TEXT,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    accepted_at INTEGER,
    delivered_at INTEGER,
    FOREIGN KEY (wish_id) REFERENCES wishes(id) ON DELETE CASCADE
  )`,
  `CREATE TABLE IF NOT EXISTS deliverables (
    id TEXT PRIMARY KEY NOT NULL,
    wish_id TEXT NOT NULL,
    assignment_id TEXT,
    kind TEXT NOT NULL,
    url TEXT NOT NULL,
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
  "CREATE INDEX IF NOT EXISTS wishes_status_created_idx ON wishes(status, created_at)",
  "CREATE INDEX IF NOT EXISTS wishes_city_status_idx ON wishes(city, status)",
  "CREATE INDEX IF NOT EXISTS assignments_wish_created_idx ON assignments(wish_id, created_at)",
  "CREATE INDEX IF NOT EXISTS deliverables_wish_created_idx ON deliverables(wish_id, created_at)",
  "CREATE INDEX IF NOT EXISTS wish_events_wish_created_idx ON wish_events(wish_id, created_at)",
] as const;

export function ensureWishSchema(db: D1Database) {
  if (!schemaInitialization) {
    schemaInitialization = db
      .batch(schemaStatements.map((statement) => db.prepare(statement)))
      .then(() => undefined)
      .catch((error) => {
        schemaInitialization = null;
        throw error;
      });
  }

  return schemaInitialization;
}
