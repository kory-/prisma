export const MAX_TABS = 16;
export function applyOperation(state, command) {
  const next = { volume: state.volume, muted: state.muted };
  if (command.op === 'mute') next.muted = !next.muted;
  else if (command.op === 'release') { next.volume = 1; next.muted = false; }
  else if (command.op === 'set' && Number.isFinite(command.value)) next.volume = Math.max(0, Math.min(1, command.value));
  else if (['up', 'down'].includes(command.op) && Number.isFinite(command.step)) {
    const step = Math.max(1, Math.min(100, command.step)) / 100;
    next.volume = Math.max(0, Math.min(1, next.volume + (command.op === 'up' ? step : -step)));
  } else throw new Error('Enter a valid volume.');
  return next;
}
export function storedTab(value) {
  return { volume: Number.isFinite(value?.volume) ? Math.max(0, Math.min(1, value.volume)) : 1,
    muted: value?.muted === true, detected: value?.detected === true };
}
export function tabStatus(tab) {
  const frames = [...tab.frames.values()];
  const controlled = frames.some(frame => frame.hasMedia);
  const playing = tab.audible || frames.some(frame => frame.playing);
  return { playing, controlled, errorCode: !controlled && tab.audible ? 'reload_page' : '', error: !controlled && tab.audible ? 'Reload this page to control its volume.' : '' };
}
export function snapshots(tabs) {
  return [...tabs.values()].filter(tab => tab.detected).map(tab => ({ ...tab, ...tabStatus(tab) }))
    .sort((a, b) => Number(b.playing) - Number(a.playing) || a.id - b.id).slice(0, MAX_TABS)
    .map(tab => ({ id: tab.id, name: tab.name, icon: tab.icon, volume: tab.volume, muted: tab.muted,
      playing: tab.playing, error: tab.error, errorCode: tab.errorCode, lastCommand: tab.lastCommand || '' }));
}
