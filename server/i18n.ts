/**
 * 服务端面向用户的文案翻译。
 *
 * 只翻译**错误消息**，不碰任何业务数据。心愿正文、昵称、城市、场景取值都是
 * 用户或数据库的内容，翻译它们会篡改数据——尤其 `occasion` 原样存库，
 * 客户端也约定它永远是中文（见 ios/Gratia/BusinessVocabulary.swift）。
 *
 * 中文原文当 key，和 iOS 端一致：中文请求原样返回，查不到的也原样返回，
 * 所以漏翻一条最多是那一句仍显示中文，不会变成空白或 key 名。
 */

export type Language = "zh" | "en";

/// 从 Accept-Language 判断。iOS 的 URLSession 会自动带上这个头。
export function preferredLanguage(request: Request): Language {
  const header = request.headers.get("accept-language") ?? "";
  // 只要首选语言不是中文就按英文处理。中文是默认，判断从宽：
  // zh、zh-CN、zh-Hans、zh-TW 都算中文。
  const first = header.split(",")[0]?.trim().toLowerCase() ?? "";
  if (!first) return "zh";
  return first.startsWith("zh") ? "zh" : "en";
}

const FIELD_LABELS: Record<string, string> = {
  称呼: "Your name",
  联系方式: "Contact",
  城市: "City",
  地标: "Place",
  常驻地标: "Usual area",
  心愿场景: "Occasion",
  心愿编号: "Reference code",
  想说的话: "Your message",
  期望时间: "Date",
};

const MESSAGES: Record<string, string> = {
  // 权限与鉴权
  "请先登录后再操作": "Please sign in first.",
  "登录已失效，请重新登录": "Your session has expired. Please sign in again.",
  "账户不存在或已删除": "That account doesn't exist or has been deleted.",
  "未找到账户": "Account not found.",
  "运营 PIN 尚未配置": "The operations PIN isn't configured.",
  "运营 PIN 不正确": "Incorrect operations PIN.",
  "不允许的请求来源": "Request origin not allowed.",
  "仅接受 JSON 请求": "Only JSON requests are accepted.",
  "接口不存在": "Not found.",
  "服务暂时不可用，请稍后再试": "The service is temporarily unavailable. Please try again later.",

  // 登录
  "微信登录暂未配置，请稍后重试": "WeChat sign-in isn't configured yet.",
  "微信登录服务暂时不可用，请稍后重试": "WeChat sign-in is temporarily unavailable. Please try again later.",
  "微信登录未完成，请重新尝试": "WeChat sign-in didn't complete. Please try again.",
  "微信登录凭证无效，请重新尝试": "That WeChat sign-in didn't work. Please try again.",
  "Apple 登录凭证无效，请重新尝试": "That Apple sign-in didn't work. Please try again.",
  "Apple 登录服务暂时不可用，请稍后重试": "Sign in with Apple is temporarily unavailable. Please try again later.",
  "Apple 登录凭证无法验证，请重新尝试": "Couldn't verify your Apple sign-in. Please try again.",
  "Apple 登录凭证来源不正确": "That Apple sign-in came from an unexpected source.",
  "Apple 登录凭证不属于本应用": "That Apple sign-in isn't for this app.",
  "Apple 登录凭证已过期，请重新登录": "Your Apple sign-in has expired. Please sign in again.",
  "Apple 登录校验失败，请重新登录": "Apple sign-in verification failed. Please sign in again.",
  "Apple 登录凭证缺少用户标识": "That Apple sign-in is missing a user identifier.",

  // 资料
  "昵称需在 1–20 个字之间": "Your name must be 1–20 characters.",
  "昵称不能只包含空格或不可见字符": "Your name can't be only spaces or invisible characters.",
  "这个昵称不可用，请换一个": "That name isn't available. Please choose another.",
  "这个昵称已经有人在用了，请换一个": "That name is already taken. Please choose another.",
  "昵称不能为空": "Your name can't be empty.",
  "缺少昵称": "Name is missing.",
  "没有要更新的内容": "Nothing to update.",
  "头像不存在": "That photo doesn't exist.",
  "头像不能超过 5MB": "Photos must be 5MB or smaller.",
  "头像仅支持 JPG、PNG 或 WebP": "Photos must be JPG, PNG, or WebP.",

  // 心愿
  "未找到该心愿": "Wish not found.",
  "该心愿目前不再接受新的响应": "This wish isn't accepting new answers.",
  "没有找到匹配的心愿，请检查编号和联系方式":
    "No matching wish. Check the reference code and contact details.",
  "未找到可确认的心愿": "No wish to confirm.",
  "心愿状态刚刚发生变化，请刷新后重试": "This wish just changed. Please refresh and try again.",
  "更新后未找到心愿": "Wish not found after the update.",
  "请完整填写心愿信息": "Please complete all the wish details.",
  "请检查心愿信息": "Please check the wish details.",
  "提交未通过校验": "Some fields need fixing.",
  "请填写心愿编号和联系方式": "Enter the reference code and contact details.",
  "请检查查询信息": "Please check what you entered.",

  // 响应与交付
  "未找到该响应": "Answer not found.",
  "未找到所选响应者": "The chosen helper wasn't found.",
  "请填写响应者称呼和联系方式": "Enter the helper's name and contact details.",
  "你不是该心愿被选中的帮助者": "You aren't the chosen helper for this wish.",
  "该心愿还没有派单记录": "This wish hasn't been assigned yet.",
  "请完整填写响应信息": "Please complete all the details.",
  "请检查响应信息": "Please check the details.",
  "请上传 1–9 个图片或视频": "Upload 1–9 photos or videos.",
  "请选择要交付的照片或视频": "Choose the photos or videos to send.",
  "一次最多上传 9 个文件": "You can upload up to 9 files at a time.",
  "单个文件不能超过 25MB": "Each file must be 25MB or smaller.",
  "文件不能超过 25MB；较大视频可继续使用 HTTPS 链接交付":
    "Files must be 25MB or smaller. For larger videos, use an HTTPS link instead.",
  "仅支持 JPG、PNG、WebP、MP4、WebM 或 MOV": "Only JPG, PNG, WebP, MP4, WebM, or MOV are supported.",
  "未找到该交付内容": "Delivery not found.",
  "交付内容尚未准备好": "That delivery isn't ready yet.",
  "请填写交付链接": "Enter the delivery link.",
  "交付链接需为有效的 HTTPS 地址": "The delivery link must be a valid HTTPS address.",
  "交付链接无效": "That delivery link isn't valid.",
  "交付内容不存在或链接已失效": "That delivery doesn't exist, or the link has expired.",
  "交付文件不存在": "That file doesn't exist.",
  "文件存储尚未配置": "File storage isn't configured.",
  "请确认你已知晓并同意内容授权说明": "Please agree to the content terms before continuing.",
  "请确认允许运营人员为履约联系你": "Please agree to be contacted about arranging this.",
  "请选择交付方式": "Choose how you'd like it delivered.",

  // 会话
  "未找到该会话": "Conversation not found.",
  "你无权查看该会话": "You don't have access to this conversation.",
  "消息内容需在 1–500 字之间": "Messages must be 1–500 characters.",
  "该心愿已结束，会话不再接受新消息": "This wish is finished; the conversation is closed.",
  "请选择举报原因": "Choose a reason for reporting.",
  "该会话没有可屏蔽的对象": "There's no one to block in this conversation.",
  "该会话没有可取消屏蔽的对象": "There's no one to unblock in this conversation.",
  "该举报没有关联会话": "That report has no linked conversation.",
  "未找到该举报": "Report not found.",

  // 推送
  "缺少设备令牌": "Device token is missing.",

  // 运营侧（运营台是中文界面，这里只是兜底）
  "缺少运营操作": "Missing operation.",
  "不支持的运营操作": "Unsupported operation.",
  "请填写未通过原因": "Enter a reason for rejecting.",
  "未找到该供应者": "Provider not found.",
  "这个联系方式已经在供应者名册中": "That contact is already on the provider list.",
  "供应者保存失败": "Couldn't save the provider.",
  "供应者更新失败": "Couldn't update the provider.",
  "履约中状态只能在派单时自动设置": "The in-progress state is set automatically on assignment.",
  "供应者仍有进行中的订单，请先完成、取消或退回匹配":
    "This provider still has open jobs. Finish, cancel, or unassign them first.",
  "未找到所选供应者": "The chosen provider wasn't found.",
  "所选供应者当前不可接单": "The chosen provider can't take jobs right now.",
  "请完整填写供应者信息": "Please complete all the provider details.",
  "请检查供应者信息": "Please check the provider details.",
  "缺少供应者更新信息": "Missing provider update.",
  "没有需要更新的内容": "Nothing to update.",
};

/**
 * 翻译一条面向用户的消息。
 *
 * 除了静态表，还要处理一条模板：字段长度校验是
 * `${label}需为 ${min}–${max} 个字符` 拼出来的，拼完才成串，查表查不到。
 */
export function translateMessage(text: string, lang: Language): string {
  if (lang === "zh") return text;
  const direct = MESSAGES[text];
  if (direct) return direct;

  const bounded = text.match(/^(.+)需为 (\d+)–(\d+) 个字符$/);
  if (bounded) {
    const label = FIELD_LABELS[bounded[1]] ?? bounded[1];
    return `${label} must be ${bounded[2]}–${bounded[3]} characters.`;
  }
  // 查不到就原样返回：漏一条最多是这句仍是中文，不会变成空白或 key 名。
  return text;
}

/// 翻译错误响应体里的 `error` 与 `fields`，其余原样保留——
/// 那些是业务数据，不能碰。
export function translateErrorPayload(payload: unknown, lang: Language): unknown {
  if (lang === "zh" || typeof payload !== "object" || payload === null) return payload;
  const record = payload as Record<string, unknown>;
  if (typeof record.error !== "string") return payload;

  const result: Record<string, unknown> = { ...record };
  result.error = translateMessage(record.error, lang);
  if (record.fields && typeof record.fields === "object") {
    const fields: Record<string, string> = {};
    for (const [key, value] of Object.entries(record.fields as Record<string, unknown>)) {
      fields[key] = typeof value === "string" ? translateMessage(value, lang) : String(value);
    }
    result.fields = fields;
  }
  return result;
}
