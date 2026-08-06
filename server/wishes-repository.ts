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

  // 不再向用户索取联系方式。contact 列是 NOT NULL，用账号标识占位既满足
  // 约束，也让防重复提交改为按账号判断；无账号的历史路径保持原行为。
  const contactKey = userId ? `account:${userId}` : input.contact;
  const duplicate = await db
    .prepare(
      "SELECT * FROM wishes WHERE contact = ? AND message = ? AND created_at >= ? ORDER BY created_at DESC LIMIT 1",
    )
    .bind(contactKey, input.message, now - 60_000)
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
        contactKey,
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

  // 不再向用户索取联系方式，因此去重改为按账号。responder_contact 列有
  // NOT NULL 与 (wish_id, responder_contact) 唯一约束，用账号标识占位既能
  // 满足约束，又不落任何真实联系方式；无账号的历史路径仍按原值去重。
  const dedupeKey = userId ? `account:${userId}` : input.responderContact;
  const duplicate = await db
    .prepare(
      userId
        ? "SELECT * FROM wish_responses WHERE wish_id = ? AND user_id = ? LIMIT 1"
        : "SELECT * FROM wish_responses WHERE wish_id = ? AND responder_contact = ? LIMIT 1",
    )
    .bind(wishId, userId ?? input.responderContact)
    .first<WishResponseRow>();
  if (duplicate) return { response: toWishResponse(duplicate), created: false };

  const id = crypto.randomUUID();
  const now = Date.now();
  await db.batch([
    db
      .prepare(
        "INSERT INTO wish_responses (id, wish_id, responder_name, responder_contact, note, status, user_id, created_at, updated_at) VALUES (?, ?, ?, ?, ?, 'pending', ?, ?, ?)",
      )
      .bind(id, wishId, input.responderName, dedupeKey, input.note ?? null, userId ?? null, now, now),
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
      responderContact: dedupeKey,
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
        `SELECT w.*, r.id AS response_id, r.status AS response_status, r.created_at AS response_created_at
         FROM wish_responses r JOIN wishes w ON w.id = r.wish_id
         WHERE r.user_id = ? ORDER BY r.updated_at DESC LIMIT 100`,
      )
      .bind(userId)
      .all<WishRow & { response_id: string; response_status: WishResponse["status"]; response_created_at: number }>(),
  ]);

  // 每条心愿的响应数，以及已选中的那条响应（供客户端直接跳进会话）
  const wishIds = requestResult.results.map((row) => row.id);
  const responseCounts = new Map<string, number>();
  const selectedResponses = new Map<string, string>();
  if (wishIds.length > 0) {
    const placeholders = wishIds.map(() => "?").join(",");
    const counts = await db
      .prepare(
        `SELECT wish_id, COUNT(*) AS total,
                MAX(CASE WHEN status = 'selected' THEN id END) AS selected_id
         FROM wish_responses WHERE wish_id IN (${placeholders}) GROUP BY wish_id`,
      )
      .bind(...wishIds)
      .all<{ wish_id: string; total: number; selected_id: string | null }>();
    for (const row of counts.results) {
      responseCounts.set(row.wish_id, Number(row.total));
      if (row.selected_id) selectedResponses.set(row.wish_id, row.selected_id);
    }
  }

  return {
    requests: requestResult.results.map((row) => ({
      ...toPublicWish(row),
      updatedAt: row.updated_at,
      hasDeliverable: Boolean(row.deliverable_id),
      canConfirmCompletion: row.status === "delivered",
      // 发布者需要在「我发布的」直接看到有几个人响应、能不能选人，
      // 否则只能靠自己去翻私聊，闭环最容易断在这一步。
      responseCount: responseCounts.get(row.id) ?? 0,
      canSelectResponder: row.status === "matching" && (responseCounts.get(row.id) ?? 0) > 0,
      selectedResponseId: selectedResponses.get(row.id) ?? null,
    })),
    responses: responseResult.results.map((row) => ({
      wish: toPublicWish(row),
      responseStatus: row.response_status,
      respondedAt: row.response_created_at,
      // 帮助者需要在「我帮助的」直接看到自己被没被选中、能不能提交交付
      responseId: row.response_id,
      canDeliver: row.response_status === "selected" && row.status === "in_progress",
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
  upload: {
    /// 一次「完成帮助」的说明文字，与本组文件一同交付
    note?: string;
    /// 最多 9 个图片或视频，按数组顺序保持展示次序
    files: { deliverableId: string; storageKey: string; accessToken: string; url: string }[];
  },
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

  if (upload.files.length < 1 || upload.files.length > 9) {
    throw new WishWorkflowError("请上传 1–9 个图片或视频", 400);
  }

  const now = Date.now();
  // 同一次「完成帮助」的文件共享 group_id，说明文字记在第一条上，
  // position 保持展示次序。
  const groupId = crypto.randomUUID();
  const result = await db.batch([
    db
      .prepare("UPDATE wishes SET status = 'delivered', updated_at = ? WHERE id = ? AND status = 'in_progress'")
      .bind(now, wishId),
    db
      .prepare("UPDATE assignments SET status = 'delivered', delivered_at = ?, updated_at = ? WHERE id = ?")
      .bind(now, now, wish.assignment.id),
    ...upload.files.map((file, index) =>
      db
        .prepare(
          "INSERT INTO deliverables (id, wish_id, assignment_id, kind, url, storage_key, access_token, note, group_id, position, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        )
        .bind(
          file.deliverableId,
          wishId,
          wish.assignment!.id,
          wish.deliveryType,
          file.url,
          file.storageKey,
          file.accessToken,
          index === 0 ? upload.note ?? null : null,
          groupId,
          index,
          now,
        ),
    ),
    db
      .prepare(
        "INSERT INTO wish_events (wish_id, event_type, from_status, to_status, actor, note, created_at) VALUES (?, 'responder_delivered', 'in_progress', 'delivered', 'responder', ?, ?)",
      )
      .bind(wishId, upload.note ?? null, now),
  ]);
  if ((result[0].meta.changes ?? 0) !== 1) {
    throw new WishWorkflowError("心愿状态刚刚发生变化，请刷新后重试", 409);
  }

  const updated = await getAdminWishRow(db, wishId);
  if (!updated) throw new WishWorkflowError("更新后未找到心愿", 500);
  return toPublicWish(updated);
}

// MARK: - 站内私聊
//
// 会话以「心愿 + 一条响应」为单位：帮助者一响应即可开聊，因此同一心愿可能
// 同时存在多个会话，需求方据此判断选谁。纯文字，不支持文件——降低审核面，
// 交付走独立的上传通道。

/// 判定某用户是否有权读写该会话，并返回会话双方。
/// 只有心愿的发布者、或该响应的提交者本人可以进入。
async function requireConversationAccess(db: D1Database, responseId: string, userId: string) {
  const row = await db
    .prepare(
      `SELECT r.id AS response_id, r.wish_id, r.user_id AS responder_user_id, r.responder_name,
              r.status AS response_status, w.user_id AS owner_user_id, w.status AS wish_status
       FROM wish_responses r JOIN wishes w ON w.id = r.wish_id
       WHERE r.id = ? LIMIT 1`,
    )
    .bind(responseId)
    .first<{
      response_id: string;
      wish_id: string;
      responder_user_id: string | null;
      responder_name: string;
      response_status: string;
      owner_user_id: string | null;
      wish_status: WishStatus;
    }>();
  if (!row) throw new WishWorkflowError("未找到该会话", 404);

  const isOwner = row.owner_user_id === userId;
  const isResponder = row.responder_user_id === userId;
  if (!isOwner && !isResponder) throw new WishWorkflowError("你无权查看该会话", 403);

  const counterpartId = isOwner ? row.responder_user_id : row.owner_user_id;
  // 任一方拉黑之后，会话即不可继续。
  if (counterpartId) {
    const blocked = await db
      .prepare(
        "SELECT 1 FROM user_blocks WHERE (blocker_user_id = ? AND blocked_user_id = ?) OR (blocker_user_id = ? AND blocked_user_id = ?) LIMIT 1",
      )
      .bind(userId, counterpartId, counterpartId, userId)
      .first();
    if (blocked) throw new WishWorkflowError("该会话已被屏蔽", 403);
  }
  return { ...row, isOwner, isResponder, counterpartId };
}

export async function listConversationMessages(db: D1Database, responseId: string, userId: string) {
  await ensureWishSchema(db);
  const access = await requireConversationAccess(db, responseId, userId);
  const rows = await db
    .prepare(
      "SELECT id, sender_user_id, body, created_at FROM wish_messages WHERE response_id = ? AND deleted_at IS NULL ORDER BY created_at ASC LIMIT 500",
    )
    .bind(responseId)
    .all<{ id: string; sender_user_id: string; body: string; created_at: number }>();

  // 打开会话即视为读到最新一条：这是最自然的标记时机，
  // 不需要客户端再单独调一次接口。
  await db
    .prepare(
      "INSERT INTO conversation_reads (response_id, user_id, last_read_at) VALUES (?, ?, ?)\n" +
      "ON CONFLICT(response_id, user_id) DO UPDATE SET last_read_at = excluded.last_read_at",
    )
    .bind(responseId, userId, Date.now())
    .run();

  return {
    responseId,
    wishId: access.wish_id,
    wishStatus: access.wish_status,
    responseStatus: access.response_status,
    // 对方以昵称示人，不暴露账号标识或联系方式
    counterpartName: access.isOwner ? access.responder_name : "发布者",
    viewerRole: access.isOwner ? ("requester" as const) : ("responder" as const),
    messages: rows.results.map((row) => ({
      id: row.id,
      body: row.body,
      mine: row.sender_user_id === userId,
      createdAt: row.created_at,
    })),
  };
}

export async function sendConversationMessage(
  db: D1Database,
  responseId: string,
  userId: string,
  body: string,
) {
  await ensureWishSchema(db);
  const access = await requireConversationAccess(db, responseId, userId);
  const text = body.trim();
  if (text.length < 1 || text.length > 500) {
    throw new WishWorkflowError("消息内容需在 1–500 字之间", 400);
  }
  // 已完成或已取消的心愿不再接受新消息，避免会话无限期存续。
  if (["completed", "cancelled", "rejected"].includes(access.wish_status)) {
    throw new WishWorkflowError("该心愿已结束，会话不再接受新消息", 409);
  }

  const id = crypto.randomUUID();
  const now = Date.now();
  await db
    .prepare(
      "INSERT INTO wish_messages (id, wish_id, response_id, sender_user_id, body, created_at) VALUES (?, ?, ?, ?, ?, ?)",
    )
    .bind(id, access.wish_id, responseId, userId, text, now)
    .run();
  return { id, body: text, mine: true, createdAt: now };
}

/// 举报。App 内存在陌生人即时通讯时，App Store 指南 1.2 要求必须提供。
export async function reportAbuse(
  db: D1Database,
  reporterUserId: string,
  input: { responseId?: string; wishId?: string; reason: string; detail?: string },
) {
  await ensureWishSchema(db);
  const reason = input.reason.trim();
  if (reason.length < 1 || reason.length > 60) throw new WishWorkflowError("请选择举报原因", 400);

  let reportedUserId: string | null = null;
  let wishId = input.wishId ?? null;
  if (input.responseId) {
    const access = await requireConversationAccess(db, input.responseId, reporterUserId);
    reportedUserId = access.counterpartId;
    wishId = access.wish_id;
  }

  const id = crypto.randomUUID();
  await db
    .prepare(
      "INSERT INTO abuse_reports (id, reporter_user_id, wish_id, response_id, reported_user_id, reason, detail, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, 'open', ?)",
    )
    .bind(id, reporterUserId, wishId, input.responseId ?? null, reportedUserId, reason, input.detail?.slice(0, 500) ?? null, Date.now())
    .run();
  return { id, status: "open" as const };
}

/// 拉黑对方。拉黑后双向不可再进入该会话。
export async function blockCounterpart(db: D1Database, responseId: string, userId: string) {
  await ensureWishSchema(db);
  const access = await requireConversationAccess(db, responseId, userId);
  if (!access.counterpartId) throw new WishWorkflowError("该会话没有可屏蔽的对象", 400);
  await db
    .prepare("INSERT OR IGNORE INTO user_blocks (blocker_user_id, blocked_user_id, created_at) VALUES (?, ?, ?)")
    .bind(userId, access.counterpartId, Date.now())
    .run();
  return { blocked: true };
}

/// 我参与的全部会话，供「私聊」标签页使用。
/// 同时覆盖两种身份：我发布的心愿收到的响应，以及我响应过的心愿。
export async function listMyConversations(db: D1Database, userId: string) {
  await ensureWishSchema(db);
  const rows = await db
    .prepare(
      `SELECT r.id AS response_id, r.responder_name, r.status AS response_status,
              r.user_id AS responder_user_id,
              w.id AS wish_id, w.public_code, w.city, w.landmark, w.occasion, w.status AS wish_status,
              w.user_id AS owner_user_id,
              (SELECT body FROM wish_messages m WHERE m.response_id = r.id AND m.deleted_at IS NULL
                 ORDER BY m.created_at DESC LIMIT 1) AS last_body,
              (SELECT created_at FROM wish_messages m WHERE m.response_id = r.id AND m.deleted_at IS NULL
                 ORDER BY m.created_at DESC LIMIT 1) AS last_at,
              (SELECT COUNT(*) FROM wish_messages m
                 WHERE m.response_id = r.id AND m.deleted_at IS NULL
                   AND m.sender_user_id != ?
                   AND m.created_at > COALESCE(
                     (SELECT last_read_at FROM conversation_reads cr
                       WHERE cr.response_id = r.id AND cr.user_id = ?), 0)) AS unread
       FROM wish_responses r JOIN wishes w ON w.id = r.wish_id
       WHERE w.user_id = ? OR r.user_id = ?
       ORDER BY COALESCE(last_at, r.created_at) DESC LIMIT 100`,
    )
    .bind(userId, userId, userId, userId)
    .all<{
      response_id: string;
      responder_name: string;
      response_status: string;
      responder_user_id: string | null;
      wish_id: string;
      public_code: string;
      city: string;
      landmark: string;
      occasion: string;
      wish_status: WishStatus;
      owner_user_id: string | null;
      last_body: string | null;
      last_at: number | null;
      unread: number;
    }>();

  // 被任一方拉黑的会话不再出现在列表里
  const blocks = await db
    .prepare("SELECT blocker_user_id, blocked_user_id FROM user_blocks WHERE blocker_user_id = ? OR blocked_user_id = ?")
    .bind(userId, userId)
    .all<{ blocker_user_id: string; blocked_user_id: string }>();
  const blockedIds = new Set(
    blocks.results.flatMap((row) => [row.blocker_user_id, row.blocked_user_id]).filter((id) => id !== userId),
  );

  const visible = rows.results.filter((row) => {
    const isOwner = row.owner_user_id === userId;
    const counterpart = isOwner ? row.responder_user_id : row.owner_user_id;
    return !counterpart || !blockedIds.has(counterpart);
  });

  return {
    // Dock 角标用的总未读数，避免客户端自己累加
    totalUnread: visible.reduce((sum, row) => sum + Number(row.unread ?? 0), 0),
    conversations: rows.results
      .filter((row) => {
        const isOwner = row.owner_user_id === userId;
        const counterpart = isOwner ? row.responder_user_id : row.owner_user_id;
        return !counterpart || !blockedIds.has(counterpart);
      })
      .map((row) => {
        const isOwner = row.owner_user_id === userId;
        return {
          responseId: row.response_id,
          wishId: row.wish_id,
          publicCode: row.public_code,
          title: `${row.city} · ${row.landmark}`,
          occasion: row.occasion,
          wishStatus: row.wish_status,
          responseStatus: row.response_status,
          viewerRole: isOwner ? ("requester" as const) : ("responder" as const),
          counterpartName: isOwner ? row.responder_name : "发布者",
          lastMessage: row.last_body,
          lastMessageAt: row.last_at,
          unreadCount: Number(row.unread ?? 0),
        };
      }),
  };
}

// MARK: - 故事公开
//
// 完成之后由需求方单独决定是否公开到首页，默认不公开。帮助者在响应时已
// 同意其提交的文字与影像由需求方支配（含公开分享），该同意时间记录在
// wish_responses.content_license_agreed_at。

export async function publishWishStory(
  db: D1Database,
  wishId: string,
  ownerUserId: string,
  input: { nickname?: string },
) {
  await ensureWishSchema(db);
  const row = await getAdminWishRow(db, wishId);
  if (!row || row.user_id !== ownerUserId) throw new WishWorkflowError("未找到该心愿", 404);
  const wish = toAdminWish(row);
  // 只有真正完成的心愿才能成为故事，避免半途内容进入公开流
  requireStatus(wish, ["completed"]);

  const nickname = (input.nickname ?? "").trim().slice(0, 20);
  const now = Date.now();
  await db
    .prepare("UPDATE wishes SET story_published_at = ?, story_nickname = ?, updated_at = ? WHERE id = ? AND user_id = ?")
    .bind(now, nickname || null, now, wishId, ownerUserId)
    .run();
  return { published: true, publishedAt: now };
}

export async function unpublishWishStory(db: D1Database, wishId: string, ownerUserId: string) {
  await ensureWishSchema(db);
  const result = await db
    .prepare("UPDATE wishes SET story_published_at = NULL, updated_at = ? WHERE id = ? AND user_id = ?")
    .bind(Date.now(), wishId, ownerUserId)
    .run();
  if ((result.meta.changes ?? 0) !== 1) throw new WishWorkflowError("未找到该心愿", 404);
  return { published: false };
}

/// 首页故事流。只返回需求方明确公开过的已完成心愿，
/// 且不含联系方式与精确位置——与「公开故事不显示联系方式」的承诺一致。
export async function listPublishedStories(db: D1Database, limit = 30) {
  await ensureWishSchema(db);
  const rows = await db
    .prepare(
      `SELECT id, public_code, city, landmark, occasion, message, delivery_type,
              story_nickname, story_published_at
       FROM wishes
       WHERE story_published_at IS NOT NULL AND status = 'completed'
       ORDER BY story_published_at DESC LIMIT ?`,
    )
    .bind(limit)
    .all<{
      id: string;
      public_code: string;
      city: string;
      landmark: string;
      occasion: string;
      message: string;
      delivery_type: string;
      story_nickname: string | null;
      story_published_at: number;
    }>();

  const stories = [];
  for (const row of rows.results) {
    const media = await db
      .prepare(
        "SELECT id, url, kind, note FROM deliverables WHERE wish_id = ? ORDER BY position ASC, created_at ASC LIMIT 9",
      )
      .bind(row.id)
      .all<{ id: string; url: string; kind: string; note: string | null }>();
    stories.push({
      id: row.id,
      publicCode: row.public_code,
      nickname: row.story_nickname ?? "匿名",
      city: row.city,
      landmark: row.landmark,
      occasion: row.occasion,
      message: row.message,
      deliveryType: row.delivery_type,
      publishedAt: row.story_published_at,
      note: media.results.find((item) => item.note)?.note ?? null,
      media: media.results.map((item) => ({ id: item.id, url: item.url, kind: item.kind })),
    });
  }
  return { stories };
}

// MARK: - 用户资料（昵称与头像）
//
// 昵称与头像会出现在私聊、响应列表与公开故事里，属于公开可见的用户生成内容，
// 因此先审后可见：本人始终看到自己刚提交的版本，他人看到上一版通过审核的版本；
// 没有通过版本时他人看到系统默认值。与心愿正文的既有规则一致。

const defaultDisplayName = "哈喽卧得用户";

export type UserProfile = {
  displayName: string;
  avatarUrl: string | null;
  /// 待审核时为 true，用于在「我的」上给本人一个明确提示
  pendingReview: boolean;
  reviewNote: string | null;
};

/// 本人视角：看到自己刚提交的版本
export async function getOwnProfile(db: D1Database, userId: string): Promise<UserProfile> {
  await ensureWishSchema(db);
  const row = await db
    .prepare("SELECT display_name, avatar_key, profile_status, profile_note FROM users WHERE id = ? LIMIT 1")
    .bind(userId)
    .first<{ display_name: string | null; avatar_key: string | null; profile_status: string; profile_note: string | null }>();
  if (!row) throw new WishWorkflowError("未找到账户", 404);
  return {
    displayName: row.display_name || defaultDisplayName,
    avatarUrl: row.avatar_key ? `/api/avatars/${encodeURIComponent(row.avatar_key)}` : null,
    pendingReview: row.profile_status === "pending",
    reviewNote: row.profile_note,
  };
}

/// 他人视角：只返回已通过审核的版本
export async function getPublicProfile(db: D1Database, userId: string): Promise<UserProfile> {
  const row = await db
    .prepare("SELECT approved_display_name, approved_avatar_key FROM users WHERE id = ? LIMIT 1")
    .bind(userId)
    .first<{ approved_display_name: string | null; approved_avatar_key: string | null }>();
  return {
    displayName: row?.approved_display_name || defaultDisplayName,
    avatarUrl: row?.approved_avatar_key ? `/api/avatars/${encodeURIComponent(row.approved_avatar_key)}` : null,
    pendingReview: false,
    reviewNote: null,
  };
}

/// 提交新的昵称或头像。提交即进入待审核，他人仍看旧版本。
export async function submitProfile(
  db: D1Database,
  userId: string,
  input: { displayName?: string; avatarKey?: string },
) {
  await ensureWishSchema(db);
  const now = Date.now();
  const updates: string[] = [];
  const values: unknown[] = [];

  if (input.displayName !== undefined) {
    const name = input.displayName.trim();
    if (name.length < 1 || name.length > 20) {
      throw new WishWorkflowError("昵称需在 1–20 个字之间", 400);
    }
    updates.push("display_name = ?");
    values.push(name);
  }
  if (input.avatarKey !== undefined) {
    updates.push("avatar_key = ?");
    values.push(input.avatarKey);
  }
  if (updates.length === 0) throw new WishWorkflowError("没有要更新的内容", 400);

  updates.push("profile_status = 'pending'", "profile_note = NULL", "profile_updated_at = ?");
  values.push(now, userId);
  await db.prepare(`UPDATE users SET ${updates.join(", ")} WHERE id = ?`).bind(...values).run();
  return getOwnProfile(db, userId);
}

/// 运营审核用户资料。通过则把待审内容提升为对外可见版本。
export async function reviewProfile(
  db: D1Database,
  userId: string,
  action: "approve" | "reject",
  note?: string,
) {
  await ensureWishSchema(db);
  if (action === "approve") {
    await db
      .prepare(
        `UPDATE users SET approved_display_name = display_name, approved_avatar_key = avatar_key,
                          profile_status = 'approved', profile_note = NULL WHERE id = ?`,
      )
      .bind(userId)
      .run();
  } else {
    // 退回时清掉待审内容，回落到上一版通过的资料，避免违规内容滞留
    await db
      .prepare(
        `UPDATE users SET display_name = approved_display_name, avatar_key = approved_avatar_key,
                          profile_status = 'rejected', profile_note = ? WHERE id = ?`,
      )
      .bind(note ?? "资料未通过审核，请修改后重新提交", userId)
      .run();
  }
  return getOwnProfile(db, userId);
}

/// 运营待办：待审核的用户资料
export async function listPendingProfiles(db: D1Database) {
  await ensureWishSchema(db);
  const rows = await db
    .prepare(
      `SELECT id, display_name, avatar_key, profile_updated_at FROM users
       WHERE profile_status = 'pending' ORDER BY profile_updated_at ASC LIMIT 100`,
    )
    .all<{ id: string; display_name: string | null; avatar_key: string | null; profile_updated_at: number | null }>();
  return {
    profiles: rows.results.map((row) => ({
      userId: row.id,
      displayName: row.display_name,
      avatarUrl: row.avatar_key ? `/api/avatars/${encodeURIComponent(row.avatar_key)}` : null,
      submittedAt: row.profile_updated_at,
    })),
  };
}
