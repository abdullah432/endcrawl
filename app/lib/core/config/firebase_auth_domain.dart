/// Keep Firebase's redirect helper on the same origin as the hosted app.
/// Only domains belonging to this app's Firebase Hosting site qualify.
String firebaseAuthDomain(String host, {required String fallback}) {
  const hostingDomains = {
    'app.lastreel.cookoo.dev',
    'endcrawl-620c2.web.app',
    'endcrawl-620c2.firebaseapp.com',
  };
  return hostingDomains.contains(host) ? host : fallback;
}
