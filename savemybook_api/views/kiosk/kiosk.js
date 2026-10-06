(function () {
  'use strict';

  const Core = window.SmbDeviceCore;
  const QR = window.SmbQrCode;
  const root = document.getElementById('kiosk');

  const OPTIONS_KEY = 'smb.kiosk.options';
  const LOCK_NAME = 'smb-kiosk-device';
  const LOG_LIMIT = 100;
  const FONT = '-apple-system, BlinkMacSystemFont, "PingFang TC", "Noto Sans TC", "Microsoft JhengHei", sans-serif';
  const NO_LINE_START = new Set('，。、：；！？）」』》…,.:;!?)');
  const NO_LINE_END = new Set('（「『《(');
  const isWordChar = (ch) => ch !== undefined && ch.charCodeAt(0) < 0x80 && ch !== ' ';

  const C = {
    bg: '#0e1318',
    header: '#18212a',
    text: '#eef2f5',
    muted: '#93a2ad',
    track: '#2a3540',
    offline: '#66737d',
    accent: '#46b59c',
    warn: '#f0b429',
    danger: '#e0685c',
    white: '#ffffff',
    black: '#000000'
  };

  const el = (tag, className, text) => {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text != null) node.textContent = text;
    return node;
  };

  const storage = {
    get(key) {
      try { return window.localStorage.getItem(key); } catch (err) { return null; }
    },
    set(key, value) {
      try { window.localStorage.setItem(key, value); } catch (err) {}
    },
    remove(key) {
      try { window.localStorage.removeItem(key); } catch (err) {}
    }
  };

  const loadOptions = () => {
    try {
      const saved = JSON.parse(storage.get(OPTIONS_KEY) || '{}');
      return { autoClose: saved.autoClose !== false, sensor: saved.sensor === true };
    } catch (err) {
      return { autoClose: true, sensor: false };
    }
  };

  const saveOptions = (options) => storage.set(OPTIONS_KEY, JSON.stringify(options));

  const random = () => {
    const buf = new Uint32Array(1);
    window.crypto.getRandomValues(buf);
    return buf[0] / 4294967296;
  };

  const clock = {
    now: () => window.performance.now(),
    setTimeout: (fn, ms) => window.setTimeout(fn, ms),
    clearTimeout: (id) => window.clearTimeout(id)
  };

  const pad2 = (n) => String(n).padStart(2, '0');
  const timeText = (at) => {
    const d = new Date(at);
    return `${pad2(d.getHours())}:${pad2(d.getMinutes())}:${pad2(d.getSeconds())}`;
  };

  const showMessage = (text) => {
    root.textContent = '';
    root.appendChild(el('p', 'layout-message', text));
  };

  const createScreen = (core) => {
    const { LAYOUT } = Core;
    const { WIDTH: W, HEIGHT: H, HEADER_HEIGHT: HEADER, TEXT_WIDTH: TW, FONTS } = LAYOUT;
    const CX = W / 2;
    const MID_Y = (HEADER + H) / 2;
    const F = {
      small: { size: FONTS.SMALL, weight: 400 },
      body: { size: FONTS.BODY, weight: 400 },
      title: { size: FONTS.TITLE, weight: 500 },
      code: { size: FONTS.CODE, weight: 500 },
      label: { size: FONTS.LABEL, weight: 500 },
      labelSm: { size: FONTS.LABEL_SM, weight: 500 },
      ring: { size: FONTS.RING, weight: 500 },
      huge: { size: FONTS.HUGE, weight: 500 }
    };
    const canvas = el('canvas', 'screen');
    canvas.width = W;
    canvas.height = H;
    canvas.setAttribute('role', 'img');
    const ctx = canvas.getContext('2d');
    const state = { view: core.view, ratio: 1, queued: false, qrCache: { payload: null, matrix: null } };

    const resize = () => {
      const rect = canvas.getBoundingClientRect();
      if (!rect.width) return;
      const ratio = (rect.width / W) * (window.devicePixelRatio || 1);
      const width = Math.round(W * ratio);
      const height = Math.round(H * ratio);
      if (canvas.width !== width || canvas.height !== height) {
        canvas.width = width;
        canvas.height = height;
      }
      state.ratio = ratio;
      schedule();
    };

    const useFont = (f) => {
      ctx.font = `${f.weight} ${f.size}px ${FONT}`;
    };

    // 韌體以整數像素計算字寬；不取整時「SaveMyBook App」會多出不到 1 像素而斷行位置不同。
    const measure = (f, value) => {
      useFont(f);
      return Math.round(ctx.measureText(value).width);
    };

    // 與韌體相同：中文字與數字的視覺中心約在基線上方 0.38 字高。
    const text = (f, value, x, cy, color, align = 'left') => {
      useFont(f);
      ctx.fillStyle = color;
      ctx.textAlign = align;
      ctx.textBaseline = 'alphabetic';
      ctx.fillText(value, x, cy + Math.round(f.size * 0.38));
    };

    // 斷行規則同韌體 wrapText：英數字連成一個單位，行首不放標點。
    const wrapText = (f, value, maxWidth) => {
      const tokens = [];
      let joinNext = false;
      for (const ch of String(value || '')) {
        if (ch === ' ') {
          tokens.push(' ');
          joinNext = false;
          continue;
        }
        const last = tokens[tokens.length - 1];
        const attach = last !== undefined && last !== ' '
          && (joinNext || NO_LINE_START.has(ch) || (isWordChar(ch) && isWordChar(last[last.length - 1])));
        if (attach) tokens[tokens.length - 1] += ch;
        else tokens.push(ch);
        joinNext = NO_LINE_END.has(ch);
      }
      const lines = [];
      let line = '';
      for (const t of tokens) {
        if (t === ' ' && !line) continue;
        if (line && measure(f, line + t) > maxWidth) {
          lines.push(line.trimEnd());
          line = t === ' ' ? '' : t;
        } else {
          line += t;
        }
      }
      line = line.trimEnd();
      if (line) lines.push(line);
      return lines;
    };

    const balancedWrap = (f, value, width) => {
      const lines = wrapText(f, value, width);
      if (lines.length < 2) return lines;
      let lo = Math.floor(width / 2);
      let hi = width;
      while (lo < hi) {
        const mid = Math.floor((lo + hi) / 2);
        if (wrapText(f, value, mid).length === lines.length) hi = mid;
        else lo = mid + 1;
      }
      return wrapText(f, value, hi);
    };

    const paragraph = (f, value, x, cy, width, color, lineH, maxLines = 3, align = 'center') => {
      const lines = balancedWrap(f, value, width).slice(0, maxLines);
      let y = cy - Math.trunc(((lines.length - 1) * lineH) / 2);
      for (const line of lines) {
        text(f, line, x, y, color, align);
        y += lineH;
      }
    };

    const rect = (x, y, w, h, color) => {
      ctx.fillStyle = color;
      ctx.fillRect(x, y, w, h);
    };

    const disc = (cx, cy, r, color) => {
      ctx.fillStyle = color;
      ctx.beginPath();
      ctx.arc(cx, cy, r, 0, Math.PI * 2);
      ctx.fill();
    };

    const stroke = (points, width, color) => {
      ctx.lineWidth = width;
      ctx.lineCap = 'round';
      ctx.lineJoin = 'round';
      ctx.strokeStyle = color;
      ctx.beginPath();
      points.forEach(([x, y], i) => (i ? ctx.lineTo(x, y) : ctx.moveTo(x, y)));
      ctx.stroke();
    };

    const ring = (cx, cy, r, width, ratio, fg, track) => {
      ctx.lineWidth = width;
      ctx.lineCap = 'butt';
      ctx.strokeStyle = track;
      ctx.beginPath();
      ctx.arc(cx, cy, r, 0, Math.PI * 2);
      ctx.stroke();
      const filled = Math.max(0, Math.min(1, ratio));
      if (filled <= 0) return;
      ctx.strokeStyle = fg;
      ctx.beginPath();
      ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * filled);
      ctx.stroke();
    };

    const bar = (x, y, w, ratio, color = C.accent) => {
      rect(x, y, w, 4, C.track);
      rect(x, y, Math.round(w * Math.max(0, Math.min(1, ratio))), 4, color);
    };

    const ratioOf = (countdown) => (countdown && countdown.totalMs > 0 ? countdown.remainingMs / countdown.totalMs : 0);
    const line = (view, i) => view.lines[i] || '';

    const icon = (kind, cx, cy) => {
      const color = kind === 'check' ? C.accent : kind === 'alert' ? C.warn : C.muted;
      ring(cx, cy, LAYOUT.NOTICE.ICON_R, 3, 1, color, color);
      if (kind === 'check') {
        stroke([[cx - 10, cy + 1], [cx - 3, cy + 8], [cx + 11, cy - 7]], 3, color);
      } else if (kind === 'alert') {
        stroke([[cx, cy - 11], [cx, cy + 3]], 3.5, color);
        disc(cx, cy + 10, 2, color);
      } else if (kind === 'clock') {
        stroke([[cx, cy - 13], [cx, cy], [cx + 9, cy + 5]], 3, color);
      } else if (kind === 'pause') {
        stroke([[cx - 6, cy - 10], [cx - 6, cy + 10]], 4, color);
        stroke([[cx + 6, cy - 10], [cx + 6, cy + 10]], 4, color);
      } else if (kind === 'wrench') {
        stroke([[cx - 11, cy + 11], [cx + 3, cy - 3]], 5, color);
        disc(cx + 6, cy - 6, 8, color);
        stroke([[cx + 6, cy - 6], [cx + 14, cy - 14]], 5, C.bg);
      }
    };

    // 與韌體相同：標題列右側顯示臺灣時間（韌體以後端回應的 Date 標頭校時）
    const clockFmt = new Intl.DateTimeFormat('en-GB', { timeZone: 'Asia/Taipei', hour: '2-digit', minute: '2-digit', hourCycle: 'h23' });
    const header = (view) => {
      rect(0, 0, W, HEADER, C.header);
      text(F.title, view.header, 10, HEADER / 2, C.text);
      text(F.title, clockFmt.format(new Date()), W - 10, HEADER / 2, view.connection === 'online' ? C.text : C.offline, 'right');
    };

    const drawPairing = (view) => {
      const P = LAYOUT.PAIRING;
      if (!view.pairing.code) {
        text(F.title, line(view, 0), CX, P.STATUS_TITLE_Y, C.muted, 'center');
        paragraph(F.body, line(view, 1), CX, P.STATUS_Y, TW, view.pairing.error ? C.warn : C.text, 24, 2);
        return;
      }
      text(F.title, line(view, 0), CX, P.TITLE_Y, C.muted, 'center');
      text(F.code, view.pairing.code, CX, P.CODE_Y, C.text, 'center');
      text(F.body, line(view, 2), CX, P.PROMPT_Y, C.text, 'center');
      text(F.small, line(view, 3), CX, P.REMAINING_Y, C.muted, 'center');
      const [bx, by, bw] = P.BAR;
      bar(bx, by, bw, ratioOf(view.pairing));
    };

    // QR Code 的模組以裝置像素對齊繪製，縮放後格線之間才不會出現細縫。
    const drawQr = (modules, n, x, y, scale) => {
      const quiet = LAYOUT.IDLE.QUIET_ZONE;
      rect(x, y, (n + quiet * 2) * scale, (n + quiet * 2) * scale, C.white);
      const r = state.ratio;
      ctx.save();
      ctx.setTransform(1, 0, 0, 1, 0, 0);
      ctx.fillStyle = C.black;
      for (let row = 0; row < n; row++) {
        const y0 = Math.round((y + (row + quiet) * scale) * r);
        const y1 = Math.round((y + (row + quiet + 1) * scale) * r);
        for (let col = 0; col < n; col++) {
          if (!modules[row][col]) continue;
          const x0 = Math.round((x + (col + quiet) * scale) * r);
          const x1 = Math.round((x + (col + quiet + 1) * scale) * r);
          ctx.fillRect(x0, y0, x1 - x0, y1 - y0);
        }
      }
      ctx.restore();
    };

    const drawIdle = (view) => {
      if (!view.qr) {
        paragraph(F.title, line(view, 0), CX, MID_Y, TW, C.text, 24, 2);
        return;
      }
      const I = LAYOUT.IDLE;
      if (state.qrCache.payload !== view.qr.payload) {
        state.qrCache = { payload: view.qr.payload, matrix: QR.encode(view.qr.payload) };
      }
      const { size: n, modules } = state.qrCache.matrix;
      const modulesWithQuiet = n + I.QUIET_ZONE * 2;
      const scale = modulesWithQuiet * I.SCALE <= H - I.QR_Y - I.MARGIN ? I.SCALE : I.MIN_SCALE;
      const side = modulesWithQuiet * scale;
      drawQr(modules, n, I.QR_X, I.QR_Y, scale);
      bar(I.QR_X, I.QR_Y + side + I.BAR_GAP, side, view.qr.refreshRatio);

      const left = I.QR_X + side + I.TEXT_GAP;
      const width = W - I.MARGIN - left;
      const cx = left + Math.floor(width / 2);
      const lines = view.lines.flatMap((value) => wrapText(F.body, value, width));
      let y = I.QR_Y + Math.floor(side / 2) - Math.floor((lines.length * I.LINE_HEIGHT) / 2) + 12;
      for (const value of lines) {
        text(F.body, value, cx, y, C.text, 'center');
        y += I.LINE_HEIGHT;
      }
    };

    const drawNotice = (view) => {
      const N = LAYOUT.NOTICE;
      icon(view.icon, N.ICON_X, N.ICON_Y);
      paragraph(F.title, line(view, 0), CX, N.TITLE_Y, TW, C.text, 24, 2);
      if (view.lines.length > 1) paragraph(F.body, line(view, 1), CX, N.TEXT_Y, TW, C.muted, 22, 2);
    };

    const drawSelect = (view) => {
      const S = LAYOUT.SELECT;
      paragraph(F.title, line(view, 0), CX, S.TITLE_Y, TW, C.text, 24, 2);
      paragraph(F.body, line(view, 1), CX, S.TEXT_Y, TW, C.text, 22, 2);
      if (view.countdown) {
        text(F.small, view.lines[view.lines.length - 1], CX, S.REMAINING_Y, C.muted, 'center');
        const [bx, by, bw] = S.BAR;
        bar(bx, by, bw, ratioOf(view.countdown));
      }
    };

    const drawMatch = (view) => {
      const M = LAYOUT.MATCH;
      text(F.title, line(view, 0), CX, M.TITLE_Y, C.text, 'center');
      if (view.code) text(F.huge, view.code, CX, M.CODE_Y, C.text, 'center');
      if (view.countdown) {
        text(F.small, view.lines[view.lines.length - 1], CX, M.REMAINING_Y, C.muted, 'center');
        const [bx, by, bw] = M.BAR;
        bar(bx, by, bw, ratioOf(view.countdown));
      }
    };

    // 櫃門編號放不下一列時改用小字，並平均分列，例如 4 扇排成 2＋2。
    const drawOpen = (view) => {
      const O = LAYOUT.OPEN;
      const labels = line(view, 0).split('　').filter(Boolean);
      let f = F.label;
      let gap = O.LABEL_GAP;
      const rowWidth = (font, count) => labels.slice(0, count).reduce((w, label, i) => w + measure(font, label) + (i ? gap : 0), 0);
      const count = Math.max(1, labels.length);
      let perRow = count;
      if (rowWidth(f, perRow) > O.LABEL_WIDTH) {
        f = F.labelSm;
        gap = O.LABEL_SM_GAP;
        while (perRow > 1 && rowWidth(f, perRow) > O.LABEL_WIDTH) perRow -= 1;
        const rows = Math.ceil(count / perRow);
        perRow = Math.ceil(count / rows);
      }
      let y = f === F.label ? O.LABEL_Y : O.LABEL_SM_Y;
      let lastRow = y;
      for (let i = 0; i < labels.length; i += perRow) {
        let x = O.LABEL_X;
        for (const label of labels.slice(i, i + perRow)) {
          text(f, label, x, y, C.text);
          x += measure(f, label) + gap;
        }
        lastRow = y;
        y += O.LABEL_ROW_H;
      }
      const msgY = f === F.label ? O.MESSAGE_Y : Math.max(O.MESSAGE_Y, lastRow + 44);
      if (view.notice) paragraph(F.title, view.notice, O.MESSAGE_X, msgY, O.MESSAGE_WIDTH, C.warn, 24, 2, 'left');
      else paragraph(F.body, line(view, 1), O.MESSAGE_X, msgY, O.MESSAGE_WIDTH, C.text, 24, 3, 'left');

      if (view.countdown) {
        const R = O.RING;
        const ratio = ratioOf(view.countdown);
        ring(R.X, R.Y, R.R, R.WIDTH, ratio, ratio < 0.2 ? C.warn : C.accent, C.track);
        text(F.ring, String(Math.ceil(view.countdown.remainingMs / 1000)), R.X, R.Y, C.text, 'center');
      }
    };

    const drawCentered = (view) => {
      const multi = view.lines.length > 1;
      paragraph(F.title, line(view, 0), CX, MID_Y - (multi ? 14 : 0), TW, C.text, 24, 2);
      if (multi) paragraph(F.small, line(view, 1), CX, MID_Y + 22, TW, C.muted, 20, 2);
    };

    const draw = () => {
      state.queued = false;
      const view = state.view;
      ctx.setTransform(state.ratio, 0, 0, state.ratio, 0, 0);
      rect(0, 0, W, H, C.bg);
      header(view);
      switch (view.screen) {
        case 'pairing':
          drawPairing(view);
          break;
        case 'idle':
          drawIdle(view);
          break;
        case 'closed_hours':
        case 'maintenance':
        case 'disabled':
        case 'result':
          drawNotice(view);
          break;
        case 'select':
          drawSelect(view);
          break;
        case 'match':
          drawMatch(view);
          break;
        case 'open':
        case 'admin':
          drawOpen(view);
          break;
        default:
          drawCentered(view);
      }
    };

    const schedule = () => {
      if (state.queued) return;
      state.queued = true;
      window.requestAnimationFrame(draw);
    };

    if (window.ResizeObserver) new window.ResizeObserver(resize).observe(canvas);
    window.addEventListener('resize', resize);

    return {
      canvas,
      start() {
        resize();
        schedule();
        window.setInterval(schedule, 15000);
      },
      update(view) {
        state.view = view;
        // 背光調暗：整個螢幕等比例變暗
        canvas.style.filter = view.brightness < 100 ? `brightness(${view.brightness / 100})` : '';
        schedule();
        const label = view.lines.filter(Boolean).join('，');
        canvas.setAttribute('aria-label', `書櫃螢幕：${label || view.screen}`);
      }
    };
  };

  const createPanel = (core, options, onSensorChange) => {
    const panel = el('section', 'panel');
    panel.setAttribute('aria-label', '模擬控制台');
    panel.appendChild(el('h1', 'panel-title', '模擬控制台（實機沒有）'));

    const card = (title) => {
      const node = el('div', 'card');
      node.appendChild(el('h2', 'card-title', title));
      panel.appendChild(node);
      return node;
    };

    const switchControl = (checked) => {
      const wrap = el('span', 'switch');
      const input = el('input');
      input.type = 'checkbox';
      input.checked = checked;
      wrap.appendChild(input);
      wrap.appendChild(el('span', 'switch-track'));
      return { wrap, input };
    };

    const row = (parent, label, hint) => {
      const node = el('div', 'row');
      const text = el('span', 'row-label', label);
      if (hint) text.appendChild(el('span', 'row-hint', hint));
      node.appendChild(text);
      parent.appendChild(node);
      return node;
    };

    const button = (label, className) => {
      const b = el('button', `btn${className ? ` ${className}` : ''}`, label);
      b.type = 'button';
      return b;
    };

    const info = card('裝置資訊');
    const dl = el('dl', 'info');
    const infoField = (label) => {
      dl.appendChild(el('dt', null, label));
      const dd = el('dd', null, '－');
      dl.appendChild(dd);
      return dd;
    };
    const fCabinet = infoField('書櫃名稱');
    const fDevice = infoField('裝置編號');
    const fConnection = infoField('連線狀態');
    const fSync = infoField('最後同步時間');
    info.appendChild(dl);

    const pairCard = card('配對');
    pairCard.appendChild(el('p', 'card-text', '書櫃螢幕顯示 8 位數配對碼，請於管理後台的書櫃裝置頁面輸入；配對碼逾時後將自動重新取得。'));

    const settings = card('設定');
    const autoClose = switchControl(options.autoClose);
    row(settings, '倒數結束自動關門', '關閉後可測試伺服器的待確認流程').appendChild(autoClose.wrap);
    const sensor = switchControl(options.sensor);
    row(settings, '模擬門磁感測器', '切換後送出開機事件，並於書櫃正面的櫃門提供開門與關門操作').appendChild(sensor.wrap);
    autoClose.input.addEventListener('change', () => {
      options.autoClose = autoClose.input.checked;
      saveOptions(options);
      core.setOptions({ autoCloseOnTimeout: options.autoClose });
    });
    sensor.input.addEventListener('change', () => {
      if (core.setOptions({ hasDoorSensor: sensor.input.checked }) === false) {
        sensor.input.checked = !sensor.input.checked;
        return;
      }
      options.sensor = sensor.input.checked;
      saveOptions(options);
      onSensorChange();
    });

    const actionsCard = card('操作');
    const offline = switchControl(false);
    row(actionsCard, '模擬離線', '所有請求視為網路失敗，事件保留於佇列').appendChild(offline.wrap);
    offline.input.addEventListener('change', () => core.setOffline(offline.input.checked));

    const latencyRow = row(actionsCard, '模擬網路延遲', '套用於每個請求的回應；4 秒時往返超過 3 秒，不執行開鎖指令');
    const latency = el('select', 'select');
    latency.setAttribute('aria-label', '模擬網路延遲');
    for (const [value, label] of [['0', '0 秒'], ['1000', '1 秒'], ['4000', '4 秒']]) {
      const opt = el('option', null, label);
      opt.value = value;
      latency.appendChild(opt);
    }
    latency.addEventListener('change', () => core.setLatency(Number(latency.value)));
    latencyRow.appendChild(latency);

    const faultRow = row(actionsCard, '模擬櫃門故障', '送出電磁鎖未釋放（LOCK_NO_RELEASE）；再按一次解除');
    const faultDoor = el('select', 'select');
    faultDoor.setAttribute('aria-label', '故障櫃門');
    for (const door of core.view.doors) {
      const opt = el('option', null, door.label);
      opt.value = String(door.channel);
      faultDoor.appendChild(opt);
    }
    const faultButton = button('送出故障');
    faultRow.appendChild(faultDoor);
    faultRow.appendChild(faultButton);
    faultButton.addEventListener('click', () => {
      const channel = Number(faultDoor.value);
      const door = core.view.doors.find((d) => d.channel === channel);
      if (door && door.fault === 'LOCK_NO_RELEASE') core.clearFault(channel, 'LOCK_NO_RELEASE');
      else core.injectFault(channel, 'LOCK_NO_RELEASE');
    });
    faultDoor.addEventListener('change', () => refresh(core.view));

    const rebootRow = row(actionsCard, '模擬重新開機', '門開啟中重新開機時，將回報作業中斷');
    const rebootButton = button('重新開機');
    rebootButton.addEventListener('click', () => core.reboot());
    rebootRow.appendChild(rebootButton);

    const copyRow = row(actionsCard, '複製 QR 內容', '供無相機的 iOS 模擬器貼上使用');
    const copyButton = button('複製');
    copyRow.appendChild(copyButton);
    const copyFeedback = el('p', 'feedback');
    actionsCard.appendChild(copyFeedback);
    copyButton.addEventListener('click', async () => {
      const payload = core.view.qr && core.view.qr.payload;
      copyFeedback.classList.remove('is-error');
      if (!payload) {
        copyFeedback.textContent = '目前沒有可複製的 QR Code';
        return;
      }
      try {
        await navigator.clipboard.writeText(payload);
        copyFeedback.textContent = '已複製 QR 內容';
      } catch (err) {
        copyFeedback.classList.add('is-error');
        copyFeedback.textContent = '無法寫入剪貼簿，請確認瀏覽器權限';
      }
    });

    const unpairRow = row(actionsCard, '解除配對', '通知伺服器解除配對並清除本機資料');
    const unpairButton = button('解除配對', 'btn-danger');
    unpairButton.addEventListener('click', async () => {
      if (!window.confirm('確定要解除此模擬書櫃的配對？解除後書櫃螢幕將顯示新的配對碼，須由管理員重新輸入。')) return;
      unpairButton.disabled = true;
      await core.unpair();
      unpairButton.disabled = false;
    });
    unpairRow.appendChild(unpairButton);

    const logCard = card('事件紀錄');
    const logList = el('ol', 'log');
    logList.setAttribute('aria-live', 'off');
    logCard.appendChild(logList);
    const entries = [];
    let lastSync = null;

    const renderLog = () => {
      logList.textContent = '';
      if (!entries.length) {
        logList.appendChild(el('li', 'log-empty', '尚無紀錄'));
        return;
      }
      for (const entry of entries) {
        const li = el('li');
        li.appendChild(el('span', 'log-time', timeText(entry.at)));
        li.appendChild(el('span', `log-dir ${entry.dir === 'out' ? 'is-out' : 'is-in'}`, entry.dir === 'out' ? '→' : '←'));
        const main = el('span', 'log-main');
        if (entry.status != null) {
          main.appendChild(el('span', `log-status${entry.status === 0 || entry.status >= 400 ? ' is-error' : ''}`, entry.status === 0 ? '—' : String(entry.status)));
        }
        main.appendChild(document.createTextNode(`${entry.method} ${entry.path.replace('/api/device/v1', '')}  ${entry.summary || ''}`));
        if (entry.count > 1) main.appendChild(el('span', 'log-repeat', `×${entry.count}`));
        li.appendChild(main);
        logList.appendChild(li);
      }
    };

    const addLog = (entry) => {
      if (entry.dir === 'in' && entry.status >= 200 && entry.status < 300) lastSync = entry.at;
      const top = entries[0];
      if (top && top.dir === entry.dir && top.method === entry.method && top.path === entry.path
        && top.status === entry.status && top.summary === entry.summary) {
        top.count += 1;
        top.at = entry.at;
      } else {
        entries.unshift(Object.assign({ count: 1 }, entry));
        if (entries.length > LOG_LIMIT) entries.length = LOG_LIMIT;
      }
      renderLog();
      fSync.textContent = lastSync ? timeText(lastSync) : '－';
    };

    const refresh = (view) => {
      const paired = view.screen !== 'pairing';
      pairCard.hidden = paired;
      fCabinet.textContent = view.cabinetName || '－';
      fDevice.textContent = view.deviceNo || '－';
      fConnection.textContent = '';
      const dot = el('span', `status-dot${paired && view.connection === 'online' ? ' is-online' : ''}`);
      fConnection.appendChild(dot);
      fConnection.appendChild(document.createTextNode(paired ? (view.connection === 'online' ? '連線中' : '未連線') : '尚未配對'));

      const busy = view.screen === 'open' || view.screen === 'admin' || view.screen === 'opening';
      sensor.input.disabled = busy;
      const selected = view.doors.find((d) => d.channel === Number(faultDoor.value));
      faultButton.textContent = selected && selected.fault === 'LOCK_NO_RELEASE' ? '解除故障' : '送出故障';
      faultButton.disabled = !paired;
      copyButton.disabled = !view.qr;
      unpairButton.disabled = !paired;
    };

    renderLog();
    return { node: panel, refresh, addLog };
  };

  const createCabinet = (core, screenCanvas, options) => {
    const device = el('div', 'device');
    const cabinet = el('div', 'cabinet');
    cabinet.setAttribute('role', 'group');
    cabinet.setAttribute('aria-label', '書櫃正面');
    const face = el('div', 'cabinet-face');
    cabinet.appendChild(face);

    const top = el('div', 'cabinet-top');
    const sticker = el('div', 'sticker');
    const mark = el('span', 'sticker-mark');
    mark.setAttribute('aria-hidden', 'true');
    sticker.appendChild(mark);
    const words = el('span', 'sticker-words');
    const name = el('span', 'sticker-name');
    name.appendChild(document.createTextNode('救'));
    name.appendChild(el('span', 'sticker-accent', '「舊」'));
    name.appendChild(document.createTextNode('我的書'));
    words.appendChild(name);
    const latin = el('span', 'sticker-latin', 'SaveMyBook');
    latin.lang = 'en';
    words.appendChild(latin);
    sticker.appendChild(words);
    const bezel = el('div', 'bezel');
    bezel.appendChild(screenCanvas);
    top.appendChild(sticker);
    top.appendChild(bezel);
    face.appendChild(top);

    const doorList = el('div', 'doors');
    const doors = new Map();
    for (const door of core.view.doors) {
      const row = el('div', 'door');
      row.setAttribute('role', 'group');
      row.setAttribute('aria-label', `櫃門 ${door.label}`);
      const bay = el('div', 'door-bay');
      bay.setAttribute('aria-hidden', 'true');
      const leaf = el('span', 'door-leaf');
      leaf.appendChild(el('span', 'door-lock'));
      bay.appendChild(leaf);
      bay.appendChild(el('span', 'door-hinge'));
      row.appendChild(bay);

      const info = el('div', 'door-info');
      const head = el('div', 'door-head');
      head.appendChild(el('span', 'door-label', door.label));
      const stateText = el('span', 'door-state', '上鎖');
      head.appendChild(stateText);
      const note = el('span', 'door-note');
      head.appendChild(note);
      info.appendChild(head);
      const actions = el('div', 'door-actions');
      const openBtn = el('button', 'btn', '開門');
      const closeBtn = el('button', 'btn', '關門');
      openBtn.type = 'button';
      closeBtn.type = 'button';
      openBtn.addEventListener('click', () => core.setDoorPhysical(door.channel, 'open'));
      closeBtn.addEventListener('click', () => core.setDoorPhysical(door.channel, 'closed'));
      actions.appendChild(openBtn);
      actions.appendChild(closeBtn);
      info.appendChild(actions);
      row.appendChild(info);
      doorList.appendChild(row);
      doors.set(door.channel, { row, stateText, note, actions, openBtn, closeBtn });
    }
    face.appendChild(doorList);

    device.appendChild(cabinet);
    device.appendChild(el('p', 'device-caption', '2.8 吋 320 × 240 顯示螢幕（無觸控）'));

    const doorState = (door) => {
      if (door.fault) return ['故障', 'is-fault'];
      if (door.unlocking) return ['開鎖中', 'is-unlocking'];
      if (door.open) return ['開啟', 'is-open'];
      return ['上鎖', null];
    };

    const refresh = (view) => {
      const paired = view.screen !== 'pairing';
      for (const door of view.doors) {
        const d = doors.get(door.channel);
        if (!d) continue;
        const [label, cls] = doorState(door);
        d.row.classList.toggle('is-fault', cls === 'is-fault');
        d.row.classList.toggle('is-unlocking', cls === 'is-unlocking');
        d.row.classList.toggle('is-open', door.open);
        d.stateText.textContent = label;
        d.note.textContent = paired && !door.enabled ? '暫停分配' : '';
        d.actions.hidden = !options.sensor;
        d.openBtn.disabled = door.open;
        d.closeBtn.disabled = !door.open;
      }
    };

    return { node: device, refresh };
  };

  const startKiosk = () => {
    const options = loadOptions();
    let screen = null;
    let cabinet = null;
    let panel = null;
    const pendingLogs = [];

    const core = new Core.DeviceCore({
      baseUrl: '',
      fetch: window.fetch.bind(window),
      storage,
      clock,
      kind: 'simulator',
      firmware: 'sim-1.0.0',
      doorCount: 4,
      unlockPulseMs: 800,
      hasDoorSensor: options.sensor,
      autoCloseOnTimeout: options.autoClose,
      random,
      onView(view) {
        if (screen) screen.update(view);
        if (cabinet) cabinet.refresh(view);
        if (panel) panel.refresh(view);
      },
      onLog(entry) {
        if (panel) panel.addLog(entry);
        else pendingLogs.push(entry);
      }
    });

    root.textContent = '';
    screen = createScreen(core);
    cabinet = createCabinet(core, screen.canvas, options);
    panel = createPanel(core, options, () => cabinet.refresh(core.view));
    root.appendChild(cabinet.node);
    root.appendChild(panel.node);
    pendingLogs.forEach((entry) => panel.addLog(entry));

    screen.update(core.view);
    cabinet.refresh(core.view);
    panel.refresh(core.view);
    screen.start();
    core.start();
  };

  if (!root) return;
  if (!Core || !QR) {
    showMessage('模擬書櫃載入失敗，請重新整理頁面。');
    return;
  }
  if (navigator.locks && typeof navigator.locks.request === 'function') {
    navigator.locks.request(LOCK_NAME, { ifAvailable: true }, (lock) => {
      if (!lock) {
        showMessage('模擬書櫃已在其他分頁執行');
        return undefined;
      }
      startKiosk();
      return new Promise(() => {});
    });
  } else {
    startKiosk();
  }
})();
