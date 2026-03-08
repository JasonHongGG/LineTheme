import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;

class ThemeArchiveMerger {
  Uint8List merge({
    required List<int> baseArchiveBytes,
    required List<int> overlayArchiveBytes,
  }) {
    final baseArchive = ZipDecoder().decodeBytes(
      baseArchiveBytes,
      verify: false,
    );
    final overlayArchive = ZipDecoder().decodeBytes(
      overlayArchiveBytes,
      verify: false,
    );

    final baseFiles = _buildArchiveFileMap(baseArchive);
    final overlayFiles = _buildArchiveFileMap(overlayArchive);

    final baseJsonPath = _findArchivePath(
      baseFiles.keys,
      exactPath: 'themefile/theme.json',
      suffixPath: 'theme.json',
    );
    final overlayJsonPath = _findArchivePath(
      overlayFiles.keys,
      exactPath: 'theme.json',
      suffixPath: 'theme.json',
    );

    if (baseJsonPath == null || overlayJsonPath == null) {
      throw const FormatException('缺少 theme.json，無法進行合併。');
    }

    final baseJson =
        json.decode(utf8.decode(baseFiles[baseJsonPath]!))
            as Map<String, dynamic>;
    final overlayJson =
        json.decode(utf8.decode(overlayFiles[overlayJsonPath]!))
            as Map<String, dynamic>;

    final mergeResult = _mergeJson(baseJson, overlayJson);
    final outputEntries = <String, List<int>>{
      for (final entry in baseFiles.entries) entry.key: entry.value,
    };

    outputEntries[baseJsonPath] = utf8.encode(
      const JsonEncoder.withIndent('    ').convert(mergeResult.mergedJson),
    );

    final usedOverlayImages = mergeResult.pngFiles.toSet().toList()..sort();
    for (final imageName in usedOverlayImages) {
      final overlayImagePath = _findArchivePath(
        overlayFiles.keys,
        exactPath: 'images/$imageName',
        suffixPath: 'images/$imageName',
      );

      if (overlayImagePath != null) {
        outputEntries['themefile/images/$imageName'] =
            overlayFiles[overlayImagePath]!;
      }
    }

    final archive = Archive();
    final sortedKeys = outputEntries.keys.toList()..sort();
    for (final entryPath in sortedKeys) {
      final bytes = outputEntries[entryPath]!;
      archive.addFile(
        ArchiveFile(entryPath, bytes.length, Uint8List.fromList(bytes)),
      );
    }

    final encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded);
  }

  _MergeResult _mergeJson(
    Map<String, dynamic> sourceJson,
    Map<String, dynamic> overlayJson,
  ) {
    final mergedJson = Map<String, dynamic>.from(sourceJson);
    final pngFiles = <String>[];

    for (final entry in sourceJson.entries) {
      if (!overlayJson.containsKey(entry.key)) {
        continue;
      }

      mergedJson[entry.key] = overlayJson[entry.key];
      pngFiles.addAll(_findAllUsedPng(overlayJson[entry.key]));
    }

    return _MergeResult(mergedJson: mergedJson, pngFiles: pngFiles);
  }

  List<String> _findAllUsedPng(Object? jsonData) {
    final pngFiles = <String>[];

    if (jsonData is String) {
      if (jsonData.toLowerCase().contains('png')) {
        pngFiles.add(path.basename(jsonData));
      }
      return pngFiles;
    }

    if (jsonData is List) {
      for (final item in jsonData) {
        pngFiles.addAll(_findAllUsedPng(item));
      }
      return pngFiles;
    }

    if (jsonData is Map) {
      for (final entry in jsonData.entries) {
        pngFiles.addAll(_findAllUsedPng(entry.key));
        pngFiles.addAll(_findAllUsedPng(entry.value));
      }
    }

    return pngFiles;
  }

  Map<String, List<int>> _buildArchiveFileMap(Archive archive) {
    final output = <String, List<int>>{};

    for (final file in archive.files) {
      if (!file.isFile) {
        continue;
      }

      output[file.name] = List<int>.from(file.content as List<int>);
    }

    return output;
  }

  String? _findArchivePath(
    Iterable<String> candidates, {
    required String exactPath,
    required String suffixPath,
  }) {
    for (final candidate in candidates) {
      if (candidate == exactPath) {
        return candidate;
      }
    }

    for (final candidate in candidates) {
      if (candidate.endsWith(suffixPath)) {
        return candidate;
      }
    }

    return null;
  }
}

class _MergeResult {
  const _MergeResult({required this.mergedJson, required this.pngFiles});

  final Map<String, dynamic> mergedJson;
  final List<String> pngFiles;
}
