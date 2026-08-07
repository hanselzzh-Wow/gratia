-- 推送通知所需的设备令牌。
--
-- 以 token 为主键而不是 user_id：一个人可能有手机和 iPad 两台设备，两台都
-- 该收到通知；而同一台设备换账号登录时，user_id 会被覆盖成新的那个人——
-- 这正是我们要的，否则前一个账号的通知会推到已经换人的设备上。
--
-- environment 区分 sandbox / production。TestFlight 与 App Store 的构建走
-- production，Xcode 直接跑的 Debug 构建走 sandbox；发错端点 APNs 会回
-- BadDeviceToken，而这个错误从字面看不出是环境不对，排查会很久。

CREATE TABLE IF NOT EXISTS `device_tokens` (
  `token` text PRIMARY KEY NOT NULL,
  `user_id` text NOT NULL,
  `platform` text DEFAULT 'ios' NOT NULL,
  `environment` text DEFAULT 'production' NOT NULL,
  `created_at` integer NOT NULL,
  `updated_at` integer NOT NULL
);
CREATE INDEX IF NOT EXISTS `device_tokens_user_idx` ON `device_tokens` (`user_id`);
