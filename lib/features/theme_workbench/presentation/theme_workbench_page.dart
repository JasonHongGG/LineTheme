import 'dart:async';

import 'package:flutter/material.dart';

import '../data/native_theme_access.dart';
import '../domain/theme_models.dart';
import 'theme_workbench_controller.dart';
import 'theme_workbench_state.dart';

class ThemeWorkbenchPage extends StatefulWidget {
  const ThemeWorkbenchPage({super.key});

  @override
  State<ThemeWorkbenchPage> createState() => _ThemeWorkbenchPageState();
}

class _ThemeWorkbenchPageState extends State<ThemeWorkbenchPage> {
  late final ThemeWorkbenchController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ThemeWorkbenchController();
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final state = _controller.state;
        final info = state.themeBundleInfo;

        return Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: <Color>[Color(0xFFF7F2E8), Color(0xFFE5EFE6), Color(0xFFD7E5E0)]),
            ),
            child: SafeArea(
              child: RefreshIndicator(
                onRefresh: state.hasFileAccess ? _controller.reloadInstalledThemes : _controller.bootstrap,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                  children: <Widget>[
                    _HeroPanel(
                      title: 'LINE Theme Tester',
                      subtitle: '輸入 LINE Store 主題網址，下載官方 theme zip，合併到指定的 themefile 並直接覆寫到 LINE 的 theme 資料夾。',
                      trailing: FilledButton.tonalIcon(onPressed: state.isBusy ? null : _controller.reloadInstalledThemes, icon: const Icon(Icons.refresh_rounded), label: const Text('重新掃描')),
                    ),
                    const SizedBox(height: 18),
                    _ThemeSlotSection(controller: _controller, state: state),
                    const SizedBox(height: 18),
                    _ThemeUrlSection(controller: _controller, state: state),
                    const SizedBox(height: 18),
                    _ThemePreviewSection(state: state, info: info),
                    if (state.errorMessage != null) ...<Widget>[
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: const Color(0xFFFFE5DE), borderRadius: BorderRadius.circular(18)),
                        child: Text(
                          state.errorMessage!,
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
      },
    );
  }
}

class _ThemeSlotSection extends StatelessWidget {
  const _ThemeSlotSection({required this.controller, required this.state});

  final ThemeWorkbenchController controller;
  final ThemeWorkbenchState state;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '1. Theme 目標槽位',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('目標路徑: ${NativeThemeAccess.lineThemeRootPath}', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          if (state.checkingPermission)
            const LinearProgressIndicator()
          else if (!state.hasFileAccess)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(state.shizukuStatus?.binderAvailable == true ? 'Shizuku 已連線，但此 app 尚未完成授權。' : 'Shizuku 尚未就緒。'),
                const SizedBox(height: 10),
                const Text('1. 先安裝並啟動 Shizuku'),
                const SizedBox(height: 4),
                const Text('2. 回到這裡按下方按鈕請求授權'),
                const SizedBox(height: 12),
                _ShizukuStatusPanel(status: state.shizukuStatus),
                const SizedBox(height: 10),
                FilledButton.icon(onPressed: controller.requestAccess, icon: const Icon(Icons.security_rounded), label: const Text('請求 Shizuku 授權')),
              ],
            )
          else if (state.loadingThemes)
            const LinearProgressIndicator()
          else if (state.installedThemes.isEmpty)
            const Text('Shizuku 已授權，但找不到任何已安裝的 themefile.xxx。請確認 LINE 主題資料夾存在，且各子資料夾內有 themefile.xxx。')
          else
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: state.selectedSlot,
              decoration: const InputDecoration(labelText: '選擇要覆寫的 themefile 代號'),
              selectedItemBuilder: (context) {
                return state.installedThemes
                    .map(
                      (theme) => Align(
                        alignment: Alignment.centerLeft,
                        child: Text('themefile.${theme.slot}  •  ${theme.directoryName}', maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList();
              },
              items: state.installedThemes
                  .map(
                    (theme) => DropdownMenuItem<String>(
                      value: theme.slot,
                      child: Text('themefile.${theme.slot}  •  ${theme.directoryName}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: state.isBusy ? null : controller.selectSlot,
            ),
        ],
      ),
    );
  }
}

class _ThemeUrlSection extends StatelessWidget {
  const _ThemeUrlSection({required this.controller, required this.state});

  final ThemeWorkbenchController controller;
  final ThemeWorkbenchState state;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '2. 輸入主題網址',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: controller.urlController,
            enabled: !state.applyingTheme,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'LINE Theme Store URL', hintText: 'https://store.line.me/themeshop/product/...'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              FilledButton.icon(onPressed: state.resolvingTheme || state.applyingTheme ? null : controller.resolveTheme, icon: const Icon(Icons.travel_explore_rounded), label: const Text('解析網址')),
              OutlinedButton.icon(onPressed: (!state.hasFileAccess || state.isBusy || state.selectedSlot == null) ? null : controller.applyTheme, icon: const Icon(Icons.auto_fix_high_rounded), label: const Text('下載並套用')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemePreviewSection extends StatelessWidget {
  const _ThemePreviewSection({required this.state, required this.info});

  final ThemeWorkbenchState state;
  final ThemeBundleInfo? info;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
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
                    image: info == null ? null : DecorationImage(image: NetworkImage(info!.coverUrl), fit: BoxFit.cover),
                  ),
                  child: info == null ? const Center(child: Text('解析網址後會顯示封面')) : null,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _InfoLine(label: '目標槽位', value: state.selectedSlot == null ? '未選擇' : 'themefile.${state.selectedSlot}'),
                    _InfoLine(label: 'Theme ID', value: info?.themeId ?? '尚未解析'),
                    _InfoLine(label: 'Version', value: info?.version.toString() ?? '尚未解析'),
                    const _InfoLine(label: '平台', value: 'ANDROID'),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(value: state.progressValue == 0 ? null : state.progressValue),
                    const SizedBox(height: 8),
                    Text(state.progressMessage),
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
                if (state.activityLog.isEmpty)
                  Text('尚未開始處理', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70))
                else
                  for (final line in state.activityLog)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(line, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white)),
                    ),
              ],
            ),
          ),
        ],
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Wrap(
        runSpacing: 8,
        spacing: 8,
        children: entries
            .map(
              (entry) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFFF3F5F1), borderRadius: BorderRadius.circular(12)),
                child: Text('${entry.$1}: ${entry.$2}'),
              ),
            )
            .toList(),
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
      decoration: BoxDecoration(color: const Color(0xFF173D36), borderRadius: BorderRadius.circular(26)),
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
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Text(subtitle, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
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
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.88), borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyLarge,
          children: <InlineSpan>[
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
