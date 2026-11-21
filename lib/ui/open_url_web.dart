import 'dart:js_interop';

@JS('window.open')
external JSAny? _windowOpen(JSString url, JSString target);

void openUrl(String url) => _windowOpen(url.toJS, '_blank'.toJS);
