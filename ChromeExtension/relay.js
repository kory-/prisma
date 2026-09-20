// Isolated world: tab/frame identity comes only from Chrome's port sender.
(() => {
  const CHANNEL = 'prisma-audio-v2';
  if (globalThis.__prismaRelayV2) return;
  globalThis.__prismaRelayV2 = true;
  let port = null, retry = null, latest = null;
  const post = message => window.postMessage({ channel: CHANNEL, ...message }, '*');
  const bypass = () => post({ type: 'settings', factor: 1, revision: '' });
  function connect() {
    clearTimeout(retry);
    try {
      if (!chrome.runtime.id) { bypass(); return; }
      const candidate = chrome.runtime.connect({ name: 'prisma-auto' }); port = candidate;
      candidate.onMessage.addListener(message => {
        if (message.type === 'settings') post(message);
      });
      candidate.onDisconnect.addListener(() => {
        void chrome.runtime.lastError;
        if (port !== candidate) return;
        port = null; bypass(); retry = setTimeout(connect, 1000);
      });
      if (latest) candidate.postMessage(latest);
      post({ type: 'probe' });
    } catch { port = null; bypass(); }
  }
  window.addEventListener('message', event => {
    if (event.source !== window || event.data?.channel !== CHANNEL || event.data.type !== 'status') return;
    const data = event.data;
    latest = { type: 'status', hasMedia: data.hasMedia === true, playing: data.playing === true,
      revision: typeof data.revision === 'string' ? data.revision.slice(0, 64) : '' };
    try { port?.postMessage(latest); } catch { port = null; bypass(); }
  });
  window.addEventListener('pagehide', () => { const previous = port; port = null; previous?.disconnect(); bypass(); });
  window.addEventListener('pageshow', () => { if (!port) connect(); });
  connect();
})();
