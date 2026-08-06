import { ensureWishSchema } from "../db/runtime";
import {
  deliveryTypes,
  wishStatuses,
  type AdminWish,
  type AdminWishActionInput,
  type CreateProviderInput,
  type CreateWishInput,
  type CreateWishResponseInput,
  type DeliveryType,
  type PublicWish,
  type Provider,
  type ProviderStatus,
  type TrackedWish,
  type UpdateProviderInput,
  type WishAssignment,
  type WishDeliverable,
  type WishEvent,
  type WishResponse,
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
  user_id: string | null;
  created_at: number;
  updated_at: number;
};

type AdminWishRow = WishRow & {
  assignment_id: string | null;
  assignment_provider_id: string | null;
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

type ProviderRow = {
  id: string;
  name: string;
  contact: string;
  city: string;
  landmarks: string;
  availability_note: string | null;
  status: string;
  completed_count: number;
  last_assigned_at: number | null;
  created_at: number;
  updated_at: number;
};

type WishResponseRow = {
  id: string;
  wish_id: string;
  responder_name: string;
  responder_contact: string;
  note: string | null;
  status: string;
  user_id: string | null;
  created_at: number;
  updated_at: number;
};

const adminSelect = `
  SELECT
    w.*,
    a.id AS assignment_id,
    a.provider_id AS assignment_provider_id,
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
    providerId: row.assignment_provider_id,
    providerName: row.assignment_provider_name,
    providerContact: row.assignment_provider_contact,
    status: (row.assignment_status ?? "offered") as WishAssignment["status"],
    note: row.assignment_note,
    createdAt: row.assignment_created_at ?? row.created_at,
    updatedAt: row.assignment_updated_at ?? row.updated_at,
  };
}

function toProvider(row: ProviderRow): Provider {
  return {
    id: row.id,
    name: row.name,
    contact: row.contact,
    city: row.city,
    landmarks: row.landmarks,
    availabilityNote: row.availability_note,
    status: row.status as ProviderStatus,
    completedCount: row.completed_count,
    lastAssignedAt: row.last_assigned_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
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

function toWishResponse(row: WishResponseRow): WishResponse {
  return {
    id: row.id,
    responderName: row.responder_name,
    responderContact: row.responder_contact,
    note: row.note,
    status: row.status as WishResponse["status"],
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function toAdminWish(row: AdminWishRow, responses: WishResponse[] = []): AdminWish {
  return {
    ...toPublicWish(row),
    requesterName: row.requester_name,
    contact: row.contact,
    publishFeeFen: row.publish_fee_fen,
    moderationNote: row.moderation_note,
    updatedAt: row.updated_at,
    assignment: toAssignment(row),
    deliverable: toDeliverable(row),
    responses,
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

async function getWishResponses(db: D1Database, wishId: string) {
  const result = await db
    .prepare("SELECT * FROM wish_responses WHERE wish_id = ? ORDER BY created_at DESC")
    .bind(wishId)
    .all<WishResponseRow>();
  return result.results.map(toWishResponse);
}

export async function createWish(db: D1Database, input: CreateWishInput, userId?: string) {
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
          status, source, user_id, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 500, 'pending_review', 'web', ?, ?, ?)`,
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
        userId ?? null,
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

export async function listProviders(db: D1Database, city?: string) {
  await ensureWishSchema(db);
  const result = city
    ? await db
        .prepare("SELECT * FROM providers WHERE city = ? ORDER BY status ASC, updated_at DESC LIMIT 200")
        .bind(city)
        .all<ProviderRow>()
    : await db.prepare("SELECT * FROM providers ORDER BY city ASC, status ASC, updated_at DESC LIMIT 200").all<ProviderRow>();
  return result.results.map(toProvider);
}

export async function createProvider(db: D1Database, input: CreateProviderInput) {
  await ensureWishSchema(db);
  const duplicate = await db
    .prepare("SELECT id FROM providers WHERE contact = ? LIMIT 1")
    .bind(input.contact)
    .first<{ id: string }>();
  if (duplicate) throw new WishWorkflowError("这个联系方式已经在供应者名册中", 409);
  const id = crypto.randomUUID();
  const now = Date.now();
  await db
    .prepare(
      "INSERT INTO providers (id, name, contact, city, landmarks, availability_note, status, completed_count, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, 'available', 0, ?, ?)",
    )
    .bind(id, input.name, input.contact, input.city, input.landmarks, input.availabilityNote ?? null, now, now)
    .run();
  const row = await db.prepare("SELECT * FROM providers WHERE id = ?").bind(id).first<ProviderRow>();
  if (!row) throw new WishWorkflowError("供应者保存失败", 500);
  return toProvider(row);
}

export async function updateProvider(db: D1Database, id: string, update: UpdateProviderInput) {
  await ensureWishSchema(db);
  const current = await db.prepare("SELECT * FROM providers WHERE id = ? LIMIT 1").bind(id).first<ProviderRow>();
  if (!current) throw new WishWorkflowError("未找到该供应者", 404);
  if (update.status === "busy" && current.status !== "busy") {
    throw new WishWorkflowError("履约中状态只能在派单时自动设置", 409);
  }
  if (current.status === "busy" && update.status && update.status !== "busy") {
    throw new WishWorkflowError("供应者仍有进行中的订单，请先完成、取消或退回匹配", 409);
  }
  const now = Date.now();
  try {
    await db
      .prepare(
        "UPDATE providers SET name = ?, contact = ?, city = ?, landmarks = ?, availability_note = ?, status = ?, updated_at = ? WHERE id = ?",
      )
      .bind(
        update.name ?? current.name,
        update.contact ?? current.contact,
        update.city ?? current.city,
        update.landmarks ?? current.landmarks,
        update.availabilityNote !== undefined ? update.availabilityNote || null : current.availability_note,
        update.status ?? current.status,
        now,
        id,
      )
      .run();
  } catch (error) {
    if (String(error).includes("UNIQUE")) throw new WishWorkflowError("这个联系方式已经在供应者名册中", 409);
    throw error;
  }
  const row = await db.prepare("SELECT * FROM providers WHERE id = ?").bind(id).first<ProviderRow>();
  if (!row) throw new WishWorkflowError("供应者更新失败", 500);
  return toProvider(row);
}

export async function createWishResponse(
  db: D1Database,
  wishId: string,
  input: CreateWishResponseInput,
  userId?: string,
) {
  await ensureWishSchema(db);
  const wish = await db.prepare("SELECT * FROM wishes WHERE id = ? LIMIT 1").bind(wishId).first<WishRow>();
  if (!wish) throw new WishWorkflowError("未找到该心愿", 404);
  if (wish.status !== "matching") {
    throw new WishWorkflowError("该心愿目前不再接受新的响应", 409);
  }

  const duplicate = await db
    .prepare("SELECT * FROM wish_responses WHERE wish_id = ? AND responder_contact = ? LIMIT 1")
    .bind(wishId, input.responderContact)
    .first<WishResponseRow>();
  if (duplicate) return { response: toWishResponse(duplicate), created: false };

  const id = crypto.randomUUID();
  const now = Date.now();
  await db.batch([
    db
      .prepare(
        "INSERT INTO wish_responses (id, wish_id, responder_name, responder_contact, note, status, user_id, created_at, updated_at) VALUES (?, ?, ?, ?, ?, 'pending', ?, ?, ?)",
      )
      .bind(id, wishId, input.responderName, input.responderContact, input.note ?? null, userId ?? null, now, now),
    db
      .prepare(
        "INSERT INTO wish_events (wish_id, event_type, from_status, to_status, actor, note, created_at) VALUES (?, 'response_submitted', 'matching', 'matching', 'responder', ?, ?)",
      )
      .bind(wishId, input.note ?? null, now),
  ]);
  return {
    created: true,
    response: {
      id,
      responderName: input.responderName,
      responderContact: input.responderContact,
      note: input.note ?? null,
      status: "pending" as const,
      createdAt: now,
      updatedAt: now,
    },
  };
}

export async function trackWish(db: D1Database, publicCode: string, contact: string): Promise<TrackedWish> {
  await ensureWishSchema(db);
  const row = await db
    .prepare(`${adminSelect} WHERE w.public_code = ? AND w.contact = ? LIMIT 1`)
    .bind(publicCode, contact)
    .first<AdminWishRow>();
  if (!row) throw new WishWorkflowError("没有找到匹配的心愿，请检查编号和联系方式", 404);
  const adminWish = toAdminWish(row);
  const eventResult = await db
    .prepare(
      "SELECT event_type, from_status, to_status, created_at FROM wish_events WHERE wish_id = ? ORDER BY created_at ASC LIMIT 50",
    )
    .bind(row.id)
    .all<{ event_type: string; from_status: string | null; to_status: string | null; created_at: number }>();
  const events: WishEvent[] = eventResult.results.map((event) => ({
    eventType: event.event_type,
    fromStatus: event.from_status ? asWishStatus(event.from_status) : null,
    toStatus: event.to_status ? asWishStatus(event.to_status) : null,
    createdAt: event.created_at,
  }));
  return {
    ...toPublicWish(row),
    updatedAt: row.updated_at,
    assignment: adminWish.assignment
      ? { providerName: adminWish.assignment.providerName, status: adminWish.assignment.status }
      : null,
    deliverable: adminWish.deliverable,
    events,
  };
}

export async function listAccountActivity(db: D1Database, userId: string) {
  await ensureWishSchema(db);
  const [requestResult, responseResult] = await Promise.all([
    db
      .prepare(`${adminSelect} WHERE w.user_id = ? ORDER BY w.updated_at DESC LIMIT 100`)
      .bind(userId)
      .all<AdminWishRow>(),
    db
      .prepare(
        `SELECT w.*, r.status AS response_status, r.created_at AS response_created_at
         FROM wish_responses r JOIN wishes w ON w.id = r.wish_id
         WHERE r.user_id = ? ORDER BY r.updated_at DESC LIMIT 100`,
      )
      .bind(userId)
      .all<WishRow & { response_status: WishResponse["status"]; response_created_at: number }>(),
  ]);

  return {
    requests: requestResult.results.map((row) => ({
      ...toPublicWish(row),
      updatedAt: row.updated_at,
      hasDeliverable: Boolean(row.deliverable_id),
      canConfirmCompletion: row.status === "delivered",
    })),
    responses: responseResult.results.map((row) => ({
      wish: toPublicWish(row),
      responseStatus: row.response_status,
      respondedAt: row.response_created_at,
    })),
  };
}

export async function completeWishForOwner(db: D1Database, wishId: string, userId: string) {
  await ensureWishSchema(db);
  const row = await getAdminWishRow(db, wishId);
  if (!row || row.user_id !== userId) throw new WishWorkflowError("未找到可确认的心愿", 404);
  const wish = toAdminWish(row);
  requireStatus(wish, ["delivered"]);
  const now = Date.now();
  const statements: D1PreparedStatement[] = [
    db
      .prepare("UPDATE wishes SET status = 'completed', updated_at = ? WHERE id = ? AND status = 'delivered' AND user_id = ?")
      .bind(now, wishId, userId),
  ];
  if (wish.assignment?.providerId) {
    statements.push(
      db
        .prepare("UPDATE providers SET status = 'available', completed_count = completed_count + 1, updated_at = ? WHERE id = ?")
        .bind(now, wish.assignment.providerId),
    );
  }
  statements.push(
    db
      .prepare(
        "INSERT INTO wish_events (wish_id, event_type, from_status, to_status, actor, note, created_at) VALUES (?, 'requester_completed', 'delivered', 'completed', 'requester', NULL, ?)",
      )
      .bind(wishId, now),
  );
  const result = await db.batch(statements);
  if ((result[0].meta.changes ?? 0) !== 1) {
    throw new WishWorkflowError("心愿状态刚刚发生变化，请刷新后重试", 409);
  }
  const updated = await getAdminWishRow(db, wishId);
  if (!updated) throw new WishWorkflowError("更新后未找到心愿", 500);
  return toPublicWish(updated);
}

export async function getAccountDeliverable(db: D1Database, wishId: string, userId: string) {
  await ensureWishSchema(db);
  const wish = await db
    .prepare("SELECT id FROM wishes WHERE id = ? AND user_id = ? LIMIT 1")
    .bind(wishId, userId)
    .first<{ id: string }>();
  if (!wish) throw new WishWorkflowError("未找到该交付内容", 404);
  const delivery = await db
    .prepare(
      "SELECT id, kind, url, storage_key AS storageKey FROM deliverables WHERE wish_id = ? ORDER BY created_at DESC LIMIT 1",
    )
    .bind(wishId)
    .first<{ id: string; kind: string; url: string; storageKey: string | null }>();
  if (!delivery) throw new WishWorkflowError("交付内容尚未准备好", 404);
  return delivery;
}

export async function listAdminWishes(db: D1Database, status?: string) {
  await ensureWishSchema(db);
  const validStatus = status && wishStatuses.includes(status as WishStatus) ? status : null;
  const query = validStatus
    ? db
        .prepare(`${adminSelect} WHERE w.status = ? ORDER BY w.created_at DESC LIMIT 100`)
        .bind(validStatus)
    : db.prepare(`${adminSelect} ORDER BY w.created_at DESC LIMIT 100`);
  const [result, responseResult] = await Promise.all([
    query.all<AdminWishRow>(),
    db.prepare("SELECT * FROM wish_responses ORDER BY created_at DESC LIMIT 300").all<WishResponseRow>(),
  ]);
  const responsesByWish = new Map<string, WishResponse[]>();
  for (const row of responseResult.results) {
    const current = responsesByWish.get(row.wish_id) ?? [];
    current.push(toWishResponse(row));
    responsesByWish.set(row.wish_id, current);
  }
  return result.results.map((row) => toAdminWish(row, responsesByWish.get(row.id) ?? []));
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
  const wish = toAdminWish(currentRow, await getWishResponses(db, id));
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
      let providerName = input.providerName;
      let providerContact = input.providerContact;
      let providerId: string | null = null;
      if (input.providerId) {
        const selectedProvider = await db
          .prepare("SELECT * FROM providers WHERE id = ? LIMIT 1")
          .bind(input.providerId)
          .first<ProviderRow>();
        if (!selectedProvider) throw new WishWorkflowError("未找到所选供应者", 404);
        if (selectedProvider.status !== "available") {
          throw new WishWorkflowError("所选供应者当前不可接单", 409);
        }
        providerId = selectedProvider.id;
        providerName = selectedProvider.name;
        providerContact = selectedProvider.contact;
        statements.push(
          db
            .prepare("UPDATE providers SET status = 'busy', last_assigned_at = ?, updated_at = ? WHERE id = ? AND status = 'available'")
            .bind(now, now, selectedProvider.id),
        );
      } else if (input.responseId) {
        const selectedResponse = await db
          .prepare("SELECT * FROM wish_responses WHERE id = ? AND wish_id = ? LIMIT 1")
          .bind(input.responseId, wish.id)
          .first<WishResponseRow>();
        if (!selectedResponse) throw new WishWorkflowError("未找到所选响应者", 404);
        providerName = selectedResponse.responder_name;
        providerContact = selectedResponse.responder_contact;
        statements.push(
          db
            .prepare("UPDATE wish_responses SET status = 'selected', updated_at = ? WHERE id = ?")
            .bind(now, selectedResponse.id),
        );
      }
      if (!providerName || !providerContact) {
        throw new WishWorkflowError("请填写响应者称呼和联系方式");
      }
      nextStatus = "assigned";
      statements.push(
        db
          .prepare(
            "INSERT INTO assignments (id, wish_id, provider_id, provider_name, provider_contact, status, note, created_at, updated_at) VALUES (?, ?, ?, ?, ?, 'offered', ?, ?, ?)",
          )
          .bind(
            crypto.randomUUID(),
            wish.id,
            providerId,
            providerName,
            providerContact,
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
      if (wish.assignment?.providerId) {
        statements.push(
          db
            .prepare("UPDATE providers SET status = 'available', completed_count = completed_count + 1, updated_at = ? WHERE id = ?")
            .bind(now, wish.assignment.providerId),
        );
      }
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
        if (wish.assignment.providerId) {
          statements.push(
            db
              .prepare("UPDATE providers SET status = 'available', updated_at = ? WHERE id = ?")
              .bind(now, wish.assignment.providerId),
          );
        }
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
        if (wish.assignment.providerId) {
          statements.push(
            db
              .prepare("UPDATE providers SET status = 'available', updated_at = ? WHERE id = ?")
              .bind(now, wish.assignment.providerId),
          );
        }
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
  return toAdminWish(updated, await getWishResponses(db, id));
}

export async function recordUploadedDeliverable(
  db: D1Database,
  id: string,
  upload: {
    deliverableId: string;
    storageKey: string;
    accessToken: string;
    url: string;
    note?: string;
  },
) {
  await ensureWishSchema(db);
  const currentRow = await getAdminWishRow(db, id);
  if (!currentRow) throw new WishWorkflowError("未找到该心愿", 404);
  const wish = toAdminWish(currentRow, await getWishResponses(db, id));
  requireStatus(wish, ["in_progress"]);
  if (!wish.assignment) throw new WishWorkflowError("该心愿还没有派单记录", 409);

  const now = Date.now();
  const results = await db.batch([
    db
      .prepare("UPDATE wishes SET status = 'delivered', moderation_note = ?, updated_at = ? WHERE id = ? AND status = 'in_progress'")
      .bind(upload.note ?? wish.moderationNote, now, wish.id),
    db
      .prepare("UPDATE assignments SET status = 'delivered', delivered_at = ?, updated_at = ? WHERE id = ?")
      .bind(now, now, wish.assignment.id),
    db
      .prepare(
        "INSERT INTO deliverables (id, wish_id, assignment_id, kind, url, storage_key, access_token, note, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
      )
      .bind(
        upload.deliverableId,
        wish.id,
        wish.assignment.id,
        wish.deliveryType,
        upload.url,
        upload.storageKey,
        upload.accessToken,
        upload.note ?? null,
        now,
      ),
    db
      .prepare(
        "INSERT INTO wish_events (wish_id, event_type, from_status, to_status, actor, note, created_at) VALUES (?, 'file_uploaded', 'in_progress', 'delivered', 'operator', ?, ?)",
      )
      .bind(wish.id, upload.note ?? null, now),
  ]);
  if ((results[0].meta.changes ?? 0) !== 1) {
    throw new WishWorkflowError("心愿状态刚刚发生变化，请刷新后重试", 409);
  }

  const updated = await getAdminWishRow(db, id);
  if (!updated) throw new WishWorkflowError("更新后未找到心愿", 500);
  return toAdminWish(updated, await getWishResponses(db, id));
}

export async function getStoredDeliverable(db: D1Database, id: string, accessToken: string) {
  await ensureWishSchema(db);
  return db
    .prepare(
      "SELECT id, storage_key AS storageKey FROM deliverables WHERE id = ? AND access_token = ? AND storage_key IS NOT NULL LIMIT 1",
    )
    .bind(id, accessToken)
    .first<{ id: string; storageKey: string }>();
}

export async function getWishHealth(db: D1Database) {
  await ensureWishSchema(db);
  const row = await db.prepare("SELECT COUNT(*) AS count FROM wishes").first<{ count: number }>();
  return { database: "ready" as const, wishCount: Number(row?.count ?? 0) };
}

// MARK: - 发布者与帮助者之间的直接闭环
//
// 此前选人与上传交付都必须经过运营，这意味着运营是唯一同时持有双方联系
// 方式的一方，反而成了最大的隐私暴露面。以下三个函数让发布者在应用内直接
// 选定帮助者、帮助者直接上传交付；运营只保留公开内容的初审。

/// 发布者查看自己心愿收到的响应。**刻意不返回响应者联系方式**——
/// 站内既然能选人和交付，发布者就没有理由拿到对方的微信或手机号。
export async function listResponsesForOwner(db: D1Database, wishId: string, ownerUserId: string) {
  await ensureWishSchema(db);
  const wish = await db
    .prepare("SELECT id, user_id, status FROM wishes WHERE id = ? LIMIT 1")
    .bind(wishId)
    .first<{ id: string; user_id: string | null; status: WishStatus }>();
  if (!wish || wish.user_id !== ownerUserId) throw new WishWorkflowError("未找到该心愿", 404);

  const rows = await db
    .prepare(
      "SELECT id, responder_name, note, status, created_at FROM wish_responses WHERE wish_id = ? ORDER BY created_at ASC LIMIT 100",
    )
    .bind(wishId)
    .all<{ id: string; responder_name: string; note: string | null; status: string; created_at: number }>();

  return {
    wishStatus: wish.status,
    responses: rows.results.map((row) => ({
      id: row.id,
      responderName: row.responder_name,
      note: row.note,
      status: row.status,
      createdAt: row.created_at,
    })),
  };
}

/// 发布者选定一位帮助者：该响应置为 selected，其余置为 declined，
/// 同时建立派单记录并把心愿推进到 in_progress，使后续交付无需运营介入。
export async function selectResponderForOwner(
  db: D1Database,
  wishId: string,
  responseId: string,
  ownerUserId: string,
) {
  await ensureWishSchema(db);
  const row = await getAdminWishRow(db, wishId);
  if (!row || row.user_id !== ownerUserId) throw new WishWorkflowError("未找到该心愿", 404);
  const wish = toAdminWish(row);
  requireStatus(wish, ["matching"]);

  const response = await db
    .prepare("SELECT * FROM wish_responses WHERE id = ? AND wish_id = ? LIMIT 1")
    .bind(responseId, wishId)
    .first<WishResponseRow>();
  if (!response) throw new WishWorkflowError("未找到该响应", 404);

  const now = Date.now();
  const result = await db.batch([
    db
      .prepare(
        "UPDATE wishes SET status = 'in_progress', updated_at = ? WHERE id = ? AND status = 'matching' AND user_id = ?",
      )
      .bind(now, wishId, ownerUserId),
    db
      .prepare("UPDATE wish_responses SET status = 'selected', updated_at = ? WHERE id = ? AND wish_id = ?")
      .bind(now, responseId, wishId),
    db
      .prepare("UPDATE wish_responses SET status = 'declined', updated_at = ? WHERE wish_id = ? AND id != ?")
      .bind(now, wishId, responseId),
    db
      .prepare(
        "INSERT INTO assignments (id, wish_id, provider_id, provider_name, provider_contact, status, note, created_at, updated_at) VALUES (?, ?, NULL, ?, ?, 'accepted', NULL, ?, ?)",
      )
      .bind(crypto.randomUUID(), wishId, response.responder_name, response.responder_contact, now, now),
    db
      .prepare(
        "INSERT INTO wish_events (wish_id, event_type, from_status, to_status, actor, note, created_at) VALUES (?, 'requester_selected_responder', 'matching', 'in_progress', 'requester', NULL, ?)",
      )
      .bind(wishId, now),
  ]);
  if ((result[0].meta.changes ?? 0) !== 1) {
    throw new WishWorkflowError("心愿状态刚刚发生变化，请刷新后重试", 409);
  }

  const updated = await getAdminWishRow(db, wishId);
  if (!updated) throw new WishWorkflowError("更新后未找到心愿", 500);
  return toPublicWish(updated);
}

/// 被选中的帮助者直接上传交付。授权依据是"本人是该心愿被选中的响应者"，
/// 不需要运营密钥；上传后心愿进入 delivered，由发布者确认完成。
export async function recordResponderDeliverable(
  db: D1Database,
  wishId: string,
  responderUserId: string,
  upload: { deliverableId: string; storageKey: string; accessToken: string; url: string; note?: string },
) {
  await ensureWishSchema(db);
  const response = await db
    .prepare("SELECT * FROM wish_responses WHERE wish_id = ? AND user_id = ? AND status = 'selected' LIMIT 1")
    .bind(wishId, responderUserId)
    .first<WishResponseRow>();
  if (!response) throw new WishWorkflowError("你不是该心愿被选中的帮助者", 403);

  const row = await getAdminWishRow(db, wishId);
  if (!row) throw new WishWorkflowError("未找到该心愿", 404);
  const wish = toAdminWish(row);
  requireStatus(wish, ["in_progress"]);
  if (!wish.assignment) throw new WishWorkflowError("该心愿还没有派单记录", 409);

  const now = Date.now();
  const result = await db.batch([
    db
      .prepare("UPDATE wishes SET status = 'delivered', updated_at = ? WHERE id = ? AND status = 'in_progress'")
      .bind(now, wishId),
    db
      .prepare("UPDATE assignments SET status = 'delivered', delivered_at = ?, updated_at = ? WHERE id = ?")
      .bind(now, now, wish.assignment.id),
    db
      .prepare(
        "INSERT INTO deliverables (id, wish_id, assignment_id, kind, url, storage_key, access_token, note, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
      )
      .bind(
        upload.deliverableId,
        wishId,
        wish.assignment.id,
        wish.deliveryType,
        upload.url,
        upload.storageKey,
        upload.accessToken,
        upload.note ?? null,
        now,
      ),
    db
      .prepare(
        "INSERT INTO wish_events (wish_id, event_type, from_status, to_status, actor, note, created_at) VALUES (?, 'responder_delivered', 'in_progress', 'delivered', 'responder', NULL, ?)",
      )
      .bind(wishId, now),
  ]);
  if ((result[0].meta.changes ?? 0) !== 1) {
    throw new WishWorkflowError("心愿状态刚刚发生变化，请刷新后重试", 409);
  }

  const updated = await getAdminWishRow(db, wishId);
  if (!updated) throw new WishWorkflowError("更新后未找到心愿", 500);
  return toPublicWish(updated);
}
