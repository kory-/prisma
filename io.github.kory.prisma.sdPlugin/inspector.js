let ws, uuid, settings = {}, isAutoAction = false;
const el = id => document.getElementById(id);
const t = key => PrismaI18n.text(key);
function visibility() {
  el('fixed').hidden = el('mode').value !== 'fixed';
  el('auto').hidden = el('mode').value !== 'auto';
}
async function connectElgatoStreamDeckSocket(port, id, event, info, actionInfo) {
  uuid = id;
  const a = JSON.parse(actionInfo);
  await PrismaI18n.load(JSON.parse(info));
  settings = a.payload.settings || {};
  isAutoAction = a.action.endsWith('.auto');
  const isDial = isAutoAction || a.payload.controller === 'Encoder';
  el('step-label').textContent = t(isDial ? 'Amount per tick (%)' : 'Amount per press (%)');
  el('help').textContent = t(isDial ? 'Turn to adjust volume. Press or tap to mute. Enable volume control in Prisma first.' : 'Press to control the selected app. Enable volume control in Prisma first.');
  el('mode').value = isAutoAction ? 'auto' : settings.mode || 'fixed';
  el('mode').disabled = isAutoAction;
  ['app', 'label', 'step'].forEach(k => { el(k).value = settings[k] ?? (k === 'step' ? 5 : ''); });
  visibility(); document.body.hidden = false;
  ws = new WebSocket('ws://127.0.0.1:' + port);
  ws.onopen = () => {
    ws.send(JSON.stringify({ event, uuid }));
    ws.send(JSON.stringify({ event: 'sendToPlugin', action: a.action, context: uuid, payload: { request: 'apps' } }));
  };
  ws.onmessage = e => {
    const m = JSON.parse(e.data);
    if (m.event === 'sendToPropertyInspector' && Array.isArray(m.payload?.apps)) {
      el('apps').replaceChildren(new Option(t('Select an app'), ''));
      m.payload.apps.forEach(a => el('apps').add(new Option(a.name, a.id)));
      el('apps').value = settings.app || '';
    }
  };
}
function save() {
  const step = Number(el('step').value);
  const valid = el('step').value.trim() !== '' && Number.isFinite(step) && step >= 1 && step <= 100;
  el('error').textContent = valid ? '' : t('Enter a number from 1 to 100.');
  el('error').hidden = valid;
  el('step').setAttribute('aria-invalid', String(!valid));
  if (!valid) return;
  ['mode', 'app', 'label'].forEach(k => { settings[k] = el(k).value; }); settings.step = step;
  visibility();
  if (ws?.readyState === 1) ws.send(JSON.stringify({ event: 'setSettings', context: uuid, payload: settings }));
}
['mode', 'app', 'label', 'step'].forEach(k => { el(k).onchange = save; });
el('apps').onchange = e => { el('app').value = e.target.value; save(); };

el('setup').onclick = event => {
  if (ws?.readyState !== 1) return;
  event.preventDefault();
  ws.send(JSON.stringify({ event: 'openUrl', payload: { url: el('setup').href } }));
};
