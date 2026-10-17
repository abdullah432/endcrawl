{{flutter_js}}
{{flutter_build_config}}

// The build token changes on release builds. A new URL also bypasses files
// stored by browsers under the previous one-hour cache policy. Use a query
// name other than "v": legacy Flutter workers strip that name when caching.
const lastReelBuild = {{flutter_service_worker_version}};
for (const build of _flutter.buildConfig.builds) {
  for (const key of ['mainJsPath', 'mainWasmPath', 'jsSupportRuntimePath']) {
    if (build[key]) {
      const url = new URL(build[key], document.baseURI);
      url.searchParams.set('lastreelBuild', lastReelBuild ?? 'phone-handoff');
      build[key] = url.href;
    }
  }
}

// Existing installations update to Flutter's self-cleaning worker, which
// retires the legacy asset cache. No new caching worker is installed.
_flutter.loader.load({
  serviceWorkerSettings: {serviceWorkerVersion: lastReelBuild},
});
