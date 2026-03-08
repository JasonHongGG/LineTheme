import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class InstalledTheme {
  const InstalledTheme({required this.slot, required this.directoryName, required this.archiveUri});

  final String slot;
  final String directoryName;
  final String archiveUri;
}

class ThemeBundleInfo {
  const ThemeBundleInfo({required this.storeUrl, required this.coverUrl, required this.themeId, required this.version, required this.downloadUrl});

  final String storeUrl;
  final String coverUrl;
  final String themeId;
  final int version;
  final Uri downloadUrl;
}

class ThemeProcessProgress {
  const ThemeProcessProgress({required this.value, required this.message, this.logLine});

  final double value;
  final String message;
  final String? logLine;
}

class ShizukuStatus {
  const ShizukuStatus({required this.binderAvailable, required this.permissionGranted, required this.shouldShowRationale, required this.serviceVersion, required this.serverUid});

  final bool binderAvailable;
  final bool permissionGranted;
  final bool shouldShowRationale;
  final int serviceVersion;
  final int serverUid;

  bool get isReady => binderAvailable && permissionGranted;
}

class _MergeResult {
  const _MergeResult({required this.mergedJson, required this.pngFiles});

  final Map<String, dynamic> mergedJson;
  final List<String> pngFiles;
}

class LineThemeService {
  static const String lineThemeRootPath = '/storage/emulated/0/Android/data/jp.naver.line.android/files/theme';
  static const MethodChannel _channel = MethodChannel('line_theme_tester/theme_access');

  final http.Client _client;

  LineThemeService({http.Client? client}) : _client = client ?? http.Client();

  void dispose() {
    _client.close();
  }

  Future<bool> hasThemeFolderAccess() async {
    await _ensureAndroid();
    try {
      return (await _channel.invokeMethod<bool>('isShizukuReady')) ?? false;
    } on MissingPluginException {
      throw StateError(_nativeSyncErrorMessage());
    }
  }

  Future<ShizukuStatus> getShizukuStatus() async {
    await _ensureAndroid();

    try {
      final raw = await _channel.invokeMapMethod<Object?, Object?>('getShizukuStatus');
      final map = Map<Object?, Object?>.from(raw ?? const <Object?, Object?>{});

      return ShizukuStatus(binderAvailable: map['binderAvailable'] == true, permissionGranted: map['permissionGranted'] == true, shouldShowRationale: map['shouldShowRationale'] == true, serviceVersion: (map['serviceVersion'] as int?) ?? -1, serverUid: (map['serverUid'] as int?) ?? -1);
    } on MissingPluginException {
      throw StateError(_nativeSyncErrorMessage());
    }
  }

  Future<bool> requestThemeFolderAccess() async {
    await _ensureAndroid();
    try {
      return (await _channel.invokeMethod<bool>('requestShizukuPermission')) ?? false;
    } on MissingPluginException {
      throw StateError(_nativeSyncErrorMessage());
    }
  }

  Future<List<InstalledTheme>> listInstalledThemes() async {
    await _ensureAndroid();

    try {
      final rawThemes = await _channel.invokeListMethod<dynamic>('listInstalledThemes');
      if (rawThemes == null) {
        return const <InstalledTheme>[];
      }

      return rawThemes.map((dynamic item) {
        final map = Map<Object?, Object?>.from(item as Map<Object?, Object?>);
        return InstalledTheme(slot: map['slot']! as String, directoryName: map['directoryName']! as String, archiveUri: map['archiveUri']! as String);
      }).toList();
    } on PlatformException catch (error) {
      throw FileSystemException(error.message ?? '列出已安裝主題失敗。');
    }
  }

  Future<ThemeBundleInfo> inspectStoreUrl(String storeUrl) async {
    final uri = Uri.tryParse(storeUrl);
    if (uri == null || !uri.hasScheme) {
      throw const FormatException('LINE Theme URL 格式不正確。');
    }

    final response = await _client.get(uri, headers: const <String, String>{'content-type': 'text/html; charset=UTF-8', 'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'});

    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('讀取 LINE Store 頁面失敗，HTTP ${response.statusCode}');
    }

    final document = html_parser.parse(response.body);
    final coverUrl = _extractCoverUrl(document.outerHtml);
    if (coverUrl == null) {
      throw const FormatException('找不到主題封面圖，無法推算版本號。');
    }

    final normalizedCoverUrl = coverUrl.startsWith('//') ? 'https:$coverUrl' : coverUrl;
    final coverUri = Uri.parse(normalizedCoverUrl);
    final segments = coverUri.pathSegments;
    final productsIndex = segments.indexOf('products');

    if (productsIndex < 0 || segments.length <= productsIndex + 5) {
      throw const FormatException('封面圖 URL 格式不符合預期，無法解析 theme id / version。');
    }

    final themeId = segments[productsIndex + 4];
    final version = int.tryParse(segments[productsIndex + 5]);
    if (themeId.length < 6 || version == null) {
      throw const FormatException('封面圖 URL 缺少正確的主題版本資訊。');
    }

    final downloadUrl = Uri.parse(
      'https://shop.line-scdn.net/themeshop/v1/products/'
      '${themeId.substring(0, 2)}/${themeId.substring(2, 4)}/${themeId.substring(4, 6)}/'
      '$themeId/$version/ANDROID/theme.zip',
    );

    return ThemeBundleInfo(storeUrl: storeUrl, coverUrl: normalizedCoverUrl, themeId: themeId, version: version, downloadUrl: downloadUrl);
  }

  Future<void> applyTheme({required String selectedSlot, required ThemeBundleInfo themeBundleInfo, required void Function(ThemeProcessProgress event) onProgress}) async {
    await _ensureAndroid();

    onProgress(const ThemeProcessProgress(value: 0.08, message: '定位目標 themefile', logLine: '掃描已安裝的主題檔案'));

    InstalledTheme? installedTheme;
    for (final theme in await listInstalledThemes()) {
      if (theme.slot == selectedSlot) {
        installedTheme = theme;
        break;
      }
    }

    if (installedTheme == null) {
      throw FileSystemException('找不到 themefile.$selectedSlot');
    }

    onProgress(ThemeProcessProgress(value: 0.18, message: '下載官方 theme.zip', logLine: '下載 ${themeBundleInfo.downloadUrl}'));

    final sourceResponse = await _client.get(themeBundleInfo.downloadUrl);
    if (sourceResponse.statusCode != HttpStatus.ok) {
      throw HttpException('下載官方主題失敗，HTTP ${sourceResponse.statusCode}');
    }

    onProgress(const ThemeProcessProgress(value: 0.33, message: '讀取目標 themefile', logLine: '載入原始目標檔案'));

    final originalBytes = await _readThemeArchive(installedTheme.archiveUri);

    onProgress(const ThemeProcessProgress(value: 0.48, message: '合併 JSON 與圖片資源', logLine: '依照舊版 Python 規則覆蓋共用 key'));

    final mergedArchiveBytes = _mergeThemeArchives(baseArchiveBytes: originalBytes, overlayArchiveBytes: sourceResponse.bodyBytes);

    onProgress(ThemeProcessProgress(value: 0.82, message: '覆寫目標 themefile', logLine: '寫回 themefile.$selectedSlot'));

    await _writeThemeArchive(installedTheme.archiveUri, mergedArchiveBytes);

    onProgress(const ThemeProcessProgress(value: 0.96, message: '處理完成', logLine: '新的主題封包已寫入裝置'));
  }

  Uint8List _mergeThemeArchives({required List<int> baseArchiveBytes, required List<int> overlayArchiveBytes}) {
    final baseArchive = ZipDecoder().decodeBytes(baseArchiveBytes, verify: false);
    final overlayArchive = ZipDecoder().decodeBytes(overlayArchiveBytes, verify: false);

    final baseFiles = _buildArchiveFileMap(baseArchive);
    final overlayFiles = _buildArchiveFileMap(overlayArchive);

    final baseJsonPath = _findArchivePath(baseFiles.keys, exactPath: 'themefile/theme.json', suffixPath: 'theme.json');
    final overlayJsonPath = _findArchivePath(overlayFiles.keys, exactPath: 'theme.json', suffixPath: 'theme.json');

    if (baseJsonPath == null || overlayJsonPath == null) {
      throw const FormatException('缺少 theme.json，無法進行合併。');
    }

    final baseJson = json.decode(utf8.decode(baseFiles[baseJsonPath]!)) as Map<String, dynamic>;
    final overlayJson = json.decode(utf8.decode(overlayFiles[overlayJsonPath]!)) as Map<String, dynamic>;

    final mergeResult = _mergeJson(baseJson, overlayJson);

    final outputEntries = <String, List<int>>{for (final entry in baseFiles.entries) entry.key: entry.value};

    outputEntries[baseJsonPath] = utf8.encode(const JsonEncoder.withIndent('    ').convert(mergeResult.mergedJson));

    final usedOverlayImages = mergeResult.pngFiles.toSet().toList()..sort();
    for (final imageName in usedOverlayImages) {
      final overlayImagePath = _findArchivePath(overlayFiles.keys, exactPath: 'images/$imageName', suffixPath: 'images/$imageName');

      if (overlayImagePath != null) {
        outputEntries['themefile/images/$imageName'] = overlayFiles[overlayImagePath]!;
      }
    }

    final archive = Archive();
    final sortedKeys = outputEntries.keys.toList()..sort();
    for (final entryPath in sortedKeys) {
      final bytes = outputEntries[entryPath]!;
      archive.addFile(ArchiveFile(entryPath, bytes.length, Uint8List.fromList(bytes)));
    }

    final encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded);
  }

  _MergeResult _mergeJson(Map<String, dynamic> sourceJson, Map<String, dynamic> overlayJson) {
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

  String? _findArchivePath(Iterable<String> candidates, {required String exactPath, required String suffixPath}) {
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

  String? _extractCoverUrl(String htmlSource) {
    final match = RegExp(r'''(https?:)?//shop\.line-scdn\.net/themeshop/v1/products/[^"']+/icon_198x278\.png''', caseSensitive: false).firstMatch(htmlSource);

    return match?.group(0);
  }

  Future<Uint8List> _readThemeArchive(String archivePath) async {
    try {
      final bytes = await _channel.invokeMethod<Uint8List>('readThemeArchive', <String, dynamic>{'archiveUri': archivePath});
      if (bytes == null) {
        throw const FileSystemException('讀取目標 themefile 失敗。');
      }
      return bytes;
    } on PlatformException catch (error) {
      throw FileSystemException(error.message ?? '讀取目標 themefile 失敗。');
    }
  }

  Future<void> _writeThemeArchive(String archivePath, Uint8List bytes) async {
    try {
      await _channel.invokeMethod<void>('writeThemeArchive', <String, dynamic>{'archiveUri': archivePath, 'bytes': bytes});
    } on PlatformException catch (error) {
      throw FileSystemException(error.message ?? '寫入目標 themefile 失敗。');
    }
  }

  Future<void> _ensureAndroid() async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('這個測試工具目前只支援 Android 裝置。');
    }
  }

  String _nativeSyncErrorMessage() {
    return '目前執行中的 app 還是舊版 Android native 程式碼。請完整關掉目前的 flutter run，重新安裝一次 app，再試 Shizuku。';
  }
}
