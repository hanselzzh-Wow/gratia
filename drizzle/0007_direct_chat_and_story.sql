-- 让需求方与帮助者在应用内直接完成沟通、交付与公开，运营不再居中传话。
-- 运营只保留公开内容的初审。

-- 站内私聊。会话以「心愿 + 响应」为单位：帮助者一响应即可开聊，
-- 因此同一心愿可能同时存在多个会话，需求方据此判断选谁。
CREATE TABLE IF NOT EXISTS `wish_messages` (
  `id` text PRIMARY KEY NOT NULL,
  `wish_id` text NOT NULL REFERENCES `wishes`(`id`) ON DELETE cascade,
  `response_id` text NOT NULL REFERENCES `wish_responses`(`id`) ON DELETE cascade,
  `sender_user_id` text NOT NULL REFERENCES `users`(`id`) ON DELETE cascade,
  -- 只允许纯文字，不做富文本与文件，降低审核与安全面
  `body` text NOT NULL,
  `created_at` integer NOT NULL,
  `deleted_at` integer
);
CREATE INDEX IF NOT EXISTS `wish_messages_response_created_idx` ON `wish_messages` (`response_id`,`created_at`);

-- 举报与拉黑。App 内存在陌生人即时通讯时，App Store 审核指南 1.2 要求
-- 必须提供举报机制与屏蔽对方的能力。
CREATE TABLE IF NOT EXISTS `abuse_reports` (
  `id` text PRIMARY KEY NOT NULL,
  `reporter_user_id` text NOT NULL REFERENCES `users`(`id`) ON DELETE cascade,
  `wish_id` text REFERENCES `wishes`(`id`) ON DELETE set null,
  `response_id` text REFERENCES `wish_responses`(`id`) ON DELETE set null,
  `reported_user_id` text REFERENCES `users`(`id`) ON DELETE set null,
  `reason` text NOT NULL,
  `detail` text,
  `status` text DEFAULT 'open' NOT NULL,
  `created_at` integer NOT NULL
);
CREATE INDEX IF NOT EXISTS `abuse_reports_status_created_idx` ON `abuse_reports` (`status`,`created_at`);

CREATE TABLE IF NOT EXISTS `user_blocks` (
  `blocker_user_id` text NOT NULL REFERENCES `users`(`id`) ON DELETE cascade,
  `blocked_user_id` text NOT NULL REFERENCES `users`(`id`) ON DELETE cascade,
  `created_at` integer NOT NULL,
  PRIMARY KEY (`blocker_user_id`, `blocked_user_id`)
);

-- 帮助者响应时的授权记录：选择帮助即同意其提交的文字与影像由需求方支配，
-- 包括公开分享的权利。记录同意时间以便追溯。
ALTER TABLE `wish_responses` ADD `content_license_agreed_at` integer;

-- 交付内容分组：一次「完成帮助」可包含一段文字和最多 9 个图片/视频，
-- 同组文件共享 group_id 与文字说明，并以 position 保持顺序。
ALTER TABLE `deliverables` ADD `group_id` text;
ALTER TABLE `deliverables` ADD `position` integer DEFAULT 0 NOT NULL;

-- 故事公开：完成之后由需求方单独决定是否公开到首页，默认不公开。
ALTER TABLE `wishes` ADD `story_published_at` integer;
ALTER TABLE `wishes` ADD `story_nickname` text;
CREATE INDEX IF NOT EXISTS `wishes_story_published_idx` ON `wishes` (`story_published_at`);
