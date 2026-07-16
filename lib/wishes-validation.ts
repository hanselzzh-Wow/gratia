import {
  adminWishActions,
  deliveryTypes,
  type AdminWishActionInput,
  type CreateWishInput,
  type CreateWishResponseInput,
  type DeliveryType,
} from "./wishes-contract";

export class WishInputError extends Error {
  fields: Record<string, string>;

  constructor(message: string, fields: Record<string, string> = {}) {
    super(message);
    this.name = "WishInputError";
    this.fields = fields;
  }
}

function cleanText(value: unknown) {
  return typeof value === "string"
    ? value.replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, "").trim()
    : "";
}

function boundedText(
  value: unknown,
  field: string,
  label: string,
  min: number,
  max: number,
  errors: Record<string, string>,
) {
  const text = cleanText(value);
  if (text.length < min || text.length > max) {
    errors[field] = `${label}需为 ${min}–${max} 个字符`;
  }
  return text;
}

export function normalizeCreateWish(payload: unknown): CreateWishInput {
  if (!payload || typeof payload !== "object") {
    throw new WishInputError("请完整填写心愿信息");
  }

  const input = payload as Record<string, unknown>;
  if (cleanText(input.website)) {
    throw new WishInputError("提交未通过校验");
  }

  const fields: Record<string, string> = {};
  const requesterName = boundedText(input.requesterName, "requesterName", "称呼", 1, 30, fields);
  const contact = boundedText(input.contact, "contact", "联系方式", 3, 80, fields);
  const city = boundedText(input.city, "city", "城市", 2, 24, fields);
  const landmark = boundedText(input.landmark, "landmark", "地标", 2, 40, fields);
  const occasion = boundedText(input.occasion, "occasion", "心愿场景", 2, 24, fields);
  const message = boundedText(input.message, "message", "想说的话", 5, 120, fields);
  const deadlineText = boundedText(input.deadlineText, "deadlineText", "期望时间", 2, 40, fields);

  const deliveryType = cleanText(input.deliveryType) as DeliveryType;
  if (!deliveryTypes.includes(deliveryType)) {
    fields.deliveryType = "请选择交付方式";
  }

  const rewardFen = Number(input.rewardFen);
  if (!Number.isInteger(rewardFen) || rewardFen < 0 || rewardFen > 100_000) {
    fields.rewardFen = "感谢金需在 0–1000 元之间";
  }

  if (input.contactConsent !== true) {
    fields.contactConsent = "请确认允许运营人员为履约联系你";
  }

  if (Object.keys(fields).length > 0) {
    throw new WishInputError("请检查心愿信息", fields);
  }

  return {
    requesterName,
    contact,
    city,
    landmark,
    occasion,
    message,
    deliveryType,
    deadlineText,
    rewardFen,
    contactConsent: true,
  };
}

export function normalizeWishResponse(payload: unknown): CreateWishResponseInput {
  if (!payload || typeof payload !== "object") {
    throw new WishInputError("请完整填写响应信息");
  }
  const input = payload as Record<string, unknown>;
  if (cleanText(input.website)) throw new WishInputError("提交未通过校验");

  const fields: Record<string, string> = {};
  const responderName = boundedText(input.responderName, "responderName", "称呼", 1, 30, fields);
  const responderContact = boundedText(
    input.responderContact,
    "responderContact",
    "联系方式",
    3,
    80,
    fields,
  );
  const note = cleanText(input.note).slice(0, 160);
  if (input.contactConsent !== true) {
    fields.contactConsent = "请确认允许运营人员为撮合联系你";
  }
  if (Object.keys(fields).length > 0) {
    throw new WishInputError("请检查响应信息", fields);
  }
  return {
    responderName,
    responderContact,
    note: note || undefined,
    contactConsent: true,
  };
}

export function normalizeTrackingInput(payload: unknown) {
  if (!payload || typeof payload !== "object") {
    throw new WishInputError("请填写心愿编号和联系方式");
  }
  const input = payload as Record<string, unknown>;
  const fields: Record<string, string> = {};
  const publicCode = boundedText(input.publicCode, "publicCode", "心愿编号", 8, 24, fields).toUpperCase();
  const contact = boundedText(input.contact, "contact", "联系方式", 3, 80, fields);
  if (Object.keys(fields).length > 0) {
    throw new WishInputError("请检查查询信息", fields);
  }
  return { publicCode, contact };
}

export function normalizeAdminAction(payload: unknown): AdminWishActionInput {
  if (!payload || typeof payload !== "object") {
    throw new WishInputError("缺少运营操作");
  }

  const input = payload as Record<string, unknown>;
  const action = cleanText(input.action) as AdminWishActionInput["action"];
  if (!adminWishActions.includes(action)) {
    throw new WishInputError("不支持的运营操作");
  }

  return {
    action,
    note: cleanText(input.note).slice(0, 300) || undefined,
    providerName: cleanText(input.providerName).slice(0, 40) || undefined,
    providerContact: cleanText(input.providerContact).slice(0, 80) || undefined,
    deliveryUrl: cleanText(input.deliveryUrl).slice(0, 500) || undefined,
    responseId: cleanText(input.responseId).slice(0, 80) || undefined,
  };
}
