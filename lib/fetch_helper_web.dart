@JS()
library;

import 'dart:js_interop';

// ── fetch no-cors ─────────────────────────────────────────────────────────────
@JS('fetch')
external JSPromise _jsFetch(JSString url, JSAny? init);

/// Hace un POST con mode:'no-cors' usando fetch() nativo del browser.
/// No-cors evita el preflight CORS — el GAS recibe la petición y ejecuta
/// el envío, aunque la respuesta es opaque (no legible).
void sendNoCorsPost(String url, String jsonBody) {
  final init = {
    'method': 'POST',
    'mode': 'no-cors',
    'headers': {'Content-Type': 'application/json'},
    'body': jsonBody,
  }.jsify();
  _jsFetch(url.toJS, init);
}

// ── Detección de Safari ───────────────────────────────────────────────────────
@JS('navigator.userAgent')
external JSString get _userAgent;

/// Devuelve true si el browser es Safari (Apple).
/// Safari incluye "Safari" en el userAgent pero NO "Chrome" ni "Chromium"
/// ni "CriOS" (Chrome en iOS). Firefox no incluye "Safari".
bool isSafariBrowser() {
  final ua = _userAgent.toDart;
  final isChrome =
      ua.contains('Chrome') || ua.contains('Chromium') || ua.contains('CriOS');
  final isSafari = ua.contains('Safari');
  return isSafari && !isChrome;
}
