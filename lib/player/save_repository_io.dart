import 'dart:io';

import 'save_repository_base.dart';

/// A [JsonSaveRepository] backed by a JSON file on the local filesystem.
class JsonFileSaveRepository extends JsonSaveRepository {
  JsonFileSaveRepository(File file)
      : this.file = file,
        super(
          readRaw: () {
            if (!file.existsSync()) return null;
            return file.readAsStringSync();
          },
          writeRaw: (raw) {
            file.parent.createSync(recursive: true);
            file.writeAsStringSync(raw);
          },
        );

  final File file;
}

/// Creates the default [SaveRepository] for native/VM platforms.
SaveRepository createDefaultSaveRepository() {
  final saveFile = File('${Directory.systemTemp.path}/carnation_saves_v1.json');
  return JsonFileSaveRepository(saveFile);
}
