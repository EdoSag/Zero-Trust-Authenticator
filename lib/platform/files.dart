import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

/// Picking and saving files with the system's own screens.
abstract class Files {
  /// The picked file's name and bytes, or null when cancelled.
  Future<(String, Uint8List)?> pick({bool image = false});

  /// Asks where to save [bytes]. False when cancelled.
  Future<bool> save({
    required String name,
    required String mimeType,
    required Uint8List bytes,
  });
}

class SystemFiles implements Files {
  SystemFiles(this._ref);
  final Ref _ref;

  // The vault must not lock because the picker covered the app.
  VaultController get _vault => _ref.read(vaultControllerProvider.notifier);

  @override
  Future<(String, Uint8List)?> pick({bool image = false}) async {
    final file = await _vault.whileShowingSystemUi(
      () => FilePicker.pickFile(type: image ? FileType.image : FileType.any),
    );
    if (file == null) return null;
    return (file.name, await file.xFile.readAsBytes());
  }

  @override
  Future<bool> save({
    required String name,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    final saved = await _vault.whileShowingSystemUi(
      () =>
          FilePicker.saveFile(fileName: name, mimeType: mimeType, bytes: bytes),
    );
    return saved != null;
  }
}

final filesProvider = Provider<Files>((ref) => SystemFiles(ref));
