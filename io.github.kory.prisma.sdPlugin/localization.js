const PrismaI18n = {
  language: 'en', strings: {},
  text(key) { return this.strings[key] || key; },
  async load(info) {
    const identifier = String(info?.application?.language || 'en').toLowerCase().replaceAll('_', '-');
    this.language = identifier.split('-')[0] === 'ja' ? 'ja' : 'en';
    try {
      const response = await fetch(this.language + '.json');
      this.strings = response.ok ? (await response.json()).Localization || {} : {};
    } catch { this.strings = {}; }
    document.documentElement.lang = this.language;
    document.querySelectorAll('[data-i18n]').forEach(node => { node.textContent = this.text(node.dataset.i18n); });
    document.querySelectorAll('[data-i18n-placeholder]').forEach(node => { node.placeholder = this.text(node.dataset.i18nPlaceholder); });
  }
};
