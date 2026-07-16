export const wishStatuses = [
  "pending_review",
  "matching",
  "assigned",
  "in_progress",
  "delivered",
  "completed",
  "rejected",
  "cancelled",
] as const;

export type WishStatus = (typeof wishStatuses)[number];

export const wishStatusLabels: Record<WishStatus, string> = {
  pending_review: "待审核",
  matching: "待匹配",
  assigned: "已派单",
  in_progress: "进行中",
  delivered: "待确认",
  completed: "已完成",
  rejected: "未通过",
  cancelled: "已取消",
};

export const deliveryTypes = ["spoken_video", "scenery_voiceover", "handwritten_card"] as const;
export type DeliveryType = (typeof deliveryTypes)[number];

export const deliveryTypeLabels: Record<DeliveryType, string> = {
  spoken_video: "口播视频",
  scenery_voiceover: "景色配音",
  handwritten_card: "手写卡片",
};

export interface CreateWishInput {
  requesterName: string;
  contact: string;
  city: string;
  landmark: string;
  occasion: string;
  message: string;
  deliveryType: DeliveryType;
  deadlineText: string;
  rewardFen: number;
  contactConsent: boolean;
  website?: string;
}

export interface CreateWishResponseInput {
  responderName: string;
  responderContact: string;
  note?: string;
  contactConsent: boolean;
  website?: string;
}

export interface PublicWish {
  id: string;
  publicCode: string;
  city: string;
  landmark: string;
  occasion: string;
  message: string;
  deliveryType: DeliveryType;
  deadlineText: string;
  rewardFen: number;
  status: WishStatus;
  createdAt: number;
}

export interface WishAssignment {
  id: string;
  providerId: string | null;
  providerName: string;
  providerContact: string;
  status: "offered" | "accepted" | "arrived" | "delivered" | "declined" | "cancelled";
  note: string | null;
  createdAt: number;
  updatedAt: number;
}

export const providerStatuses = ["available", "busy", "paused"] as const;
export type ProviderStatus = (typeof providerStatuses)[number];

export const providerStatusLabels: Record<ProviderStatus, string> = {
  available: "可接单",
  busy: "履约中",
  paused: "已暂停",
};

export interface Provider {
  id: string;
  name: string;
  contact: string;
  city: string;
  landmarks: string;
  availabilityNote: string | null;
  status: ProviderStatus;
  completedCount: number;
  lastAssignedAt: number | null;
  createdAt: number;
  updatedAt: number;
}

export interface CreateProviderInput {
  name: string;
  contact: string;
  city: string;
  landmarks: string;
  availabilityNote?: string;
}

export interface UpdateProviderInput {
  name?: string;
  contact?: string;
  city?: string;
  landmarks?: string;
  availabilityNote?: string;
  status?: ProviderStatus;
}

export interface WishDeliverable {
  id: string;
  kind: DeliveryType | "link";
  url: string;
  note: string | null;
  createdAt: number;
}

export interface WishResponse {
  id: string;
  responderName: string;
  responderContact: string;
  note: string | null;
  status: "pending" | "selected" | "declined";
  createdAt: number;
  updatedAt: number;
}

export interface WishEvent {
  eventType: string;
  fromStatus: WishStatus | null;
  toStatus: WishStatus | null;
  createdAt: number;
}

export interface TrackedWish extends PublicWish {
  updatedAt: number;
  assignment: Pick<WishAssignment, "providerName" | "status"> | null;
  deliverable: WishDeliverable | null;
  events: WishEvent[];
}

export interface AdminWish extends PublicWish {
  requesterName: string;
  contact: string;
  publishFeeFen: number;
  moderationNote: string | null;
  updatedAt: number;
  assignment: WishAssignment | null;
  deliverable: WishDeliverable | null;
  responses: WishResponse[];
}

export const adminWishActions = [
  "approve",
  "reject",
  "assign",
  "accept",
  "mark_delivered",
  "complete",
  "cancel",
  "reopen_matching",
] as const;

export type AdminWishAction = (typeof adminWishActions)[number];

export interface AdminWishActionInput {
  action: AdminWishAction;
  note?: string;
  providerName?: string;
  providerContact?: string;
  deliveryUrl?: string;
  responseId?: string;
  providerId?: string;
}

export interface ApiErrorPayload {
  error: string;
  fields?: Record<string, string>;
}
