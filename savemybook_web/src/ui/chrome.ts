/** 刊頭目錄、右側書口與跳轉。 */
export interface Chapter { el: HTMLElement; id: string; label: string; title: string; page: number }

export function chapters(): Chapter[] {
  return [...document.querySelectorAll<HTMLElement>('main > .ch')].map((el, i) => ({
    el, id: el.id, label: el.dataset.label || '', title: el.dataset.title || '', page: i + 1,
  }));
}

type Jump = (id: string) => void;

export function buildChrome(list: Chapter[], jump: Jump, hold: (on: boolean) => void) {
  const edge = document.querySelector('.fore-edge ol')!;
  const toc = document.querySelector<HTMLElement>('.toc')!;
  const tocList = toc.querySelector('.toc__list')!;
  const button = document.querySelector<HTMLButtonElement>('.toc-button')!;
  const folio = document.querySelector<HTMLElement>('[data-folio]')!;

  for (const c of list) {
    const li = document.createElement('li');
    li.innerHTML = `<a href="#${c.id}" aria-label="${c.label}　${c.title}"><span>${c.label}　${c.title}</span></a>`;
    edge.append(li);
    const row = document.createElement('li');
    row.innerHTML = `<a href="#${c.id}"><span class="no">${c.label}</span><span class="t">${c.title}</span><span class="dots"></span><span class="p">${c.page}</span></a>`;
    tocList.append(row);
  }

  const open = () => {
    toc.hidden = false;
    toc.classList.remove('is-closing');
    button.setAttribute('aria-expanded', 'true');
    document.documentElement.classList.add('toc-open');
    hold(true);
    (toc.querySelector('[aria-current="true"]') as HTMLElement | null ?? toc.querySelector('a'))?.focus();
  };
  const close = (restore = true) => {
    if (toc.hidden) return;
    toc.classList.add('is-closing');
    button.setAttribute('aria-expanded', 'false');
    document.documentElement.classList.remove('toc-open');
    hold(false);
    setTimeout(() => { toc.hidden = true; toc.classList.remove('is-closing'); }, 380);
    if (restore) button.focus();
  };
  button.addEventListener('click', () => (toc.hidden ? open() : close()));
  toc.querySelector('.toc__close')!.addEventListener('click', () => close());
  toc.addEventListener('click', (e) => { if (e.target === toc) close(); });
  addEventListener('keydown', (e) => {
    if (e.key === 'Escape') close();
    if (!toc.hidden && e.key === 'Tab') {
      const items = [...toc.querySelectorAll<HTMLElement>('a, button')];
      const first = items[0], last = items[items.length - 1];
      if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus(); }
      else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus(); }
    }
  });

  document.addEventListener('click', (e) => {
    const a = (e.target as HTMLElement).closest<HTMLAnchorElement>('a[href^="#"]');
    if (!a) return;
    const id = a.getAttribute('href')!.slice(1);
    if (!document.getElementById(id)) return;
    e.preventDefault();
    close(false);
    jump(id);
    history.replaceState(null, '', `#${id}`);
  });

  let current = -1;
  return {
    setCurrent(index: number) {
      if (index === current) return;
      current = index;
      folio.textContent = String(index + 1);
      edge.querySelectorAll('a').forEach((a, i) => {
        a.classList.toggle('is-current', i === index);
        a.classList.toggle('is-read', i < index);
      });
      tocList.querySelectorAll('a').forEach((a, i) => a.setAttribute('aria-current', String(i === index)));
    },
  };
}

/** 標題拆行，供逐行浮現。 */
export function splitLines() {
  document.querySelectorAll<HTMLElement>('.reveal-lines').forEach((el) => {
    const parts = el.innerHTML.split(/<br\s*\/?>/i);
    el.innerHTML = parts.map((p) => `<span class="line"><span>${p.trim()}</span></span>`).join('');
  });
}

/** 數字滾動：進入畫面時由 0 數到目標值。 */
export function countUp(el: HTMLElement, duration = 1400) {
  if (el.dataset.done) return;
  el.dataset.done = '1';
  const to = Number(el.dataset.to);
  const dec = Number(el.dataset.dec || 0);
  const sep = el.dataset.sep === '1';
  const fmt = (v: number) => {
    const s = v.toFixed(dec);
    return sep ? Number(s).toLocaleString('en-US', { minimumFractionDigits: dec, maximumFractionDigits: dec }) : s;
  };
  const t0 = performance.now();
  const tick = (now: number) => {
    const k = Math.min(1, (now - t0) / duration);
    const e = 1 - Math.pow(1 - k, 4);
    el.textContent = fmt(to * e);
    if (k < 1) requestAnimationFrame(tick);
  };
  requestAnimationFrame(tick);
}

/** 進入視窗時加上 is-in。 */
export function revealOnView() {
  const io = new IntersectionObserver((entries) => {
    for (const en of entries) {
      if (!en.isIntersecting) continue;
      const el = en.target as HTMLElement;
      el.classList.add('is-in');
      el.querySelectorAll<HTMLElement>('.count').forEach((c) => countUp(c));
      if (el.classList.contains('count')) countUp(el);
      io.unobserve(el);
    }
  }, { rootMargin: '0px 0px -12% 0px', threshold: 0.2 });
  document.querySelectorAll('.reveal, .reveal-lines, .ledger, .fee, .ch-problem .count').forEach((el) => io.observe(el));
}

/** 磁吸：游標靠近時元素微微跟隨。 */
export function magnetic() {
  if (!matchMedia('(hover: hover)').matches) return;
  document.querySelectorAll<HTMLElement>('.magnetic').forEach((el) => {
    let raf = 0;
    el.addEventListener('pointermove', (e) => {
      const r = el.getBoundingClientRect();
      const x = (e.clientX - r.left - r.width / 2) * 0.18;
      const y = (e.clientY - r.top - r.height / 2) * 0.24;
      cancelAnimationFrame(raf);
      raf = requestAnimationFrame(() => { el.style.transform = `translate(${x}px, ${y}px)`; });
    });
    el.addEventListener('pointerleave', () => {
      el.style.transition = 'transform .5s cubic-bezier(.16,1,.3,1)';
      el.style.transform = '';
      setTimeout(() => { el.style.transition = ''; }, 500);
    });
  });
}

export function filmDialog(hold: (on: boolean) => void) {
  const dialog = document.querySelector<HTMLDialogElement>('.film')!;
  const video = dialog.querySelector('video')!;
  document.querySelector('.film-button')!.addEventListener('click', () => {
    dialog.showModal();
    hold(true);
    video.play().catch(() => {});
  });
  const close = () => { video.pause(); dialog.close(); };
  dialog.querySelector('.film__close')!.addEventListener('click', close);
  dialog.addEventListener('click', (e) => { if (e.target === dialog) close(); });
  dialog.addEventListener('close', () => { video.pause(); hold(false); });
}
