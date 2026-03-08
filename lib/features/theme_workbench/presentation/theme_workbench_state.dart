import '../domain/theme_models.dart';

class ThemeWorkbenchState {
  const ThemeWorkbenchState({
    this.installedThemes = const <InstalledTheme>[],
    this.themeBundleInfo,
    this.shizukuStatus,
    this.selectedSlot,
    this.errorMessage,
    this.checkingPermission = true,
    this.hasFileAccess = false,
    this.loadingThemes = false,
    this.resolvingTheme = false,
    this.applyingTheme = false,
    this.progressValue = 0,
    this.progressMessage = '等待開始',
    this.activityLog = const <String>[],
  });

  static const Object _unset = Object();

  final List<InstalledTheme> installedThemes;
  final ThemeBundleInfo? themeBundleInfo;
  final ShizukuStatus? shizukuStatus;
  final String? selectedSlot;
  final String? errorMessage;
  final bool checkingPermission;
  final bool hasFileAccess;
  final bool loadingThemes;
  final bool resolvingTheme;
  final bool applyingTheme;
  final double progressValue;
  final String progressMessage;
  final List<String> activityLog;

  bool get isBusy =>
      checkingPermission || loadingThemes || resolvingTheme || applyingTheme;

  ThemeWorkbenchState copyWith({
    List<InstalledTheme>? installedThemes,
    Object? themeBundleInfo = _unset,
    Object? shizukuStatus = _unset,
    Object? selectedSlot = _unset,
    Object? errorMessage = _unset,
    bool? checkingPermission,
    bool? hasFileAccess,
    bool? loadingThemes,
    bool? resolvingTheme,
    bool? applyingTheme,
    double? progressValue,
    String? progressMessage,
    List<String>? activityLog,
  }) {
    return ThemeWorkbenchState(
      installedThemes: installedThemes ?? this.installedThemes,
      themeBundleInfo: identical(themeBundleInfo, _unset)
          ? this.themeBundleInfo
          : themeBundleInfo as ThemeBundleInfo?,
      shizukuStatus: identical(shizukuStatus, _unset)
          ? this.shizukuStatus
          : shizukuStatus as ShizukuStatus?,
      selectedSlot: identical(selectedSlot, _unset)
          ? this.selectedSlot
          : selectedSlot as String?,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      checkingPermission: checkingPermission ?? this.checkingPermission,
      hasFileAccess: hasFileAccess ?? this.hasFileAccess,
      loadingThemes: loadingThemes ?? this.loadingThemes,
      resolvingTheme: resolvingTheme ?? this.resolvingTheme,
      applyingTheme: applyingTheme ?? this.applyingTheme,
      progressValue: progressValue ?? this.progressValue,
      progressMessage: progressMessage ?? this.progressMessage,
      activityLog: activityLog ?? this.activityLog,
    );
  }
}
