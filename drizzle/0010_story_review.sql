-- 公开到首页前必须审核。
--
-- 此前需求方点「公开到首页」即刻进入公开故事流，但帮助者上传的照片/视频
-- 从未被审核过——等于未经审核的用户上传影像可以直接公开展示。心愿正文在
-- 发布时审过，媒体没有，这是漏的一环。
--
-- 改为：点公开 = 提交申请（pending），运营通过后才出现在首页。

ALTER TABLE `wishes` ADD `story_status` text;
CREATE INDEX IF NOT EXISTS `wishes_story_status_idx` ON `wishes` (`story_status`,`story_published_at`);
