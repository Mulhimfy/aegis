import 'package:flutter/widgets.dart';

import '../data/prefs/store.dart';
import '../features/scan/scan_controller.dart';
import '../features/share/share_service.dart';

/// Dependency scope.
///
/// The app has one controller and three services, so an inherited widget is the
/// whole of its dependency injection. Adding a framework for four objects would
/// be more code to read and nothing to gain.
class AppScope extends InheritedNotifier<ScanController> {
  const AppScope({
    super.key,
    required ScanController controller,
    required this.store,
    required this.share,
    required super.child,
  }) : super(notifier: controller);

  final Store store;
  final ShareService share;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope above this widget.');
    return scope!;
  }

  /// Reads the scope without subscribing, for callbacks that only act.
  static AppScope read(BuildContext context) {
    final element =
        context.getElementForInheritedWidgetOfExactType<AppScope>();
    assert(element != null, 'No AppScope above this widget.');
    return element!.widget as AppScope;
  }

  static ScanController controllerOf(BuildContext context) =>
      of(context).notifier!;

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      super.updateShouldNotify(oldWidget) ||
      store != oldWidget.store ||
      share != oldWidget.share;
}

extension AppScopeX on BuildContext {
  ScanController get scan => AppScope.controllerOf(this);
  Store get store => AppScope.of(this).store;
  ShareService get shareService => AppScope.of(this).share;
}
