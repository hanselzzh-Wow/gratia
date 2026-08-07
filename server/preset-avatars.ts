/**
 * App 内置预设头像的指纹清单。
 *
 * 新用户必须设头像，但不是每个人手边都有合适的照片，也不是每个人愿意放自己
 * 的脸。预设图是那条兜底路径——而它必须**立即生效**：否则用户按引导选了头像，
 * 别人看到的依然是灰色人像，一直等到运营上线点一下为止，这个「必须设头像」
 * 就等于没做。
 *
 * 所以这里按内容指纹放行，而不是听客户端自称「我传的是预设图」——后者随便
 * 改个请求就能让任意图片跳过审核。图案本身是我们自己程序化生成的
 * （`scripts/generate-preset-avatars.py`），不是用户产生的内容，
 * 免审是成立的。
 *
 * ⚠️ 改动那个生成脚本会改变哈希，这份清单必须同步更新，否则预设头像会退回
 * 到走人工审核——不报错，只是安静地不再免审。脚本会打印新的清单。
 */
const PRESET_AVATAR_SHA256 = new Set([
  "2593939b026e021bf130829e755604aac64c614a53d4eaaa65e7ec14605c3ac0", // preset-1.png
  "ececa2458e83f8b4c1d6e365b092904c85b8067c174fc480177e061e0a5ab243", // preset-2.png
  "21ca2a909de70f5af0152ac6473c67ad9ae3af40991a4f378ae825344121567a", // preset-3.png
  "640405f510872200102124aef9a497d337814ff0eec472dfbd9eaa7816ecaf99", // preset-4.png
  "0d272eab6b54f5b8401284e47aceac0aea5533d008df49040b91f4f43349bbcc", // preset-5.png
  "f55186a675bd4e7158b9e007acdf862ab3025aecb5f5112f52e7e3cb12a02a64", // preset-6.png
  "c8f736de9ddccb3fe1b4c7833b3a9e2bedb363d05218f62c61fefe014cc646d3", // preset-7.png
  "bae1772eb17bb0e6d06cbfe5384929839d9c2286e954f5a10ffb0b2dec0a7890", // preset-8.png
  "fbabd0d218efc3ccb4496d49bb7157f76da4da344d33e6db39f36108590003a4", // preset-9.png
  "a5ee8e01b7c474c44c15ac34fe2007bd3575d2c4cfc97499dd53cb086803ecf9", // preset-10.png
  "67652f651003492659210e2424660283df8f1d3549b51e141453eeb287919984", // preset-11.png
  "2b6e6eff5ebf2f41c9d7181c784e451ea58f45959675af4cc761684c23f3f7fb", // preset-12.png
]);

export const presetAvatarCount = PRESET_AVATAR_SHA256.size;

/// 这份字节是不是我们自己的预设头像。
export async function isPresetAvatar(bytes: ArrayBuffer): Promise<boolean> {
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  const hex = Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, "0")).join("");
  return PRESET_AVATAR_SHA256.has(hex);
}
