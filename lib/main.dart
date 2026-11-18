import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'bootstrap/app_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  _installNonFatalLayoutErrorGuard();

  const windowOptions = WindowOptions(
    titleBarStyle: TitleBarStyle.hidden,
    fullScreen: true,
    center: true,
    minimumSize: Size(500, 650),
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setMinimizable(true);
    await windowManager.setMaximizable(true);
    await windowManager.setClosable(true);
    await windowManager.setFullScreen(true);
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const AppBootstrap());
}

void _installNonFatalLayoutErrorGuard() {
  final defaultHandler = FlutterError.onError;

  ErrorWidget.builder = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    return Container(
      color: const Color(0xFFF8FAFC),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      child: const Text(
        'This section could not be loaded.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(0xFF475569),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  };

  FlutterError.onError = (FlutterErrorDetails details) {
    if (defaultHandler != null) {
      defaultHandler(details);
    } else {
      FlutterError.presentError(details);
    }
  };
}
