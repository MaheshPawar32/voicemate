import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/vokey_theme.dart';

/// Rounded neon card used across the app.
class NeonCard extends StatelessWidget {
  const NeonCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.glow,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? glow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: VokeyTokens.card,
          borderRadius: BorderRadius.circular(VokeyTokens.radius),
          border: Border.all(
            color: glow?.withValues(alpha: .55) ?? VokeyTokens.cardBorder,
          ),
          boxShadow: glow == null
              ? null
              : [
                  BoxShadow(color: glow!.withValues(alpha: .18), blurRadius: 24)
                ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(VokeyTokens.radius),
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      );
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Text(
          text,
          style: const TextStyle(
            color: VokeyTokens.muted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: .3,
          ),
        ),
      );
}

/// Icon tile + title/subtitle + trailing (chevron by default).
class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor = VokeyTokens.cyan,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: NeonCard(
          onTap: onTap,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              IconBadge(icon: icon, color: iconColor),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: VokeyTokens.muted,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              trailing ??
                  (onTap == null
                      ? const SizedBox.shrink()
                      : const Icon(
                          Icons.chevron_right_rounded,
                          color: VokeyTokens.muted,
                        )),
            ],
          ),
        ),
      );
}

class IconBadge extends StatelessWidget {
  const IconBadge(
      {super.key,
      required this.icon,
      this.color = VokeyTokens.cyan,
      this.size = 40});
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(size * .32),
        ),
        child: Icon(icon, color: color, size: size * .55),
      );
}

class ToggleRow extends StatelessWidget {
  const ToggleRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => SettingRow(
        icon: icon,
        title: title,
        subtitle: subtitle,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        trailing: Switch(value: value, onChanged: onChanged),
      );
}

/// Small coloured status capsule: "Granted", "Running", "ON".
class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, this.color = VokeyTokens.success});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 7, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}

/// Pill-style segmented selector (Single / Double / Triple, Overview / Daily …).
class PillSegments<T> extends StatelessWidget {
  const PillSegments({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final Map<T, String> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: VokeyTokens.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: VokeyTokens.cardBorder),
        ),
        child: Row(
          children: [
            for (final entry in options.entries)
              Expanded(
                child: Semantics(
                  selected: entry.key == value,
                  button: true,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onChanged(entry.key);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        gradient: entry.key == value
                            ? const LinearGradient(
                                colors: [VokeyTokens.violet, Color(0xFF5B5BF0)],
                              )
                            : null,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        entry.value,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: entry.key == value
                              ? Colors.white
                              : VokeyTokens.muted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

/// Red "Stop" pill used for every stop control.
class DangerButton extends StatelessWidget {
  const DangerButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.stop_rounded,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
        onPressed: onPressed == null
            ? null
            : () {
                HapticFeedback.mediumImpact();
                onPressed!();
              },
        icon: Icon(icon),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: VokeyTokens.error,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
        ),
      );
}

/// Labelled slider row with a percentage/value readout.
class LabeledSlider extends StatelessWidget {
  const LabeledSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.display,
    this.divisions,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;
  final String display;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(display, style: const TextStyle(color: VokeyTokens.muted)),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: display,
            onChanged: onChanged,
          ),
        ],
      );
}

/// Live equalizer bars driven by a 0..1 level. Static when [level] is null.
class LevelBars extends StatelessWidget {
  const LevelBars(
      {super.key, required this.level, this.bars = 21, this.height = 44});
  final double? level;
  final int bars;
  final double height;

  @override
  Widget build(BuildContext context) {
    final l = (level ?? 0).clamp(0.0, 1.0);
    return Semantics(
      label: 'Microphone level ${(l * 100).round()} percent',
      child: SizedBox(
        height: height,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(bars, (i) {
            final centre = 1 - (i - bars / 2).abs() / (bars / 2);
            final shape = .25 + .75 * centre * (.6 + .4 * math.sin(i * 1.7));
            final h = 4 + (height - 4) * shape * (.15 + .85 * l);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 110),
              width: 3.5,
              height: h,
              margin: const EdgeInsets.symmetric(horizontal: 1.6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: const LinearGradient(
                  colors: [VokeyTokens.cyan, VokeyTokens.violet],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Neutral empty state with optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          children: [
            IconBadge(icon: icon, size: 64, color: VokeyTokens.violet),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: VokeyTokens.muted, height: 1.45),
            ),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      );
}

/// Inline error/notice banner with optional retry.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    super.key,
    required this.message,
    this.color = VokeyTokens.error,
    this.onDismiss,
    this.icon = Icons.info_outline_rounded,
  });

  final String message;
  final Color color;
  final VoidCallback? onDismiss;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: .35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: TextStyle(color: color, height: 1.4)),
            ),
            if (onDismiss != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Dismiss',
                onPressed: onDismiss,
                icon: Icon(Icons.close_rounded, color: color, size: 18),
              ),
          ],
        ),
      );
}

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '${h.toString().padLeft(2, '0')}:$m:$s' : '$m:$s';
}

/// Bottom sheet with a single-choice list; returns the picked value or null.
Future<T?> showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required Map<T, String> options,
  required T current,
}) =>
    showModalBottomSheet<T>(
      context: context,
      backgroundColor: VokeyTokens.surface,
      builder: (sheetContext) => SafeArea(
        child: RadioGroup<T>(
          groupValue: current,
          onChanged: (v) => Navigator.pop(sheetContext, v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              for (final entry in options.entries)
                RadioListTile<T>(value: entry.key, title: Text(entry.value)),
            ],
          ),
        ),
      ),
    );
