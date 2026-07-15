"use client";

import { FormEvent, useMemo, useState } from "react";
import Link from "next/link";
import { wishesClient, WishApiError } from "../../lib/wishes-client";
import {
  wishStatuses,
  wishStatusLabels,
  deliveryTypeLabels,
  type AdminWish,
  type AdminWishActionInput,
  type WishStatus,
} from "../../lib/wishes-contract";

type WishDraft = {
  note?: string;
  providerName?: string;
  providerContact?: string;
  deliveryUrl?: string;
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
  const [status, setStatus] = useState<WishStatus | "all">("all");
  const [drafts, setDrafts] = useState<Record<string, WishDraft>>({});
  const [busyId, setBusyId] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const visibleWishes = useMemo(
    () => (status === "all" ? wishes : wishes.filter((wish) => wish.status === status)),
    [status, wishes],
  );

  const pendingCount = wishes.filter((wish) => wish.status === "pending_review").length;
  const matchingCount = wishes.filter((wish) => wish.status === "matching").length;
  const activeCount = wishes.filter((wish) => ["assigned", "in_progress", "delivered"].includes(wish.status)).length;

  async function load(key = adminKey) {
    setLoading(true);
    setError("");
    try {
      const result = await wishesClient.listAdmin(key);
      setWishes(result.wishes);
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
    try {
      const result = await wishesClient.applyAdminAction(adminKey, wish.id, {
        action,
        ...draft,
      });
      setWishes((current) => current.map((item) => (item.id === wish.id ? result.wish : item)));
      setDrafts((current) => ({ ...current, [wish.id]: {} }));
    } catch (requestError) {
      setError(requestError instanceof Error ? requestError.message : "操作失败，请重试");
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

        <div className="ops-filter" aria-label="订单状态筛选">
          <button className={status === "all" ? "active" : ""} onClick={() => setStatus("all")}>全部</button>
          {wishStatuses.map((item) => (
            <button key={item} className={status === item ? "active" : ""} onClick={() => setStatus(item)}>
              {wishStatusLabels[item]}
            </button>
          ))}
        </div>

        {error && <div className="ops-error ops-page-error" role="alert">{error}</div>}

        <div className="ops-list">
          {visibleWishes.map((wish) => {
            const draft = drafts[wish.id] ?? {};
            const busy = busyId === wish.id;
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

                  {wish.status === "matching" && <><div className="ops-field-row"><label><span>响应者称呼</span><input value={draft.providerName ?? ""} onChange={(event) => updateDraft(wish.id, { providerName: event.target.value })} /></label><label><span>响应者联系方式</span><input value={draft.providerContact ?? ""} onChange={(event) => updateDraft(wish.id, { providerContact: event.target.value })} /></label></div><button disabled={busy} onClick={() => void act(wish, "assign")}>确认手工派单</button></>}

                  {wish.status === "assigned" && <button disabled={busy} onClick={() => void act(wish, "accept")}>记录响应者已接单</button>}

                  {wish.status === "in_progress" && <><label><span>HTTPS 交付链接</span><input type="url" value={draft.deliveryUrl ?? ""} onChange={(event) => updateDraft(wish.id, { deliveryUrl: event.target.value })} placeholder="https://…" /></label><button disabled={busy} onClick={() => void act(wish, "mark_delivered")}>记录已交付</button></>}

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
