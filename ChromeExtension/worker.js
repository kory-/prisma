import { t } from './i18n.mjs';
import { applyOperation, storedTab, snapshots } from './auto-state.mjs';
const HOST = 'local.prisma.chrome';
const tabs = new Map(), faviconCache = new Map();
let port = null, retryAt = 0, session = '', enabled = true, lastApp = 0;
let app = { alive: false, active: false }, connectionError = '', saveTimer = null;
function sendNative(message) { try { port?.postMessage(message); } catch { port = null; } }
function currentTabs() { return snapshots(tabs).map(tab => tab.errorCode ? { ...tab, error: t(tab.errorCode) } : tab); }
function settings(tab) { return { type: 'settings', factor: enabled ? (tab.muted ? 0 : tab.volume) : 1, revision: tab.revision || '' }; }
function sendSettings(tab) {
  for (const frame of tab.frames.values()) { try { frame.port.postMessage(settings(tab)); } catch {} }
}
function setEnabled(value) { enabled = value; for (const tab of tabs.values()) sendSettings(tab); }
function persist() {
  clearTimeout(saveTimer);
  saveTimer = setTimeout(() => {
    const levels = Object.fromEntries([...tabs.values()].filter(tab => tab.detected).map(tab => [tab.id, storedTab(tab)]));
    chrome.storage.session.set({ session, levels }).catch(() => {});
  }, 100);
}
function publish() {
  connect(); sendNative({ type: 'state', session, tabs: currentTabs() });
  chrome.action.setBadgeText({ text: tabs.size && currentTabs().length ? String(currentTabs().length) : '' }).catch(() => {});
}
function control(id, command) {
  const tab = tabs.get(id); if (!tab || !tab.detected) throw new Error(t('tab_not_found'));
  if (command.op === 'focus') { chrome.tabs.update(id, { active: true }).then(tab => chrome.windows.update(tab.windowId, { focused: true })).catch(() => {}); return; }
  try { Object.assign(tab, applyOperation(tab, command)); } catch { throw new Error(t('invalid_volume')); }
  tab.revision = command.requestId || crypto.randomUUID(); tab.lastCommand = '';
  // UI operations resume both the extension and the native mixer.
  setEnabled(true); sendSettings(tab); persist(); publish(); sendNative({ type: 'activate' });
}
function connect() {
  if (port || Date.now() < retryAt || !session) return;
  retryAt = Date.now() + 5000;
  let candidate;
  try { candidate = chrome.runtime.connectNative(HOST); } catch (e) { connectionError = e.message; return; }
  port = candidate;
  candidate.onDisconnect.addListener(() => {
    connectionError = chrome.runtime.lastError?.message || t('disconnected');
    if (port === candidate) { port = null; if (app.alive) setEnabled(false); app.alive = false; }
  });
  candidate.onMessage.addListener(message => {
    if (message.type === 'app') {
      app = { alive: true, active: Boolean(message.active) }; lastApp = Date.now(); connectionError = '';
      if (enabled !== app.active) setEnabled(app.active);
    } else if (message.type === 'command' && message.session === session) {
      try { control(message.id, message); } catch { publish(); }
    }
  });
  candidate.postMessage({ type: 'hello' });
  candidate.postMessage({ type: 'state', session, tabs: currentTabs() });
}
async function metadata(tab) {
  let icon = '';
  try {
    const parsed = new URL(tab.url); const cacheKey = parsed.origin;
    if (faviconCache.has(cacheKey)) icon = faviconCache.get(cacheKey);
    else if (['http:', 'https:'].includes(parsed.protocol)) {
      const url = new URL(chrome.runtime.getURL('/_favicon/')); url.searchParams.set('pageUrl', tab.url); url.searchParams.set('size', '32');
      const response = await fetch(url); const bytes = new Uint8Array(await response.arrayBuffer());
      if (response.ok && bytes.length <= 6000 && bytes[0] === 137 && bytes[1] === 80) icon = 'data:image/png;base64,' + btoa(String.fromCharCode(...bytes));
      if (faviconCache.size >= 100) faviconCache.clear(); faviconCache.set(cacheKey, icon);
    }
  } catch { /* Only Chrome's local favicon store is used. */ }
  return { name: (tab.title || t('chrome_tab')).slice(0, 180), icon };
}
function ensureTab(id, seed = {}) {
  if (!tabs.has(id)) tabs.set(id, { id, ...storedTab(seed), name: t('chrome_tab'), icon: '', audible: false, frames: new Map(), revision: '', lastCommand: '' });
  return tabs.get(id);
}
async function updateMetadata(id, browserTab) {
  try {
    const actual = browserTab || await chrome.tabs.get(id);
    const record = tabs.get(id); if (!record) return;
    Object.assign(record, await metadata(actual));
  } catch {}
}
async function injectExisting() {
  const open = await chrome.tabs.query({});
  await Promise.allSettled(open.filter(tab => /^https?:\/\//.test(tab.url || '')).map(async tab => {
    // Static scripts cover future documents. One injection also adopts existing HTML media.
    await chrome.scripting.executeScript({ target: { tabId: tab.id, allFrames: true }, world: 'MAIN', files: ['page-audio.js'] });
    await chrome.scripting.executeScript({ target: { tabId: tab.id, allFrames: true }, world: 'ISOLATED', files: ['relay.js'] });
  }));
}
const ready = (async () => {
  const [stored, open] = await Promise.all([chrome.storage.session.get(['session', 'levels']), chrome.tabs.query({})]);
  session = /^[0-9a-f-]{36}$/i.test(stored.session || '') ? stored.session : crypto.randomUUID();
  await chrome.storage.session.set({ session });
  for (const browserTab of open) {
    if (!/^https?:\/\//.test(browserTab.url || '')) continue;
    if (stored.levels?.[browserTab.id] || browserTab.audible) {
      const tab = ensureTab(browserTab.id, stored.levels?.[browserTab.id]);
      tab.audible = browserTab.audible === true; tab.detected ||= tab.audible;
      await updateMetadata(tab.id, browserTab);
    }
  }
  persist(); connect(); publish();
})();
chrome.runtime.onConnect.addListener(candidate => {
  if (candidate.name !== 'prisma-auto' || candidate.sender?.id !== chrome.runtime.id || !Number.isInteger(candidate.sender?.tab?.id)) return;
  const id = candidate.sender.tab.id, frameId = candidate.sender.frameId;
  let ended = false, frame;
  candidate.onDisconnect.addListener(() => {
    void chrome.runtime.lastError; ended = true;
    const tab = tabs.get(id);
    if (tab && tab.frames.get(frameId) === frame) { tab.frames.delete(frameId); publish(); }
  });
  candidate.onMessage.addListener(message => {
    ready.then(() => {
      const tab = tabs.get(id);
      if (ended || !tab || tab.frames.get(frameId) !== frame || message.type !== 'status') return;
      frame.hasMedia = message.hasMedia === true; frame.playing = message.playing === true;
      frame.revision = typeof message.revision === 'string' ? message.revision.slice(0, 64) : '';
      if (frame.playing && !tab.detected) { tab.detected = true; updateMetadata(id).then(publish); persist(); }
      if (tab.revision && [...tab.frames.values()].filter(frame => frame.hasMedia).every(frame => frame.revision === tab.revision) && [...tab.frames.values()].some(frame => frame.hasMedia)) tab.lastCommand = tab.revision;
    }).catch(() => {});
  });
  ready.then(() => {
    if (ended) return;
    const tab = ensureTab(id);
    frame = { port: candidate, hasMedia: false, playing: false, revision: '' };
    tab.frames.set(frameId, frame); candidate.postMessage(settings(tab));
    updateMetadata(id);
  }).catch(() => {});
});
chrome.tabs.onRemoved.addListener(id => { ready.then(() => { tabs.delete(id); persist(); publish(); }); });
chrome.tabs.onUpdated.addListener((id, changes, browserTab) => {
  ready.then(() => {
    if (!/^https?:\/\//.test(browserTab.url || '')) { tabs.delete(id); persist(); publish(); return; }
    if (changes.audible === true || tabs.has(id)) {
      const tab = ensureTab(id); tab.audible = browserTab.audible === true;
      if (tab.audible && !tab.detected) { tab.detected = true; persist(); }
      if (changes.url || changes.title || changes.favIconUrl || changes.audible) updateMetadata(id, browserTab).then(publish);
    }
  }).catch(() => {});
});
async function popupState() {
  const [current] = await chrome.tabs.query({ active: true, currentWindow: true });
  return { tabs: currentTabs(), enabled, current: current ? { id: current.id, name: current.title || t('current_tab'), eligible: /^https?:\/\//.test(current.url || '') } : null,
    app: { ...app, alive: app.alive && Date.now() - lastApp < 4000 }, nativeConnected: Boolean(port), connectionError };
}
chrome.runtime.onMessage.addListener((message, sender, reply) => {
  if (sender.id !== chrome.runtime.id || sender.url !== chrome.runtime.getURL('popup.html') || message.target !== 'worker') return;
  ready.then(async () => {
    if (message.type === 'control') control(message.id, { ...message.command, requestId: crypto.randomUUID() });
    else if (message.type === 'retry') { retryAt = 0; connect(); }
    else if (message.type !== 'get') throw new Error(t('unknown_operation'));
    reply({ ok: true, ...(await popupState()) });
  }).catch(error => reply({ ok: false, error: error.message }));
  return true;
});
chrome.runtime.onInstalled.addListener(() => { ready.then(injectExisting).catch(() => {}); });
ready.then(() => {
  chrome.action.setBadgeBackgroundColor({ color: '#596579' });
  setInterval(() => {
    if (app.alive && Date.now() - lastApp > 4000) { app.alive = false; setEnabled(false); }
    for (const tab of tabs.values()) sendSettings(tab);
    publish();
  }, 1000);
}).catch(() => {});
