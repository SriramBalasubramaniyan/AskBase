import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemma/core/api/flutter_gemma.dart';
import 'package:flutter_gemma_mediapipe/flutter_gemma_mediapipe.dart';
import 'package:provider/provider.dart';

// Schema — swap this import to change the active database domain
import 'schema/agri_schema.dart';

import 'ui/app_state.dart';
import 'ui/app_theme.dart';
import 'ui/screens/chat_screen.dart';
import 'ui/screens/download_screen.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/widgets/error_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterGemma.initialize(inferenceEngines: [const MediaPipeEngine()]);

  // Lock to portrait — designed for field use on phones
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.surface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    ChangeNotifierProvider(
      // ── To swap schema: replace agriSchema with your new schema object ──
      create: (_) => AppState(agriSchema)..initialize(),
      child: const AskBaseApp(),
    ),
  );
}

class AskBaseApp extends StatelessWidget {
  const AskBaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AskBase',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const _RootRouter(),
    );
  }
}

/// Routes to the correct screen based on AppState status.
/// This is the single place that decides what the user sees.
class _RootRouter extends StatelessWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    switch (state.status) {
      case AppStatus.initializing:
        return SplashScreen(message: state.statusMessage);

      case AppStatus.needsDownload:
        return const DownloadScreen();

      case AppStatus.downloading:
        return const DownloadScreen();

      case AppStatus.loading:
        return SplashScreen(message: state.statusMessage);

      case AppStatus.ready:
        return const ChatScreen();

      case AppStatus.error:
        return ErrorScreen(
          message: state.errorMessage ?? 'An unexpected error occurred.',
          onRetry: () => state.initialize(),
        );
    }
  }
}
