import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_scope.dart';
import '../../core/design/adaptive.dart';
import '../../core/design/semantic_colors.dart';
import '../../core/design/tokens.dart';
import '../../domain/catalog.dart';
import '../../domain/check.dart';

/// The policy, served from the repo's GitHub Pages site.
///
/// App Store Review 5.1.1(i) wants this link in two places: the App Store
/// listing and somewhere reachable inside the app. Settings is the second one.
const privacyPolicyUrl = 'https://mulhimfy.github.io/aegis/privacy.html';

/// Settings.
///
/// No switches. Every one of them is a decision the app failed to make.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
  }

  Future<void> _erase() async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Erase what Aegiss remembers?',
      message: 'Your answers and your invite code. Your phone is not changed.',
      confirmLabel: 'Erase',
    );
    if (!confirmed || !mounted) return;

    await AppScope.read(context).store.eraseEverything();
    if (!mounted) return;
    Feedback2.warning();
    showTransientMessage(context, 'Erased.');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final device = context.scan.signals;

    return AdaptivePage(
      title: 'Settings',
      previousPageTitle: 'Aegiss',
      slivers: [
        SliverToBoxAdapter(
          child: AdaptiveSection(
            children: [
              AdaptiveRow(
                title: 'What Aegiss checks',
                additionalInfo: '${Catalog.allChecks.length}',
                onTap: () => Navigator.of(context).push(
                  isApple
                      ? CupertinoPageRoute<void>(
                          builder: (_) => const _CatalogPage(),
                          title: 'Settings',
                        )
                      : MaterialPageRoute<void>(
                          builder: (_) => const _CatalogPage(),
                        ),
                ),
                showChevron: true,
              ),
              AdaptiveRow(
                title: 'Phone',
                additionalInfo: device?.deviceModel.isNotEmpty == true
                    ? device!.deviceModel
                    : 'Unknown',
              ),
              AdaptiveRow(
                title: 'OS',
                additionalInfo: device == null
                    ? 'Unknown'
                    : '${device.isIOS ? "iOS" : "Android"} ${device.osVersion}',
              ),
              AdaptiveRow(title: 'Version', additionalInfo: _version),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: AdaptiveSection(
            footer: 'Aegiss has no server. Everything it knows is on this phone.',
            children: [
              AdaptiveRow(
                title: 'Privacy policy',
                titleColor: context.colors.accent,
                onTap: () => launchUrl(
                  Uri.parse(privacyPolicyUrl),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              AdaptiveRow(
                title: 'Erase what Aegiss remembers',
                titleColor: context.colors.critical,
                onTap: _erase,
              ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: MediaQuery.paddingOf(context).bottom + Insets.xl,
          ),
        ),
      ],
    );
  }
}

/// The full catalog, in the open. An app that will not say what it looks at is
/// asking for trust it has not earned.
class _CatalogPage extends StatelessWidget {
  const _CatalogPage();

  @override
  Widget build(BuildContext context) {
    final byArea = <CheckArea, List<Check>>{};
    for (final check in Catalog.allChecks) {
      byArea.putIfAbsent(check.area, () => []).add(check);
    }

    return AdaptivePage(
      title: 'Checks',
      previousPageTitle: 'Settings',
      slivers: [
        for (final area in CheckArea.values)
          if (byArea[area] != null)
            SliverToBoxAdapter(
              child: AdaptiveSection(
                header: area.label,
                children: [
                  for (final check in byArea[area]!)
                    AdaptiveRow(
                      title: check.title,
                      subtitle: check.source == CheckSource.measured
                          ? 'Read from the OS'
                          : 'You confirm it',
                    ),
                ],
              ),
            ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: MediaQuery.paddingOf(context).bottom + Insets.xl,
          ),
        ),
      ],
    );
  }
}
