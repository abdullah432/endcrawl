import { Output, Mp4OutputFormat, StreamTarget, VideoSampleSource, VideoSample, canEncodeVideo } from 'mediabunny';
import { openOutput } from './storage.js';

const files = new Map();
const sessions = new Map();
const mime = (id) => id.endsWith('.zip') ? 'application/zip' : 'video/mp4';

async function create(id) {
  await release(id);
  files.set(id, { output: await openOutput(), blob: null });
}
async function finish(id) {
  const entry = files.get(id);
  if (!entry) throw new Error('Output was discarded.');
  entry.blob ??= await entry.output.finish(mime(id));
  return entry.blob.size;
}
async function release(id) {
  const session = sessions.get(id);
  sessions.delete(id);
  if (session) await session.output.cancel().catch(() => {});
  const entry = files.get(id);
  files.delete(id);
  if (entry) await entry.output.cancel();
}
async function supported(width, height, fps, bitrate) {
  if (!globalThis.isSecureContext || !globalThis.VideoEncoder) return false;
  return canEncodeVideo('avc', { width, height, bitrate, frameRate: fps }).catch(() => false);
}

globalThis.endcrawlExport = {
  async capabilities() {
    const maxEdge = { png: 8192 }, maxEdgeAt60 = { png: 8192 };
    for (const edge of [1280, 1920, 3840]) {
      const height = Math.round(edge * 9 / 16 / 2) * 2;
      for (const fps of [30, 60]) {
        const bitrate = Math.round(12e6 * edge * height / (1920 * 1080));
        if (await supported(edge, height, fps, bitrate) && await supported(height, edge, fps, bitrate)) {
          (fps === 60 ? maxEdgeAt60 : maxEdge).h264 = edge;
        }
      }
    }
    const estimate = await navigator.storage?.estimate?.().catch(() => null);
    return JSON.stringify({ maxEdge, maxEdgeAt60, freeBytes: estimate?.quota == null ? null : estimate.quota - estimate.usage });
  },
  create,
  async write(id, bytes) { await files.get(id).output.write(bytes); },
  finish,
  release,
  async videoStart(id, width, height, num, den, bitrate) {
    if (!await supported(width, height, num / den, bitrate)) throw new Error('UNSUPPORTED: This browser cannot encode the selected picture size and frame rate.');
    await create(id);
    const file = files.get(id);
    try {
    const target = new StreamTarget(new WritableStream({
      write: ({ data, position }) => file.output.write(data, position),
      close: () => finish(id),
      abort: () => file.output.cancel(),
    }), { chunked: true, chunkSize: 1024 * 1024 });
    const output = new Output({ format: new Mp4OutputFormat({ fastStart: false }), target });
    const source = new VideoSampleSource({ codec: 'avc', bitrate });
    output.addVideoTrack(source, { frameRate: num / den });
    sessions.set(id, { output, source, width, height, num, den, next: 0 });
    await output.start();
    } catch (error) { await release(id); throw error; }
  },
  async videoAppend(id, rgba, index) {
    const s = sessions.get(id);
    if (!s || index !== s.next) throw new Error('Frames must arrive in order.');
    const sample = new VideoSample(rgba, { format: 'RGBA', codedWidth: s.width, codedHeight: s.height,
      timestamp: index * s.den / s.num, duration: s.den / s.num });
    try { await s.source.add(sample); s.next++; } finally { sample.close(); }
  },
  async videoFinish(id) {
    const s = sessions.get(id);
    s.source.close();
    await s.output.finalize();
    sessions.delete(id);
    return finish(id);
  },
  async download(id, filename) {
    const entry = files.get(id);
    if (!entry?.blob) throw new Error('The download is no longer available. Render again.');
    const url = URL.createObjectURL(entry.blob);
    const anchor = document.createElement('a');
    anchor.href = url; anchor.download = filename;
    document.body.append(anchor); anchor.click(); anchor.remove();
    setTimeout(() => URL.revokeObjectURL(url), 30000);
  },
  canShare(id, filename) {
    const blob = files.get(id)?.blob;
    return !!blob && !!navigator.canShare?.({ files: [new File([blob], filename, { type: mime(id) })] });
  },
  async share(id, filename) {
    const blob = files.get(id)?.blob;
    if (!blob) throw new Error('The output is no longer available.');
    await navigator.share({ files: [new File([blob], filename, { type: mime(id) })] });
  },
};

addEventListener('pagehide', () => { for (const id of files.keys()) void release(id); });
