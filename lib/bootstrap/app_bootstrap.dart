import 'dart:async';

import 'package:flutter/material.dart';

import '../app.dart';
import '../core/network/api_server_bootstrap.dart';

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  @override
  void initState() {
    super.initState();
    unawaited(ApiServerBootstrap.ensureRunning());
  }

  @override
  Widget build(BuildContext context) {
    return const EArchiveApp();
  }
}
