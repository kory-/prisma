import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import { applyOperation, storedTab, snapshots, tabStatus } from '../ChromeExtension/auto-state.mjs';
const code = fs.readFileSync(new URL('../ChromeExtension/page-audio.js', import.meta.url), 'utf8');
function fixture() {
  const context = vm.createContext({ console });
  vm.runInContext(`
    const messages = [], listeners = {}, documentListeners = {}, timers = [];
    let now = 1000; const Date = { now: () => now };
    const window = globalThis;
    window.addEventListener = (name, fn) => { (listeners[name] ||= []).push(fn); };
    window.postMessage = data => messages.push(data);
    const setInterval = fn => timers.push(fn);
    const real = new WeakMap();
    class HTMLMediaElement {
      constructor() { real.set(this, 1); this.paused = true; this.ended = false; this.readyState = 4; this.muted = false; this.isConnected = true; }
      get volume() { if (!real.has(this)) throw new TypeError('Illegal receiver'); return real.get(this); }
      set volume(value) { if (!real.has(this)) throw new TypeError('Illegal receiver'); if (!Number.isFinite(value) || value < 0 || value > 1) throw new RangeError(); real.set(this, value); }
      play() { this.paused = false; return Promise.resolve(); }
    }
    const a = new HTMLMediaElement(), b = new HTMLMediaElement();
    const document = { querySelectorAll: () => [a,b], addEventListener: (name, fn) => documentListeners[name] = fn };
    class MutationObserver { constructor(fn) { this.fn = fn; } observe() {} }
    class AudioNode {
      constructor(context) { this.context = context; this.edges = []; }
      connect(destination, output = 0, input = 0) { if (output > 0 || input > 0) throw new RangeError(); this.edges.push(destination); return destination; }
      disconnect(...args) { if (!args.length || typeof args[0] === 'number') { this.edges = []; return; } if (!this.edges.includes(args[0])) throw new Error('InvalidAccessError'); this.edges = this.edges.filter(x => x !== args[0]); }
    }
    class AudioContext {
      constructor() { this.destination = new AudioNode(this); this.state = 'running'; this.currentTime = 2; this.signal = .01; }
      createAnalyser() { const node = new AudioNode(this); node.getFloatTimeDomainData = array => array.fill(this.signal); return node; }
      createGain() { const node = new AudioNode(this); node.gain = { value: 1, setTargetAtTime(value) { this.value = value; } }; return node; }
      createMediaElementSource(element) { return new MediaElementAudioSourceNode(this, element); }
    }
    class MediaElementAudioSourceNode extends AudioNode { constructor(context, mediaElement) { super(context); this.mediaElement = mediaElement; } }
    Object.assign(window, { HTMLMediaElement, AudioNode, AudioContext, MediaElementAudioSourceNode });
    const settings = (factor, revision = 'one') => listeners.message.forEach(fn => fn({ source: window, data: { channel: 'prisma-audio-v2', type: 'settings', factor, revision } }));
    const actual = element => real.get(element);
  `, context);
  vm.runInContext(code, context);
  return { context, run: script => vm.runInContext(script, context) };
}
{
  const { context, run } = fixture();
  run('a.volume = .8; b.volume = .6; settings(.35)');
  assert.equal(run('a.volume'), .8); assert.equal(run('actual(a)'), .8 * .35);
  assert.equal(run('actual(b)'), .6 * .35);
  run('a.volume = .5'); assert.equal(run('actual(a)'), .175);
  assert.throws(() => run('a.volume = -1')); assert.throws(() => run('a.volume = NaN'));
  assert.throws(() => run('a.volume = 1n'));
  assert.throws(() => run("Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype, 'volume').get.call({})"));
  run('settings(0); a.volume = .2'); assert.equal(run('actual(a)'), 0); assert.equal(run('a.volume'), .2);
  run('settings(1)'); assert.equal(run('actual(a)'), .2); assert.equal(run('actual(b)'), .6);
  run("settings(.5); real.set(a, .4); documentListeners.volumechange({ type:'volumechange', target:a })");
  assert.equal(run('a.volume'), .4); assert.equal(run('actual(a)'), .2);
  run('const detached = new HTMLMediaElement(); detached.isConnected = false; detached.play()');
  assert.equal(run('actual(detached)'), .5); assert.equal(run('messages.at(-1).hasMedia'), true);
  run("a.play(); settings(0, 'mute')"); assert.equal(run('messages.at(-1).playing'), true);
  assert.equal(run('messages.at(-1).revision'), 'mute');
  run('now = 20000; timers.forEach(fn => fn())'); assert.equal(run('actual(a)'), .4);
  vm.runInContext(code, context); run('settings(.5); a.volume = .6'); assert.equal(run('actual(a)'), .3);
}
{
  const { run } = fixture();
  run('const ctx = new AudioContext(), source = new AudioNode(ctx); const returned = source.connect(ctx.destination)');
  assert.equal(run('returned === ctx.destination'), true);
  assert.equal(run('source.edges[0] === ctx.destination'), false);
  assert.equal(run('source.edges[0].edges[0].edges[0] === ctx.destination'), true);
  run('settings(.35)'); assert.equal(run('source.edges[0].edges[0].gain.value'), .35);
  const other = run('new AudioContext()'); assert.equal(other.state, 'running');
  run('const ctx2 = new AudioContext(), source2 = new AudioNode(ctx2); source2.connect(ctx2.destination); settings(0)');
  assert.equal(run('source2.edges[0].edges[0].gain.value'), 0);
  run("source.disconnect(ctx.destination, 0, 0)"); assert.equal(run('source.edges.length'), 0);
  assert.throws(() => run('source.disconnect(ctx.destination)'));
  run('source.connect(ctx.destination); source.disconnect(0)'); assert.equal(run('source.edges.length'), 0);
  assert.throws(() => run('source.connect(ctx.destination, 4)'));
  run('settings(.5); a.volume = .8; const media = ctx.createMediaElementSource(a); media.connect(ctx.destination)');
  assert.equal(run('actual(a)'), .8); assert.equal(run('media.edges[0].edges[0].gain.value'), .5);
  run('b.volume = .6; const constructed = new MediaElementAudioSourceNode(ctx, b); const intermediate = ctx.createGain(); constructed.connect(intermediate)');
  assert.equal(run('actual(b)'), .6);
  run('settings(1)'); assert.equal(run('media.edges[0].edges[0].gain.value'), 1);
  run('ctx.state = "closed"; ctx2.state = "closed"; a.paused = b.paused = true; timers.forEach(fn => fn())');
  assert.equal(run('messages.at(-1).playing'), false);
}
assert.deepEqual(applyOperation({ volume: .95, muted: false }, { op: 'up', step: 10 }), { volume: 1, muted: false });
assert.deepEqual(applyOperation({ volume: .3, muted: true }, { op: 'release' }), { volume: 1, muted: false });
assert.throws(() => applyOperation({ volume: 1, muted: false }, { op: 'set', value: NaN }));
assert.deepEqual(storedTab({ volume: 5, muted: 'yes' }), { volume: 1, muted: false, detected: false });
const make = (id, playing = false) => ({ id, name: 'Tab ' + id, icon: '', volume: 1, muted: false, detected: true, audible: false, frames: new Map([[0, { hasMedia: true, playing }]]) });
const tabs = new Map(Array.from({ length: 20 }, (_, id) => [id, make(id, id === 19)]));
assert.equal(snapshots(tabs).length, 16); assert.equal(snapshots(tabs)[0].id, 19);
tabs.get(19).frames.clear(); tabs.get(19).audible = true; assert.equal(tabStatus(tabs.get(19)).errorCode, 'reload_page');
tabs.get(19).audible = false; assert.equal(tabStatus(tabs.get(19)).playing, false);
console.log('Chrome automatic audio tests passed: media, native controls, Web Audio, restoration, routing, detection.');
