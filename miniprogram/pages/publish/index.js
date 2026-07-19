/* eslint-disable @typescript-eslint/no-require-imports */
const { request, login } = require("../../utils/api");
Page({
  data: { step: 1, submitting: false, error: "", success: null, form: { requesterName: "", contact: "", city: "", landmark: "", occasion: "", message: "", deliveryType: "spoken_video", deadlineText: "", rewardFen: "", contactConsent: false } },
  input(event) { const key = event.currentTarget.dataset.key; this.setData({ [`form.${key}`]: event.detail.value }); },
  consent(event) { this.setData({ "form.contactConsent": event.detail.value.includes("contact") }); },
  chooseType(event) { this.setData({ "form.deliveryType": event.detail.value }); },
  next() { if (this.data.step === 1 && (!this.data.form.city.trim() || !this.data.form.landmark.trim())) return this.setData({ error: "请填写城市和地标" }); if (this.data.step === 2 && (!this.data.form.occasion.trim() || this.data.form.message.trim().length < 5)) return this.setData({ error: "请补全场景和至少 5 个字的心愿" }); this.setData({ step: this.data.step + 1, error: "" }); },
  prev() { this.setData({ step: this.data.step - 1, error: "" }); },
  async submit() {
    const form = { ...this.data.form, rewardFen: Math.round(Number(this.data.form.rewardFen || 0) * 100) };
    if (!form.requesterName.trim() || !form.contact.trim() || !form.deadlineText.trim() || !form.contactConsent) return this.setData({ error: "请填写称呼、联系方式、期望时间并确认联系授权" });
    this.setData({ submitting: true, error: "" });
    try {
      await login();
      const result = await request("/api/account/wishes", { method: "POST", data: form });
      this.setData({ success: result.wish, step: 4 });
    } catch (error) { this.setData({ error: error.message }); }
    finally { this.setData({ submitting: false }); }
  },
  reset() { this.setData({ step: 1, success: null }); }
});
