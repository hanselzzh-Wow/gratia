Component({
  properties: { active: { type: String, value: "home" } },
  methods: {
    go(event) {
      const target = event.currentTarget.dataset.target;
      if (target === this.properties.active) return;
      wx.reLaunch({ url: `/pages/${target}/index` });
    }
  }
});
