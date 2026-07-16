"use client";

import { FormEvent, useMemo, useState } from "react";
import Link from "next/link";
import { wishesClient, WishApiError } from "../../lib/wishes-client";
import {
  wishStatuses,
  wishStatusLabels,
  deliveryTypeLabels,
  providerStatusLabels,
  type AdminWish,
  type AdminWishActionInput,
  type Provider,
  type WishStatus,
} from "../../lib/wishes-contract";

type WishDraft = {
  note?: string;
  providerName?: string;
  providerContact?: string;
  deliveryUrl?: string;
  responseId?: string;
  providerId?: string;
  file?: File;
};

function money(fen: number) {
  return `¥${(fen / 100).toFixed(fen % 100 === 0 ? 0 : 2)}`;
}

function dateTime(timestamp: number) {
  return new Intl.DateTimeFormat("zh-CN", {
    month: "numeric",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  }).format(new Date(timestamp));
}

export default function OperationsPage() {
  const [pinInput, setPinInput] = useState("");
  const [adminKey, setAdminKey] = useState("");
  const [wishes, setWishes] = useState<AdminWish[]>([]);
  const [providers, setProviders] = useState<Provider[]>([]);
  const [supplyOpen, setSupplyOpen] = useState(false);
  const [status, setStatus] = useState<WishStatus | "all">("all");
  const [drafts, setDrafts] = useState<Record<string, WishDraft>>({});
  const [busyId, setBusyId] = useState("");
  const [loading, setLoading] = useState(false);
  const [exporting, setExporting] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");

  const visibleWishes = useMemo(
    () => (status === "all" ? wishes : wishes.filter((wish) => wish.status === status)),
    [status, wishes],
  );

  const pendingCount = wishes.filter((wish) => wish.status === "pending_review").length;
  const matchingCount = wishes.filter((wish) => wish.status === "matching").length;
  const activeCount = wishes.filter((wish) => ["assigned", "in_progress", "delivered"].includes(wish.status)).length;
  const completedCount = wishes.filter((wish) => wish.status === "completed").length;
  const availableProviderCount = providers.filter((provider) => provider.status === "available").length;
  const pilotChecks = [
    { label: "至少 3 位种子响应者", ready: providers.length >= 3 },
    { label: "至少 2 位当前可接单", ready: availableProviderCount >= 2 },
    { label: "至少跑通 1 笔测试单", ready: completedCount >= 1 },
    { label: "待审核队列已清空", ready: pendingCount === 0 },
  ];
  const passedPilotChecks = pilotChecks.filter((check) => check.ready).length;

  async function load(key = adminKey) {
    setLoading(true);
    setError("");
    setNotice("");
    try {
      const [wishResult, providerResult] = await Promise.all([
        wishesClient.listAdmin(key),
        wishesClient.listProviders(key),
      ]);
      setWishes(wishResult.wishes);
      setProviders(providerResult.providers);
      setAdminKey(key);
    } catch (requestError) {
      setError(requestError instanceof Error ? requestError.message : "运营台连接失败");
      if (requestError instanceof WishApiError && requestError.status === 401) setAdminKey("");
    } finally {
      setLoading(false);
    }
  }

  function connect(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (pinInput.trim()) void load(pinInput.trim());
  }

  function updateDraft(id: string, patch: WishDraft) {
    setDrafts((current) => ({ ...current, [id]: { ...current[id], ...patch } }));
  }

  async function act(wish: AdminWish, action: AdminWishActionInput["action"]) {
    const draft = drafts[wish.id] ?? {};
    setBusyId(wish.id);
    setError("");
    setNotice("");
    try {
      const result = await wishesClient.applyAdminAction(adminKey, wish.id, {
        action,
        note: draft.note,
        providerName: draft.providerName,
        providerContact: draft.providerContact,
        deliveryUrl: draft.deliveryUrl,
        responseId: draft.responseId,
        providerId: draft.providerId,
      });
      setWishes((current) => current.map((item) => (item.id === wish.id ? result.wish : item)));
      if (action === "assign" && draft.providerId) {
        setProviders((current) => current.map((provider) => provider.id === draft.providerId ? { ...provider, status: "busy", lastAssignedAt: Date.now() } : provider));
      }
      if (["cancel", "reopen_matching", "complete"].includes(action) && wish.assignment?.providerId) {
        setProviders((current) => current.map((provider) => provider.id === wish.assignment?.providerId ? { ...provider, status: "available", completedCount: action === "complete" ? provider.completedCount + 1 : provider.completedCount } : provider));
      }
      setDrafts((current) => ({ ...current, [wish.id]: {} }));
    } catch (requestError) {
      setError(requestError instanceof Error ? requestError.message : "操作失败，请重试");
    } finally {
      setBusyId("");
    }
  }

  async function addProvider(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;
    const data = new FormData(form);
    setLoading(true);
    setError("");
    setNotice("");
    try {
      const result = await wishesClient.createProvider(adminKey, {
        name: String(data.get("name") ?? ""),
        contact: String(data.get("contact") ?? ""),
        city: String(data.get("city") ?? ""),
        landmarks: String(data.get("landmarks") ?? ""),
        availabilityNote: String(data.get("availabilityNote") ?? ""),
      });
      setProviders((current) => [result.provider, ...current]);
      form.reset();
    } catch (requestError) {
      setError(requestError instanceof Error ? requestError.message : "供应者保存失败");
    } finally {
      setLoading(false);
    }
  }

  async function setProviderStatus(provider: Provider, status: Provider["status"]) {
    setBusyId(provider.id);
    setError("");
    setNotice("");
    try {
      const result = await wishesClient.updateProvider(adminKey, provider.id, { status });
      setProviders((current) => current.map((item) => item.id === provider.id ? result.provider : item));
    } catch (requestError) {
      setError(requestError instanceof Error ? requestError.message : "供应状态更新失败");
    } finally {
      setBusyId("");
    }
  }

  async function exportOperations() {
    setExporting(true);
    setError("");
    setNotice("");
    try {
      const blob = await wishesClient.exportOperations(adminKey);
      const objectUrl = URL.createObjectURL(blob);
      const anchor = document.createElement("a");
      anchor.href = objectUrl;
      anchor.download = `haluowode-ops-${new Date().toISOString().slice(0, 10)}.csv`;
      document.body.append(anchor);
      anchor.click();
      anchor.remove();
      window.setTimeout(() => URL.revokeObjectURL(objectUrl), 0);
      setNotice("运营数据已导出；文件只用于内部运营，请勿转发。");
    } catch (requestError) {
      setError(requestError instanceof Error ? requestError.message : "运营数据导出失败");
    } finally {
      setExporting(false);
    }
  }

  async function upload(wish: AdminWish) {
    const draft = drafts[wish.id] ?? {};
    if (!draft.file) {
      setError("请先选择要交付的照片或视频");
      return;
    }
    setBusyId(wish.id);
    setError("");
    setNotice("");
    try {
      const result = await wishesClient.uploadDeliverable(adminKey, wish.id, draft.file, draft.note);
      setWishes((current) => current.map((item) => (item.id === wish.id ? result.wish : item)));
      setDrafts((current) => ({ ...current, [wish.id]: {} }));
    } catch (requestError) {
      setError(requestError instanceof Error ? requestError.message : "文件上传失败，请重试");
    } finally {
      setBusyId("");
    }
  }

  if (!adminKey) {
    return (
      <main className="ops-login-shell">
        <Link className="ops-back-link" href="/">← 返回产品</Link>
        <form className="ops-login-card" onSubmit={connect}>
          <span className="ops-kicker">HALUOWODE · OPERATIONS</span>
          <h1>心愿运营台</h1>
          <p>审核新心愿、手工匹配响应者，并跟踪交付状态。</p>
          <label>
            <span>运营 PIN</span>
            <input
              type="password"
              autoComplete="current-password"
              value={pinInput}
              onChange={(event) => setPinInput(event.target.value)}
              placeholder="输入运营 PIN"
              required
            />
          </label>
          {error && <div className="ops-error" role="alert">{error}</div>}
          <button type="submit" disabled={loading}>{loading ? "连接中…" : "进入运营台"}</button>
          <small>PIN 只保留在当前页面内存中，刷新后需要重新输入。</small>
        </form>
      </main>
    );
  }

  return (
    <main className="ops-shell">
      <header className="ops-header">
        <div>
          <Link href="/">哈喽卧得</Link>
          <span>运营控制台</span>
        </div>
        <nav>
          <button onClick={() => void load()} disabled={loading}>{loading ? "刷新中…" : "刷新订单"}</button>
          <button className="secondary" onClick={() => void exportOperations()} disabled={exporting}>{exporting ? "导出中…" : "导出运营表"}</button>
          <button className="quiet" onClick={() => { setAdminKey(""); setPinInput(""); }}>退出</button>
        </nav>
      </header>

      <section className="ops-content">
        <div className="ops-title-row">
          <div><span className="ops-kicker">MANUAL MATCHING · MVP</span><h1>今天的心愿</h1></div>
          <p>先把每一单稳稳送达，再逐步自动化。</p>
        </div>

        <div className="ops-metrics">
          <article><span>待审核</span><strong>{pendingCount}</strong><small>需要内容判断</small></article>
          <article><span>待匹配</span><strong>{matchingCount}</strong><small>寻找合适的在场者</small></article>
          <article><span>履约中</span><strong>{activeCount}</strong><small>派单至确认完成</small></article>
          <article><span>全部心愿</span><strong>{wishes.length}</strong><small>最近 100 条</small></article>
        </div>

        <section className="ops-supply-panel">
          <button className="ops-supply-toggle" onClick={() => setSupplyOpen((current) => !current)}><span><b>供应者名册</b><small>{providers.length} 人 · {availableProviderCount} 人可接单</small></span><i>{supplyOpen ? "收起" : "管理"}</i></button>
          {supplyOpen && <div className="ops-supply-body">
            <form className="ops-provider-form" onSubmit={addProvider}>
              <div><span className="ops-kicker">SUPPLY FIRST</span><h2>新增种子响应者</h2><p>记录真实可联系的人、常驻城市和地标，派单时直接选择。</p></div>
              <label><span>称呼</span><input name="name" required maxLength={40} /></label>
              <label><span>联系方式</span><input name="contact" required minLength={3} maxLength={80} /></label>
              <label><span>城市</span><select name="city" defaultValue="上海"><option>上海</option><option>北京</option><option>广州</option><option>深圳</option><option>成都</option></select></label>
              <label><span>常驻地标</span><input name="landmarks" required minLength={2} maxLength={200} placeholder="例如：外滩、陆家嘴、武康路" /></label>
              <label className="wide"><span>可用时间与备注</span><input name="availabilityNote" maxLength={300} placeholder="例如：周末下午，可拍 30 秒短视频" /></label>
              <button type="submit" disabled={loading}>加入名册</button>
            </form>
            <div className="ops-provider-list">
              {providers.map((provider) => <article key={provider.id}><div><span className={`provider-status provider-${provider.status}`}>{providerStatusLabels[provider.status]}</span><b>{provider.name}</b><small>{provider.city} · {provider.landmarks}</small></div><p>{provider.contact}{provider.availabilityNote ? ` · ${provider.availabilityNote}` : ""}</p><footer><span>已完成 {provider.completedCount} 单</span>{provider.status === "paused" ? <button disabled={busyId === provider.id} onClick={() => void setProviderStatus(provider, "available")}>恢复接单</button> : provider.status === "available" ? <button disabled={busyId === provider.id} onClick={() => void setProviderStatus(provider, "paused")}>暂停</button> : <button disabled>履约中</button>}</footer></article>)}
              {!providers.length && <div className="ops-provider-empty">先录入 3–5 位能稳定联系到的种子响应者。</div>}
            </div>
          </div>}
        </section>

        <section className="ops-pilot-panel" aria-label="试运营准备度">
          <div>
            <span className="ops-kicker">PILOT READINESS</span>
            <h2>试运营准备度</h2>
            <p>{passedPilotChecks === pilotChecks.length ? "基础条件已齐，可以邀请第一小批真实用户。" : "先把未完成项补齐，再邀请真实用户进入。"}</p>
          </div>
          <strong>{passedPilotChecks}<small> / {pilotChecks.length}</small></strong>
          <ul>
            {pilotChecks.map((check) => (
              <li className={check.ready ? "ready" : ""} key={check.label}>
                <span aria-hidden="true">{check.ready ? "✓" : "○"}</span>{check.label}
              </li>
            ))}
          </ul>
        </section>

        <div className="ops-filter" aria-label="订单状态筛选">
          <button className={status === "all" ? "active" : ""} onClick={() => setStatus("all")}>全部</button>
          {wishStatuses.map((item) => (
            <button key={item} className={status === item ? "active" : ""} onClick={() => setStatus(item)}>
              {wishStatusLabels[item]}
            </button>
          ))}
        </div>

        {error && <div className="ops-error ops-page-error" role="alert">{error}</div>}
        {notice && <div className="ops-notice" role="status">{notice}</div>}

        <div className="ops-list">
          {visibleWishes.map((wish) => {
            const draft = drafts[wish.id] ?? {};
            const busy = busyId === wish.id;
            const matchingProviders = providers.filter(
              (provider) => provider.status === "available" && provider.city === wish.city,
            );
            return (
              <article className="ops-wish" key={wish.id}>
                <div className="ops-wish-main">
                  <div className="ops-wish-topline">
                    <span className={`ops-status status-${wish.status}`}>{wishStatusLabels[wish.status]}</span>
                    <b>{wish.publicCode}</b>
                    <time>{dateTime(wish.createdAt)}</time>
                  </div>
                  <h2>{wish.city} · {wish.landmark}</h2>
                  <p className="ops-message">{wish.message}</p>
                  <div className="ops-tags">
                    <span>{wish.occasion}</span>
                    <span>{deliveryTypeLabels[wish.deliveryType]}</span>
                    <span>{wish.deadlineText}</span>
                    <span>{money(wish.rewardFen)} 感谢金</span>
                  </div>
                  <dl className="ops-contact">
                    <div><dt>发布者</dt><dd>{wish.requesterName}</dd></div>
                    <div><dt>联系方式</dt><dd>{wish.contact}</dd></div>
                    {wish.assignment && <div><dt>响应者</dt><dd>{wish.assignment.providerName} · {wish.assignment.providerContact}</dd></div>}
                    {wish.deliverable && <div><dt>交付物</dt><dd><a href={wish.deliverable.url} target="_blank" rel="noreferrer">打开交付链接 ↗</a></dd></div>}
                  </dl>
                </div>

                <div className="ops-actions">
                  <label><span>运营备注</span><textarea value={draft.note ?? ""} onChange={(event) => updateDraft(wish.id, { note: event.target.value })} placeholder="审核原因、派单说明或交付备注" /></label>

                  {wish.status === "pending_review" && <div className="ops-button-row"><button disabled={busy} onClick={() => void act(wish, "approve")}>审核通过</button><button className="danger" disabled={busy} onClick={() => void act(wish, "reject")}>不予通过</button></div>}

                  {wish.status === "matching" && <>
                    {matchingProviders.length > 0 && <div className="ops-provider-picks"><span>{wish.city}可接单供应者</span>{matchingProviders.map((provider) => <button key={provider.id} className={draft.providerId === provider.id ? "selected" : ""} onClick={() => updateDraft(wish.id, { providerId: provider.id, responseId: undefined, providerName: provider.name, providerContact: provider.contact })}><b>{provider.name}</b><small>{provider.landmarks} · 已完成 {provider.completedCount} 单</small></button>)}</div>}
                    {wish.responses.length > 0 && <div className="ops-responses"><span>{wish.responses.length} 位在场者已报名</span>{wish.responses.map((response) => <button key={response.id} className={draft.responseId === response.id ? "selected" : ""} onClick={() => updateDraft(wish.id, { responseId: response.id, providerId: undefined, providerName: response.responderName, providerContact: response.responderContact })}><b>{response.responderName}</b><small>{response.responderContact}{response.note ? ` · ${response.note}` : ""}</small></button>)}</div>}
                    <div className="ops-field-row"><label><span>响应者称呼</span><input value={draft.providerName ?? ""} onChange={(event) => updateDraft(wish.id, { providerName: event.target.value, responseId: undefined, providerId: undefined })} /></label><label><span>响应者联系方式</span><input value={draft.providerContact ?? ""} onChange={(event) => updateDraft(wish.id, { providerContact: event.target.value, responseId: undefined, providerId: undefined })} /></label></div><button disabled={busy} onClick={() => void act(wish, "assign")}>确认手工派单</button>
                  </>}

                  {wish.status === "assigned" && <button disabled={busy} onClick={() => void act(wish, "accept")}>记录响应者已接单</button>}

                  {wish.status === "in_progress" && <><label><span>直接上传照片或短视频（最大 25MB）</span><input type="file" accept="image/jpeg,image/png,image/webp,video/mp4,video/webm,video/quicktime" onChange={(event) => updateDraft(wish.id, { file: event.target.files?.[0] })} /></label>{draft.file && <small className="ops-file-name">已选择：{draft.file.name}</small>}<button disabled={busy || !draft.file} onClick={() => void upload(wish)}>上传并记录交付</button><div className="ops-divider"><span>或使用外部链接</span></div><label><span>HTTPS 交付链接</span><input type="url" value={draft.deliveryUrl ?? ""} onChange={(event) => updateDraft(wish.id, { deliveryUrl: event.target.value })} placeholder="https://…" /></label><button className="secondary" disabled={busy} onClick={() => void act(wish, "mark_delivered")}>用链接记录交付</button></>}

                  {wish.status === "delivered" && <button disabled={busy} onClick={() => void act(wish, "complete")}>发布者已确认，完成订单</button>}

                  {["assigned", "in_progress", "cancelled"].includes(wish.status) && <button className="secondary" disabled={busy} onClick={() => void act(wish, "reopen_matching")}>退回待匹配</button>}
                  {!(["completed", "rejected", "cancelled"] as WishStatus[]).includes(wish.status) && <button className="ghost-danger" disabled={busy} onClick={() => void act(wish, "cancel")}>取消此心愿</button>}
                </div>
              </article>
            );
          })}
          {!visibleWishes.length && <div className="ops-empty">当前筛选下还没有心愿。</div>}
        </div>
      </section>
    </main>
  );
}
