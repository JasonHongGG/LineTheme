import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/native_theme_access.dart';
import '../domain/theme_models.dart';
import 'theme_workbench_controller.dart';
import 'theme_workbench_state.dart';
import 'widgets/theme_workbench_widgets.dart';

class ThemeWorkbenchPage extends StatefulWidget {
  const ThemeWorkbenchPage({super.key});

  @override
  State<ThemeWorkbenchPage> createState() => _ThemeWorkbenchPageState();
}

class _ThemeWorkbenchPageState extends State<ThemeWorkbenchPage>
    with SingleTickerProviderStateMixin {
  late final ThemeWorkbenchController _controller;
  late final AnimationController _ambientController;

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();
    _controller = ThemeWorkbenchController();
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    _ambientController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        _controller,
        _ambientController,
      ]),
      builder: (context, _) {
        final state = _controller.state;

        return Scaffold(
          body: Stack(
            children: <Widget>[
              WorkbenchAmbientBackdrop(
                animationValue: _ambientController.value,
              ),
              SafeArea(
                child: RefreshIndicator(
                  color: const Color(0xFFC88D5B),
                  onRefresh: state.hasFileAccess
                      ? _controller.reloadInstalledThemes
                      : _controller.bootstrap,
                  child: ListView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
                    children: <Widget>[
                      WorkbenchAnimatedReveal(
                        delay: const Duration(milliseconds: 70),
                        child: _AccessSection(
                          controller: _controller,
                          state: state,
                        ),
                      ),
                      const SizedBox(height: 14),
                      WorkbenchAnimatedReveal(
                        delay: const Duration(milliseconds: 140),
                        child: _SlotSection(
                          controller: _controller,
                          state: state,
                        ),
                      ),
                      const SizedBox(height: 14),
                      WorkbenchAnimatedReveal(
                        delay: const Duration(milliseconds: 210),
                        child: _UrlSection(
                          controller: _controller,
                          state: state,
                        ),
                      ),
                      const SizedBox(height: 14),
                      WorkbenchAnimatedReveal(
                        delay: const Duration(milliseconds: 280),
                        child: _PreviewSection(state: state),
                      ),
                      const SizedBox(height: 14),
                      WorkbenchAnimatedReveal(
                        delay: const Duration(milliseconds: 350),
                        child: _ProgressSection(state: state),
                      ),
                      if (state.errorMessage != null) ...<Widget>[
                        const SizedBox(height: 14),
                        WorkbenchAnimatedReveal(
                          delay: const Duration(milliseconds: 420),
                          child: _ErrorBanner(message: state.errorMessage!),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AccessSection extends StatelessWidget {
  const _AccessSection({required this.controller, required this.state});

  final ThemeWorkbenchController controller;
  final ThemeWorkbenchState state;

  @override
  Widget build(BuildContext context) {
    return WorkbenchSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const WorkbenchSectionHeader(
            title: 'Shizuku 授權',
            subtitle: 'ACCESS',
            icon: Icons.shield_outlined,
          ),
          const SizedBox(height: 16),
          Text(
            NativeThemeAccess.lineThemeRootPath,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF514A44),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 16),
          if (state.checkingPermission)
            const _InlineNotice(
              icon: Icons.sync_rounded,
              message: '正在確認 Shizuku 狀態與資料夾權限。',
            )
          else if (state.hasFileAccess)
            const _InlineNotice(
              icon: Icons.check_circle_rounded,
              message: '權限已就緒，可以開始選擇槽位並套用主題。',
              tint: Color(0xFFC88D5B),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _InlineNotice(
                  icon: Icons.info_outline_rounded,
                  message: _buildAccessMessage(state.shizukuStatus),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: state.isBusy ? null : controller.requestAccess,
                    icon: const Icon(Icons.lock_open_rounded),
                    label: const Text('開通主題資料夾權限'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _buildAccessMessage(ShizukuStatus? status) {
    if (status == null || !status.binderAvailable) {
      return 'Shizuku 尚未連線。先確認服務正在執行，再回到這裡重新授權。';
    }
    if (status.permissionGranted) {
      return '權限看起來已存在，但還沒刷新到主題列表，往下拉重新整理即可。';
    }
    if (status.shouldShowRationale) {
      return '此 App 曾被拒絕授權，請到 Shizuku 內重新允許。';
    }
    return '按下按鈕後應會出現 Shizuku 授權視窗。';
  }
}

class _SlotSection extends StatelessWidget {
  const _SlotSection({required this.controller, required this.state});

  final ThemeWorkbenchController controller;
  final ThemeWorkbenchState state;

  @override
  Widget build(BuildContext context) {
    return WorkbenchSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Expanded(
                child: WorkbenchSectionHeader(
                  title: '選擇槽位',
                  subtitle: 'TARGET',
                  icon: Icons.folder_copy_outlined,
                ),
              ),
              const SizedBox(width: 12),
              _HintEntryButton(onTap: () => _showSlotGuide(context)),
            ],
          ),
          const SizedBox(height: 14),
          if (!state.hasFileAccess)
            const _InlineNotice(
              icon: Icons.lock_outline_rounded,
              message: '先完成上方授權，才會讀取可覆寫的 themefile 槽位。',
            )
          else if (state.loadingThemes)
            const _InlineNotice(
              icon: Icons.sync_rounded,
              message: '正在讀取已安裝的 themefile 槽位。',
            )
          else if (state.installedThemes.isEmpty)
            const _InlineNotice(
              icon: Icons.search_off_rounded,
              message: '目前找不到任何已安裝主題槽位，請確認 LINE 主題資料夾內容。',
              tint: Color(0xFFB4503C),
            )
          else ...<Widget>[
            Column(
              children: state.installedThemes.map((theme) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: WorkbenchSelectableCard(
                    title: 'themefile.${theme.slot}',
                    subtitle: theme.directoryName,
                    selected: state.selectedSlot == theme.slot,
                    onTap: state.isBusy
                        ? () {}
                        : () => controller.selectSlot(theme.slot),
                    onLongPress: () =>
                        _copyThemeId(context, theme.directoryName),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  void _showSlotGuide(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFFFFCF7),
      builder: (context) {
        final textTheme = Theme.of(context).textTheme;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '槽位操作',
                style: textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF201E1C),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              const _GuideLine(
                icon: Icons.touch_app_rounded,
                title: '短按卡片',
                body: '直接選擇要覆寫的 themefile 槽位。',
              ),
              const SizedBox(height: 10),
              const _GuideLine(
                icon: Icons.content_copy_rounded,
                title: '長按卡片',
                body: '複製該槽位的 ID。',
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _copyThemeId(BuildContext context, String themeId) async {
    await Clipboard.setData(ClipboardData(text: themeId));
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已複製 ID: $themeId'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1400),
      ),
    );
  }
}

class _HintEntryButton extends StatelessWidget {
  const _HintEntryButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFF3ECE2),
            border: Border.all(color: const Color(0xFFE4D9CA)),
          ),
          child: const Center(
            child: Icon(
              Icons.priority_high_rounded,
              size: 18,
              color: Color(0xFF6F655C),
            ),
          ),
        ),
      ),
    );
  }
}

class _GuideLine extends StatelessWidget {
  const _GuideLine({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFF3ECE2),
          ),
          child: Icon(icon, color: const Color(0xFFC88D5B), size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: const Color(0xFF201E1C),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF514A44),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UrlSection extends StatelessWidget {
  const _UrlSection({required this.controller, required this.state});

  final ThemeWorkbenchController controller;
  final ThemeWorkbenchState state;

  @override
  Widget build(BuildContext context) {
    return WorkbenchSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const WorkbenchSectionHeader(
            title: '主題網址',
            subtitle: 'SOURCE',
            icon: Icons.link_rounded,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller.urlController,
            enabled: !state.applyingTheme,
            maxLines: 1,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'LINE Theme Store URL',
              hintText: '貼上主題網址',
              prefixIcon: const Icon(Icons.link_rounded),
              suffixIcon: controller.urlController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '清除網址',
                      onPressed: state.applyingTheme
                          ? null
                          : controller.clearUrl,
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: state.resolvingTheme || state.applyingTheme
                  ? null
                  : controller.resolveTheme,
              icon: const Icon(Icons.travel_explore_rounded),
              label: Text(state.resolvingTheme ? '解析中...' : '解析網址'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed:
                  (!state.hasFileAccess ||
                      state.isBusy ||
                      state.selectedSlot == null)
                  ? null
                  : controller.applyTheme,
              icon: const Icon(Icons.auto_fix_high_rounded),
              label: Text(state.applyingTheme ? '套用中...' : '下載並套用'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewSection extends StatelessWidget {
  const _PreviewSection({required this.state});

  final ThemeWorkbenchState state;

  @override
  Widget build(BuildContext context) {
    final info = state.themeBundleInfo;

    return WorkbenchSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const WorkbenchSectionHeader(
            title: '主題預覽',
            subtitle: 'PREVIEW',
            icon: Icons.palette_outlined,
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color(0xFFF6F3EE), Color(0xFFEEE8DF)],
                ),
              ),
              child: AspectRatio(
                aspectRatio: 198 / 278,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F3EE),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: info == null
                        ? const WorkbenchEmptyPreview()
                        : Image.network(
                            info.coverUrl,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) {
                                return child;
                              }
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFFC88D5B),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return const WorkbenchEmptyPreview();
                            },
                          ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (info != null)
            Column(
              children: <Widget>[
                _PreviewInfoRow(
                  label: 'Theme ID',
                  value: info.themeId,
                  icon: Icons.tag_rounded,
                ),
                const SizedBox(height: 10),
                _PreviewInfoRow(
                  label: '版本',
                  value: info.version.toString(),
                  icon: Icons.update_rounded,
                ),
                const SizedBox(height: 10),
                _PreviewInfoRow(
                  label: '下載來源',
                  value: info.downloadUrl.toString(),
                  icon: Icons.cloud_download_outlined,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PreviewInfoRow extends StatelessWidget {
  const _PreviewInfoRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onLongPress: () => _copyValue(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF3ECE2),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE5DCCF)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0x14C88D5B),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 19, color: const Color(0xFFC88D5B)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            label,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: const Color(0xFF7A726A),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.content_copy_rounded,
                          size: 16,
                          color: Color(0xFF9A8E82),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _compactValue(),
                      maxLines: label == '下載來源' ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF201E1C),
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _compactValue() {
    if (label == '版本') {
      return value;
    }

    if (label == '下載來源') {
      final uri = Uri.tryParse(value);
      if (uri != null) {
        return '${uri.host}${uri.path}';
      }
      return value;
    }

    if (value.length <= 18) {
      return value;
    }

    return '${value.substring(0, 8)}...${value.substring(value.length - 6)}';
  }

  Future<void> _copyValue(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已複製$label'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }
}

class _ProgressSection extends StatelessWidget {
  const _ProgressSection({required this.state});

  final ThemeWorkbenchState state;

  @override
  Widget build(BuildContext context) {
    final logs = state.activityLog.take(3).toList(growable: false);

    return WorkbenchSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const WorkbenchSectionHeader(
            title: '處理進度',
            subtitle: 'STATUS',
            icon: Icons.timeline_rounded,
          ),
          const SizedBox(height: 16),
          WorkbenchProgressStrip(
            value: state.progressValue,
            label: state.progressMessage,
          ),
          const SizedBox(height: 14),
          if (logs.isEmpty)
            const _InlineNotice(
              icon: Icons.chat_bubble_outline_rounded,
              message: '目前還沒有操作紀錄。開始解析或套用後會顯示最近進度。',
            )
          else
            Column(
              children: logs.map((line) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F2EA),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE6DED2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.fiber_manual_record_rounded,
                            size: 12,
                            color: Color(0xFFC88D5B),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            line,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: const Color(0xFF514A44),
                                  height: 1.45,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.icon,
    required this.message,
    this.tint = const Color(0xFF6F7C8D),
  });

  final IconData icon;
  final String message;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: tint.withValues(alpha: 0.1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: tint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF514A44),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFFFFEEE9),
        border: Border.all(color: const Color(0xFFF1C1B4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.error_outline_rounded, color: Color(0xFFB4503C)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF7A3023),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
