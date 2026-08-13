import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'data/prefs/store.dart';
import 'data/probe/probe_channel.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The system bars belong to the system. Making them transparent lets the
  // OS draw its own contrast scrim over whatever the app puts underneath,
  // which is what every first-party app on both platforms does.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final store = await Store.open();

  runApp(AegissApp(store: store, probe: ProbeChannel()));
}
