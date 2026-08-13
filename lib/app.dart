import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'core/app_scope.dart';
import 'core/design/theme.dart';
import 'core/design/tokens.dart';
import 'data/prefs/store.dart';
import 'data/probe/probe_channel.dart';
import 'features/scan/scan_controller.dart';
import 'features/scan/scan_page.dart';
import 'features/share/referral.dart';
import 'features/share/share_service.dart';
import 'features/welcome/welcome_page.dart';

/// The application root.
///
/// Builds a `CupertinoApp` on Apple platforms and a `MaterialApp` on Android,
/// rather than one app widget wearing the other's clothes. That decision at the
/// root is what lets every screen below use its platform's real navigation,
/// real transitions and real text scaling without fighting anything.
class AegisApp extends StatefulWidget {
  const AegisApp({
    super.key,
    required this.store,
    required this.probe,
    this.share,
  });

  final Store store;
  final DeviceProbe probe;
  final ShareService? share;

  @override
  State<AegisApp> createState() => _AegisAppState();
}

class _AegisAppState extends State<AegisApp> {
  late final ScanController _controller;
  late final ShareService _share;
  late final AppLinks _links;
  StreamSubscription<Uri>? _linkSubscription;

  Invite? _invite;
  bool _onboarded = false;

  @override
  void initState() {
    super.initState();
    _controller = ScanController(
      probe: widget.probe,
      store: widget.store,
    );
    _share = widget.share ?? ShareService();
    _onboarded = widget.store.onboarded;
    _listenForInvites();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// An invite link is the app's front door for most of its users, so it is
  /// handled both as a cold start and while running.
  Future<void> _listenForInvites() async {
    _links = AppLinks();
    try {
      final initial = await _links.getInitialLink();
      if (initial != null) _handleLink(initial);
    } on Exception {
      // A platform without link support simply has no invites to deliver.
    }
    _linkSubscription = _links.uriLinkStream.listen(
      _handleLink,
      onError: (Object _) {},
    );
  }

  void _handleLink(Uri uri) {
    final invite = Referral.parse(uri);
    if (invite == null) return;

    // Attribution is recorded once, on the first link that ever arrives. A
    // later link from someone else does not overwrite who actually introduced
    // this person to the app.
    if (widget.store.invitedBy() == null) {
      unawaited(widget.store.setInvitedBy(invite.code));
    }
    if (mounted) setState(() => _invite = invite);
  }

  Future<void> _begin() async {
    await widget.store.completeOnboarding();
    if (!mounted) return;
    setState(() => _onboarded = true);
    unawaited(_controller.run());
  }

  @override
  Widget build(BuildContext context) {
    final home = _onboarded
        ? const ScanPage()
        : WelcomePage(invite: _invite, onBegin: _begin);

    // The scope sits above the app, and therefore above its Navigator. Pushed
    // routes and modal sheets are built by that Navigator, so anything below it
    // would leave every pushed page unable to see the controller.
    return AppScope(
      controller: _controller,
      store: widget.store,
      share: _share,
      child: isApple
          ? CupertinoApp(
              title: 'Aegis',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.cupertino(
                MediaQuery.platformBrightnessOf(context),
              ),
              home: home,
            )
          // Android 12 and later generate a colour scheme from the user's
          // wallpaper. Honouring it is what makes the app look like it came
          // with the phone.
          : DynamicColorBuilder(
              builder: (lightScheme, darkScheme) => MaterialApp(
                title: 'Aegis',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.material(Brightness.light, lightScheme),
                darkTheme: AppTheme.material(Brightness.dark, darkScheme),
                home: home,
              ),
            ),
    );
  }
}
