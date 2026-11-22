import 'dart:js_interop';

import 'passphrase_store.dart';

/// The browser's localStorage: the passphrase survives reloads on this device.
PassphraseStore browserPassphraseStore() => _LocalStorageStore();

extension type _Storage._(JSObject _) implements JSObject {
  external JSString? getItem(JSString key);
  external void setItem(JSString key, JSString value);
  external void removeItem(JSString key);
}

@JS('localStorage')
external _Storage get _localStorage;

const _key = 'job-fit-owner-key';

/// localStorage can be blocked (private mode): then fall back to memory.
class _LocalStorageStore implements PassphraseStore {
  final _memory = MemoryPassphraseStore();

  @override
  String? read() {
    try {
      return _localStorage.getItem(_key.toJS)?.toDart;
    } catch (_) {
      return _memory.read();
    }
  }

  @override
  void write(String passphrase) {
    try {
      _localStorage.setItem(_key.toJS, passphrase.toJS);
    } catch (_) {
      _memory.write(passphrase);
    }
  }

  @override
  void clear() {
    try {
      _localStorage.removeItem(_key.toJS);
    } catch (_) {}
    _memory.clear();
  }
}
