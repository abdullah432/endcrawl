import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {test} from 'node:test';
import vm from 'node:vm';

const bootstrap = readFileSync(new URL('../web/flutter_bootstrap.js', import.meta.url), 'utf8');
const origin = 'https://app.lastreel.cookoo.dev/';

function start(version, builds) {
  let loaded;
  const context = {
    URL,
    document: {baseURI: origin},
    _flutter: {loader: {load(settings) {
      loaded = {settings, builds: context._flutter.buildConfig.builds};
    }}},
  };
  vm.runInNewContext(bootstrap
    .replace('{{flutter_js}}', '')
    .replace('{{flutter_build_config}}', `_flutter.buildConfig = ${JSON.stringify({builds})};`)
    .replace('{{flutter_service_worker_version}}', JSON.stringify(version)), context);
  return loaded;
}

test('a fresh page bypasses the old cached app and changes URLs on the next release', () => {
  const oldCache = new Map([[`${origin}main.dart.js`, 'previous access UI']]);
  const first = start('release-1', [{mainJsPath: 'main.dart.js'}, {}]);
  const next = start('release-2', [{mainJsPath: 'main.dart.js'}, {}]);
  const request = first.builds[0].mainJsPath;
  assert.equal(oldCache.has(request), false);
  assert.notEqual(request, next.builds[0].mainJsPath);
  assert.equal(new URL(request).searchParams.get('lastreelBuild'), 'release-1');
  assert.equal(new URL(request).searchParams.has('v'), false);
  assert.equal(first.settings.serviceWorkerSettings.serviceWorkerVersion, 'release-1');
  assert.equal(Object.keys(first.builds[1]).length, 0);
});

test('Wasm and its supporting runtime use the same release identifier', () => {
  const {builds} = start('release-2', [{
    mainWasmPath: 'main.dart.wasm',
    jsSupportRuntimePath: 'main.dart.mjs',
  }]);
  for (const url of Object.values(builds[0])) {
    assert.equal(new URL(url).origin, new URL(origin).origin);
    assert.equal(new URL(url).searchParams.get('lastreelBuild'), 'release-2');
  }
});

test('the page inlines the loader and Firebase revalidates root and entry files', () => {
  const index = readFileSync(new URL('../web/index.html', import.meta.url), 'utf8');
  assert.match(index, /<script>\{\{flutter_bootstrap_js\}\}<\/script>/);
  assert.doesNotMatch(index, /src="flutter_bootstrap\.js/);
  assert.match(index, /name="viewport" content="width=device-width/);
  const config = JSON.parse(readFileSync(new URL('../../firebase.json', import.meta.url), 'utf8'));
  const app = config.hosting.find(site => site.target === 'app');
  const global = app.headers.find(rule => rule.source === '**');
  assert.equal(global.headers.find(header => header.key === 'Cache-Control').value,
    'no-cache, max-age=0, must-revalidate');
  assert.ok(app.headers.every(rule => rule.headers.every(header =>
    header.key !== 'Cache-Control' || !header.value.includes('max-age=3600'))));
});
