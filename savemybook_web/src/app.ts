import Lenis from 'lenis';
import * as THREE from 'three';
import { CabinetView, webglOK } from './three/view';
import { Cabinet } from './three/cabinet';
import { Kiosk, type KioskParams, type KioskState } from './three/textures';
import { Lift, type Dir } from './ui/lift';
import { wrapPhones } from './ui/phone';
import { BOARD } from './data/pcb';
import type { PopKey } from './data/pops';
import { $, $$, clamp, easeInOut, easeOut, lerp, mobile, seg } from './lib/util';

type Pt = { x: number; y: number };

function homography(w: number, h: number, q: Pt[]) {
  const src = [[0, 0], [w, 0], [w, h], [0, h]];
  const A: number[][] = [], b: number[] = [];
  for (let i = 0; i < 4; i++) {
    const [x, y] = src[i], { x: u, y: v } = q[i];
    A.push([x, y, 1, 0, 0, 0, -u * x, -u * y]); b.push(u);
    A.push([0, 0, 0, x, y, 1, -v * x, -v * y]); b.push(v);
  }
  for (let i = 0; i < 8; i++) {
    let p = i;
    for (let r = i + 1; r < 8; r++) if (Math.abs(A[r][i]) > Math.abs(A[p][i])) p = r;
    [A[i], A[p]] = [A[p], A[i]];
    [b[i], b[p]] = [b[p], b[i]];
    for (let r = i + 1; r < 8; r++) {
      const f = A[r][i] / A[i][i];
      for (let c = i; c < 8; c++) A[r][c] -= f * A[i][c];
      b[r] -= f * b[i];
    }
  }
  const x = new Array(8).fill(0);
  for (let i = 7; i >= 0; i--) {
    let s = b[i];
    for (let c = i + 1; c < 8; c++) s -= A[i][c] * x[c];
    x[i] = s / A[i][i];
  }
  const m = [x[0], x[3], 0, x[6], x[1], x[4], 0, x[7], 0, 0, 1, 0, x[2], x[5], 0, 1];
  return `matrix3d(${m.map((v) => +v.toFixed(8)).join(',')})`;
}

function warmKiosk(k: Kiosk) {
  const base = { refresh: 0, seconds: 30, digits: 1, check: 1, digitsText: '25' };
  for (const state of ['match', 'opening', 'open', 'done', 'qr'] as KioskState[]) k.draw({ state, ...base });
}

export function boot() {
  const root = document.documentElement;
  const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const motion = !reduce && webglOK();
  if (!motion) root.classList.add('still');
  wrapPhones();

  const lenis = reduce ? null : new Lenis({ lerp: 0.1, wheelMultiplier: 0.9, autoRaf: false });
  const header = $('.site-header');
  const scrollTo = (y: number, immediate = false) => {
    y = Math.max(0, y);
    if (lenis) lenis.scrollTo(y, immediate ? { immediate: true, force: true } : { duration: 1.2 });
    else window.scrollTo({ top: y, behavior: immediate || reduce ? 'auto' : 'smooth' });
  };
  const absTop = (el: Element) => el.getBoundingClientRect().top + scrollY;

  const qItems = $$('.q-item');
  let qIndex = 0;
  if (!reduce) {
    setInterval(() => {
      if (document.hidden) return;
      const prev = qItems[qIndex];
      prev.classList.remove('is-on');
      prev.classList.add('is-off');
      setTimeout(() => prev.classList.remove('is-off'), 750);
      qIndex = (qIndex + 1) % qItems.length;
      qItems[qIndex].classList.add('is-on');
    }, 2600);
  }

  const film = $<HTMLDialogElement>('#film'), video = $<HTMLVideoElement>('video', film);
  $$('[data-film]').forEach((a) => a.addEventListener('click', (e) => {
    e.preventDefault();
    film.showModal();
    lenis?.stop();
    video.play().catch(() => {});
  }));
  const closeFilm = () => { video.pause(); film.close(); };
  $('.film__close', film).addEventListener('click', closeFilm);
  film.addEventListener('click', (e) => { if (e.target === film) closeFilm(); });
  film.addEventListener('close', () => { video.pause(); lenis?.start(); });

  document.addEventListener('click', (e) => {
    const a = (e.target as HTMLElement).closest<HTMLAnchorElement>('a[href^="#"]');
    if (!a || a.hasAttribute('data-film')) return;
    const t = document.getElementById(a.getAttribute('href')!.slice(1));
    if (!t) return;
    e.preventDefault();
    scrollTo(t.id === 'top' ? 0 : absTop(t) - 44);
  });

  let rvs = $$('.rv');
  if (reduce) { rvs.forEach((el) => el.classList.add('in')); rvs = []; }
  const reveal = () => {
    const lim = innerHeight * 0.92;
    for (let i = rvs.length - 1; i >= 0; i--) if (rvs[i].getBoundingClientRect().top < lim) { rvs[i].classList.add('in'); rvs.splice(i, 1); }
  };

  /* 3D 書櫃 */
  const heroHost = $('[data-gl="hero"]'), cabHost = $('[data-gl="cab"]');
  const heroView = motion ? new CabinetView(heroHost, { dprMax: 1.75, fov: 20 }) : null;
  const cabView = motion ? new CabinetView(cabHost, { dprMax: 2, fov: 20 }) : null;
  const views = [heroView, cabView].filter((v): v is CabinetView => !!v);
  const W = Cabinet.WIDTH, H = Cabinet.HEIGHT, DP = Cabinet.DEPTH;
  const closed = CabinetView.box(-W / 2, W / 2, -H / 2, H / 2, -DP / 2, DP / 2 + 0.5);
  const doorBox = (() => {
    if (!cabView) return [] as THREE.Vector3[];
    const cab = cabView.cabinet;
    cab.setDoor(0, 1);
    cab.group.updateMatrixWorld(true);
    const b = new THREE.Box3().setFromObject(cab.doors[0].pivot);
    cab.setDoor(0, 0);
    const inv = new THREE.Matrix4().copy(cab.group.matrixWorld).invert();
    return CabinetView.box(b.min.x, b.max.x, b.min.y, b.max.y, b.min.z, b.max.z).map((p) => p.applyMatrix4(inv));
  })();
  const kiosk = cabView ? cabView.cabinet.kiosk : new Kiosk();
  const heroBase = { cy: 0.5 };

  /* 首頁 */
  const stage = $('.hero-stage');
  const buyer = $('[data-phone="buyer"]');
  const heroOpts = {
    S: 1,
    host: stage,
    bounds: () => { const r = stage.getBoundingClientRect(); return new DOMRect(Math.max(r.left, 0) + 14, r.top + 8, Math.min(r.width, innerWidth) - 28, r.height - 16); },
    place: (slot: DOMRect, w: number, h: number) => {
      const pr = buyer.getBoundingClientRect();
      return mobile() ? { x: slot.left - (w - slot.width) - pr.width * 0.12, y: slot.top - (h - slot.height) / 2 - pr.width * 0.18 } : { x: slot.left + pr.width * 0.22, y: slot.top - (h - slot.height) / 2 - pr.width * 0.12 };
    },
  };
  const heroLift = new Lift(buyer, 'notice', heroOpts);
  let heroT0 = 0;
  setTimeout(() => { heroT0 = performance.now(); }, reduce ? 0 : 1500);

  function layoutHero() {
    const top = stage.getBoundingClientRect().top + scrollY;
    stage.style.height = `${clamp(innerHeight - top - 12, mobile() ? 300 : 330, 720)}px`;
    const sr = stage.getBoundingClientRect();
    let box: { x0: number; x1: number; y0: number; y1: number };
    if (heroView) {
      const m = mobile();
      const w = heroHost.clientWidth, h = heroHost.clientHeight;
      heroView.yaw = -0.32;
      heroView.pitch = 0.1;
      heroView.resize();
      heroView.fit(closed, m ? { l: w * 0.12, r: w * 0.22, t: 8, b: Math.max(h * 0.08, 56) } : { l: w * 0.3, r: w * 0.3, t: h * 0.02, b: h * 0.06 + 34 }, 0.92);
      heroBase.cy = heroView.cy;
      box = heroView.bounds(closed);
    } else {
      const ir = $('.gl__still', heroHost).getBoundingClientRect();
      box = { x0: ir.left - sr.left, x1: ir.right - sr.left, y0: ir.top - sr.top, y1: ir.bottom - sr.top };
    }
    stage.style.setProperty('--cab-l', `${box.x0}px`);
    stage.style.setProperty('--cab-r', `${box.x1}px`);
    stage.style.setProperty('--cab-b', `${box.y1}px`);
    stage.style.setProperty('--cab-h', `${box.y1 - box.y0}px`);
    heroOpts.S = 1.3;
    heroLift.layout();
  }

  /* 各區浮出的元素 */
  const vps = $$('[data-vp]').map((el) => ({ el, e: -1 }));
  const lifts = new Map<HTMLElement, Lift>();
  for (const ph of $$('[data-lift]')) {
    const vp = ph.closest<HTMLElement>('[data-vp]')!;
    const dir = (ph.dataset.dir || 'right') as Dir;
    lifts.set(vp, new Lift(ph, ph.dataset.lift as PopKey, {
      S: dir === 'up' ? 1.08 : 1.16,
      dir,
      rot: dir === 'left' ? -1.2 : dir === 'right' ? 1.2 : 0,
      bounds: () => {
        const r = vp.getBoundingClientRect(), vw = document.documentElement.clientWidth;
        if (mobile()) return new DOMRect(14, r.top, vw - 28, r.height);
        if (dir === 'up') return new DOMRect(16, r.top + 4, vw - 32, r.height);
        if (dir === 'left') return new DOMRect(16, r.top - 40, r.right - 16, r.height + 80);
        return new DOMRect(r.left, r.top - 40, vw - 16 - r.left, r.height + 80);
      },
    }));
  }
  const pcb = $('.pcb');
  const boardImg = $('.pcb__board');
  boardImg.style.setProperty('--bx', `${BOARD.x}%`);
  boardImg.style.setProperty('--by', `${BOARD.y}%`);
  boardImg.style.setProperty('--bw', `${BOARD.w}%`);
  boardImg.style.setProperty('--bh', `${BOARD.h}%`);

  /* 智慧書櫃：固定捲動四步 */
  const pin = $('[data-pin="cab"]');
  const visual = $('.cab-visual');
  const tabs = $$<HTMLButtonElement>('.tabs button');
  const stepEls = $$('.step');
  const shots = Object.fromEntries($$<HTMLImageElement>('[data-phone="cab"] img').map((i) => [i.dataset.s!, i]));
  const camCanvas = $<HTMLCanvasElement>('.cam-screen canvas');
  const kSlot = $('.k-slot'), kLift = $('.k-lift'), kCanvas = $<HTMLCanvasElement>('.k-lift__canvas');
  const flyEls = $$('.fly span');
  const sellerPhone = $('[data-phone="cab"]');
  const cabLift = new Lift($('[data-phone="cab-buyer"]'), 'notice', { S: 1.12, dir: 'right', bounds: () => visual.getBoundingClientRect() });
  const BOXES: Pt[] = [{ x: 162.5, y: 397 }, { x: 230.5, y: 397 }];
  const geo = { win: [] as Pt[], end: { x: 0, y: 0, w: 0, h: 0 }, ready: false };
  const camA = { cx: 0.5, cy: 0.5, fill: 0.6, dy: 0 }, camB = { ...camA };
  const camPhones = $$('.cab-phone');
  const mech = { door: -1, dep: -1 };
  let step = -1, lastKiosk = -1, camMix = -1;

  const mirror = (c: HTMLCanvasElement) => {
    const g = c.getContext('2d')!;
    g.clearRect(0, 0, c.width, c.height);
    g.drawImage(kiosk.canvas, 0, 0, c.width, c.height);
  };

  function layoutCab() {
    if (!cabView) return;
    const m = mobile();
    for (const el of camPhones) el.style.translate = '';
    const vr = visual.getBoundingClientRect();
    const phone = $('.cab-phone--seller .phone').getBoundingClientRect();
    const pts = [...closed, ...doorBox];
    const bleed = Math.max(0, document.documentElement.clientWidth - vr.right);
    visual.style.setProperty('--bleed', `${bleed}px`);
    cabView.yaw = -0.3;
    cabView.pitch = 0.1;
    cabView.resize();
    const save = (cam: typeof camA, dy = 0) => Object.assign(cam, { cx: cabView.cx, cy: cabView.cy, fill: cabView.fill, dy });
    if (m) {
      const V = vr.height, ph = phone.height, below = ph * 0.58;
      const liftW = Math.min(214, vr.width * 0.6, (V * 0.3) / 0.75), liftH = liftW * 0.75;
      const mg = { l: 8, r: 8 + bleed, b: below };
      const dyFor = () => cabView.bounds(closed).y1 - ph * 0.42 - (V - ph);
      cabView.fit(pts, { ...mg, t: 12 }, 0.92, 'top');
      const b0 = cabView.bounds(closed);
      cabView.fit(pts, { ...mg, t: Math.max(12, (V - (b0.y1 - b0.y0) - below) / 2) }, 0.92, 'top');
      save(camB, dyFor());
      cabView.fit(pts, { ...mg, t: liftH + 22 }, 0.92, 'top');
      save(camA, dyFor());
      const box = cabView.bounds(closed), c = cabView.screenCorners();
      if (!c) return;
      const cx = (c[0].x + c[1].x + c[2].x + c[3].x) / 4;
      geo.win = c;
      geo.end = { x: clamp(cx - liftW * 0.3, 8, vr.width - liftW - 8), y: Math.max(4, box.y0 - 14 - liftH), w: liftW, h: liftH };
    } else {
      cabView.fit(pts, { l: phone.right - vr.left - phone.width * 0.1, r: 6 + bleed, t: 36, b: 24 }, 0.95);
      save(camA);
      save(camB);
      const c = cabView.screenCorners();
      if (!c) return;
      geo.win = c;
      const room = phone.top - vr.top - 30;
      const liftW = Math.min(phone.width * 1.06, room / 0.75), liftH = liftW * 0.75;
      geo.end = { x: Math.max(0, phone.left - vr.left + (phone.width - liftW) / 2), y: phone.top - vr.top - 22 - liftH, w: liftW, h: liftH };
    }
    camMix = -1;
    geo.ready = true;
  }

  function setCam(k: number) {
    if (!cabView || k === camMix) return;
    camMix = k;
    cabView.cx = lerp(camB.cx, camA.cx, k);
    cabView.cy = lerp(camB.cy, camA.cy, k);
    cabView.fill = lerp(camB.fill, camA.fill, k);
    cabView.pose();
    const dy = lerp(camB.dy, camA.dy, k);
    for (const el of camPhones) el.style.translate = dy ? `0 ${dy.toFixed(1)}px` : '';
    const c = cabView.screenCorners();
    if (c) geo.win = c;
  }

  function quad(e: number): Pt[] {
    const k = easeInOut(e), r = geo.end;
    const end = [{ x: r.x, y: r.y }, { x: r.x + r.w, y: r.y }, { x: r.x + r.w, y: r.y + r.h }, { x: r.x, y: r.y + r.h }];
    return geo.win.map((p, i) => ({ x: lerp(p.x, end[i].x, k), y: lerp(p.y, end[i].y, k) }));
  }

  function kioskFor(p: number, now: number): KioskParams {
    const base = { refresh: (now % 30000) / 30000, seconds: 52, digits: 1, check: 1, digitsText: '25' };
    let state: KioskState = 'qr';
    if (p >= 0.25 && p < 0.5) { state = 'match'; base.digits = 1 - clamp(seg(p, 0.32, 0.42) * 4); }
    else if (p >= 0.5 && p < 0.535) state = 'opening';
    else if (p >= 0.535 && p < 0.81) { state = 'open'; base.seconds = 29; }
    else if (p >= 0.81) { state = 'done'; base.check = seg(p, 0.81, 0.86); }
    return { state, ...base };
  }

  function cabFrame(p: number, now: number) {
    const s = Math.min(3, Math.floor(p * 4));
    if (s !== step) {
      step = s;
      tabs.forEach((t, i) => t.setAttribute('aria-selected', String(i === s)));
      stepEls.forEach((c, i) => c.classList.toggle('on', i === s));
    }
    const fly = seg(p, 0.32, 0.42);
    const shot = p < 0.25 ? 'scan' : p < 0.5 ? (fly >= 1 ? 'match' : 'match0') : p < 0.81 ? 'open' : 'done';
    for (const [k, img] of Object.entries(shots)) img.classList.toggle('on', k === shot);
    visual.classList.toggle('scan', p < 0.25);
    visual.classList.toggle('done', p >= 0.82);
    cabLift.set(easeOut(seg(p, 0.86, 0.95)));

    kiosk.draw(kioskFor(p, now));
    const ver = kiosk.texture.version;
    if (ver !== lastKiosk) { lastKiosk = ver; mirror(kCanvas); if (p < 0.25) mirror(camCanvas); }
    if (cabView) {
      const door = p < 0.75 ? easeOut(seg(p, 0.535, 0.62)) : 1 - easeInOut(seg(p, 0.75, 0.81));
      const dep = easeInOut(seg(p, 0.63, 0.73));
      if (door !== mech.door || dep !== mech.dep) {
        mech.door = door;
        mech.dep = dep;
        cabView.cabinet.setDoor(0, door);
        cabView.cabinet.setDeposit(dep);
        cabView.dirty = true;
      }
    }

    const e = p < 0.5 ? seg(p, 0.02, 0.12) : 1 - seg(p, 0.5, 0.56);
    setCam(easeInOut(p < 0.5 ? seg(p, 0, 0.1) : 1 - seg(p, 0.52, 0.6)));
    if (geo.ready && e > 0.001) {
      const w = 320, h = 240;
      kLift.style.width = `${w}px`;
      kLift.style.height = `${h}px`;
      kLift.style.transform = homography(w, h, quad(e));
      kLift.style.setProperty('--e', e.toFixed(3));
      kLift.style.visibility = 'visible';
      kSlot.style.width = `${w}px`;
      kSlot.style.height = `${h}px`;
      kSlot.style.transform = homography(w, h, geo.win);
      kSlot.style.visibility = 'visible';
      kSlot.style.opacity = String(Math.min(1, e * 40));
    } else {
      kLift.style.visibility = 'hidden';
      kSlot.style.visibility = 'hidden';
    }

    if (geo.ready && fly > 0 && fly < 1 && p < 0.5) {
      const r = geo.end;
      const screen = $('.phone__screen', sellerPhone).getBoundingClientRect(), vr = visual.getBoundingClientRect();
      const k = screen.width / 393;
      flyEls.forEach((el, i) => {
        const t = easeInOut(clamp((fly - i * 0.12) / 0.88));
        const a = { x: r.x + r.w * (kiosk.digitsAt.x + (i ? 1 : -1) * Kiosk.DIGIT_GAP), y: r.y + r.h * kiosk.digitsAt.y };
        const bpt = { x: screen.left - vr.left + BOXES[i].x * k, y: screen.top - vr.top + BOXES[i].y * k };
        const c = { x: lerp(a.x, bpt.x, 0.2), y: lerp(a.y, bpt.y, 0.55) };
        const x = (1 - t) * (1 - t) * a.x + 2 * (1 - t) * t * c.x + t * t * bpt.x;
        const y = (1 - t) * (1 - t) * a.y + 2 * (1 - t) * t * c.y + t * t * bpt.y;
        const fs = lerp(r.h * Kiosk.DIGIT_EM, 28 * k, t);
        const dk = clamp(t * 3);
        el.style.visibility = t > 0 && t < 1 ? 'visible' : 'hidden';
        el.style.fontSize = `${fs.toFixed(2)}px`;
        el.style.color = `rgb(${Math.round(lerp(255, 29, dk))},${Math.round(lerp(255, 29, dk))},${Math.round(lerp(255, 31, dk))})`;
        el.style.transform = `translate(${(x - fs * 0.29).toFixed(1)}px, ${(y - fs * 0.5).toFixed(1)}px)`;
      });
    } else flyEls.forEach((el) => { el.style.visibility = 'hidden'; });
  }

  tabs.forEach((t, i) => t.addEventListener('click', () => {
    scrollTo(absTop(pin) + (pin.offsetHeight - innerHeight) * ((i + 0.6) / 4));
  }));

  /* 服務費試算 */
  const fee = $<HTMLInputElement>('#fee-price');
  const feeOut = { p: $('[data-fee-p]'), a: $('[data-fee-a]'), b: $('[data-fee-b]') };
  const paintFee = () => {
    const price = Number(fee.value);
    feeOut.p.textContent = String(price);
    feeOut.a.textContent = String(Math.floor(price * 0.9));
    feeOut.b.textContent = String(Math.floor(price * 0.65));
    fee.style.setProperty('--pct', `${((price - 50) / 950) * 100}%`);
  };
  fee.addEventListener('input', paintFee);
  paintFee();

  function layout() {
    layoutHero();
    layoutCab();
    for (const l of lifts.values()) l.layout();
    cabLift.layout();
  }

  /* 主迴圈 */
  function frame(now: number) {
    lenis?.raf(now);
    header.classList.toggle('stuck', scrollY > 8);
    reveal();
    const vh = innerHeight;
    for (const v of vps) {
      const b = v.el.getBoundingClientRect();
      if (b.bottom < -200 || b.top > vh + 200) continue;
      const vis = clamp((vh - b.top) / (vh + b.height));
      let e = reduce ? 1 : easeOut(clamp((vis - 0.16) / 0.3));
      e = e > 0.995 ? 1 : e < 0.005 ? 0 : e;
      if (e === v.e) continue;
      v.e = e;
      v.el.style.setProperty('--e', String(+e.toFixed(4)));
      lifts.get(v.el)?.set(e);
      if (v.el.contains(pcb)) pcb.classList.toggle('lifting', e > 0);
    }
    const r = pin.getBoundingClientRect();
    if (r.top < vh * 1.2 && r.bottom > -vh * 0.2) cabFrame(clamp(-r.top / Math.max(1, r.height - vh)), now);
    if (heroView?.visible) {
      const t = now / 1000;
      heroView.yaw = -0.32 + Math.sin(t * 0.35) * 0.06;
      heroView.cy = heroBase.cy + Math.sin(t * 0.5) * 0.005;
      heroView.pose();
      heroView.cabinet.kiosk.draw({ state: 'qr', refresh: (now % 30000) / 30000, seconds: 60, digits: 1, check: 1 });
    }
    if (heroT0) heroLift.set(easeOut(clamp((now - heroT0) / 1100)));
    for (const v of views) v.render();
    requestAnimationFrame(frame);
  }

  let rz = 0;
  const queue = () => { cancelAnimationFrame(rz); rz = requestAnimationFrame(layout); };
  addEventListener('resize', queue);
  new ResizeObserver(queue).observe(document.body);
  Promise.all([...views.map((v) => v.cabinet.ready), document.fonts.ready]).then(() => {
    warmKiosk(kiosk);
    if (heroView) warmKiosk(heroView.cabinet.kiosk);
    layout();
    for (const v of views) { v.renderer.compile(v.scene, v.camera); v.renderer.render(v.scene, v.camera); v.dirty = true; }
  });
  for (const img of $$<HTMLImageElement>('.hero img, .cab img')) img.decode().catch(() => {});
  const pre = new IntersectionObserver((entries) => {
    for (const en of entries) {
      if (!en.isIntersecting) continue;
      const img = en.target as HTMLImageElement;
      pre.unobserve(img);
      img.loading = 'eager';
      img.decode().catch(() => {});
    }
  }, { rootMargin: '1600px 0px' });
  $$<HTMLImageElement>('img[loading="lazy"]').forEach((img) => pre.observe(img));
  layout();
  requestAnimationFrame(frame);

  const go = (id: string, k = 0) => {
    const el = id === 'cab-pin' ? pin : document.getElementById(id);
    if (!el) return;
    scrollTo(absTop(el) + k * Math.max(0, el.offsetHeight - innerHeight), true);
  };
  Object.assign(window, { __go: go, __site: { lenis, layout, heroStart: () => heroT0, views: { hero: heroView, cab: cabView } } });
}
