import 'dart:js_interop';

import 'save_repository_base.dart';

@JS('window.localStorage')
external _WebStorage? get _localStorage;

extension type _WebStorage._(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void setItem(String key, String value);
}

/// A [JsonSaveRepository] backed by browser `localStorage` for Flutter Web.
class LocalStorageSaveRepository extends JsonSaveRepository {
  LocalStorageSaveRepository({String storageKey = defaultStorageKey})
      : this.storageKey = storageKey,
        super(
          readRaw: () => _localStorage?.getItem(storageKey),
          writeRaw: (raw) => _localStorage?.setItem(storageKey, raw),
        );

  static const String defaultStorageKey = 'carnation_saves_v1';

  final String storageKey;
}

/// Creates the default [SaveRepository] for Flutter Web.
SaveRepository createDefaultSaveRepository() => LocalStorageSaveRepository();
