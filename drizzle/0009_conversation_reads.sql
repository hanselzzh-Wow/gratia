-- 会话已读位置。按「会话 + 用户」记录，因为同一会话有两个参与者，
-- 各自的已读进度互不相干。未读数 = 该会话中对方发出且晚于本人已读时间的消息数。

CREATE TABLE IF NOT EXISTS `conversation_reads` (
  `response_id` text NOT NULL REFERENCES `wish_responses`(`id`) ON DELETE cascade,
  `user_id` text NOT NULL REFERENCES `users`(`id`) ON DELETE cascade,
  `last_read_at` integer NOT NULL,
  PRIMARY KEY (`response_id`, `user_id`)
);
