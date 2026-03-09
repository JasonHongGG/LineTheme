import 'dart:io';

import 'package:flutter/services.dart';

import '../domain/theme_models.dart';

class NativeThemeAccess {
  static const String lineThemeRootPath = '/storage/emulated/0/Android/data/jp.naver.line.android/files/theme';
  static const MethodChannel _channel = MethodChannel('line_theme/theme_access');

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

  Future<Uint8List> readThemeArchive(String archivePath) async {
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

  Future<void> writeThemeArchive(String archivePath, Uint8List bytes) async {
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
