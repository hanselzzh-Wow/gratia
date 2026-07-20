const STATUS_LABELS = {
  pending_review: "待审核", matching: "待匹配", assigned: "已派单", in_progress: "进行中",
  delivered: "待确认", completed: "已完成", rejected: "未通过", cancelled: "已取消"
};

function wishCard(wish) {
  return {
    ...wish,
    statusLabel: STATUS_LABELS[wish.status] || "处理中",
    rewardText: wish.rewardFen > 0 ? `感谢金 ¥${(wish.rewardFen / 100).toFixed(0)}` : "一份真诚的感谢"
  };
}

module.exports = { STATUS_LABELS, wishCard };
