Page({
  data: { keyword: "", city: "城市", scene: "主题", delivery: "形式" },
  change(event) { this.setData({ keyword: event.detail.value }); },
  choose(event) { this.setData({ [event.currentTarget.dataset.key]: event.currentTarget.dataset.value }); },
  reset() { this.setData({ keyword: "", city: "城市", scene: "主题", delivery: "形式" }); }
});
