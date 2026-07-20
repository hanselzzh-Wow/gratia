/* eslint-disable @typescript-eslint/no-require-imports */
const { request, login, logout } = require("../../utils/api");
const { STATUS_LABELS } = require("../../utils/presentation");
Page({
  data: { user: null, activity: null, loading: false, error: "", code: "", contact: "", tracked: null, tracking: false, deleting: false },
  onShow() { this.refresh(); },
  async refresh() {
    if (!wx.getStorageSync("gratia_session_token")) return this.setData({ user: null, activity: null });
    this.setData({ loading: true, error: "" });
    try { const [me, activity] = await Promise.all([request("/api/me"), request("/api/account/wishes")]); this.decorate(activity); this.setData({ user: me.user, activity }); }
    catch (error) { logout(); this.setData({ user: null, activity: null, error: error.message }); }
    finally { this.setData({ loading: false }); }
  },
  decorate(activity) { activity.requests = activity.requests.map((item) => ({ ...item, statusLabel: STATUS_LABELS[item.status] || "处理中" })); activity.responses = activity.responses.map((item) => ({ ...item, statusLabel: STATUS_LABELS[item.wish.status] || "处理中" })); },
  async signIn() { this.setData({ loading: true, error: "" }); try { await login(); await this.refresh(); } catch (error) { this.setData({ error: error.message }); } finally { this.setData({ loading: false }); } },
  input(event) { this.setData({ [event.currentTarget.dataset.key]: event.detail.value }); },
  async track() { if (!this.data.code.trim() || !this.data.contact.trim()) return this.setData({ error: "请填写编号和联系方式" }); this.setData({ tracking: true, error: "", tracked: null }); try { const result = await request("/api/wishes/track", { method: "POST", data: { publicCode: this.data.code, contact: this.data.contact } }); this.setData({ tracked: { ...result.wish, statusLabel: STATUS_LABELS[result.wish.status] || "处理中" } }); } catch (error) { this.setData({ error: error.message }); } finally { this.setData({ tracking: false }); } },
  async complete(event) { try { await request(`/api/account/wishes/${event.currentTarget.dataset.id}/complete`, { method: "POST" }); wx.showToast({ title: "已确认完成", icon: "success" }); await this.refresh(); } catch (error) { this.setData({ error: error.message }); } },
  openDelivery(event) { wx.navigateTo({ url: `/pages/delivery/index?id=${encodeURIComponent(event.currentTarget.dataset.id)}` }); },
  deleteAccount() { wx.showModal({ title: "删除微信账户？", content: "将注销登录身份、清除账户关联的称呼和联系方式；为履约与审计保留的去标识订单记录不会公开个人信息。此操作不可恢复。", confirmText: "删除账户", confirmColor: "#A53B4B", success: async (result) => { if (!result.confirm) return; this.setData({ deleting: true }); try { await request("/api/me", { method: "DELETE" }); logout(); this.setData({ user: null, activity: null }); wx.showToast({ title: "账户已删除", icon: "success" }); } catch (error) { this.setData({ error: error.message }); } finally { this.setData({ deleting: false }); } } }); }
});
