import 'passphrase_store.dart';

/// Not in a browser (tests): memory only.
PassphraseStore browserPassphraseStore() => MemoryPassphraseStore();
