"use client";

import { FormEvent, useMemo, useState } from "react";

type Tab = "pool" | "publish" | "tasks" | "profile";

const wishes = [
  {
    id: 1,
    city: "上海",
    landmark: "外滩",
    type: "生日祝福",
    deadline: "明天 18:00 前",
    reward: 18,
    distance: "2.4 km",
    copy: "请在江边替我对小满说一句：二十四岁，也要继续闪闪发光。",
    format: "30 秒口播视频",
    color: "blue",
  },
  {
    id: 2,
    city: "北京",
    landmark: "鼓楼",
    type: "毕业加油",
    deadline: "7月18日前",
    reward: 12,
    distance: "5.8 km",
    copy: "想把鼓楼傍晚的钟声送给即将毕业的室友，祝她勇敢去远方。",
    format: "景色 + 画外音",
    color: "orange",
  },
  {
    id: 3,
    city: "成都",
    landmark: "IFS 熊猫",
    type: "日常鼓励",
    deadline: "本周内",
    reward: 9,
    distance: "1.7 km",
    copy: "朋友最近有点低落，想请你和熊猫同框比个耶，告诉她：慢一点也没关系。",
    format: "照片 + 手写卡片",
    color: "green",
  },
];

const nav: { key: Tab; label: string; icon: string }[] = [
  { key: "pool", label: "愿望池", icon: "⌁" },
  { key: "publish", label: "发愿望", icon: "+" },
  { key: "tasks", label: "行程", icon: "✓" },
  { key: "profile", label: "我的", icon: "○" },
];

export default function Home() {
  const [tab, setTab] = useState<Tab>("pool");
  const [city, setCity] = useState("附近");
  const [accepted, setAccepted] = useState<number[]>([]);
  const [published, setPublished] = useState(false);
  const [toast, setToast] = useState("");

  const visibleWishes = useMemo(
    () => (city === "附近" || city === "全部" ? wishes : wishes.filter((w) => w.city === city)),
    [city],
  );

  function flash(message: string) {
    setToast(message);
    window.setTimeout(() => setToast(""), 2400);
  }

  function acceptWish(id: number) {
    if (accepted.includes(id)) return;
    setAccepted((current) => [...current, id]);
    flash("接单成功，心愿已加入你的行程");
  }

  function publishWish(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setPublished(true);
    flash("心愿已提交，等待平台审核");
  }

  return (
    <main className="app-shell">
      <aside className="brand-panel">
        <div className="brand-mark"><img src="/hlwd.png" alt="哈喽卧得" /></div>
        <p className="eyebrow">HELLO WORLD · 心愿正在发生</p>
        <h1>让不在场的你，<br />也能抵达远方。</h1>
        <p className="brand-copy">请一个恰好在那里的人，替你拍下一处风景、说出一句想说的话。</p>
        <div className="brand-stats">
          <div><strong>128</strong><span>心愿已完成</span></div>
          <div><strong>5</strong><span>首发城市</span></div>
          <div><strong>4.9</strong><span>平均感动值</span></div>
        </div>
        <div className="quote-card">
          <span>“</span>
          <p>陌生人的善意，是一张通往世界的车票。</p>
        </div>
      </aside>

      <section className="phone-stage">
        <div className="phone-app">
          <header className="topbar">
            <div className="mini-brand">
              <img src="/hlwd.png" alt="" />
              <div><b>哈喽卧得</b><span>Hello World · 唾手可得</span></div>
            </div>
            <button className="avatar" onClick={() => setTab("profile")} aria-label="打开个人中心">韩</button>
          </header>

          <div className="screen-content">
            {tab === "pool" && (
              <section className="view pool-view">
                <div className="hero-card">
                  <p className="kicker">今天，也有人替你在远方</p>
                  <h2>把一句话，送到<br /><em>某个特别的地方</em></h2>
                  <button onClick={() => setTab("publish")}>许下一个心愿 <span>→</span></button>
                  <div className="orbit orbit-one" /><div className="orbit orbit-two" />
                </div>

                <div className="section-title">
                  <div><span className="live-dot" />愿望池</div>
                  <span>{visibleWishes.length} 个心愿等待回应</span>
                </div>

                <div className="city-filter" aria-label="城市筛选">
                  {["附近", "上海", "北京", "成都", "全部"].map((item) => (
                    <button key={item} className={city === item ? "active" : ""} onClick={() => setCity(item)}>{item}</button>
                  ))}
                </div>

                <div className="wish-list">
                  {visibleWishes.map((wish) => (
                    <article className="wish-card" key={wish.id}>
                      <div className="wish-head">
                        <div className={`place-icon ${wish.color}`}>⌖</div>
                        <div className="place"><b>{wish.city} · {wish.landmark}</b><span>{wish.distance} · {wish.deadline}</span></div>
                        <span className="reward">¥{wish.reward}</span>
                      </div>
                      <span className="wish-type">{wish.type}</span>
                      <p>{wish.copy}</p>
                      <div className="wish-foot">
                        <span>▣ {wish.format}</span>
                        <button className={accepted.includes(wish.id) ? "done" : ""} onClick={() => acceptWish(wish.id)}>
                          {accepted.includes(wish.id) ? "已加入行程" : "我恰好在这里"}
                        </button>
                      </div>
                    </article>
                  ))}
                  {visibleWishes.length === 0 && <div className="empty">这座城市的第一份心愿，正在路上。</div>}
                </div>
              </section>
            )}

            {tab === "publish" && (
              <section className="view publish-view">
                <div className="view-heading"><button onClick={() => setTab("pool")}>←</button><div><span>发一个轻轻的愿望</span><h2>想让它在哪里发生？</h2></div></div>
                {published ? (
                  <div className="success-card">
                    <div className="success-orb">✓</div>
                    <span>心愿编号 #HW0715</span>
                    <h2>你的心愿已经起飞</h2>
                    <p>我们会先完成内容审核，再把它投进当地的愿望池。有人回应时会第一时间通知你。</p>
                    <div className="status-line"><i className="active" /><i /><i /><i /></div>
                    <div className="status-labels"><span>已提交</span><span>审核中</span><span>待响应</span><span>待交付</span></div>
                    <button onClick={() => { setPublished(false); setTab("pool"); }}>回到愿望池</button>
                  </div>
                ) : (
                  <form className="wish-form" onSubmit={publishWish}>
                    <label><span><b>01</b> 心愿场景</span><select required defaultValue="生日祝福"><option>生日祝福</option><option>加油鼓励</option><option>毕业祝福</option><option>浪漫表白</option><option>节日问候</option></select></label>
                    <div className="form-row">
                      <label><span><b>02</b> 城市</span><select required defaultValue="上海"><option>上海</option><option>北京</option><option>广州</option><option>深圳</option><option>成都</option></select></label>
                      <label><span>地标</span><select required defaultValue="外滩"><option>外滩</option><option>东方明珠</option><option>武康路</option></select></label>
                    </div>
                    <label><span><b>03</b> 想说的话</span><textarea required maxLength={120} placeholder="例如：请替我对小满说，二十四岁也要继续闪闪发光。" /><small>仅接受祝福、鼓励与善意表达 · 最多120字</small></label>
                    <label><span><b>04</b> 交付方式</span><div className="format-picks"><label><input type="radio" name="format" defaultChecked />口播视频</label><label><input type="radio" name="format" />景色配音</label><label><input type="radio" name="format" />手写卡片</label></div></label>
                    <div className="price-box"><div><span>发布费</span><small>用于审核与过滤无效请求</small></div><strong>¥ 5.00</strong></div>
                    <button className="primary-submit" type="submit">确认发布心愿 <span>→</span></button>
                    <p className="form-note">提交即表示同意《心愿发布规范》，审核不通过将原路退款。</p>
                  </form>
                )}
              </section>
            )}

            {tab === "tasks" && (
              <section className="view tasks-view">
                <div className="simple-heading"><span>我的行程</span><h2>善意正在路上</h2></div>
                <div className="impact-card"><span>本月点亮</span><strong>{accepted.length || 0}<small> 个心愿</small></strong><p>每一次抵达，都让世界近一点。</p></div>
                <div className="task-tabs"><button className="active">进行中 {accepted.length}</button><button>已完成 8</button></div>
                {accepted.length ? accepted.map((id) => {
                  const wish = wishes.find((item) => item.id === id)!;
                  return <article className="task-card" key={id}><div><span>{wish.city}</span><b>{wish.landmark}</b></div><p>{wish.copy}</p><div className="progress"><i /><i /><i /><i /></div><div className="progress-label"><span>已接单</span><span>已到达</span><span>已上传</span><span>已完成</span></div><button onClick={() => flash("演示版已记录到达状态")}>我已到达地标</button></article>;
                }) : <div className="empty-task"><div>⌁</div><b>还没有正在进行的心愿</b><p>去愿望池看看，也许有人正等着你。</p><button onClick={() => setTab("pool")}>逛逛愿望池</button></div>}
              </section>
            )}

            {tab === "profile" && (
              <section className="view profile-view">
                <div className="profile-hero"><div className="large-avatar">韩</div><h2>远方来信</h2><p>上海祝福官 · Lv.2</p><div><span><b>8</b>完成心愿</span><span><b>4.9</b>感动值</span><span><b>3</b>城市徽章</span></div></div>
                <div className="badge-card"><span>本周身份</span><h3>外滩愿望响应者</h3><p>再完成 2 个心愿，解锁「城市信使」徽章</p><div><i /></div></div>
                <div className="menu-card"><button><span>♡</span>我的心愿<i>2 个进行中</i></button><button><span>⌁</span>帮助记录<i>8 次抵达</i></button><button><span>☆</span>我的徽章<i>3 枚</i></button><button><span>⚙</span>设置与规则<i>›</i></button></div>
                <button className="logout" onClick={() => flash("演示模式暂不需要登录")}>退出体验账号</button>
              </section>
            )}
          </div>

          <nav className="bottom-nav">
            {nav.map((item) => <button key={item.key} onClick={() => setTab(item.key)} className={tab === item.key ? "active" : ""}><i>{item.icon}</i><span>{item.label}</span></button>)}
          </nav>
          {toast && <div className="toast">✓ {toast}</div>}
        </div>
      </section>
    </main>
  );
}
