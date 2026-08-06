#!/bin/zsh

# ChatGPT.app 是当前 Codex 桌面应用的宿主进程。caffeinate -i 只阻止
# 系统因空闲休眠，不阻止屏幕关闭；-w 会在宿主进程退出时自动结束。
while true; do
  pid=$(/usr/bin/pgrep -x ChatGPT | /usr/bin/head -n 1)
  if [[ -n "$pid" ]]; then
    echo "$(/bin/date '+%Y-%m-%d %H:%M:%S') Codex active (pid=$pid); preventing idle sleep"
    /usr/bin/caffeinate -i -w "$pid"
    echo "$(/bin/date '+%Y-%m-%d %H:%M:%S') Codex exited; restoring normal sleep"
  fi
  /bin/sleep 10
done
