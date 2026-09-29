const PAIRS = `
這这 們们 說说 為为 書书 發发 髮发 會会 來来 時时 個个 學学 國国 對对 過过 還还 進进 後后 麼么 經经 現现 樣样 從从 動动 應应
頭头 長长 問问 開开 關关 間间 實实 業业 義义 與与 產产 種种 務务 東东 車车 門门 馬马 鳥鸟 魚鱼 頁页 專专 買买 賣卖 讀读 寫写
愛爱 歡欢 親亲 讓让 認认 識识 語语 話话 該该 請请 誰谁 沒没 氣气 華华 葉叶 麗丽 樂乐 於于 雙双 雖虽 邊边 達达 運运 選选 遠远
連连 調调 變变 歷历 曆历 觀观 視视 覽览 覺觉 記记 設设 許许 論论 講讲 詞词 譯译 詩诗 課课 談谈 計计 訂订 訊讯 證证 評评 試试
誠诚 誤误 圖图 場场 報报 壓压 處处 備备 復复 複复 夠够 夢梦 孫孙 寧宁 將将 導导 層层 屬属 島岛 帶带 幫帮 廣广 張张 彈弹 態态
懷怀 戰战 戲戏 擊击 護护 權权 歲岁 歸归 殺杀 漢汉 灣湾 燈灯 爾尔 獨独 獎奖 畫画 當当 療疗 盡尽 監监 眾众 碼码 礎础 禮礼 穩稳
級级 紀纪 約约 紅红 純纯 紙纸 細细 終终 組组 結结 絕绝 給给 統统 綠绿 維维 網网 線线 練练 總总 績绩 織织 續续 習习 聽听 職职
聯联 腦脑 臉脸 興兴 舊旧 藝艺 節节 範范 築筑 簡简 絲丝 蘭兰 虛虚 蟲虫 術术 衛卫 裝装 製制 見见 規规 觸触 訴诉 詳详 誌志 議议
貝贝 負负 財财 貨货 質质 購购 貴贵 資资 賽赛 轉转 輕轻 輪轮 農农 適适 遺遗 郵邮 鄉乡 醫医 釋释 針针 鋼钢 錄录 錢钱 錯错 鏡镜
鐵铁 閱阅 陳陈 陽阳 陰阴 陸陆 隊队 際际 險险 隨随 隱隐 難难 電电 靈灵 韓韩 響响 頂顶 順顺 預预 領领 題题 顏颜 願愿 類类 顯显
風风 飛飞 飯饭 養养 餘余 館馆 驗验 體体 鬥斗 麥麦 黃黄 齊齐 龍龙 億亿 優优 傳传 傷伤 價价 僅仅 儀仪 兒儿 兩两 內内 別别 劃划
劇剧 勞劳 勢势 區区 協协 單单 嚴严 員员 圍围 園园 團团 塊块 壞坏 聲声 壽寿 奪夺 婦妇 媽妈 寶宝 審审 寬宽 尋寻 屆届 幣币 幹干
乾干 廳厅 彎弯 徵征 惡恶 慣惯 慶庆 憂忧 戶户 擇择 擔担 據据 擴扩 攝摄 敗败 敵敌 數数 斷断 條条 楊杨 極极 標标 樓楼 機机 檢检
歐欧 決决 況况 淚泪 淨净 測测 溫温 滅灭 滿满 潔洁 澤泽 濟济 濕湿 災灾 無无 煙烟 熱热 爭争 牆墙 狀状 猶犹 環环 畢毕 異异 盤盘
確确 積积 窮穷 競竞 筆笔 簽签 籤签 糾纠 納纳 紛纷 絡络 綜综 緊紧 緒绪 編编 緣缘 縣县 縱纵 繪绘 羅罗 聖圣 腳脚 臨临 萬万 蓋盖
藥药 蘇苏 號号 補补 裡里 裏里 討讨 訓训 訪访 誘诱 諾诺 謀谋 謝谢 譽誉 讚赞 豐丰 豬猪 貓猫 貧贫 責责 費费 賀贺 賴赖 贈赠 贏赢
軍军 軟软 載载 輔辅 輯辑 輸输 辦办 辭辞 遞递 遲迟 邏逻 鄰邻 鐘钟 鍵键 鎮镇 閃闪 閉闭 閒闲 闊阔 陣阵 階阶 雜杂 雞鸡 離离 雲云
頻频 顧顾 飲饮 驅驱 驚惊 魯鲁 鮮鲜 鳳凤 鹽盐 點点 黨党 齒齿 龜龟 夥伙 週周 麵面 臺台 颱台 著着 衝冲 託托 醜丑 隻只 係系 繫系
鬆松 準准 闆板 蘋苹 厭厌 構构 則则 鄭郑 銀银 紹绍 聞闻 劉刘 趙赵 吳吴 鄧邓 蕭萧 馮冯 賈贾 韋韦 盧卢
譚谭 鄒邹 靜静 燒烧 貿贸 帳账 樹树 憶忆 憑凭 爺爷 誕诞 勵励 糧粮 鍋锅 紐纽 總总 銷销 險险 滯滞 濃浓 廟庙 瑪玛 麗丽
參参 儲储 換换 額额 項项 須须 詢询 煩烦 嗎吗`;

const TO_SIMPLIFIED = new Map(PAIRS.trim().split(/\s+/).map((pair) => [...pair]));

// 這些簡化字在繁體中文也是常用字（例如「皇后」「里程」「干涉」），只能用於書名比對時的字形統一，不能當成簡體字的證據。
const SHARED = new Set('后里干余云丑板斗志范制征叶万于台松面冲托只系准着周伙苹丰划');
const SIMPLIFIED_ONLY = new Set([...TO_SIMPLIFIED.values()].filter((ch) => !SHARED.has(ch)));

const toSimplified = (text) => Array.from(String(text ?? ''), (ch) => TO_SIMPLIFIED.get(ch) ?? ch).join('');

const eitherScript = (re) => {
  const chars = Array.from(re.source);
  let out = '';
  let inClass = false;
  for (let i = 0; i < chars.length; i += 1) {
    const ch = chars[i];
    if (ch === '\\') {
      out += ch + (chars[i + 1] ?? '');
      i += 1;
      continue;
    }
    if (ch === '[' && !inClass) inClass = true;
    else if (ch === ']' && inClass) inClass = false;
    const simple = TO_SIMPLIFIED.get(ch);
    if (!simple) out += ch;
    else out += inClass ? ch + simple : `[${ch}${simple}]`;
  }
  return new RegExp(out, re.flags);
};

const HAN = /\p{Script=Han}/u;

const simplifiedShare = (text) => {
  let han = 0;
  let count = 0;
  for (const ch of String(text ?? '')) {
    if (!HAN.test(ch)) continue;
    han += 1;
    if (SIMPLIFIED_ONLY.has(ch)) count += 1;
  }
  return { count, ratio: han === 0 ? 0 : count / han };
};

module.exports = { toSimplified, simplifiedShare, eitherScript };
