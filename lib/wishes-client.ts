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
};
