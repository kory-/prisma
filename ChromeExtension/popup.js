import { t, localizeDocument } from './i18n.mjs';
localizeDocument(document);
const $ = id => document.getElementById(id);
const request = message => chrome.runtime.sendMessage({ target: 'worker', ...message });
let current, manipulating = false, renderedTabs = "";
function error(text = '') { $('error').textContent = text; $('error').hidden = !text; }
async function act(message) {
  try { const result = await request(message); if (!result.ok) throw new Error(result.error); error(); render(result); }
  catch (e) { error(e.message); }
}
function render(state) {
  current = state.current;
  $('connection').textContent = state.app.alive ? (state.app.active ? t('connected') : t('control_off')) : state.nativeConnected ? t('launch_prisma') : t('standalone');
  $('retry').title = state.connectionError ? t('setup_required') : t('retry_connection');
  const detected = state.tabs.find(tab => tab.id === current?.id);
  $('current-title').textContent = current?.name || t('no_tab');
  $('current-note').textContent = !current?.eligible ? t('open_audio_page') : detected?.error || (detected ? t('detected_note') : t('auto_detect_note'));
  const signature = JSON.stringify(state.tabs);
  if (manipulating || signature === renderedTabs) return;
  renderedTabs = signature;
  $('tabs').replaceChildren(); $('empty').hidden = state.tabs.length > 0;
  for (const tab of state.tabs) {
    const row = document.createElement('div'); row.className = 'tab';
    const title = document.createElement('div'); title.className = 'tab-title';
    const image = document.createElement('img'); image.src = tab.icon?.startsWith('data:image/png;base64,') ? tab.icon : 'icons/32.png'; image.alt = '';
    const name = document.createElement('span'); name.textContent = tab.name; name.title = tab.name;
    const remove = document.createElement('button'); remove.className = 'quiet remove'; remove.textContent = '↺'; remove.title = t('reset_volume'); remove.setAttribute('aria-label', t('reset_named_volume', tab.name)); remove.onclick = () => act({ type: 'control', id: tab.id, command: { op: 'release' } });
    title.append(image, name, remove);
    const controls = document.createElement('div'); controls.className = 'controls';
    const range = document.createElement('input'); range.type = 'range'; range.min = '0'; range.max = '100'; range.value = String(Math.round(tab.volume * 100)); range.setAttribute('aria-label', t('named_volume', tab.name));
    const value = document.createElement('output'); value.textContent = range.value + '%';
    let sending = false, latest = null;
    const flush = async () => { if (sending || latest === null) return; const level = latest; latest = null; sending = true; try { const result = await request({ type: 'control', id: tab.id, command: { op: 'set', value: level } }); if (!result.ok) error(result.error); } catch (e) { error(e.message); } finally { sending = false; if (latest !== null) flush(); } };
    range.onpointerdown = () => { manipulating = true; };
    range.oninput = () => { manipulating = true; value.textContent = range.value + '%'; latest = Number(range.value) / 100; flush(); };
    range.onchange = () => { manipulating = false; };
    range.onblur = () => { manipulating = false; };
    const mute = document.createElement('button'); mute.className = 'mute'; mute.textContent = tab.muted ? t('unmute') : t('mute'); mute.setAttribute('aria-pressed', String(tab.muted)); mute.setAttribute('aria-label', t('toggle_named_mute', tab.name)); mute.onclick = () => act({ type: 'control', id: tab.id, command: { op: 'mute' } });
    controls.append(range, value, mute); row.append(title, controls);
    if (tab.error) { const note = document.createElement('p'); note.className = 'note'; note.textContent = tab.error; row.append(note); }
    $('tabs').append(row);
  }
}
$('retry').onclick = () => act({ type: 'retry' });
async function refresh() { try { const state = await request({ type: 'get' }); if (state.ok) render(state); } catch (e) { error(e.message); } }
refresh(); setInterval(refresh, 1000);
