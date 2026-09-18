---
name: home-rose-direction
description: "产品负责人 2026-07-18 确定的首页新方向:纯白底+玫粉点缀+媒体优先信息流,探索中未立项"
metadata: 
  node_type: memory
  type: project
  originSessionId: 38c0e6b8-b31d-41ed-88e7-ddf3164d09c0
  modified: 2026-07-18T16:15:31.915Z
---

产品负责人(Hansangbai)于 2026-07-18 晚给出首页新视觉方向,尚在预览迭代阶段,未立项、未冻结、未写入仓库:

- **底色**:纯白 #FFFFFF,放弃 v3 的暖白 #FBF6EC("大厂都用白")。
- **玫粉体系**(用户亲自选定,来源于 iPhone 16 Plus 粉的低饱和深化):Primary Rose `#9A536D`(选中/发布/点赞/品牌)、Deep Rose `#7F4058`(链接/按下态)、Soft Rose `#E4C6D0`(头像底/标签,用户很喜欢这个色)、Rose Tint `#FAF4F6`、Ink `#191719`、次文字 `#706A6D`、分隔线 `#ECE8EA`。明确不要蓝色、不要 Claude 橙。
- **首页形态**(v2 修正,用户拍板):**X/Twitter 式文字优先**,不是 Instagram 媒体优先——"故事比素材重要",文字在上讲清场景与经过(15pt 正文,可多段),媒体缩进为 16pt 圆角"证据卡"在文字之下;左头像列+右内容列;操作栏(评论/转发/点赞图标,无数字)沿内容列摊开。每条含首字母头像(Soft Rose 底)、公开昵称、城市级地点、模糊相对时间、"已授权公开"标注。发布入口收为右上角小圆钮,主入口仍是 Dock"发布"。纯文字故事(无媒体)也是合法形态。
- **启动页**:只有 logo + "让想说的话,抵达远方",无介绍文案;产品介绍移到引导页/空态/我的→关于。
- **Dock 最终结构**(2026-07-19 用户拍板,已授权 SwiftUI 实现):首页|搜索|发布(中央动作,弹 Sheet 不切页)|帮助|我的;删除"进度"栏目(进度移入 我的→我发布的/我帮助的,内按 等待回应/进行中/已完成 筛选)。Dock 只用图标不带汉字;普通项未选中灰 #A9A2A5、选中近黑 #191719(实心变体),仅中央发布用玫红。首页图标=地球 globe.asia.australia(沿用原版网页"分享"栏语义);帮助图标=自绘斜向互扣握手(HandshakeIcon.imageset,源 SVG 在会话 scratchpad,构图向原版 fa-handshake-angle 致意但独立绘制);搜索=放大镜;我的=人形。
- **原版参考**:`哈喽卧得/index.html`(项目根目录)+ https://hansel1005.github.io/helloworld/ ,原版四栏 分享(globe)/发布(add)/互助(handshake-angle)/我的(user)。发布页"声音示范"(长按录母语发音示范给帮助者)被用户点名为未来全球化功能——后端无音频字段,未实现,记为设计注记。
- **实现分支**:`worktrees/claude-rose-redesign`,分支 `claude/rose-home-redesign`(基于 main 3e5cb0c,含 AG-006 真实追踪);不碰 ProgressView/DeliveryPreviewView(AG-007 在 review)、后端、签名、任务管理文件。
- **合规红线(用户确认"永远最严")**:虚构内容只用于设计稿/Preview,生产无授权故事就显示诚实空态;头像和昵称也需独立公开授权;点赞/评论不伪造数字、不做本地假成功;分享可较早用系统 ShareLink 做成真的。
- 预览产出:`~/Desktop/哈喽卧得-玫粉首页预览/首页预览.html` + artifact `https://claude.ai/code/artifact/982c770b-f435-42a7-ac45-b51ea67922c9`(favicon 🌸,更新时用同一 URL)。

**工作方式**:用户会反复迭代预览直到满意,满意后才由 Codex 立项新设计冻结(v3 冻结文档规定换品牌色必须走新版本化冻结,不能散改 token)。探索稿不得写入仓库 worktree 或 `.ai/handoffs/`。相关任务:[[cl-005-status]]。
