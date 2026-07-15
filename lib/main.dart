import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'theme/app_colors.dart';
import 'theme/app_typography.dart';
import 'pickup/pickup_shell.dart';
import 'pickup/state/game_state.dart';

/// DEFAULT ENTRY — the Pickup app. This is what TestFlight / Xcode / every
/// `flutter build` runs. (im-him lives in its own repo; its old entry is
/// preserved at lib/main_imhim.dart.bak.)
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const PickupApp());
}

class PickupApp extends StatelessWidget {
  const PickupApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GameState(),
      child: MaterialApp(
        title: 'Pickup',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppColors.base,
          colorScheme: const ColorScheme.dark(
            surface: AppColors.base,
            primary: AppColors.red,
            secondary: AppColors.accent,
          ),
          textTheme: TextTheme(bodyMedium: AppTypography.body),
          splashColor: AppColors.accentGlow,
          highlightColor: Colors.transparent,
        ),
        home: const PickupShell(),
      ),
    );
  }
}
