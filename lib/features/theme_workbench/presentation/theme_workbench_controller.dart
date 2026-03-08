import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/line_theme_repository.dart';
import '../domain/theme_models.dart';
import 'theme_workbench_state.dart';

class ThemeWorkbenchController extends ChangeNotifier with WidgetsBindingObserver {
  ThemeWorkbenchController({LineThemeRepository? repository}) : _repository = repository ?? LineThemeRepository() {
    urlController.addListener(notifyListeners);
  }

  final LineThemeRepository _repository;
  final TextEditingController urlController = TextEditingController(text: 'https://store.line.me/themeshop/product/63d469be-e4c4-46d9-8822-bc8ddcc2fb0f/zh-Hant');

  ThemeWorkbenchState _state = const ThemeWorkbenchState();
  bool _initialized = false;

  ThemeWorkbenchState get state => _state;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
    await bootstrap();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(bootstrap());
    }
  }

  Future<void> bootstrap() async {
    _updateState(_state.copyWith(checkingPermission: true, errorMessage: null));

    try {
      final status = await _repository.getShizukuStatus();
      _updateState(_state.copyWith(shizukuStatus: status, hasFileAccess: status.isReady));

      if (status.isReady) {
        await reloadInstalledThemes();
      }
    } catch (error) {
      _updateState(_state.copyWith(errorMessage: error.toString()));
    } finally {
      _updateState(_state.copyWith(checkingPermission: false));
    }
  }

  Future<void> requestAccess() async {
    _updateState(_state.copyWith(checkingPermission: true, errorMessage: null));

    try {
      final granted = await _repository.requestThemeFolderAccess();
      final status = await _repository.getShizukuStatus();
      _updateState(_state.copyWith(shizukuStatus: status, hasFileAccess: status.isReady));

      if (granted && status.isReady) {
        await reloadInstalledThemes();
      } else {
        _updateState(_state.copyWith(errorMessage: _buildShizukuGuidance(status)));
      }
    } catch (error) {
      _updateState(_state.copyWith(errorMessage: error.toString()));
    } finally {
      _updateState(_state.copyWith(checkingPermission: false));
    }
  }

  Future<void> reloadInstalledThemes() async {
    _updateState(_state.copyWith(loadingThemes: true, errorMessage: null));

    try {
      final themes = await _repository.listInstalledThemes();
      final selectedSlot = themes.isEmpty
          ? null
          : themes.any((theme) => theme.slot == _state.selectedSlot)
          ? _state.selectedSlot
          : themes.first.slot;

      _updateState(_state.copyWith(installedThemes: themes, selectedSlot: selectedSlot));
    } catch (error) {
      _updateState(_state.copyWith(errorMessage: error.toString()));
    } finally {
      _updateState(_state.copyWith(loadingThemes: false));
    }
  }

  Future<void> resolveTheme() async {
    FocusManager.instance.primaryFocus?.unfocus();

    var sourceUrl = urlController.text.trim();
    if (sourceUrl.isEmpty) {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final clipboardText = clipboardData?.text?.trim() ?? '';
      if (clipboardText.isEmpty) {
        _updateState(_state.copyWith(errorMessage: '請先輸入主題網址，或先把網址複製到剪貼簿。', progressValue: 0, progressMessage: '等待網址'));
        return;
      }

      sourceUrl = clipboardText;
      urlController.value = TextEditingValue(
        text: clipboardText,
        selection: TextSelection.collapsed(offset: clipboardText.length),
      );
    }

    _updateState(_state.copyWith(resolvingTheme: true, errorMessage: null, progressValue: 0.1, progressMessage: '解析輸入網址'));

    try {
      final info = await _repository.inspectStoreUrl(sourceUrl);
      _updateState(_state.copyWith(themeBundleInfo: info, progressValue: 0.22, progressMessage: '已取得主題資訊與版本', activityLog: _prependLog(_state.activityLog, '找到 Theme ID ${info.themeId} / version ${info.version}')));
    } catch (error) {
      _updateState(_state.copyWith(errorMessage: error.toString(), progressValue: 0, progressMessage: '網址解析失敗'));
    } finally {
      _updateState(_state.copyWith(resolvingTheme: false));
    }
  }

  Future<void> applyTheme() async {
    final selectedSlot = _state.selectedSlot;
    if (selectedSlot == null) {
      _updateState(_state.copyWith(errorMessage: '請先選擇要覆寫的 themefile 代號。'));
      return;
    }

    var info = _state.themeBundleInfo;
    if (info == null) {
      await resolveTheme();
      info = _state.themeBundleInfo;
      if (info == null) {
        return;
      }
    }

    _updateState(_state.copyWith(applyingTheme: true, errorMessage: null, activityLog: const <String>[]));

    try {
      await _repository.applyTheme(
        selectedSlot: selectedSlot,
        themeBundleInfo: info,
        onProgress: (event) {
          _updateState(_state.copyWith(progressValue: event.value, progressMessage: event.message, activityLog: event.logLine == null ? _state.activityLog : _prependLog(_state.activityLog, event.logLine!)));
        },
      );

      _updateState(_state.copyWith(progressValue: 1, progressMessage: '已完成並覆寫 themefile.$selectedSlot', activityLog: _prependLog(_state.activityLog, 'themefile.$selectedSlot 已完成更新')));
    } catch (error) {
      _updateState(_state.copyWith(errorMessage: error.toString(), activityLog: _prependLog(_state.activityLog, '處理失敗: $error')));
    } finally {
      _updateState(_state.copyWith(applyingTheme: false));
    }
  }

  void selectSlot(String? value) {
    _updateState(_state.copyWith(selectedSlot: value));
  }

  void clearUrl() {
    urlController.clear();
    _updateState(_state.copyWith(errorMessage: null));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    urlController.removeListener(notifyListeners);
    urlController.dispose();
    _repository.dispose();
    super.dispose();
  }

  String _buildShizukuGuidance(ShizukuStatus? status) {
    if (status == null || !status.binderAvailable) {
      return '目前還沒有接上 Shizuku binder。請確認 Shizuku 畫面顯示「正在執行」，然後把 app 從最近工作清掉後重開一次。';
    }

    if (status.permissionGranted) {
      return 'Shizuku 已連線，但主題列表尚未重新整理。請再按一次重新掃描。';
    }

    if (status.shouldShowRationale) {
      return 'Shizuku 已連線，但此 app 先前被拒絕授權。請到 Shizuku 的已授權/已拒絕應用程式清單裡，重新允許 LINE Theme。';
    }

    return 'Shizuku 已連線，但尚未授權給此 app。按下按鈕後應該會跳出授權視窗；如果沒有，先把 app 重開再試一次。';
  }

  List<String> _prependLog(List<String> current, String line) {
    final next = <String>[line, ...current];
    if (next.length > 8) {
      return next.take(8).toList(growable: false);
    }
    return next;
  }

  void _updateState(ThemeWorkbenchState nextState) {
    _state = nextState;
    notifyListeners();
  }
}
