-- 用户资料：昵称与头像。
--
-- 这两样都会出现在私聊、响应列表与公开故事里，属于公开可见的用户生成内容，
-- 因此必须经人工审核后才对他人可见。审核期间：本人看到自己的新资料，
-- 他人看到上一版通过审核的资料；没有通过版本时他人看到系统默认值。
-- 这与心愿正文「先审后公开」的既有规则一致。

ALTER TABLE `users` ADD `display_name` text;
ALTER TABLE `users` ADD `avatar_key` text;
-- 已通过审核、当前对他人可见的版本
ALTER TABLE `users` ADD `approved_display_name` text;
ALTER TABLE `users` ADD `approved_avatar_key` text;
-- pending / approved / rejected；仅在有待审内容时为 pending
ALTER TABLE `users` ADD `profile_status` text DEFAULT 'approved' NOT NULL;
ALTER TABLE `users` ADD `profile_note` text;
ALTER TABLE `users` ADD `profile_updated_at` integer;

CREATE INDEX IF NOT EXISTS `users_profile_status_idx` ON `users` (`profile_status`,`profile_updated_at`);
