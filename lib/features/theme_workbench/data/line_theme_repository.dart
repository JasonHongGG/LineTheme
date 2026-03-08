import 'dart:io';

import '../domain/theme_archive_merger.dart';
import '../domain/theme_models.dart';
import 'line_store_client.dart';
import 'native_theme_access.dart';

class LineThemeRepository {
  LineThemeRepository({
    NativeThemeAccess? nativeAccess,
    LineStoreClient? storeClient,
    ThemeArchiveMerger? archiveMerger,
  }) : _nativeAccess = nativeAccess ?? NativeThemeAccess(),
       _storeClient = storeClient ?? LineStoreClient(),
       _archiveMerger = archiveMerger ?? ThemeArchiveMerger();

  final NativeThemeAccess _nativeAccess;
  final LineStoreClient _storeClient;
  final ThemeArchiveMerger _archiveMerger;

  Future<ShizukuStatus> getShizukuStatus() {
    return _nativeAccess.getShizukuStatus();
  }

  Future<bool> requestThemeFolderAccess() {
    return _nativeAccess.requestThemeFolderAccess();
  }

  Future<List<InstalledTheme>> listInstalledThemes() {
    return _nativeAccess.listInstalledThemes();
  }

  Future<ThemeBundleInfo> inspectStoreUrl(String storeUrl) {
    return _storeClient.inspectStoreUrl(storeUrl);
  }

  Future<void> applyTheme({
    required String selectedSlot,
    required ThemeBundleInfo themeBundleInfo,
    required void Function(ThemeProcessProgress event) onProgress,
  }) async {
    onProgress(
      const ThemeProcessProgress(
        value: 0.08,
        message: '定位目標 themefile',
        logLine: '掃描已安裝的主題檔案',
      ),
    );

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

    onProgress(
      ThemeProcessProgress(
        value: 0.18,
        message: '下載官方 theme.zip',
        logLine: '下載 ${themeBundleInfo.downloadUrl}',
      ),
    );

    final overlayArchiveBytes = await _storeClient.downloadThemeBundle(
      themeBundleInfo.downloadUrl,
    );

    onProgress(
      const ThemeProcessProgress(
        value: 0.33,
        message: '讀取目標 themefile',
        logLine: '載入原始目標檔案',
      ),
    );

    final originalBytes = await _nativeAccess.readThemeArchive(
      installedTheme.archiveUri,
    );

    onProgress(
      const ThemeProcessProgress(
        value: 0.48,
        message: '合併 JSON 與圖片資源',
        logLine: '依照舊版 Python 規則覆蓋共用 key',
      ),
    );

    final mergedArchiveBytes = _archiveMerger.merge(
      baseArchiveBytes: originalBytes,
      overlayArchiveBytes: overlayArchiveBytes,
    );

    onProgress(
      ThemeProcessProgress(
        value: 0.82,
        message: '覆寫目標 themefile',
        logLine: '寫回 themefile.$selectedSlot',
      ),
    );

    await _nativeAccess.writeThemeArchive(
      installedTheme.archiveUri,
      mergedArchiveBytes,
    );

    onProgress(
      const ThemeProcessProgress(
        value: 0.96,
        message: '處理完成',
        logLine: '新的主題封包已寫入裝置',
      ),
    );
  }

  void dispose() {
    _storeClient.dispose();
  }
}
