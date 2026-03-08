import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'line_theme_service.dart';

void main() {
  runApp(const LineThemeTesterApp());
}

class LineThemeTesterApp extends StatelessWidget {
  const LineThemeTesterApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTextTheme = GoogleFonts.notoSansTcTextTheme();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LINE Theme Tester',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E6B5B), brightness: Brightness.light),
        scaffoldBackgroundColor: const Color(0xFFF6F1E8),
        textTheme: baseTextTheme,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFF2E6B5B), width: 1.5),
          ),
        ),
      ),
      home: const ThemeWorkbenchPage(),
    );
  }
}

class ThemeWorkbenchPage extends StatefulWidget {
  const ThemeWorkbenchPage({super.key});

  @override
  State<ThemeWorkbenchPage> createState() => _ThemeWorkbenchPageState();
}

class _ThemeWorkbenchPageState extends State<ThemeWorkbenchPage> with WidgetsBindingObserver {
  final LineThemeService _service = LineThemeService();
  final TextEditingController _urlController = TextEditingController(text: 'https://store.line.me/themeshop/product/36a8914b-b9cf-4b8e-8d61-e5e572124440/zh-Hant');

  List<InstalledTheme> _installedThemes = const [];
  ThemeBundleInfo? _themeBundleInfo;
  ShizukuStatus? _shizukuStatus;
  String? _selectedSlot;
  String? _errorMessage;
  bool _checkingPermission = true;
  bool _hasFileAccess = false;
  bool _loadingThemes = false;
  bool _resolvingTheme = false;
  bool _applyingTheme = false;
  double _progressValue = 0;
  String _progressMessage = '等待開始';
  final List<String> _activityLog = <String>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_bootstrap());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_bootstrap());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _urlController.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _checkingPermission = true;
      _errorMessage = null;
    });

    try {
      final status = await _service.getShizukuStatus();
      setState(() {
        _shizukuStatus = status;
        _hasFileAccess = status.isReady;
      });

      if (status.isReady) {
        await _reloadInstalledThemes();
      }
    } catch (error) {
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _checkingPermission = false;
        });
      }
    }
  }

  Future<void> _requestAccess() async {
    setState(() {
      _checkingPermission = true;
      _errorMessage = null;
    });

    try {
      final granted = await _service.requestThemeFolderAccess();
      final status = await _service.getShizukuStatus();
      setState(() {
        _shizukuStatus = status;
        _hasFileAccess = status.isReady;
      });

      if (granted && status.isReady) {
        await _reloadInstalledThemes();
      } else {
        setState(() {
          _errorMessage = _buildShizukuGuidance(status);
        });
      }
    } catch (error) {
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _checkingPermission = false;
        });
      }
    }
  }

  String _buildShizukuGuidance(ShizukuStatus? status) {
    if (status == null || !status.binderAvailable) {
      return '目前還沒有接上 Shizuku binder。請確認 Shizuku 畫面顯示「正在執行」，然後把 app 從最近工作清掉後重開一次。';
    }

    if (status.permissionGranted) {
      return 'Shizuku 已連線，但主題列表尚未重新整理。請再按一次重新掃描。';
    }

    if (status.shouldShowRationale) {
      return 'Shizuku 已連線，但此 app 先前被拒絕授權。請到 Shizuku 的已授權/已拒絕應用程式清單裡，重新允許 LINE Theme Tester。';
    }

    return 'Shizuku 已連線，但尚未授權給此 app。按下按鈕後應該會跳出授權視窗；如果沒有，先把 app 重開再試一次。';
  }

  String _formatThemeLabel(InstalledTheme theme) {
    return 'themefile.${theme.slot}  •  ${theme.directoryName}';
  }

  Future<void> _reloadInstalledThemes() async {
    setState(() {
      _loadingThemes = true;
      _errorMessage = null;
    });

    try {
      final themes = await _service.listInstalledThemes();
      setState(() {
        _installedThemes = themes;
        if (themes.isNotEmpty) {
          final stillExists = themes.any((theme) => theme.slot == _selectedSlot);
          _selectedSlot = stillExists ? _selectedSlot : themes.first.slot;
        } else {
          _selectedSlot = null;
        }
      });
    } catch (error) {
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingThemes = false;
        });
      }
    }
  }

  Future<void> _resolveTheme() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _resolvingTheme = true;
      _errorMessage = null;
      _progressValue = 0.1;
      _progressMessage = '解析輸入網址';
    });

    try {
      final info = await _service.inspectStoreUrl(_urlController.text.trim());
      setState(() {
        _themeBundleInfo = info;
        _progressValue = 0.22;
        _progressMessage = '已取得主題資訊與版本';
        _appendLog('找到 Theme ID ${info.themeId} / version ${info.version}');
      });
    } catch (error) {
      setState(() {
        _errorMessage = error.toString();
        _progressValue = 0;
        _progressMessage = '網址解析失敗';
      });
    } finally {
      if (mounted) {
        setState(() {
          _resolvingTheme = false;
        });
      }
    }
  }

  Future<void> _applyTheme() async {
    final selectedSlot = _selectedSlot;
    if (selectedSlot == null) {
      setState(() {
        _errorMessage = '請先選擇要覆寫的 themefile 代號。';
      });
      return;
    }

    ThemeBundleInfo? info = _themeBundleInfo;
    if (info == null) {
      await _resolveTheme();
      info = _themeBundleInfo;
      if (info == null) {
        return;
      }
    }

    setState(() {
      _applyingTheme = true;
      _errorMessage = null;
      _activityLog.clear();
    });

    try {
      await _service.applyTheme(
        selectedSlot: selectedSlot,
        themeBundleInfo: info,
        onProgress: (event) {
          if (!mounted) {
            return;
          }
          setState(() {
            _progressValue = event.value;
            _progressMessage = event.message;
            if (event.logLine != null) {
              _appendLog(event.logLine!);
            }
          });
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _progressValue = 1;
        _progressMessage = '已完成並覆寫 themefile.$selectedSlot';
        _appendLog('themefile.$selectedSlot 已完成更新');
      });
    } catch (error) {
      setState(() {
        _errorMessage = error.toString();
        _appendLog('處理失敗: $error');
      });
    } finally {
      if (mounted) {
        setState(() {
          _applyingTheme = false;
        });
      }
    }
  }

  void _appendLog(String line) {
    _activityLog.insert(0, line);
    if (_activityLog.length > 8) {
      _activityLog.removeLast();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _checkingPermission || _loadingThemes || _resolvingTheme || _applyingTheme;
    final info = _themeBundleInfo;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: <Color>[Color(0xFFF7F2E8), Color(0xFFE5EFE6), Color(0xFFD7E5E0)]),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _hasFileAccess ? _reloadInstalledThemes : _bootstrap,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              children: <Widget>[
                _HeroPanel(
                  title: 'LINE Theme Tester',
                  subtitle: '輸入 LINE Store 主題網址，下載官方 theme zip，合併到指定的 themefile 並直接覆寫到 LINE 的 theme 資料夾。',
                  trailing: FilledButton.tonalIcon(onPressed: isBusy ? null : _reloadInstalledThemes, icon: const Icon(Icons.refresh_rounded), label: const Text('重新掃描')),
                ),
                const SizedBox(height: 18),
                _SectionCard(
                  title: '1. Theme 目標槽位',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('目標路徑: ${LineThemeService.lineThemeRootPath}', style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 12),
                      if (_checkingPermission)
                        const LinearProgressIndicator()
                      else if (!_hasFileAccess)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(_shizukuStatus?.binderAvailable == true ? 'Shizuku 已連線，但此 app 尚未完成授權。' : 'Shizuku 尚未就緒。'),
                            const SizedBox(height: 10),
                            const Text('1. 先安裝並啟動 Shizuku'),
                            const SizedBox(height: 4),
                            const Text('2. 回到這裡按下方按鈕請求授權'),
                            const SizedBox(height: 12),
                            _ShizukuStatusPanel(status: _shizukuStatus),
                            const SizedBox(height: 10),
                            FilledButton.icon(onPressed: _requestAccess, icon: const Icon(Icons.security_rounded), label: const Text('請求 Shizuku 授權')),
                          ],
                        )
                      else if (_loadingThemes)
                        const LinearProgressIndicator()
                      else if (_installedThemes.isEmpty)
                        const Text('Shizuku 已授權，但找不到任何已安裝的 themefile.xxx。請確認 LINE 主題資料夾存在，且各子資料夾內有 themefile.xxx。')
                      else
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _selectedSlot,
                          decoration: const InputDecoration(labelText: '選擇要覆寫的 themefile 代號'),
                          selectedItemBuilder: (context) {
                            return _installedThemes
                                .map(
                                  (theme) => Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(_formatThemeLabel(theme), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                )
                                .toList();
                          },
                          items: _installedThemes
                              .map(
                                (theme) => DropdownMenuItem<String>(
                                  value: theme.slot,
                                  child: Text(_formatThemeLabel(theme), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ),
                              )
                              .toList(),
                          onChanged: isBusy
                              ? null
                              : (value) {
                                  setState(() {
                                    _selectedSlot = value;
                                  });
                                },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _SectionCard(
                  title: '2. 輸入主題網址',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      TextField(
                        controller: _urlController,
                        enabled: !_applyingTheme,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'LINE Theme Store URL', hintText: 'https://store.line.me/themeshop/product/...'),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: <Widget>[
                          FilledButton.icon(onPressed: _resolvingTheme || _applyingTheme ? null : _resolveTheme, icon: const Icon(Icons.travel_explore_rounded), label: const Text('解析網址')),
                          OutlinedButton.icon(onPressed: (!_hasFileAccess || isBusy || _selectedSlot == null) ? null : _applyTheme, icon: const Icon(Icons.auto_fix_high_rounded), label: const Text('下載並套用')),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _SectionCard(
                  title: '3. 主題預覽與處理狀態',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Container(
                              height: 240,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(22),
                                color: const Color(0xFFE9E3D8),
                                image: info == null ? null : DecorationImage(image: NetworkImage(info.coverUrl), fit: BoxFit.cover),
                              ),
                              child: info == null ? const Center(child: Text('解析網址後會顯示封面')) : null,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                _InfoLine(label: '目標槽位', value: _selectedSlot == null ? '未選擇' : 'themefile.$_selectedSlot'),
                                _InfoLine(label: 'Theme ID', value: info?.themeId ?? '尚未解析'),
                                _InfoLine(label: 'Version', value: info?.version.toString() ?? '尚未解析'),
                                _InfoLine(label: '平台', value: 'ANDROID'),
                                const SizedBox(height: 12),
                                LinearProgressIndicator(value: _progressValue == 0 ? null : _progressValue),
                                const SizedBox(height: 8),
                                Text(_progressMessage),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: const Color(0xFF153D36), borderRadius: BorderRadius.circular(18)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Activity',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 10),
                            if (_activityLog.isEmpty)
                              Text('尚未開始處理', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70))
                            else
                              for (final line in _activityLog)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(line, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white)),
                                ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_errorMessage != null) ...<Widget>[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: const Color(0xFFFFE5DE), borderRadius: BorderRadius.circular(18)),
                    child: Text(
                      _errorMessage!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF7A2415), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShizukuStatusPanel extends StatelessWidget {
  const _ShizukuStatusPanel({required this.status});

  final ShizukuStatus? status;

  @override
  Widget build(BuildContext context) {
    final effectiveStatus = status;
    final entries = <(String, String)>[
      ('Binder', effectiveStatus == null ? '未知' : (effectiveStatus.binderAvailable ? '已連線' : '未連線')),
      ('授權', effectiveStatus == null ? '未知' : (effectiveStatus.permissionGranted ? '已允許' : '未允許')),
      ('Rationale', effectiveStatus == null ? '未知' : (effectiveStatus.shouldShowRationale ? '需到 Shizuku 內重新允許' : '可直接請求')),
      ('Service', effectiveStatus == null || effectiveStatus.serviceVersion < 0 ? '未知' : effectiveStatus.serviceVersion.toString()),
      ('UID', effectiveStatus == null || effectiveStatus.serverUid < 0 ? '未知' : effectiveStatus.serverUid.toString()),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD6E4DA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Shizuku 狀態', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final (label, value) in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('$label: $value', style: Theme.of(context).textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.title, required this.subtitle, required this.trailing});

  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(colors: <Color>[Color(0xFF1B5347), Color(0xFF2D6A5B), Color(0xFF7BA992)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x33153D36), blurRadius: 30, offset: Offset(0, 18))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(subtitle, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              trailing,
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFBF7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5DDD0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF253A34)),
          children: <InlineSpan>[
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
