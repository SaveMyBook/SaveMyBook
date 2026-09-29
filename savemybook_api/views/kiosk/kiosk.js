(function () {
  'use strict';

  const Core = window.SmbDeviceCore;
  const QR = window.SmbQrCode;
  const root = document.getElementById('kiosk');

  const OPTIONS_KEY = 'smb.kiosk.options';
  const LOCK_NAME = 'smb-kiosk-device';
  const LOG_LIMIT = 100;
  const FONT = '-apple-system, BlinkMacSystemFont, "PingFang TC", "Noto Sans TC", "Microsoft JhengHei", sans-serif';
  const ANIMATED = new Set(['booting', 'processing', 'offline', 'opening']);
  const CODE_FONT = 'ui-monospace, SFMono-Regular, Menlo, Consolas, monospace';

  const C = {
    bg: '#0e1318',
    header: '#18212a',
    text: '#eef2f5',
    muted: '#93a2ad',
    track: '#2a3540',
    online: '#3ccf8e',
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
    const { LAYOUT, format } = Core;
    const canvas = el('canvas', 'screen');
    canvas.width = LAYOUT.WIDTH;
    canvas.height = LAYOUT.HEIGHT;
    canvas.setAttribute('role', 'img');
    const ctx = canvas.getContext('2d');
    const state = { view: core.view, ratio: 1, dirty: true, qrCache: { payload: null, matrix: null } };

    const font = (size, bold, family = FONT) => `${bold ? '700' : '400'} ${size}px ${family}`;

    const resize = () => {
      const rect = canvas.getBoundingClientRect();
      if (!rect.width) return;
      const ratio = (rect.width / LAYOUT.WIDTH) * (window.devicePixelRatio || 1);
      const width = Math.round(LAYOUT.WIDTH * ratio);
      const height = Math.round(LAYOUT.HEIGHT * ratio);
      if (canvas.width !== width || canvas.height !== height) {
        canvas.width = width;
        canvas.height = height;
      }
      state.ratio = ratio;
      state.dirty = true;
    };

    const wrap = (text, maxWidth, maxLines) => {
      const lines = [];
      let line = '';
      for (const ch of String(text)) {
        const next = line + ch;
        if (line && ctx.measureText(next).width > maxWidth) {
          lines.push(line);
          line = ch.trim() ? ch : '';
          if (lines.length === maxLines) return lines;
        } else {
          line = next;
        }
      }
      if (line) lines.push(line);
      return lines.slice(0, maxLines);
    };

    const text = (value, x, y, { size = 14, bold = false, color = C.text, align = 'center', baseline = 'top', family = FONT } = {}) => {
      ctx.font = font(size, bold, family);
      ctx.fillStyle = color;
      ctx.textAlign = align;
      ctx.textBaseline = baseline;
      ctx.fillText(value, x, y);
    };

    const paragraph = (value, y, { size = 14, bold = false, color = C.text, maxLines = 2, width = 220, lineHeight = 1.45 } = {}) => {
      ctx.font = font(size, bold);
      const lines = wrap(value, width, maxLines);
      lines.forEach((line, i) => text(line, LAYOUT.WIDTH / 2, y + i * size * lineHeight, { size, bold, color }));
      return lines.length;
    };

    const spinner = (cx, cy, r, t) => {
      const start = ((t || 0) / 1000) * Math.PI * 2;
      ctx.lineWidth = 4;
      ctx.lineCap = 'round';
      ctx.strokeStyle = C.track;
      ctx.beginPath();
      ctx.arc(cx, cy, r, 0, Math.PI * 2);
      ctx.stroke();
      ctx.strokeStyle = C.accent;
      ctx.beginPath();
      ctx.arc(cx, cy, r, start, start + Math.PI * 0.6);
      ctx.stroke();
    };

    const icon = (kind, cx, cy) => {
      const r = 26;
      ctx.lineWidth = 4;
      ctx.lineCap = 'round';
      ctx.lineJoin = 'round';
      const color = kind === 'check' ? C.online : kind === 'alert' ? C.warn : C.muted;
      ctx.strokeStyle = color;
      ctx.fillStyle = color;
      if (kind === 'wrench') {
        ctx.beginPath();
        ctx.moveTo(cx, cy - r);
        ctx.lineTo(cx + r, cy + r * 0.8);
        ctx.lineTo(cx - r, cy + r * 0.8);
        ctx.closePath();
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(cx, cy - 8);
        ctx.lineTo(cx, cy + 6);
        ctx.stroke();
        ctx.beginPath();
        ctx.arc(cx, cy + 14, 2.5, 0, Math.PI * 2);
        ctx.fill();
        return;
      }
      ctx.beginPath();
      ctx.arc(cx, cy, r, 0, Math.PI * 2);
      ctx.stroke();
      ctx.beginPath();
      if (kind === 'check') {
        ctx.moveTo(cx - 12, cy + 1);
        ctx.lineTo(cx - 3, cy + 10);
        ctx.lineTo(cx + 13, cy - 9);
        ctx.stroke();
      } else if (kind === 'alert') {
        ctx.moveTo(cx, cy - 13);
        ctx.lineTo(cx, cy + 4);
        ctx.stroke();
        ctx.beginPath();
        ctx.arc(cx, cy + 12, 2.5, 0, Math.PI * 2);
        ctx.fill();
      } else if (kind === 'clock') {
        ctx.moveTo(cx, cy - 14);
        ctx.lineTo(cx, cy);
        ctx.lineTo(cx + 10, cy + 6);
        ctx.stroke();
      } else if (kind === 'pause') {
        ctx.moveTo(cx - 7, cy - 11);
        ctx.lineTo(cx - 7, cy + 11);
        ctx.moveTo(cx + 7, cy - 11);
        ctx.lineTo(cx + 7, cy + 11);
        ctx.stroke();
      }
    };

    const drawQr = (qr) => {
      const [bx, by, bw, bh] = LAYOUT.IDLE.QR;
      ctx.fillStyle = C.white;
      ctx.fillRect(bx, by, bw, bh);
      if (state.qrCache.payload !== qr.payload) {
        state.qrCache = { payload: qr.payload, matrix: QR.encode(qr.payload) };
      }
      const { size, modules } = state.qrCache.matrix;
      const m = Math.floor(bw / (size + LAYOUT.IDLE.QUIET_ZONE * 2));
      const ox = bx + Math.floor((bw - size * m) / 2);
      const oy = by + Math.floor((bh - size * m) / 2);
      const r = state.ratio;
      ctx.save();
      ctx.setTransform(1, 0, 0, 1, 0, 0);
      ctx.fillStyle = C.black;
      for (let row = 0; row < size; row++) {
        const y0 = Math.round((oy + row * m) * r);
        const y1 = Math.round((oy + (row + 1) * m) * r);
        for (let col = 0; col < size; col++) {
          if (!modules[row][col]) continue;
          const x0 = Math.round((ox + col * m) * r);
          const x1 = Math.round((ox + (col + 1) * m) * r);
          ctx.fillRect(x0, y0, x1 - x0, y1 - y0);
        }
      }
      ctx.restore();
    };

    const drawBar = ([x, y, w, h], ratio, color) => {
      ctx.fillStyle = C.track;
      ctx.fillRect(x, y, w, h);
      ctx.fillStyle = color;
      ctx.fillRect(x, y, Math.max(0, Math.min(1, ratio)) * w, h);
    };

    const ratioOf = (countdown) => (countdown && countdown.totalMs > 0 ? countdown.remainingMs / countdown.totalMs : 0);

    const drawPairing = (view, t) => {
      const P = LAYOUT.PAIRING;
      const W = LAYOUT.WIDTH;
      text(view.lines[0], W / 2, P.TITLE_Y, { size: 16, bold: true, color: C.muted });
      if (!view.pairing.code) {
        if (!view.pairing.error) spinner(W / 2, P.CODE_Y, 20, t);
        paragraph(view.lines[1] || '', P.STATUS_Y, { size: 14, color: view.pairing.error ? C.warn : C.text, maxLines: 2 });
        return;
      }
      text(view.pairing.code, W / 2, P.CODE_Y, { size: 36, bold: true, baseline: 'middle', family: CODE_FONT });
      paragraph(view.lines[2], P.PROMPT_Y, { size: 14, maxLines: 1 });
      text(view.lines[3], W / 2, P.REMAINING_Y, { size: 12, color: C.muted });
      drawBar(P.BAR, ratioOf(view.pairing), C.accent);
    };

    const drawMatch = (view) => {
      const M = LAYOUT.MATCH;
      const W = LAYOUT.WIDTH;
      text(view.lines[0], W / 2, M.TITLE_Y, { size: 16, bold: true });
      if (view.code) text(view.code, W / 2, M.CODE_Y, { size: 72, bold: true, baseline: 'middle', family: CODE_FONT });
      if (view.countdown) {
        text(format('REMAINING_SECONDS', { seconds: Math.ceil(view.countdown.remainingMs / 1000) }), W / 2, M.REMAINING_Y, { size: 14, color: C.muted });
        drawBar(M.BAR, ratioOf(view.countdown), C.accent);
      }
    };

    const drawCountdownRing = (countdown) => {
      const [, y, w, h] = LAYOUT.OPEN.COUNTDOWN;
      const cx = w / 2;
      const cy = y + h / 2;
      const r = 34;
      const ratio = ratioOf(countdown);
      ctx.lineWidth = 4;
      ctx.lineCap = 'round';
      ctx.strokeStyle = C.track;
      ctx.beginPath();
      ctx.arc(cx, cy, r, 0, Math.PI * 2);
      ctx.stroke();
      if (ratio > 0) {
        ctx.strokeStyle = ratio < 0.2 ? C.warn : C.accent;
        ctx.beginPath();
        ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * ratio);
        ctx.stroke();
      }
      text(String(Math.ceil(countdown.remainingMs / 1000)), cx, cy + 2, { size: 40, bold: true, baseline: 'middle' });
    };

    const drawOpen = (view) => {
      const O = LAYOUT.OPEN;
      let labelSize = 40;
      ctx.font = font(labelSize, true);
      while (labelSize > 20 && ctx.measureText(view.lines[0]).width > 224) {
        labelSize -= 2;
        ctx.font = font(labelSize, true);
      }
      text(view.lines[0], LAYOUT.WIDTH / 2, O.LABEL_Y + (40 - labelSize) / 2, { size: labelSize, bold: true });
      const [, my, mw] = O.MESSAGE;
      if (view.notice) paragraph(view.notice, my + 10, { size: 16, bold: true, color: C.warn, maxLines: 2, width: mw });
      else paragraph(view.lines[1], my, { size: 14, maxLines: 3, width: mw });
      if (view.countdown) drawCountdownRing(view.countdown);
    };

    const draw = (t) => {
      const view = state.view;
      const W = LAYOUT.WIDTH;
      ctx.setTransform(state.ratio, 0, 0, state.ratio, 0, 0);
      ctx.fillStyle = C.bg;
      ctx.fillRect(0, 0, W, LAYOUT.HEIGHT);

      ctx.fillStyle = C.header;
      ctx.fillRect(0, 0, W, LAYOUT.HEADER_HEIGHT);
      text(view.header, 10, LAYOUT.HEADER_HEIGHT / 2 + 1, { size: 14, bold: true, align: 'left', baseline: 'middle' });
      ctx.fillStyle = view.connection === 'online' ? C.online : C.offline;
      ctx.beginPath();
      ctx.arc(W - 14, LAYOUT.HEADER_HEIGHT / 2, 4, 0, Math.PI * 2);
      ctx.fill();

      switch (view.screen) {
        case 'pairing':
          drawPairing(view, t);
          break;
        case 'idle':
          if (view.qr) {
            drawQr(view.qr);
            drawBar(LAYOUT.IDLE.BAR, view.qr.refreshRatio, C.accent);
          } else {
            spinner(W / 2, LAYOUT.IDLE.QR[1] + LAYOUT.IDLE.QR[3] / 2, 20, t);
          }
          paragraph(view.lines[0], LAYOUT.IDLE.TEXT_Y, { size: 14, maxLines: 2 });
          break;
        case 'closed_hours':
          icon(view.icon, W / 2, LAYOUT.CLOSED.ICON_Y);
          paragraph(view.lines[0] || '', LAYOUT.CLOSED.TITLE_Y, { size: 20, bold: true, maxLines: 1 });
          paragraph(view.lines[1] || '', LAYOUT.CLOSED.HOURS_Y, { size: 14, color: C.muted, maxLines: 2 });
          break;
        case 'maintenance':
        case 'disabled':
          icon(view.icon, W / 2, LAYOUT.NOTICE.ICON_Y);
          paragraph(view.lines.join(''), LAYOUT.NOTICE.TEXT_Y, { size: 16, bold: true, maxLines: 3 });
          break;
        case 'select':
          text(view.lines[0] || '', W / 2, LAYOUT.SELECT.TITLE_Y, { size: 20, bold: true });
          text(view.lines[1] || '', W / 2, LAYOUT.SELECT.TEXT_Y, { size: 14, color: C.muted });
          if (view.lines[2]) text(view.lines[2], W / 2, LAYOUT.SELECT.REMAINING_Y, { size: 12, color: C.muted });
          break;
        case 'match':
          drawMatch(view);
          break;
        case 'opening':
          spinner(W / 2, 130, 24, t);
          text(view.lines[0], W / 2, 180, { size: 16, bold: true });
          break;
        case 'open':
        case 'admin':
          drawOpen(view);
          break;
        case 'result':
          icon(view.icon, W / 2, LAYOUT.RESULT.ICON_Y);
          paragraph(view.lines.join(''), LAYOUT.RESULT.TEXT_Y, { size: 16, bold: true, maxLines: 3 });
          break;
        default: {
          const busy = ANIMATED.has(view.screen);
          if (busy) spinner(W / 2, 130, 24, t);
          paragraph(view.lines.join(''), busy ? 180 : 150, { size: 16, bold: true, maxLines: 3 });
        }
      }

      state.dirty = false;
    };

    const spinning = (view) => ANIMATED.has(view.screen) || (view.screen === 'idle' && !view.qr)
      || (view.screen === 'pairing' && !view.pairing.code && !view.pairing.error);

    const frame = (t) => {
      if (state.dirty || spinning(state.view)) draw(t);
      window.requestAnimationFrame(frame);
    };

    if (window.ResizeObserver) new window.ResizeObserver(resize).observe(canvas);
    window.addEventListener('resize', resize);

    return {
      canvas,
      start() {
        resize();
        window.requestAnimationFrame(frame);
      },
      update(view) {
        state.view = view;
        state.dirty = true;
        const label = view.lines.filter(Boolean).join('，');
        canvas.setAttribute('aria-label', `書櫃螢幕：${label || view.screen}`);
      }
    };
  };

  const createPanel = (core, options) => {
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

    const doorsCard = card('櫃門');
    const doorsGrid = el('div', 'doors');
    doorsCard.appendChild(doorsGrid);
    const tiles = new Map();
    for (const door of core.view.doors) {
      const tile = el('div', 'door-tile');
      const frame = el('div', 'door-frame');
      frame.appendChild(el('div', 'door-leaf'));
      tile.appendChild(frame);
      tile.appendChild(el('div', 'door-label', door.label));
      const stateText = el('div', 'door-state', '上鎖');
      const note = el('div', 'door-note');
      tile.appendChild(stateText);
      tile.appendChild(note);
      const actions = el('div', 'door-actions');
      const openBtn = button('開門');
      const closeBtn = button('關門');
      openBtn.addEventListener('click', () => core.setDoorPhysical(door.channel, 'open'));
      closeBtn.addEventListener('click', () => core.setDoorPhysical(door.channel, 'closed'));
      actions.appendChild(openBtn);
      actions.appendChild(closeBtn);
      tile.appendChild(actions);
      doorsGrid.appendChild(tile);
      tiles.set(door.channel, { tile, stateText, note, actions, openBtn, closeBtn });
    }

    const settings = card('設定');
    const autoClose = switchControl(options.autoClose);
    row(settings, '倒數結束自動關門', '關閉後可測試伺服器的待確認流程').appendChild(autoClose.wrap);
    const sensor = switchControl(options.sensor);
    row(settings, '模擬門磁感測器', '切換後送出開機事件，並於櫃門圖塊提供開門與關門操作').appendChild(sensor.wrap);
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

    const doorState = (door) => {
      if (door.fault) return ['故障', 'is-fault'];
      if (door.unlocking) return ['開鎖中', 'is-unlocking'];
      if (door.open) return ['開啟', 'is-open'];
      return ['上鎖', null];
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

      const sensorOn = sensor.input.checked;
      for (const door of view.doors) {
        const t = tiles.get(door.channel);
        const [label, cls] = doorState(door);
        t.tile.classList.toggle('is-fault', cls === 'is-fault');
        t.tile.classList.toggle('is-unlocking', cls === 'is-unlocking');
        t.tile.classList.toggle('is-open', door.open);
        t.stateText.textContent = label;
        t.note.textContent = paired && !door.enabled ? '暫停分配' : '';
        t.actions.hidden = !sensorOn;
        t.openBtn.disabled = door.open;
        t.closeBtn.disabled = !door.open;
      }

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

  const startKiosk = () => {
    const options = loadOptions();
    let screen = null;
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
        if (panel) panel.refresh(view);
      },
      onLog(entry) {
        if (panel) panel.addLog(entry);
        else pendingLogs.push(entry);
      }
    });

    root.textContent = '';
    const device = el('div', 'device');
    const bezel = el('div', 'bezel');
    screen = createScreen(core);
    bezel.appendChild(screen.canvas);
    device.appendChild(bezel);
    device.appendChild(el('p', 'device-caption', '240 × 320 顯示螢幕（無觸控）'));
    panel = createPanel(core, options);
    root.appendChild(device);
    root.appendChild(panel.node);
    pendingLogs.forEach((entry) => panel.addLog(entry));

    screen.update(core.view);
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
