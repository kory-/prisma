// Chrome resolves regional variants and falls back to default_locale (English).
export function t(key, substitutions) {
  return globalThis.chrome?.i18n?.getMessage(key, substitutions) || key;
}
export function localizeDocument(doc) {
  const locale = globalThis.chrome?.i18n?.getUILanguage() || 'en';
  doc.documentElement.lang = locale.toLowerCase().replaceAll('_', '-').split('-')[0] === 'ja' ? 'ja' : 'en';
  doc.querySelectorAll('[data-i18n]').forEach(node => { node.textContent = t(node.dataset.i18n); });
  doc.querySelectorAll('[data-i18n-title]').forEach(node => { node.title = t(node.dataset.i18nTitle); });
  doc.querySelectorAll('[data-i18n-aria]').forEach(node => { node.setAttribute('aria-label', t(node.dataset.i18nAria)); });
}
