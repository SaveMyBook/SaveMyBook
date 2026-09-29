const DASHES = /[‐-―−﹘﹣－]/g;

const compact = (value) => String(value ?? '').normalize('NFKC').replace(DASHES, '-').replace(/[-\s]/g, '').toUpperCase();

const check10 = (nine) => {
  const r = (11 - ([...nine].reduce((sum, d, i) => sum + Number(d) * (10 - i), 0) % 11)) % 11;
  return r === 10 ? 'X' : String(r);
};

const check13 = (twelve) => String((10 - ([...twelve].reduce((sum, d, i) => sum + Number(d) * (i % 2 ? 3 : 1), 0) % 10)) % 10);

const valid10 = (code) => /^\d{9}[\dX]$/.test(code) && check10(code.slice(0, 9)) === code[9];
const valid13 = (code) => /^\d{13}$/.test(code) && check13(code.slice(0, 12)) === code[12];

const normalize = (value) => {
  const code = compact(value);
  return valid10(code) || valid13(code) ? code : '';
};

const forms = (value) => {
  const code = compact(value);
  if (!/^(\d{9}[\dX]|\d{13})$/.test(code)) return [];
  if (code.length === 10) return [code, `978${code.slice(0, 9)}${check13(`978${code.slice(0, 9)}`)}`];
  if (code.length === 13 && code.startsWith('978')) return [code, `${code.slice(3, 12)}${check10(code.slice(3, 12))}`];
  return [code];
};

const isbn13 = (value) => forms(normalize(value)).find((form) => form.length === 13) ?? '';

const sameBook = (isbn, identifiers) => {
  const wanted = new Set(forms(isbn));
  return wanted.size > 0 && (identifiers ?? []).some((id) => forms(id).some((form) => wanted.has(form)));
};

module.exports = { compact, normalize, forms, isbn13, sameBook };
