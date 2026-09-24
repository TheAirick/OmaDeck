// A real, silent audio graph for disposable browser tests. No hardware modules,
// session manager, owner server connection, or changes to the desktop graph.
const fs = require('node:fs');
const path = require('node:path');
const {spawn, execFile} = require('node:child_process');
const {promisify} = require('node:util');
const exec = promisify(execFile);
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));

module.exports = async function privateAudio(lab, baseEnv) {
  const dir = path.join(lab, 'audio');
  fs.mkdirSync(dir, {mode: 0o700});
  const pulse = path.join(dir, 'pulse', 'native');
  fs.mkdirSync(path.dirname(pulse), {mode: 0o700});
  const env = {...baseEnv, XDG_RUNTIME_DIR: dir, PIPEWIRE_RUNTIME_DIR: dir,
    PIPEWIRE_CONFIG_DIR: dir, PIPEWIRE_CONFIG_PREFIX: '', PIPEWIRE_REMOTE: 'pipewire-0',
    PULSE_SERVER: 'unix:' + pulse};
  fs.writeFileSync(path.join(dir, 'pipewire.conf'), `
context.properties = { core.daemon = true core.name = pipewire-0 }
context.spa-libs = { audio.convert.* = audioconvert/libspa-audioconvert support.* = support/libspa-support }
context.modules = [
 { name = libpipewire-module-protocol-native }
 { name = libpipewire-module-metadata }
 { name = libpipewire-module-spa-node-factory }
 { name = libpipewire-module-client-node }
 { name = libpipewire-module-access }
 { name = libpipewire-module-adapter }
 { name = libpipewire-module-link-factory }
 { name = libpipewire-module-protocol-pulse args = { server.address = [ "unix:${pulse}" ] } }
]
context.objects = [
 { factory = metadata args = { metadata.name = default metadata.values = [ { key = default.audio.sink value = { name = omadeck-test-null } } ] } }
 { factory = adapter args = { factory.name = support.null-audio-sink node.name = omadeck-test-null media.class = Audio/Sink audio.position = [ FL FR ] adapter.auto-port-config = { mode = dsp monitor = false position = preserve } } }
]
`);
  const log = fs.openSync(path.join(dir, 'pipewire.log'), 'w');
  const server = spawn('pipewire', ['-c', 'pipewire.conf'], {env, stdio: ['ignore', log, log]});
  let failure, stopping = false, inFlight = Promise.resolve(), timer;
  server.on('error', error => { failure = error; });
  const clientEnv = {...env};
  delete clientEnv.PIPEWIRE_CONFIG_DIR;
  delete clientEnv.PIPEWIRE_CONFIG_PREFIX;
  const run = (file, args) => exec(file, args, {env: clientEnv, timeout: 3000, maxBuffer: 4 * 1024 * 1024});
  const linked = new Set();
  async function connect() {
    const graph = JSON.parse((await run('pw-dump', [])).stdout);
    for (const node of graph) {
      const info = node.info || {}, props = info.props || {};
      if (node.type.endsWith(':Node') && props['media.class'] === 'Stream/Output/Audio' && info['n-output-ports'] === 0)
        await run('pw-cli', ['set-param', String(node.id), 'PortConfig',
          '{ direction = Output mode = dsp format = { mediaType = audio mediaSubtype = raw format = F32P rate = 48000 channels = 2 position = [ FL FR ] } }']);
    }
    const sink = graph.find(node => node.info?.props?.['node.name'] === 'omadeck-test-null');
    if (!sink) throw Error('Private audio sink disappeared');
    const ports = graph.filter(node => node.type.endsWith(':Port'));
    for (const port of ports) {
      const props = port.info.props;
      if (props['port.direction'] !== 'out') continue;
      const input = ports.find(p => p.info.props['node.id'] === sink.id &&
        p.info.props['audio.channel'] === props['audio.channel']);
      if (!input) continue;
      const key = `${props['object.serial']}:${input.info.props['object.serial']}`;
      if (linked.has(key)) continue;
      await run('pw-link', [String(port.id), String(input.id)]);
      linked.add(key);
    }
  }
  async function close() {
    stopping = true;
    clearTimeout(timer);
    await inFlight;
    if (server.pid && server.exitCode === null && server.signalCode === null) {
      server.kill('SIGTERM');
      await Promise.race([new Promise(resolve => server.once('exit', resolve)), delay(3000)]);
      if (server.exitCode === null && server.signalCode === null) {
        server.kill('SIGKILL');
        await new Promise(resolve => server.once('exit', resolve));
      }
    }
    fs.closeSync(log);
  }
  try {
    for (let i = 0; !fs.existsSync(pulse); i++) {
      if (failure) throw failure;
      if (server.exitCode !== null || i >= 50) throw Error('Private audio server did not start');
      await delay(100);
    }
    await connect();
    function tick() {
      if (stopping) return;
      // Streams may vanish during tab navigation; retry on the next bounded tick.
      inFlight = connect().catch(error => { if (!stopping) fs.writeSync(log, String(error) + '\n'); })
        .finally(() => { if (!stopping) timer = setTimeout(tick, 250); });
    }
    tick();
    return {env: {PULSE_SERVER: env.PULSE_SERVER, PIPEWIRE_RUNTIME_DIR: dir,
      PIPEWIRE_REMOTE: 'pipewire-0'}, close};
  } catch (error) {
    await close();
    throw error;
  }
};
