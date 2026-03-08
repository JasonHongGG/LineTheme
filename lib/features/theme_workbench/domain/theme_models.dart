class InstalledTheme {
  const InstalledTheme({required this.slot, required this.directoryName, required this.archiveUri});

  final String slot;
  final String directoryName;
  final String archiveUri;
}

class ThemeBundleInfo {
  const ThemeBundleInfo({required this.coverUrl, required this.themeId, required this.version, required this.downloadUrl});

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
