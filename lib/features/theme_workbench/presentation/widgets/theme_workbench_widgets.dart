import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

class WorkbenchSurfaceCard extends StatelessWidget {
  const WorkbenchSurfaceCard({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.radius = 28, this.backgroundColor = const Color(0xF9FFFCF7), this.borderColor = const Color(0x14FFFFFF)});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
        boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x14171411), blurRadius: 24, offset: Offset(0, 14))],
      ),
      child: child,
    );
  }
}

class WorkbenchAnimatedReveal extends StatefulWidget {
  const WorkbenchAnimatedReveal({super.key, required this.child, this.delay = Duration.zero, this.offset = const Offset(0, 0.05)});

  final Widget child;
  final Duration delay;
  final Offset offset;

  @override
  State<WorkbenchAnimatedReveal> createState() => _WorkbenchAnimatedRevealState();
}

class _WorkbenchAnimatedRevealState extends State<WorkbenchAnimatedReveal> {
  bool _visible = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (mounted) {
        setState(() {
          _visible = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      offset: _visible ? Offset.zero : widget.offset,
      child: AnimatedOpacity(duration: const Duration(milliseconds: 420), curve: Curves.easeOut, opacity: _visible ? 1 : 0, child: widget.child),
    );
  }
}

class WorkbenchSectionHeader extends StatelessWidget {
  const WorkbenchSectionHeader({super.key, required this.title, required this.subtitle, required this.icon, this.iconBackground = const Color(0x14C88D5B), this.iconColor = const Color(0xFFC88D5B)});

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(shape: BoxShape.circle, color: iconBackground),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: const Color(0xFF7A726A), letterSpacing: 0.8, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: GoogleFonts.notoSansTc(fontSize: 22, height: 1.18, fontWeight: FontWeight.w800, color: const Color(0xFF201E1C)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class WorkbenchCompactStatus extends StatelessWidget {
  const WorkbenchCompactStatus({super.key, required this.label, required this.value, required this.icon, required this.tint});

  final String label;
  final String value;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), color: tint.withValues(alpha: 0.1)),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 16, color: tint),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: const Color(0xFF7A726A))),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(color: const Color(0xFF201E1C), fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class WorkbenchInfoTile extends StatelessWidget {
  const WorkbenchInfoTile({super.key, required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFFF7F2EA),
        border: Border.all(color: const Color(0xFFE6DED2)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(color: Color(0x14C88D5B), shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: const Color(0xFFC88D5B)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: const Color(0xFF7A726A))),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(color: const Color(0xFF201E1C), fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class WorkbenchSelectableCard extends StatelessWidget {
  const WorkbenchSelectableCard({super.key, required this.title, required this.subtitle, required this.selected, required this.onTap, required this.onLongPress});

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  String get _compactSubtitle {
    if (subtitle.length <= 28) {
      return subtitle;
    }

    return '${subtitle.substring(0, 8)}...${subtitle.substring(subtitle.length - 10)}';
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = selected ? const Color(0xFF22252B) : const Color(0xFFF3ECE2);
    final titleColor = selected ? Colors.white : const Color(0xFF201E1C);
    final subtitleColor = selected ? Colors.white.withValues(alpha: 0.72) : const Color(0xFF7A726A);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: backgroundColor,
            border: Border.all(color: selected ? const Color(0x33FFFFFF) : const Color(0xFFE5DCCF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: titleColor, fontWeight: FontWeight.w800, height: 1.15),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (selected)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), color: Colors.white.withValues(alpha: 0.12)),
                      child: Text(
                        '已選擇',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _compactSubtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: subtitleColor, fontWeight: FontWeight.w700, height: 1.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WorkbenchProgressStrip extends StatelessWidget {
  const WorkbenchProgressStrip({super.key, required this.value, required this.label});

  final double value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final safeValue = value.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF514A44))),
            ),
            const SizedBox(width: 12),
            Text(
              '${(safeValue * 100).round()}%',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: const Color(0xFF201E1C), fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: safeValue),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (context, animatedValue, _) {
              return LinearProgressIndicator(value: animatedValue == 0 ? 0.02 : animatedValue, minHeight: 10, backgroundColor: const Color(0xFFE2D7CA), color: const Color(0xFFC88D5B));
            },
          ),
        ),
      ],
    );
  }
}

class WorkbenchHeroOrnament extends StatelessWidget {
  const WorkbenchHeroOrnament({super.key, required this.animationValue});

  final double animationValue;

  @override
  Widget build(BuildContext context) {
    final offset = math.sin(animationValue * math.pi * 2) * 6;

    return Transform.translate(offset: Offset(0, offset), child: SvgPicture.string(_heroSvg, width: 112, height: 112));
  }
}

class WorkbenchEmptyPreview extends StatelessWidget {
  const WorkbenchEmptyPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[Color(0xFFF6F1EA), Color(0xFFEDE6DC)]),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SvgPicture.string(_previewSvg, width: 168, height: 152),
              const SizedBox(height: 18),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '貼上網址即可預覽',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: const Color(0xFF3B342E), fontWeight: FontWeight.w800, height: 1.2),
                ),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '解析後帶入主題資訊',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF8B7F74), fontWeight: FontWeight.w700, height: 1.2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WorkbenchAmbientBackdrop extends StatelessWidget {
  const WorkbenchAmbientBackdrop({super.key, required this.animationValue});

  final double animationValue;

  @override
  Widget build(BuildContext context) {
    final drift = math.sin(animationValue * math.pi * 2) * 20;

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[Color(0xFFF7F2EA), Color(0xFFF1E9DF), Color(0xFFE9E1D8)]),
            ),
          ),
          Positioned(
            top: -90 + drift,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: <Color>[Color(0x55E1C29F), Color(0x00E1C29F)]),
              ),
            ),
          ),
          Positioned(
            left: -80,
            bottom: -110 - drift,
            child: Container(
              width: 240,
              height: 240,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: <Color>[Color(0x40A7B0BC), Color(0x00A7B0BC)]),
              ),
            ),
          ),
          Positioned(
            top: 120 + drift,
            right: 30,
            child: Opacity(opacity: 0.18, child: SvgPicture.string(_gridSvg, width: 120, height: 120)),
          ),
        ],
      ),
    );
  }
}

const String _heroSvg = '''
<svg viewBox="0 0 112 112" fill="none" xmlns="http://www.w3.org/2000/svg">
  <rect x="8" y="8" width="96" height="96" rx="28" fill="#2A2D33"/>
  <path d="M32 77C40 56 53 38 74 28C82 24 90 23 97 25C92 40 86 57 76 74C66 89 52 100 35 105C29 96 27 86 32 77Z" fill="#D5B18C"/>
  <path d="M29 38C40 42 53 50 67 62C81 74 90 85 94 94C81 99 67 101 52 99C37 97 26 89 18 77C20 61 24 48 29 38Z" fill="#8593A5" fill-opacity="0.68"/>
  <circle cx="79" cy="37" r="8" fill="#FFF7ED"/>
</svg>
''';

const String _previewSvg = '''
<svg viewBox="0 0 180 132" fill="none" xmlns="http://www.w3.org/2000/svg">
  <rect x="24" y="18" width="132" height="96" rx="24" fill="#F5EEE6" stroke="#E4D9CC"/>
  <rect x="42" y="34" width="54" height="64" rx="18" fill="#D0AE86"/>
  <circle cx="58" cy="48" r="6" fill="#FFF8F0"/>
  <rect x="106" y="38" width="34" height="8" rx="4" fill="#DCCFC2"/>
  <rect x="106" y="52" width="28" height="8" rx="4" fill="#E4D9CD"/>
  <rect x="106" y="66" width="22" height="8" rx="4" fill="#EAE0D4"/>
  <rect x="106" y="84" width="26" height="18" rx="9" fill="#A0ABB8"/>
  <path d="M119 88V98" stroke="#FFF8F0" stroke-width="5" stroke-linecap="round"/>
  <path d="M114 93H124" stroke="#FFF8F0" stroke-width="5" stroke-linecap="round"/>
  <circle cx="146" cy="34" r="5" fill="#D0AE86"/>
  <circle cx="152" cy="46" r="3" fill="#A0ABB8"/>
  <circle cx="136" cy="46" r="3" fill="#E6DCCE"/>
</svg>
''';

const String _gridSvg = '''
<svg viewBox="0 0 160 160" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M0 40H160M0 80H160M0 120H160M40 0V160M80 0V160M120 0V160" stroke="#7B756D" stroke-opacity="0.24"/>
</svg>
''';
