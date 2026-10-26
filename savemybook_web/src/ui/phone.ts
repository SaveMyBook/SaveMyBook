import { $$ } from '../lib/util';

export function wrapPhones(root: ParentNode = document) {
  const status = '<span class="phone__island"></span><div class="phone__status"><time>9:41</time><span>'
    + '<svg viewBox="0 0 18 12"><use href="#sb-signal"/></svg><svg viewBox="0 0 16 12"><use href="#sb-wifi"/></svg>'
    + '<svg class="bat" viewBox="0 0 27 12"><use href="#sb-battery"/></svg></span></div>';
  for (const ph of $$('.phone', root)) {
    if (ph.querySelector('.phone__screen')) continue;
    const bezel = document.createElement('div');
    const screen = document.createElement('div');
    bezel.className = 'phone__bezel';
    screen.className = 'phone__screen';
    while (ph.firstChild) screen.appendChild(ph.firstChild);
    screen.insertAdjacentHTML('beforeend', status);
    bezel.appendChild(screen);
    ph.appendChild(bezel);
  }
}
