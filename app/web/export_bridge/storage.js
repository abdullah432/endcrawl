export const MEMORY_LIMIT = 64 * 1024 * 1024;

// Random-access writes are essential: the MP4 muxer patches earlier headers.
export class MemoryOutput {
  constructor(limit = MEMORY_LIMIT) { this.limit = limit; this.chunks = new Map(); this.size = 0; }
  async write(data, position = this.size) {
    if (position + data.length > this.limit) throw new Error('QUOTA: Browser memory limit reached. Try a lower resolution.');
    const chunkSize = 1024 * 1024;
    for (let offset = 0; offset < data.length;) {
      const index = Math.floor((position + offset) / chunkSize);
      const within = (position + offset) % chunkSize;
      const length = Math.min(chunkSize - within, data.length - offset);
      if (!this.chunks.has(index)) this.chunks.set(index, new Uint8Array(chunkSize));
      this.chunks.get(index).set(data.subarray(offset, offset + length), within);
      offset += length;
    }
    this.size = Math.max(this.size, position + data.length);
  }
  async finish(type) {
    const parts = [];
    for (let i = 0; i < Math.ceil(this.size / (1024 * 1024)); i++) {
      const length = Math.min(1024 * 1024, this.size - i * 1024 * 1024);
      parts.push((this.chunks.get(i) ?? new Uint8Array(length)).subarray(0, length));
    }
    return new Blob(parts, { type });
  }
  async cancel() { this.chunks.clear(); }
}

export async function openOutput() {
  if (globalThis.navigator?.storage?.getDirectory) {
    let directory, name;
    try {
      const root = await navigator.storage.getDirectory();
      directory = await root.getDirectoryHandle('lastreel-renders', { create: true });
      name = crypto.randomUUID();
      const handle = await directory.getFileHandle(name, { create: true });
      const writer = await handle.createWritable();
      let size = 0;
      let closed = false;
      return {
        get size() { return size; },
        async write(data, position = size) { await writer.write({ type: 'write', position, data }); size = Math.max(size, position + data.length); },
        async finish() { if (!closed) { await writer.close(); closed = true; } return handle.getFile(); },
        async cancel() { if (!closed) { try { await writer.abort(); } catch {} closed = true; } await directory.removeEntry(name).catch(() => {}); },
      };
    } catch (error) {
      if (directory && name) await directory.removeEntry(name).catch(() => {});
      if (error?.name === 'QuotaExceededError') throw new Error('QUOTA: Browser storage is full.');
      // Private browsing or missing writable-file support: bounded memory.
    }
  }
  return new MemoryOutput();
}
