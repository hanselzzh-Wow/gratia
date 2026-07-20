/* eslint-disable @typescript-eslint/no-require-imports */
const { API_BASE_URL } = require("../config");

function request(path, options = {}) {
  const token = wx.getStorageSync("gratia_session_token");
  return new Promise((resolve, reject) => {
    wx.request({
      url: `${API_BASE_URL}${path}`,
      method: options.method || "GET",
      data: options.data,
      header: {
        "content-type": "application/json",
        "x-client-platform": "wechat-miniprogram",
        ...(token ? { authorization: `Bearer ${token}` } : {})
      },
      success(response) {
        const payload = response.data || {};
        if (response.statusCode >= 200 && response.statusCode < 300) return resolve(payload);
        const error = new Error(payload.error || "请求暂时无法完成");
        error.statusCode = response.statusCode;
        error.fields = payload.fields;
        reject(error);
      },
      fail() { reject(new Error("网络连接失败，请检查网络后重试")); }
    });
  });
}

function login() {
  return new Promise((resolve, reject) => {
    wx.login({
      success(result) {
        if (!result.code) return reject(new Error("微信登录未返回凭证，请重试"));
        request("/api/auth/wechat", { method: "POST", data: { code: result.code } })
          .then((session) => {
            wx.setStorageSync("gratia_session_token", session.token);
            wx.setStorageSync("gratia_session_expiry", session.expiresAt);
            resolve(session.user);
          })
          .catch(reject);
      },
      fail() { reject(new Error("你取消了微信登录")); }
    });
  });
}

function logout() {
  wx.removeStorageSync("gratia_session_token");
  wx.removeStorageSync("gratia_session_expiry");
}

module.exports = { request, login, logout };
