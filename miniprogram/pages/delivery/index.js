/* eslint-disable @typescript-eslint/no-require-imports */
const { API_BASE_URL } = require("../../config");

Page({
  data: { loading: true, error: "", filePath: "", isVideo: false },
  onLoad(query) {
    const id = query.id || "";
    if (!id) return this.setData({ loading: false, error: "交付记录无效" });
    const token = wx.getStorageSync("gratia_session_token");
    wx.downloadFile({
      url: `${API_BASE_URL}/api/account/wishes/${encodeURIComponent(id)}/deliverable`,
      header: { authorization: `Bearer ${token}` },
      success: (result) => {
        if (result.statusCode < 200 || result.statusCode >= 300) return this.setData({ loading: false, error: "交付文件暂时无法读取" });
        const type = result.header["Content-Type"] || result.header["content-type"] || "";
        this.setData({ loading: false, filePath: result.tempFilePath, isVideo: type.startsWith("video/") });
      },
      fail: () => this.setData({ loading: false, error: "交付文件暂时无法读取，请稍后重试" })
    });
  }
});
