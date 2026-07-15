import { index, integer, sqliteTable, text } from "drizzle-orm/sqlite-core";

export const wishes = sqliteTable(
  "wishes",
  {
    id: text("id").primaryKey(),
    publicCode: text("public_code").notNull().unique(),
    requesterName: text("requester_name").notNull(),
    contact: text("contact").notNull(),
    city: text("city").notNull(),
    landmark: text("landmark").notNull(),
    occasion: text("occasion").notNull(),
    message: text("message").notNull(),
    deliveryType: text("delivery_type").notNull(),
    deadlineText: text("deadline_text").notNull(),
    rewardFen: integer("reward_fen").notNull().default(1800),
    publishFeeFen: integer("publish_fee_fen").notNull().default(500),
    status: text("status").notNull().default("pending_review"),
    moderationNote: text("moderation_note"),
    source: text("source").notNull().default("web"),
    createdAt: integer("created_at").notNull(),
    updatedAt: integer("updated_at").notNull(),
  },
  (table) => [
    index("wishes_status_created_idx").on(table.status, table.createdAt),
    index("wishes_city_status_idx").on(table.city, table.status),
  ],
);

export const assignments = sqliteTable(
  "assignments",
  {
    id: text("id").primaryKey(),
    wishId: text("wish_id")
      .notNull()
      .references(() => wishes.id, { onDelete: "cascade" }),
    providerName: text("provider_name").notNull(),
    providerContact: text("provider_contact").notNull(),
    status: text("status").notNull().default("offered"),
    note: text("note"),
    createdAt: integer("created_at").notNull(),
    updatedAt: integer("updated_at").notNull(),
    acceptedAt: integer("accepted_at"),
    deliveredAt: integer("delivered_at"),
  },
  (table) => [index("assignments_wish_created_idx").on(table.wishId, table.createdAt)],
);

export const deliverables = sqliteTable(
  "deliverables",
  {
    id: text("id").primaryKey(),
    wishId: text("wish_id")
      .notNull()
      .references(() => wishes.id, { onDelete: "cascade" }),
    assignmentId: text("assignment_id").references(() => assignments.id, {
      onDelete: "set null",
    }),
    kind: text("kind").notNull(),
    url: text("url").notNull(),
    note: text("note"),
    createdAt: integer("created_at").notNull(),
  },
  (table) => [index("deliverables_wish_created_idx").on(table.wishId, table.createdAt)],
);

export const wishEvents = sqliteTable(
  "wish_events",
  {
    id: integer("id").primaryKey({ autoIncrement: true }),
    wishId: text("wish_id")
      .notNull()
      .references(() => wishes.id, { onDelete: "cascade" }),
    eventType: text("event_type").notNull(),
    fromStatus: text("from_status"),
    toStatus: text("to_status"),
    actor: text("actor").notNull(),
    note: text("note"),
    createdAt: integer("created_at").notNull(),
  },
  (table) => [index("wish_events_wish_created_idx").on(table.wishId, table.createdAt)],
);
