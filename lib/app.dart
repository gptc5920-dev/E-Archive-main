import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'core/constants/app_theme.dart';
import 'features/auth/data/datasources/auth_api_data_source.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/usecases/login_usecase.dart';
import 'features/splash/presentation/pages/splash_page.dart';

class EArchiveApp extends StatelessWidget {
  const EArchiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = AuthRepositoryImpl(
      apiDataSource: AuthApiDataSource(),
    );
    final loginUseCase = LoginUseCase(repository);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'E-Archive',
      theme: AppTheme.appTheme,
      builder: (context, child) {
        return AppTheme.poppinsBuilder(
          context,
          TooltipVisibility(
            visible: false,
            child: _DesktopWindowFrame(child: child),
          ),
        );
      },
      home: SplashPage(loginUseCase: loginUseCase),
    );
  }
}

class _DesktopWindowFrame extends StatelessWidget {
  const _DesktopWindowFrame({this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF8FAFC),
      child: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 32),
              Expanded(child: child ?? const SizedBox.shrink()),
            ],
          ),
          const Positioned(
            top: 0,
            left: 0,
            right: 138,
            height: 32,
            child: DragToMoveArea(
              child: SizedBox.expand(),
            ),
          ),
          const Positioned(top: 0, right: 0, child: _WindowControls()),
        ],
      ),
    );
  }
}

class _WindowControls extends StatefulWidget {
  const _WindowControls();

  @override
  State<_WindowControls> createState() => _WindowControlsState();
}

class _WindowControlsState extends State<_WindowControls> with WindowListener {
  bool _restoreFullScreen = false;
  bool _isMaximized = true;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _syncMaximizedState();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _minimizeWindow() async {
    if (await windowManager.isFullScreen()) {
      _restoreFullScreen = true;
      await windowManager.setFullScreen(false);
      await windowManager.maximize();
    }
    await windowManager.minimize();
  }

  Future<void> _toggleMaximizeWindow() async {
    if (await windowManager.isFullScreen()) {
      await windowManager.setFullScreen(false);
      await windowManager.maximize();
      await _syncMaximizedState();
      return;
    }

    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
    await _syncMaximizedState();
  }

  Future<void> _syncMaximizedState() async {
    final isMaximized = await windowManager.isMaximized();
    if (!mounted) return;
    setState(() => _isMaximized = isMaximized);
  }

  @override
  void onWindowRestore() {
    if (!_restoreFullScreen) return;
    _restoreFullScreen = false;
    windowManager.setFullScreen(true);
    _syncMaximizedState();
  }

  @override
  void onWindowMaximize() {
    _syncMaximizedState();
  }

  @override
  void onWindowUnmaximize() {
    _syncMaximizedState();
  }

  @override
  void onWindowResize() {
    _syncMaximizedState();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8)),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: 'Minimize window',
            button: true,
            child: WindowCaptionButton.minimize(
              brightness: Brightness.light,
              onPressed: _minimizeWindow,
            ),
          ),
          Semantics(
            label: _isMaximized ? 'Restore window' : 'Maximize window',
            button: true,
            child: _isMaximized
                ? WindowCaptionButton.unmaximize(
                    brightness: Brightness.light,
                    onPressed: _toggleMaximizeWindow,
                  )
                : WindowCaptionButton.maximize(
                    brightness: Brightness.light,
                    onPressed: _toggleMaximizeWindow,
                  ),
          ),
          Semantics(
            label: 'Close window',
            button: true,
            child: WindowCaptionButton.close(
              brightness: Brightness.light,
              onPressed: windowManager.close,
            ),
          ),
        ],
      ),
    );
  }
}
