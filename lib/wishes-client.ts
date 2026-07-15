import type {
  AdminWish,
  AdminWishActionInput,
  ApiErrorPayload,
  CreateWishInput,
  PublicWish,
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
      ...(init?.body ? { "content-type": "application/json" } : {}),
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

  async listAdmin(adminKey: string, status?: string) {
    const query = status ? `?status=${encodeURIComponent(status)}` : "";
    return requestJson<{ wishes: AdminWish[] }>(`/api/admin/wishes${query}`, {
      headers: { "x-admin-key": adminKey },
    });
  },

  async applyAdminAction(adminKey: string, id: string, input: AdminWishActionInput) {
    return requestJson<{ wish: AdminWish }>(`/api/admin/wishes/${encodeURIComponent(id)}`, {
      method: "PATCH",
      headers: { "x-admin-key": adminKey },
      body: JSON.stringify(input),
    });
  },
};
