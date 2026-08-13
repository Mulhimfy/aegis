import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'semantic_colors.dart';
import 'tokens.dart';

/// The adaptive layer.
///
/// Every screen in the app is built from these. Each one delegates to the real
/// system component: `CupertinoListSection.insetGrouped` and
/// `CupertinoSliverNavigationBar` on iOS, Material 3's `SliverAppBar.large`,
/// `FilledButton` and `ListTile` on Android. Nothing here restyles the system
/// widget it wraps, which is why the app reads as native on both platforms
/// rather than as one design pretending to be two.

/// A full page with a large title that collapses on scroll, matching each
/// platform's own large-title behaviour.
class AdaptivePage extends StatelessWidget {
  const AdaptivePage({
    super.key,
    required this.title,
    required this.slivers,
    this.trailing,
    this.leading,
    this.previousPageTitle,
    this.backgroundColor,
    this.automaticallyImplyLeading = true,
  });

  final String title;
  final List<Widget> slivers;
  final Widget? trailing;
  final Widget? leading;
  final String? previousPageTitle;
  final Color? backgroundColor;
  final bool automaticallyImplyLeading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bg = backgroundColor ?? colors.groupedBackground;

    if (isApple) {
      return CupertinoPageScaffold(
        backgroundColor: bg,
        child: CustomScrollView(
          slivers: [
            CupertinoSliverNavigationBar(
              largeTitle: Text(title),
              previousPageTitle: previousPageTitle,
              leading: leading,
              trailing: trailing,
              automaticallyImplyLeading: automaticallyImplyLeading,
              backgroundColor: bg.withValues(alpha: 0.8),
              border: null,
              stretch: true,
            ),
            ...slivers,
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(title),
            leading: leading,
            actions: trailing == null ? null : [trailing!, const SizedBox(width: Insets.sm)],
            automaticallyImplyLeading: automaticallyImplyLeading,
          ),
          ...slivers,
        ],
      ),
    );
  }
}

/// A grouped section of rows with an optional header, rendered as an iOS inset
/// grouped list or a Material 3 grouped surface.
class AdaptiveSection extends StatelessWidget {
  const AdaptiveSection({
    super.key,
    required this.children,
    this.header,
    this.footer,
    this.margin,
  });

  final List<Widget> children;
  final String? header;
  final String? footer;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;

    if (isApple) {
      return CupertinoListSection.insetGrouped(
        header: header == null ? null : Text(header!),
        footer: footer == null ? null : Text(footer!),
        margin: margin ??
            const EdgeInsets.fromLTRB(Insets.lg, Insets.lg, Insets.lg, 0),
        additionalDividerMargin: 6,
        backgroundColor: const Color(0x00000000),
        children: children,
      );
    }

    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: margin ??
          const EdgeInsets.fromLTRB(Insets.lg, Insets.xl, Insets.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.sm),
              child: Text(
                header!,
                style: textTheme.labelLarge?.copyWith(color: colors.accent),
              ),
            ),
          Material(
            color: colors.surface,
            clipBehavior: Clip.antiAlias,
            borderRadius: BorderRadius.circular(Corners.container),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: Insets.lg,
                      color: colors.separator,
                    ),
                  children[i],
                ],
              ],
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(Insets.lg, Insets.sm, Insets.lg, 0),
              child: Text(
                footer!,
                style: textTheme.bodySmall?.copyWith(color: colors.secondaryLabel),
              ),
            ),
        ],
      ),
    );
  }
}

/// A single row inside an [AdaptiveSection].
class AdaptiveRow extends StatelessWidget {
  const AdaptiveRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.additionalInfo,
    this.onTap,
    this.showChevron = false,
    this.titleColor,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final String? additionalInfo;
  final VoidCallback? onTap;
  final bool showChevron;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (isApple) {
      return CupertinoListTile.notched(
        title: Text(title, style: TextStyle(color: titleColor)),
        subtitle: subtitle == null ? null : Text(subtitle!),
        leading: leading,
        additionalInfo: additionalInfo == null ? null : Text(additionalInfo!),
        trailing: trailing ?? (showChevron ? const CupertinoListTileChevron() : null),
        onTap: onTap,
      );
    }

    return ListTile(
      title: Text(title, style: TextStyle(color: titleColor)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      leading: leading,
      trailing: trailing ??
          (showChevron
              ? Icon(Icons.chevron_right, color: colors.tertiaryLabel)
              : (additionalInfo == null
                  ? null
                  : Text(
                      additionalInfo!,
                      style: TextStyle(color: colors.secondaryLabel),
                    ))),
      onTap: onTap,
    );
  }
}

/// The platform's primary action button.
class AdaptiveFilledButton extends StatelessWidget {
  const AdaptiveFilledButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    Widget button;
    if (isApple) {
      button = CupertinoButton.filled(
        onPressed: onPressed,
        sizeStyle: CupertinoButtonSize.large,
        color: destructive ? colors.critical : null,
        child: _content(context, CupertinoColors.white),
      );
    } else {
      final style = destructive
          ? FilledButton.styleFrom(
              backgroundColor: colors.critical,
              foregroundColor: Theme.of(context).colorScheme.onError,
            )
          : null;
      button = icon == null
          ? FilledButton(onPressed: onPressed, style: style, child: Text(label))
          : FilledButton.icon(
              onPressed: onPressed,
              style: style,
              icon: Icon(icon),
              label: Text(label),
            );
    }

    if (!expand) return button;
    return SizedBox(width: double.infinity, child: button);
  }

  Widget _content(BuildContext context, Color fg) {
    if (icon == null) return Text(label);
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: fg),
        const SizedBox(width: Insets.sm),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

/// The platform's secondary / text button.
class AdaptiveTextButton extends StatelessWidget {
  const AdaptiveTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (isApple) {
      return CupertinoButton(
        onPressed: onPressed,
        padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
        child: Text(
          label,
          style: TextStyle(color: destructive ? colors.critical : colors.accent),
        ),
      );
    }
    final style = destructive
        ? TextButton.styleFrom(foregroundColor: colors.critical)
        : null;
    return icon == null
        ? TextButton(onPressed: onPressed, style: style, child: Text(label))
        : TextButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon),
            label: Text(label),
          );
  }
}

/// The platform's switch.
class AdaptiveSwitch extends StatelessWidget {
  const AdaptiveSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    if (isApple) {
      return CupertinoSwitch(value: value, onChanged: onChanged);
    }
    return Switch(value: value, onChanged: onChanged);
  }
}

/// The platform's indeterminate progress indicator.
class AdaptiveSpinner extends StatelessWidget {
  const AdaptiveSpinner({super.key, this.radius = 12});

  final double radius;

  @override
  Widget build(BuildContext context) {
    if (isApple) return CupertinoActivityIndicator(radius: radius);
    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: const CircularProgressIndicator(strokeWidth: 2.5),
    );
  }
}

/// Modal sheet with the platform's own presentation and drag behaviour.
Future<T?> showAdaptiveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  if (isApple) {
    return showCupertinoSheet<T>(
      context: context,
      // The sheet hands down the controller that drives drag-to-dismiss.
      // Publishing it as the primary controller lets any scrollable inside the
      // sheet opt in without every caller having to thread it through.
      scrollableBuilder: (context, controller) => PrimaryScrollController(
        controller: controller,
        child: Builder(builder: builder),
      ),
      useNestedNavigation: true,
      showDragHandle: true,
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: builder,
  );
}

/// A destructive confirmation, using an action sheet on iOS and a dialog on
/// Android as each platform prescribes.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  if (isApple) {
    final result = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(title),
        message: Text(message),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
      ),
    );
    return result ?? false;
  }

  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Brief confirmation feedback: a snackbar on Android, and on iOS a transient
/// overlay, since HIG has no snackbar equivalent.
void showTransientMessage(BuildContext context, String message) {
  if (!isApple) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
    return;
  }

  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;
  final colors = context.colors;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => Positioned(
      left: Insets.xl,
      right: Insets.xl,
      bottom: MediaQuery.paddingOf(context).bottom + Insets.huge,
      child: IgnorePointer(
        child: _FadeIn(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: CupertinoDynamicColor.resolve(
                CupertinoColors.secondarySystemBackground,
                context,
              ),
              borderRadius: BorderRadius.circular(Corners.pill),
              boxShadow: [
                BoxShadow(
                  color: CupertinoColors.black.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Insets.lg,
                vertical: Insets.md,
              ),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.label,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future<void>.delayed(const Duration(milliseconds: 1900), entry.remove);
}

class _FadeIn extends StatefulWidget {
  const _FadeIn({required this.child});
  final Widget child;

  @override
  State<_FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<_FadeIn> {
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _opacity = 1);
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
        opacity: _opacity,
        duration: Motion.quick,
        curve: Motion.emphasized,
        child: widget.child,
      );
}

/// Haptics that match what each platform uses for the same moment.
abstract final class Feedback2 {
  static void selection() => HapticFeedback.selectionClick();
  static void light() => HapticFeedback.lightImpact();
  static void success() =>
      isApple ? HapticFeedback.mediumImpact() : HapticFeedback.lightImpact();
  static void warning() => HapticFeedback.heavyImpact();
}
