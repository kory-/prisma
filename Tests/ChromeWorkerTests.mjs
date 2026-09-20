import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import { randomUUID } from 'node:crypto';
import { t } from '../ChromeExtension/i18n.mjs';
import { applyOperation, storedTab, snapshots } from '../ChromeExtension/auto-state.mjs';
const event = () => ({ listeners: [], addListener(fn) { this.listeners.push(fn); }, emit(...args) { this.listeners.forEach(fn => fn(...args)); } });
const fakePort = sender => ({ sender, name: 'prisma-auto', onMessage: event(), onDisconnect: event(), messages: [], postMessage(message) { this.messages.push(message); } });
const native = fakePort();
const open = [{ id: 1, url: 'https://example.test/a', title: 'A', audible: false }, { id: 2, url: 'https://example.test/b', title: 'B', audible: false }];
const session = randomUUID(), data = { session, levels: { 1: { volume: .6, muted: false, detected: true }, 99: { volume: .2, detected: true } } };
const intervals = [], timeouts = new Map(); let serial = 0;
const chrome = {
  runtime: { id: 'test', getURL: path => 'chrome-extension://test/' + path, connectNative: () => native, onConnect: event(), onMessage: event(), onInstalled: event() },
  storage: { session: { get: async () => data, set: async next => Object.assign(data, next) } },
  tabs: { query: async () => open, get: async id => open.find(tab => tab.id === id), update: async () => ({}), onUpdated: event(), onRemoved: event() },
  windows: { update: async () => {} },
  action: { setBadgeText: async () => {}, setBadgeBackgroundColor: async () => {} },
  scripting: { executeScript: async () => {} }
};
const context = vm.createContext({ chrome, t, applyOperation, storedTab, snapshots, URL, crypto: { randomUUID }, console,
  setInterval: fn => intervals.push(fn), setTimeout: fn => { timeouts.set(++serial, fn); return serial; }, clearTimeout: id => timeouts.delete(id),
  fetch: async () => ({ ok: false, arrayBuffer: async () => new ArrayBuffer(0) }) });
const script = fs.readFileSync(new URL('../ChromeExtension/worker.js', import.meta.url), 'utf8').replace(/^import .*;\n/gm, '');
vm.runInContext(script, context);
const flush = async () => { for (let i = 0; i < 12; i++) await new Promise(resolve => setImmediate(resolve)); };
const run = script => vm.runInContext(script, context);
const connectFrame = (id, frameId = 0) => { const p = fakePort({ id: 'test', tab: { id }, frameId }); chrome.runtime.onConnect.emit(p); return p; };
await flush();
assert.equal(run('session'), session); assert.equal(run('tabs.has(99)'), false);
const a = connectFrame(1), b = connectFrame(2); await flush();
a.onMessage.emit({ type: 'status', hasMedia: true, playing: true }); b.onMessage.emit({ type: 'status', hasMedia: true, playing: true }); await flush();
assert.equal(run('currentTabs().length'), 2); assert.equal(run('tabs.get(1).volume'), .6);
native.onMessage.emit({ type: 'command', session, id: 1, op: 'set', value: .35, requestId: 'request-a' }); await flush();
assert.equal(a.messages.at(-1).factor, .35); assert.equal(b.messages.at(-1).factor, 1);
a.onMessage.emit({ type: 'status', hasMedia: true, playing: true, revision: 'request-a' }); await flush();
assert.equal(run('tabs.get(1).lastCommand'), 'request-a');
native.onMessage.emit({ type: 'command', session: randomUUID(), id: 1, op: 'set', value: .9 }); await flush();
assert.equal(run('tabs.get(1).volume'), .35);
native.onMessage.emit({ type: 'command', session, id: 2, op: 'mute', requestId: 'mute-b' }); await flush();
assert.equal(a.messages.at(-1).factor, .35); assert.equal(b.messages.at(-1).factor, 0);
const child = connectFrame(1, 5); await flush(); assert.equal(child.messages.at(-1).factor, .35);
const replacement = connectFrame(1); await flush(); a.onDisconnect.emit(); await flush();
assert.equal(run('tabs.get(1).frames.size'), 2); assert.equal(replacement.messages.at(-1).factor, .35);
a.onMessage.emit({ type: 'status', hasMedia: false, playing: false }); await flush();
assert.equal(run('tabs.get(1).frames.get(0).port === tabs.get(1).frames.get(5).port'), false);
native.onMessage.emit({ type: 'app', active: false }); await flush();
assert.equal(replacement.messages.at(-1).factor, 1); assert.equal(b.messages.at(-1).factor, 1);
native.onMessage.emit({ type: 'app', active: true }); await flush();
assert.equal(replacement.messages.at(-1).factor, .35); assert.equal(b.messages.at(-1).factor, 0);
chrome.tabs.onRemoved.emit(1); await flush(); replacement.onDisconnect.emit(); child.onDisconnect.emit(); await flush();
assert.equal(run('tabs.has(1)'), false);
for (const callback of timeouts.values()) callback(); await flush();
assert.equal(data.levels[1], undefined); assert.equal(data.levels[2].muted, true);
console.log('Chrome worker tests passed: auto discovery, session restore, two-tab isolation, frames/navigation, stale messages, app bypass, removal.');
