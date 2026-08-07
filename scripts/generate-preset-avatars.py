#!/usr/bin/env python3
"""生成 App 内置的预设头像。

为什么要有预设头像：新用户必须设头像，但不是每个人手边都有合适的照片，
也不是每个人都愿意放自己的脸。没有兜底选项的话，这一步会把人卡在门口，
而那正是他对产品的第一印象。

为什么是程序化生成而不是找素材：网上的「头像大全」有版权与肖像权问题，
商用不得。这里生成的是纯几何图案，来源明确。

**输出必须逐字节可复现**：服务端靠 SHA-256 白名单识别预设头像并直接放行
审核，图案变了哈希就变了，服务端那份清单必须同步更新。所以这里不用任何
随机数，全部由序号推导。

    python3 scripts/generate-preset-avatars.py

会写入 ios/Gratia/PresetAvatars/ 并打印哈希清单。
"""

import hashlib
import math
import pathlib
import sys

from PIL import Image, ImageDraw

SIZE = 512
SUPERSAMPLE = 4  # 先放大画再缩小，边缘才不会有锯齿
COUNT = 12
OUT = pathlib.Path(__file__).resolve().parent.parent / "ios" / "Gratia" / "PresetAvatars"

# 12 个色相，绕色轮一圈但整体压低饱和度，和「玫粉白」的基调不打架。
# 每项是 (背景深色, 背景浅色, 前景图形色)。
PALETTE = [
    ((154, 83, 109), (247, 239, 242), (127, 64, 88)),   # 玫瑰（品牌主色）
    ((176, 106, 98), (250, 240, 236), (140, 78, 72)),   # 陶土
    ((166, 124, 82), (250, 243, 234), (132, 96, 60)),   # 赭石
    ((146, 134, 74), (247, 245, 232), (114, 104, 54)),  # 橄榄
    ((110, 138, 96), (238, 245, 236), (82, 108, 72)),   # 苔绿
    ((88, 138, 128), (234, 245, 243), (64, 108, 100)),  # 松石
    ((84, 128, 156), (234, 243, 249), (60, 98, 122))    ,# 灰蓝
    ((96, 114, 164), (237, 240, 250), (70, 86, 128)),   # 靛青
    ((124, 106, 162), (243, 239, 250), (94, 78, 126)),  # 紫藤
    ((150, 100, 148), (248, 238, 247), (116, 74, 114)), # 丁香
    ((160, 92, 124), (249, 238, 244), (124, 66, 94)),   # 梅
    ((112, 112, 118), (241, 241, 243), (84, 84, 90)),   # 石墨（不喜欢颜色的人）
]


def draw_shape(d: ImageDraw.ImageDraw, index: int, s: int, fg: tuple) -> None:
    """六种图形 × 两种配色变体 = 12 张互不重样的图。"""
    c = s / 2
    shape = index % 6
    if shape == 0:  # 同心圆
        for r, w in ((0.30, 0.055), (0.19, 0.055)):
            rr = s * r
            d.ellipse([c - rr, c - rr, c + rr, c + rr], outline=fg, width=int(s * w))
    elif shape == 1:  # 一段弧：品牌标记的那条「从这里到那里」
        r = s * 0.27
        d.arc([c - r, c - r, c + r, c + r], start=145, end=395, fill=fg, width=int(s * 0.075))
        rr = s * 0.052
        d.ellipse([c + r - rr, c - rr, c + r + rr, c + rr], fill=fg)
    elif shape == 2:  # 三点
        r = s * 0.058
        for i in range(3):
            a = math.radians(-90 + i * 120)
            x, y = c + math.cos(a) * s * 0.17, c + math.sin(a) * s * 0.17
            d.ellipse([x - r, y - r, x + r, y + r], fill=fg)
    elif shape == 3:  # 竖条
        w, gap, h = s * 0.052, s * 0.085, s * 0.30
        for i in (-1, 0, 1):
            x = c + i * (w + gap)
            hh = h if i == 0 else h * 0.62
            d.rounded_rectangle([x - w / 2, c - hh / 2, x + w / 2, c + hh / 2], radius=w / 2, fill=fg)
    elif shape == 4:  # 菱形
        r = s * 0.26
        d.polygon([(c, c - r), (c + r, c), (c, c + r), (c - r, c)], outline=fg, width=int(s * 0.06))
    else:  # 半圆：地平线
        r = s * 0.27
        d.pieslice([c - r, c - r, c + r, c + r], start=180, end=360, fill=fg)
        d.line([c - r, c, c + r, c], fill=fg, width=int(s * 0.05))


def build(index: int) -> Image.Image:
    dark, light, fg = PALETTE[index]
    s = SIZE * SUPERSAMPLE
    img = Image.new("RGB", (s, s), light)
    d = ImageDraw.Draw(img)
    # 背景：一道柔和的对角渐变，避免整块死板的纯色
    for y in range(s):
        t = y / (s - 1)
        d.line(
            [(0, y), (s, y)],
            fill=tuple(round(light[i] + (dark[i] - light[i]) * t * 0.30) for i in range(3)),
        )
    draw_shape(d, index, s, fg)
    return img.resize((SIZE, SIZE), Image.LANCZOS)


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    rows = []
    for i in range(COUNT):
        path = OUT / f"preset-{i + 1}.png"
        # optimize=True 是确定性的；不写入时间戳，保证逐字节可复现
        build(i).save(path, "PNG", optimize=True)
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        rows.append((path.name, digest, path.stat().st_size))

    print(f"已写入 {COUNT} 张到 {OUT}\n")
    print("服务端白名单（server/preset-avatars.ts 需与此一致）：")
    for name, digest, size in rows:
        print(f'  "{digest}", // {name}  {size / 1024:.1f} KB')
    return 0


if __name__ == "__main__":
    sys.exit(main())
