import { ensureWishSchema } from "../db/runtime";
import {
  deliveryTypes,
  wishStatuses,
  type AdminWish,
  type AdminWishActionInput,
  type CreateWishInput,
  type DeliveryType,
  type PublicWish,
  type WishAssignment,
  type WishDeliverable,
  type WishStatus,
} from "../lib/wishes-contract";

type WishRow = {
  id: string;
  public_code: string;
  requester_name: string;
  contact: string;
  city: string;
  landmark: string;
  occasion: string;
  message: string;
  delivery_type: string;
  deadline_text: string;
  reward_fen: number;
  publish_fee_fen: number;
  status: string;
  moderation_note: string | null;
  created_at: number;
  updated_at: number;
};

type AdminWishRow = WishRow & {
  assignment_id: string | null;
  assignment_provider_name: string | null;
  assignment_provider_contact: string | null;
  assignment_status: string | null;
  assignment_note: string | null;
  assignment_created_at: number | null;
  assignment_updated_at: number | null;
  deliverable_id: string | null;
  deliverable_kind: string | null;
  deliverable_url: string | null;
  deliverable_note: string | null;
  deliverable_created_at: number | null;
};

const adminSelect = `
  SELECT
    w.*,
    a.id AS assignment_id,
    a.provider_name AS assignment_provider_name,
    a.provider_contact AS assignment_provider_contact,
    a.status AS assignment_status,
    a.note AS assignment_note,
    a.created_at AS assignment_created_at,
    a.updated_at AS assignment_updated_at,
    d.id AS deliverable_id,
    d.kind AS deliverable_kind,
    d.url AS deliverable_url,
    d.note AS deliverable_note,
    d.created_at AS deliverable_created_at
  FROM wishes w
  LEFT JOIN assignments a ON a.id = (
    SELECT a2.id FROM assignments a2
    WHERE a2.wish_id = w.id
    ORDER BY a2.created_at DESC LIMIT 1
  )
  LEFT JOIN deliverables d ON d.id = (
    SELECT d2.id FROM deliverables d2
    WHERE d2.wish_id = w.id
    ORDER BY d2.created_at DESC LIMIT 1
  )
`;

export class WishWorkflowError extends Error {
  status: number;

  constructor(message: string, status = 400) {
    super(message);
    this.name = "WishWorkflowError";
    this.status = status;
  }
}

function asWishStatus(value: string): WishStatus {
  if (!wishStatuses.includes(value as WishStatus)) {
    throw new WishWorkflowError(`未知心愿状态：${value}`, 500);
  }
  return value as WishStatus;
}

function asDeliveryType(value: string): DeliveryType {
  if (!deliveryTypes.includes(value as DeliveryType)) {
    throw new WishWorkflowError(`未知交付类型：${value}`, 500);
  }
  return value as DeliveryType;
}

function toPublicWish(row: WishRow): PublicWish {
  return {
    id: row.id,
    publicCode: row.public_code,
    city: row.city,
    landmark: row.landmark,
    occasion: row.occasion,
    message: row.message,
    deliveryType: asDeliveryType(row.delivery_type),
    deadlineText: row.deadline_text,
    rewardFen: row.reward_fen,
    status: asWishStatus(row.status),
    createdAt: row.created_at,
  };
}

function toAssignment(row: AdminWishRow): WishAssignment | null {
  if (!row.assignment_id || !row.assignment_provider_name || !row.assignment_provider_contact) {
    return null;
  }

  return {
    id: row.assignment_id,
    providerName: row.assignment_provider_name,
    providerContact: row.assignment_provider_contact,
    status: (row.assignment_status ?? "offered") as WishAssignment["status"],
    note: row.assignment_note,
    createdAt: row.assignment_created_at ?? row.created_at,
    updatedAt: row.assignment_updated_at ?? row.updated_at,
  };
}

function toDeliverable(row: AdminWishRow): WishDeliverable | null {
  if (!row.deliverable_id || !row.deliverable_url) return null;
  return {
    id: row.deliverable_id,
    kind: (row.deliverable_kind ?? "link") as WishDeliverable["kind"],
    url: row.deliverable_url,
    note: row.deliverable_note,
    createdAt: row.deliverable_created_at ?? row.updated_at,
  };
}

function toAdminWish(row: AdminWishRow): AdminWish {
  return {
    ...toPublicWish(row),
    requesterName: row.requester_name,
    contact: row.contact,
    publishFeeFen: row.publish_fee_fen,
    moderationNote: row.moderation_note,
    updatedAt: row.updated_at,
    assignment: toAssignment(row),
    deliverable: toDeliverable(row),
  };
}

function makePublicCode(now: number) {
  const date = new Date(now);
  const compactDate = [
    String(date.getUTCFullYear()).slice(-2),
    String(date.getUTCMonth() + 1).padStart(2, "0"),
    String(date.getUTCDate()).padStart(2, "0"),
  ].join("");
  const suffix = crypto.randomUUID().replaceAll("-", "").slice(0, 5).toUpperCase();
  return `HW${compactDate}-${suffix}`;
}

async function getAdminWishRow(db: D1Database, id: string) {
  return db
    .prepare(`${adminSelect} WHERE w.id = ? LIMIT 1`)
    .bind(id)
    .first<AdminWishRow>();
}

export async function createWish(db: D1Database, input: CreateWishInput) {
  await ensureWishSchema(db);
  const now = Date.now();

  const duplicate = await db
    .prepare(
      "SELECT * FROM wishes WHERE contact = ? AND message = ? AND created_at >= ? ORDER BY created_at DESC LIMIT 1",
    )
    .bind(input.contact, input.message, now - 60_000)
    .first<WishRow>();

  if (duplicate) {
    return { wish: toPublicWish(duplicate), created: false };
  }

  const id = crypto.randomUUID();
  const publicCode = makePublicCode(now);
  await db.batch([
    db
      .prepare(
        `INSERT INTO wishes (
          id, public_code, requester_name, contact, city, landmark, occasion,
          message, delivery_type, deadline_text, reward_fen, publish_fee_fen,
          status, source, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 500, 'pending_review', 'web', ?, ?)`,
      )
      .bind(
        id,
        publicCode,
        input.requesterName,
        input.contact,
        input.city,
        input.landmark,
        input.occasion,
        input.message,
        input.deliveryType,
        input.deadlineText,
        input.rewardFen,
        now,
        now,
      ),
    db
      .prepare(
        "INSERT INTO wish_events (wish_id, event_type, from_status, to_status, actor, note, created_at) VALUES (?, 'submitted', NULL, 'pending_review', 'requester', NULL, ?)",
      )
      .bind(id, now),
  ]);

  return {
    created: true,
    wish: {
      id,
      publicCode,
      city: input.city,
      landmark: input.landmark,
      occasion: input.occasion,
      message: input.message,
      deliveryType: input.deliveryType,
      deadlineText: input.deadlineText,
      rewardFen: input.rewardFen,
      status: "pending_review" as const,
      createdAt: now,
    },
  };
}

export async function listPublicWishes(db: D1Database, city?: string) {
  await ensureWishSchema(db);
  const limit = 40;
  const query = city
    ? db
        .prepare(
          "SELECT * FROM wishes WHERE status = 'matching' AND city = ? ORDER BY created_at DESC LIMIT ?",
        )
        .bind(city, limit)
    : db
        .prepare("SELECT * FROM wishes WHERE status = 'matching' ORDER BY created_at DESC LIMIT ?")
        .bind(limit);
  const result = await query.all<WishRow>();
  return result.results.map(toPublicWish);
}

export async function listAdminWishes(db: D1Database, status?: string) {
  await ensureWishSchema(db);
  const validStatus = status && wishStatuses.includes(status as WishStatus) ? status : null;
  const query = validStatus
    ? db
        .prepare(`${adminSelect} WHERE w.status = ? ORDER BY w.created_at DESC LIMIT 100`)
        .bind(validStatus)
    : db.prepare(`${adminSelect} ORDER BY w.created_at DESC LIMIT 100`);
  const result = await query.all<AdminWishRow>();
  return result.results.map(toAdminWish);
}

function requireStatus(wish: AdminWish, allowed: WishStatus[]) {
  if (!allowed.includes(wish.status)) {
    throw new WishWorkflowError(`当前状态“${wish.status}”不能执行此操作`, 409);
  }
}

function requireHttpsUrl(value: string | undefined) {
  if (!value) throw new WishWorkflowError("请填写交付链接");
  try {
    const url = new URL(value);
    if (url.protocol !== "https:") throw new Error("not https");
    return url.toString();
  } catch {
    throw new WishWorkflowError("交付链接需为有效的 HTTPS 地址");
  }
}

export async function applyAdminWishAction(
  db: D1Database,
  id: string,
  input: AdminWishActionInput,
) {
  await ensureWishSchema(db);
  const currentRow = await getAdminWishRow(db, id);
  if (!currentRow) throw new WishWorkflowError("未找到该心愿", 404);
  const wish = toAdminWish(currentRow);
  const now = Date.now();
  const statements: D1PreparedStatement[] = [];
  let nextStatus: WishStatus;
  let eventType = input.action;

  switch (input.action) {
    case "approve":
      requireStatus(wish, ["pending_review"]);
      nextStatus = "matching";
      break;
    case "reject":
      requireStatus(wish, ["pending_review"]);
      if (!input.note) throw new WishWorkflowError("请填写未通过原因");
      nextStatus = "rejected";
      break;
    case "assign": {
      requireStatus(wish, ["matching"]);
      if (!input.providerName || !input.providerContact) {
        throw new WishWorkflowError("请填写响应者称呼和联系方式");
      }
      nextStatus = "assigned";
      statements.push(
        db
          .prepare(
            "INSERT INTO assignments (id, wish_id, provider_name, provider_contact, status, note, created_at, updated_at) VALUES (?, ?, ?, ?, 'offered', ?, ?, ?)",
          )
          .bind(
            crypto.randomUUID(),
            wish.id,
            input.providerName,
            input.providerContact,
            input.note ?? null,
            now,
            now,
          ),
      );
      break;
    }
    case "accept":
      requireStatus(wish, ["assigned"]);
      if (!wish.assignment) throw new WishWorkflowError("该心愿还没有派单记录", 409);
      nextStatus = "in_progress";
      statements.push(
        db
          .prepare(
            "UPDATE assignments SET status = 'accepted', accepted_at = ?, updated_at = ? WHERE id = ?",
          )
          .bind(now, now, wish.assignment.id),
      );
      break;
    case "mark_delivered": {
      requireStatus(wish, ["in_progress"]);
      if (!wish.assignment) throw new WishWorkflowError("该心愿还没有派单记录", 409);
      const deliveryUrl = requireHttpsUrl(input.deliveryUrl);
      nextStatus = "delivered";
      statements.push(
        db
          .prepare(
            "UPDATE assignments SET status = 'delivered', delivered_at = ?, updated_at = ? WHERE id = ?",
          )
          .bind(now, now, wish.assignment.id),
        db
          .prepare(
            "INSERT INTO deliverables (id, wish_id, assignment_id, kind, url, note, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
          )
          .bind(
            crypto.randomUUID(),
            wish.id,
            wish.assignment.id,
            wish.deliveryType,
            deliveryUrl,
            input.note ?? null,
            now,
          ),
      );
      break;
    }
    case "complete":
      requireStatus(wish, ["delivered"]);
      nextStatus = "completed";
      break;
    case "cancel":
      requireStatus(wish, ["pending_review", "matching", "assigned", "in_progress", "delivered"]);
      nextStatus = "cancelled";
      if (wish.assignment) {
        statements.push(
          db
            .prepare("UPDATE assignments SET status = 'cancelled', updated_at = ? WHERE id = ?")
            .bind(now, wish.assignment.id),
        );
      }
      break;
    case "reopen_matching":
      requireStatus(wish, ["assigned", "in_progress", "cancelled"]);
      nextStatus = "matching";
      eventType = "reopened";
      if (wish.assignment) {
        statements.push(
          db
            .prepare("UPDATE assignments SET status = 'cancelled', updated_at = ? WHERE id = ?")
            .bind(now, wish.assignment.id),
        );
      }
      break;
  }

  const updateStatement = db
    .prepare(
      "UPDATE wishes SET status = ?, moderation_note = ?, updated_at = ? WHERE id = ? AND status = ?",
    )
    .bind(nextStatus, input.note ?? wish.moderationNote, now, wish.id, wish.status);
  const eventStatement = db
    .prepare(
      "INSERT INTO wish_events (wish_id, event_type, from_status, to_status, actor, note, created_at) VALUES (?, ?, ?, ?, 'operator', ?, ?)",
    )
    .bind(wish.id, eventType, wish.status, nextStatus, input.note ?? null, now);

  const results = await db.batch([updateStatement, ...statements, eventStatement]);
  if ((results[0].meta.changes ?? 0) !== 1) {
    throw new WishWorkflowError("心愿状态刚刚发生变化，请刷新后重试", 409);
  }

  const updated = await getAdminWishRow(db, id);
  if (!updated) throw new WishWorkflowError("更新后未找到心愿", 500);
  return toAdminWish(updated);
}

export async function getWishHealth(db: D1Database) {
  await ensureWishSchema(db);
  const row = await db.prepare("SELECT COUNT(*) AS count FROM wishes").first<{ count: number }>();
  return { database: "ready" as const, wishCount: Number(row?.count ?? 0) };
}
