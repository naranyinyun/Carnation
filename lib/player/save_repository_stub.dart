import 'save_repository_base.dart';

/// Fallback [SaveRepository] factory when neither `dart:io` nor `dart:js_interop` is available.
SaveRepository createDefaultSaveRepository() => InMemorySaveRepository();
