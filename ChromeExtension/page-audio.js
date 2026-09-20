// Runs in the page's world so volume changes also cover Web Audio and new media.
// The bridge only carries audio settings/status; it has no extension privileges.
(() => {
  const CHANNEL = 'prisma-audio-v2';
  if (window.__prismaAudioV2) { window.postMessage({ channel: CHANNEL, type: 'hello' }, '*'); return; }
  Object.defineProperty(window, '__prismaAudioV2', { value: true });
  const descriptor = Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype, 'volume');
  const bases = new WeakMap(), elements = new Set(), routed = new WeakSet(), graphs = new Map();
  let factor = 1, revision = '', lease = 0;
  const actualVolume = element => descriptor.get.call(element);
  function remember(element) {
    if (!bases.has(element)) bases.set(element, actualVolume(element));
    elements.add(element);
    return bases.get(element);
  }
  function applyMedia(element) {
    const level = remember(element) * (routed.has(element) ? 1 : factor);
    if (actualVolume(element) !== level) descriptor.set.call(element, level);
  }
  Object.defineProperty(HTMLMediaElement.prototype, 'volume', {
    ...descriptor,
    get() { const current = actualVolume(this); return bases.has(this) ? bases.get(this) : current; },
    set(value) {
      actualVolume(this); // Preserve the native illegal-receiver check.
      const number = +value;
      if (!Number.isFinite(number) || number < 0 || number > 1) { descriptor.set.call(this, number); return; }
      descriptor.set.call(this, number * (routed.has(this) ? 1 : factor));
      bases.set(this, number); elements.add(this);
    }
  });
  const originalPlay = HTMLMediaElement.prototype.play;
  HTMLMediaElement.prototype.play = function (...args) { applyMedia(this); return originalPlay.apply(this, args); };
  function scan(root) {
    if (root instanceof HTMLMediaElement) applyMedia(root);
    if (root.querySelectorAll) for (const element of root.querySelectorAll('audio,video')) applyMedia(element);
  }
  scan(document);
  new MutationObserver(records => { for (const record of records) for (const node of record.addedNodes) scan(node); }).observe(document, { childList: true, subtree: true });
  for (const event of ['play', 'playing', 'pause', 'ended', 'volumechange', 'emptied']) document.addEventListener(event, event => {
    if (event.target instanceof HTMLMediaElement) {
      const element = event.target, expected = remember(element) * (routed.has(element) ? 1 : factor);
      // Native video controls bypass the JavaScript setter. Preserve that user change.
      if (event.type === 'volumechange' && actualVolume(element) !== expected) bases.set(element, actualVolume(element));
      applyMedia(element); report();
    }
  }, true);

  if (window.AudioNode && window.AudioContext) {
    const connect = AudioNode.prototype.connect, disconnect = AudioNode.prototype.disconnect;
    function graph(context) {
      if (graphs.has(context)) return graphs.get(context);
      const analyser = context.createAnalyser(), gain = context.createGain();
      analyser.fftSize = 256; gain.gain.value = factor;
      connect.call(analyser, gain); connect.call(gain, context.destination);
      const entry = { analyser, gain, samples: new Float32Array(256) };
      graphs.set(context, entry); return entry;
    }
    AudioNode.prototype.connect = function (destination, ...args) {
      if (window.MediaElementAudioSourceNode && this instanceof MediaElementAudioSourceNode) { routed.add(this.mediaElement); applyMedia(this.mediaElement); }
      const context = this.context;
      if (context instanceof AudioContext && destination === context.destination) {
        const result = connect.call(this, graph(context).analyser, ...args);
        return result ? destination : result;
      }
      return connect.call(this, destination, ...args);
    };
    AudioNode.prototype.disconnect = function (...args) {
      if (args[0] === this.context.destination && graphs.has(this.context)) args[0] = graphs.get(this.context).analyser;
      return disconnect.apply(this, args);
    };
    const createMedia = AudioContext.prototype.createMediaElementSource;
    AudioContext.prototype.createMediaElementSource = function (element) {
      const source = createMedia.call(this, element);
      routed.add(element); applyMedia(element); return source;
    };
  }
  function setFactor(next) {
    if (factor === next) return;
    factor = next;
    for (const element of elements) applyMedia(element);
    for (const [context, entry] of graphs) {
      if (context.state === 'closed') { graphs.delete(context); continue; }
      entry.gain.gain.setTargetAtTime(factor, context.currentTime, 0.008);
    }
  }
  function report() {
    if (lease && Date.now() - lease > 15000) { setFactor(1); revision = ''; }
    let playing = false, hasMedia = false;
    for (const element of elements) {
      // Detached Audio objects can still be playing. Release inactive detached elements.
      if (!element.isConnected && (element.paused || element.ended)) { elements.delete(element); continue; }
      hasMedia = true;
      if (!element.paused && !element.ended && element.readyState >= 2 && !element.muted && remember(element) > 0) playing = true;
    }
    for (const [context, entry] of graphs) {
      if (context.state === 'closed') { graphs.delete(context); continue; }
      hasMedia = true;
      if (context.state !== 'running') continue;
      entry.analyser.getFloatTimeDomainData(entry.samples);
      if (entry.samples.some(value => Math.abs(value) > 0.0001)) playing = true;
    }
    window.postMessage({ channel: CHANNEL, type: 'status', hasMedia, playing, revision }, '*');
  }
  window.addEventListener('message', event => {
    if (event.source !== window || event.data?.channel !== CHANNEL) return;
    const message = event.data;
    if (message.type === 'settings' && Number.isFinite(message.factor) && message.factor >= 0 && message.factor <= 1) {
      lease = Date.now(); revision = typeof message.revision === 'string' ? message.revision.slice(0, 64) : '';
      setFactor(message.factor); report();
    } else if (message.type === 'probe') report();
  });
  setInterval(report, 1000);
  report();
})();
