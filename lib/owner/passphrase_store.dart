export 'browser_store_stub.dart'
    if (dart.library.js_interop) 'browser_store_web.dart';

/// Where the passphrase is kept on this device.
abstract interface class PassphraseStore {
  String? read();
  void write(String passphrase);
  void clear();
}

/// Keeps the passphrase in memory only (tests, or when the browser blocks storage).
class MemoryPassphraseStore implements PassphraseStore {
  MemoryPassphraseStore([this._value]);

  String? _value;

  @override
  String? read() => _value;

  @override
  void write(String passphrase) => _value = passphrase;

  @override
  void clear() => _value = null;
}
