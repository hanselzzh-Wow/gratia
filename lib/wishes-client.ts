import type {
  AdminWish,
  AdminWishActionInput,
  ApiErrorPayload,
  CreateWishInput,
  CreateWishResponseInput,
  CreateProviderInput,
  Provider,
  PublicWish,
  TrackedWish,
  UpdateProviderInput,
  WishResponse,
} from "./wishes-contract";

const configuredBase = process.env.NEXT_PUBLIC_API_BASE_URL?.trim().replace(/\/$/, "") ?? "";

export class WishApiError extends Error {
  status: number;
  fields?: Record<string, string>;

  constructor(message: string, status: number, fields?: Record<string, string>) {
    super(message);
    this.name = "WishApiError";
    this.status = status;
    this.fields = fields;
  }
}

function endpoint(path: string) {
  return `${configuredBase}${path}`;
}

async function requestJson<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(endpoint(path), {
    ...init,
    headers: {
      accept: "application/json",
      ...(typeof init?.body === "string" ? { "content-type": "application/json" } : {}),
      ...init?.headers,
    },
  });

  const payload = (await response.json().catch(() => ({ error: "服务返回了无效响应" }))) as
    | T
    | ApiErrorPayload;
  if (!response.ok) {
    const apiError = payload as ApiErrorPayload;
    throw new WishApiError(apiError.error || "请求失败", response.status, apiError.fields);
  }
  return payload as T;
}

export const wishesClient = {
  async list(city?: string) {
    const query = city ? `?city=${encodeURIComponent(city)}` : "";
    return requestJson<{ wishes: PublicWish[] }>(`/api/wishes${query}`);
  },

  async create(input: CreateWishInput) {
    return requestJson<{ wish: PublicWish; created: boolean }>("/api/wishes", {
      method: "POST",
      body: JSON.stringify(input),
    });
  },

  async respond(wishId: string, input: CreateWishResponseInput) {
    return requestJson<{ response: WishResponse; created: boolean }>(
      `/api/wishes/${encodeURIComponent(wishId)}/responses`,
      { method: "POST", body: JSON.stringify(input) },
    );
  },

  async track(publicCode: string, contact: string) {
    return requestJson<{ wish: TrackedWish }>("/api/wishes/track", {
      method: "POST",
      body: JSON.stringify({ publicCode, contact }),
    });
  },

  async listAdmin(adminKey: string, status?: string) {
    const query = status ? `?status=${encodeURIComponent(status)}` : "";
    return requestJson<{ wishes: AdminWish[] }>(`/api/admin/wishes${query}`, {
      headers: { "x-admin-key": adminKey },
    });
  },

  async listProviders(adminKey: string, city?: string) {
    const query = city ? `?city=${encodeURIComponent(city)}` : "";
    return requestJson<{ providers: Provider[] }>(`/api/admin/providers${query}`, {
      headers: { "x-admin-key": adminKey },
    });
  },

  async createProvider(adminKey: string, input: CreateProviderInput) {
    return requestJson<{ provider: Provider }>("/api/admin/providers", {
      method: "POST",
      headers: { "x-admin-key": adminKey },
      body: JSON.stringify(input),
    });
  },

  async updateProvider(adminKey: string, id: string, input: UpdateProviderInput) {
    return requestJson<{ provider: Provider }>(`/api/admin/providers/${encodeURIComponent(id)}`, {
      method: "PATCH",
      headers: { "x-admin-key": adminKey },
      body: JSON.stringify(input),
    });
  },

  async applyAdminAction(adminKey: string, id: string, input: AdminWishActionInput) {
    return requestJson<{ wish: AdminWish }>(`/api/admin/wishes/${encodeURIComponent(id)}`, {
      method: "PATCH",
      headers: { "x-admin-key": adminKey },
      body: JSON.stringify(input),
    });
  },

  async uploadDeliverable(adminKey: string, id: string, file: File, note?: string) {
    const form = new FormData();
    form.set("file", file);
    if (note) form.set("note", note);
    return requestJson<{ wish: AdminWish }>(
      `/api/admin/wishes/${encodeURIComponent(id)}/deliverables/upload`,
      {
        method: "POST",
        headers: { "x-admin-key": adminKey },
        body: form,
      },
    );
  },

  async exportOperations(adminKey: string) {
    const response = await fetch(endpoint("/api/admin/export.csv"), {
      headers: { "x-admin-key": adminKey },
    });
    if (!response.ok) {
      const payload = (await response.json().catch(() => ({ error: "导出失败" }))) as ApiErrorPayload;
      throw new WishApiError(payload.error || "导出失败", response.status, payload.fields);
    }
    return response.blob();
  },

  // MARK: - 用户资料审核

  async listPendingProfiles(adminKey: string) {
    return requestJson<{ profiles: PendingProfile[] }>("/api/admin/profiles", {
      headers: { "x-admin-key": adminKey },
    });
  },

  /**
   * 审核用户资料。
   *
   * `target` 指明处理哪一样——昵称与头像是两条独立的线，不传则按整份处理。
   * `ban` 只在退回昵称时有意义：重名被退不该永久锁死那个名字，辱骂性的才该，
   * 所以由运营自己勾。
   */
  async reviewProfile(
    adminKey: string,
    userId: string,
    action: "approve" | "reject",
    note?: string,
    options: { target?: "displayName" | "avatar" | "both"; ban?: boolean } = {},
  ) {
    return requestJson<unknown>(`/api/admin/profiles/${encodeURIComponent(userId)}`, {
      method: "PATCH",
      headers: { "x-admin-key": adminKey },
      body: JSON.stringify({ action, note, target: options.target, ban: options.ban }),
    });
  },

  // MARK: - 封禁昵称

  async listBannedNames(adminKey: string) {
    return requestJson<{ names: BannedName[] }>("/api/admin/banned-names", {
      headers: { "x-admin-key": adminKey },
    });
  },

  async banName(adminKey: string, name: string, reason?: string) {
    return requestJson<unknown>("/api/admin/banned-names", {
      method: "POST",
      headers: { "x-admin-key": adminKey },
      body: JSON.stringify({ name, reason }),
    });
  },

  async unbanName(adminKey: string, key: string) {
    return requestJson<unknown>(`/api/admin/banned-names/${encodeURIComponent(key)}`, {
      method: "DELETE",
      headers: { "x-admin-key": adminKey },
    });
  },

  // MARK: - 公开申请审核

  async listPendingStories(adminKey: string) {
    return requestJson<{ stories: PendingStory[] }>("/api/admin/stories", {
      headers: { "x-admin-key": adminKey },
    });
  },

  async reviewStory(adminKey: string, wishId: string, action: "approve" | "reject", note?: string) {
    return requestJson<unknown>(`/api/admin/stories/${encodeURIComponent(wishId)}`, {
      method: "PATCH",
      headers: { "x-admin-key": adminKey },
      body: JSON.stringify({ action, note }),
    });
  },

  // MARK: - 举报处理

  async listReports(adminKey: string, status = "open") {
    return requestJson<{ reports: AbuseReport[] }>(
      `/api/admin/reports?status=${encodeURIComponent(status)}`,
      { headers: { "x-admin-key": adminKey } },
    );
  },

  async readReportedConversation(adminKey: string, reportId: string) {
    return requestJson<{ responseId: string; messages: ReportedMessage[] }>(
      `/api/admin/reports/${encodeURIComponent(reportId)}/conversation`,
      { headers: { "x-admin-key": adminKey } },
    );
  },

  async resolveReport(adminKey: string, reportId: string, action: "dismiss" | "actioned", note?: string) {
    return requestJson<unknown>(`/api/admin/reports/${encodeURIComponent(reportId)}`, {
      method: "PATCH",
      headers: { "x-admin-key": adminKey },
      body: JSON.stringify({ action, note }),
    });
  },
};

export type PendingProfile = {
  userId: string;
  displayName: string | null;
  avatarUrl: string | null;
  submittedAt: number | null;
  /// 这一条里哪一样还在等：另一样可能早就通过了
  displayNamePending?: boolean;
  avatarPending?: boolean;
};

export type BannedName = {
  key: string;
  original: string;
  reason: string | null;
  createdAt: number;
};

export type PendingStoryMedia = { id: string; url: string; kind: string };

export type PendingStory = {
  wishId: string;
  publicCode: string;
  nickname: string;
  city: string;
  landmark: string;
  occasion: string;
  message: string;
  submittedAt: number;
  note: string | null;
  media: PendingStoryMedia[];
};

export type AbuseReport = {
  id: string;
  reason: string;
  detail: string | null;
  status: string;
  createdAt: number;
  responseId: string | null;
  wishPublicCode: string | null;
  wishTitle: string | null;
  messageCount: number;
};

export type ReportedMessage = {
  id: string;
  senderUserId: string;
  body: string;
  createdAt: number;
};
