import { test } from 'node:test';
import assert from 'node:assert/strict';
import { MemoryOutput, MEMORY_LIMIT, openOutput } from '../storage.js';
test('random-access MP4 patches, sequential ZIP writes and sparse regions', async () => {
  const sink = new MemoryOutput();
  await sink.write(new Uint8Array([1,2,3])); await sink.write(new Uint8Array([9]), 1);
  await sink.write(new Uint8Array([4]), 1024 * 1024 + 1);
  const data = new Uint8Array(await (await sink.finish('application/zip')).arrayBuffer());
  assert.deepEqual([...data.subarray(0,3)], [1,9,3]); assert.equal(data.at(-2), 0); assert.equal(data.at(-1), 4);
  await sink.cancel(); assert.equal(sink.chunks.size, 0);
});
test('memory output stops at 64 MiB with recoverable lower-resolution guidance', async () => {
  const sink = new MemoryOutput();
  await assert.rejects(sink.write(new Uint8Array([1]), MEMORY_LIMIT), /QUOTA.*lower resolution/);
  assert.equal(sink.size, 0);
});
test('unavailable origin-private storage falls back to bounded memory', async () => {
  assert.ok(await openOutput() instanceof MemoryOutput);
});
test('failed file initialization removes temporary output before memory fallback', async () => {
  let created, removed;
  const original = Object.getOwnPropertyDescriptor(globalThis, 'navigator');
  Object.defineProperty(globalThis, 'navigator', { configurable: true, value: { storage: {
    getDirectory: async () => ({ getDirectoryHandle: async () => ({
      getFileHandle: async (name) => { created = name; return { createWritable: async () => { throw new Error('unavailable'); } }; },
      removeEntry: async (name) => { removed = name; },
    }) }),
  } } });
  try {
    assert.ok(await openOutput() instanceof MemoryOutput);
    assert.ok(created); assert.equal(removed, created);
  } finally {
    if (original) Object.defineProperty(globalThis, 'navigator', original); else delete globalThis.navigator;
  }
});
