-- 昵称与头像拆成两条独立的审核线，并给昵称加上唯一性与封禁。
--
-- 为什么要拆：此前只有一个 profile_status，运营只能「整份通过」或「整份退回」。
-- 但现实里最常见的恰恰是一半有问题——昵称没问题、头像不合适，或者反过来。
-- 合在一起审的结果是：为了退回头像，把用户改好的昵称也一起打回，
-- 他得重填两样，而其中一样本来是合格的。
--
-- display_name_key 是规范化后的昵称，用来做唯一性判定。不直接对
-- display_name 建唯一索引，是因为「小白」「小 白」「小白 」「ＸＩＡＯ」
-- 这些在视觉上是同一个名字，规范化规则又会随着发现新的绕过手法而演进——
-- 放在应用层算、这里只存结果，改规则时不用动索引。

ALTER TABLE `users` ADD COLUMN `display_name_status` TEXT NOT NULL DEFAULT 'approved';
ALTER TABLE `users` ADD COLUMN `avatar_status` TEXT NOT NULL DEFAULT 'approved';
ALTER TABLE `users` ADD COLUMN `display_name_note` TEXT;
ALTER TABLE `users` ADD COLUMN `avatar_note` TEXT;
ALTER TABLE `users` ADD COLUMN `display_name_key` TEXT;

-- 沿用旧的整体状态作为两条线的初值，保证迁移前后可见性不变。
UPDATE `users` SET
  `display_name_status` = `profile_status`,
  `avatar_status` = `profile_status`,
  `display_name_note` = `profile_note`,
  `avatar_note` = `profile_note`;

-- 回填现有昵称的 key。这里只能做 lower+trim，应用层的规范化更强；
-- 迁移时库里没有重复昵称，所以简单版足够，之后由应用层保证。
UPDATE `users` SET `display_name_key` = LOWER(TRIM(`display_name`))
  WHERE `display_name` IS NOT NULL AND TRIM(`display_name`) <> '';

-- 部分唯一索引：只约束在用账户，已注销的用户不该继续占着名字。
CREATE UNIQUE INDEX IF NOT EXISTS `users_display_name_key_idx`
  ON `users` (`display_name_key`)
  WHERE `display_name_key` IS NOT NULL AND `deleted_at` IS NULL;

-- 被封禁的昵称。以规范化 key 为主键，所以换个空格或大小写绕不过去。
CREATE TABLE IF NOT EXISTS `banned_display_names` (
  `name_key` text PRIMARY KEY NOT NULL,
  `original` text NOT NULL,
  `reason` text,
  `created_at` integer NOT NULL
);
