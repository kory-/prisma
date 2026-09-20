import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import { t, localizeDocument } from '../ChromeExtension/i18n.mjs';
const root = new URL('../', import.meta.url);
const read = path => fs.readFileSync(new URL(path, root), 'utf8');

class Element {
  constructor(tag = '') { this.tagName = tag; this.value = ''; this.textContent = ''; this.hidden = false; this.dataset = {}; this.children = []; this.attributes = {}; }
  append(...nodes) { this.children.push(...nodes); }
  replaceChildren(...nodes) { this.children = nodes; }
  add(node) { this.children.push(node); }
  setAttribute(key, value) { this.attributes[key] = value; }
}
function documentFor(html) {
  const nodes = [], ids = {};
  for (const match of html.matchAll(/<([\w-]+)([^>]*)>/g)) {
    const node = new Element(match[1]); nodes.push(node);
    for (const attr of match[2].matchAll(/([\w-]+)="([^"]*)"/g)) {
      const [, key, value] = attr;
      if (key === 'id') ids[value] = node;
      else if (key.startsWith('data-')) node.dataset[key.slice(5).replace(/-([a-z])/g, (_, c) => c.toUpperCase())] = value;
      else node[key] = value;
    }
  }
  return { ids, documentElement: nodes[1], body: new Element('body'), getElementById: id => ids[id], createElement: tag => new Element(tag),
    querySelectorAll: selector => nodes.filter(node => Object.hasOwn(node.dataset, selector.slice(6, -1).replace(/-([a-z])/g, (_, c) => c.toUpperCase()))) };
}
for (const [locale, resolved] of [['ja', 'ja'], ['ja-JP', 'ja'], ['en-GB', 'en'], ['fr', 'en']]) {
  const catalog = JSON.parse(read(`ChromeExtension/_locales/${resolved}/messages.json`));
  globalThis.chrome = { i18n: {
    getUILanguage: () => locale,
    getMessage(key, substitutions = []) {
      assert.ok(catalog[key], `Missing Chrome string: ${key}`);
      const args = Array.isArray(substitutions) ? substitutions : [substitutions];
      return catalog[key].message.replace(/\$(\d)/g, (_, n) => args[Number(n) - 1] || '');
    }
  } };
  const document = documentFor(read('ChromeExtension/popup.html'));
  localizeDocument(document); assert.equal(document.documentElement.lang, resolved);
  assert.equal(document.ids.connection.textContent, resolved === 'ja' ? '接続を確認中…' : 'Checking connection…');
  const runtime = { sendMessage: async () => ({ ok: false }) };
  const context = vm.createContext({ document, t, localizeDocument, chrome: { runtime }, setInterval() {}, console });
  vm.runInContext(read('ChromeExtension/popup.js').replace(/^import .*;\n/gm, ''), context);
  const state = { current: { id: 1, name: 'Audio Player', eligible: true }, app: { alive: true, active: true }, tabs: [{ id: 1, name: 'Audio Player', volume: .4, muted: true, error: '' }] };
  vm.runInContext(`render(${JSON.stringify(state)})`, context);
  assert.equal(document.ids.connection.textContent, resolved === 'ja' ? 'Prismaに接続済み' : 'Connected to Prisma');
  const controls = document.ids.tabs.children[0].children[1];
  assert.equal(controls.children[2].textContent, resolved === 'ja' ? '解除' : 'Unmute');
  assert.equal(controls.children[0].attributes['aria-label'], resolved === 'ja' ? 'Audio Playerの音量' : 'Volume for Audio Player');
  assert.equal(document.ids.retry.attributes['aria-label'], catalog.retry_connection.message);

  const inspector = documentFor(read('io.github.kory-.prisma.sdPlugin/inspector.html'));
  const sockets = [];
  const deckContext = vm.createContext({ document: inspector,
    fetch: async name => ({ ok: true, json: async () => JSON.parse(read(`io.github.kory-.prisma.sdPlugin/${name}`)) }),
    Option: function(text, value) { return { text, value }; },
    WebSocket: class { constructor() { this.readyState = 1; this.messages = []; sockets.push(this); } send(message) { this.messages.push(JSON.parse(message)); } }
  });
  vm.runInContext(read('io.github.kory-.prisma.sdPlugin/localization.js'), deckContext);
  vm.runInContext(read('io.github.kory-.prisma.sdPlugin/inspector.js'), deckContext);
  const info = JSON.stringify({ application: { language: locale } });
  const action = JSON.stringify({ action: 'io.github.kory-.prisma.auto', payload: { controller: 'Encoder', settings: { step: 5 } } });
  await vm.runInContext(`connectElgatoStreamDeckSocket(1234, 'test', 'registerPropertyInspector', ${JSON.stringify(info)}, ${JSON.stringify(action)})`, deckContext);
  assert.equal(inspector.documentElement.lang, resolved);
  assert.equal(inspector.ids.mode.value, 'auto'); assert.equal(inspector.ids.mode.disabled, true);
  assert.equal(inspector.ids['step-label'].textContent, resolved === 'ja' ? '1目盛りで変更する音量（%）' : 'Amount per tick (%)');
  assert.equal(inspector.body.hidden, false);
  assert.equal(inspector.ids.setup.textContent, resolved === 'ja' ? 'Prismaの入手・設定方法' : 'Get Prisma and setup help');
  inspector.ids.step.value = '101'; vm.runInContext('save()', deckContext);
  assert.equal(sockets[0].messages.length, 0); assert.equal(inspector.ids.error.hidden, false);
  assert.equal(inspector.ids.error.textContent, resolved === 'ja' ? '1から100までの数値を入力してください。' : 'Enter a number from 1 to 100.');
  inspector.ids.step.value = '7'; vm.runInContext('save()', deckContext);
  assert.equal(sockets[0].messages[0].payload.step, 7); assert.equal(inspector.ids.error.hidden, true);
  let prevented = false; inspector.ids.setup.onclick({ preventDefault() { prevented = true; } });
  assert.equal(prevented, true);
  assert.deepEqual(sockets[0].messages[1], { event: 'openUrl', payload: { url: 'https://github.com/kory-/prisma/blob/main/docs/stream-deck.md' } });
}
delete globalThis.chrome;
console.log('PASS: Chrome and Stream Deck UI in Japanese, English, regional locales and unsupported-language fallback; accessibility and auto-save validation');
