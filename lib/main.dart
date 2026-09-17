import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'presentation/shell/app_shell.dart';
import 'presentation/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: AccordMemoApp()));
}

class AccordMemoApp extends StatelessWidget {
  const AccordMemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AccordMémo',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AppShell(),
    );
  }
}
