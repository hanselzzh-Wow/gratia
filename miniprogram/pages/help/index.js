/* eslint-disable @typescript-eslint/no-require-imports */
const { request, login } = require("../../utils/api");
const { wishCard } = require("../../utils/presentation");
Page({
  data: { wishes: [], loading: true, error: "", selected: null, name: "", contact: "", note: "", submitting: false },
  onShow() { this.load(); },
  async load() { this.setData({ loading: true, error: "" }); try { const result = await request("/api/wishes"); this.setData({ wishes: result.wishes.map(wishCard) }); } catch (error) { this.setData({ error: error.message }); } finally { this.setData({ loading: false }); } },
  respond(event) { const selected = this.data.wishes.find((wish) => wish.id === event.currentTarget.dataset.id); this.setData({ selected, error: "" }); },
  close() { this.setData({ selected: null, error: "" }); },
  input(event) { this.setData({ [event.currentTarget.dataset.key]: event.detail.value }); },
  async submit() {
    if (!this.data.name.trim() || !this.data.contact.trim()) return this.setData({ error: "请填写称呼和联系方式" });
    this.setData({ submitting: true, error: "" });
    try {
      await login();
      await request(`/api/account/wishes/${this.data.selected.id}/responses`, { method: "POST", data: { responderName: this.data.name, responderContact: this.data.contact, note: this.data.note, contactConsent: true } });
      wx.showToast({ title: "响应已提交", icon: "success" }); this.setData({ selected: null, name: "", contact: "", note: "" });
    } catch (error) { this.setData({ error: error.message }); }
    finally { this.setData({ submitting: false }); }
  }
});
