import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:unpub_web/l10n/app_localizations.dart';

import '../core/theme/theme_cubit.dart';
import 'app_dependencies.dart';
import 'app_router.dart';

Future<void> runUnpubApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dependencies = AppDependencies();
  await dependencies.authSession.restoreSession();
  runApp(UnpubApp(dependencies: dependencies));
}

class UnpubApp extends StatelessWidget {
  const UnpubApp({
    required this.dependencies,
    super.key,
  });

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    final router = createAppRouter(dependencies);

    const brandColor = Color(0xFF0059A8);
    const accentColor = Color(0xFF00A8E8);

    return BlocProvider.value(
      value: dependencies.themeCubit,
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        bloc: dependencies.themeCubit,
        builder: (context, themeMode) {
          return MaterialApp.router(
            title: 'unpub',
            debugShowCheckedModeBanner: false,
            routerConfig: router,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            themeMode: themeMode,
            theme: _themeData(
              brightness: Brightness.light,
              brandColor: brandColor,
              accentColor: accentColor,
            ),
            darkTheme: _themeData(
              brightness: Brightness.dark,
              brandColor: const Color(0xFF6CB6FF),
              accentColor: const Color(0xFF3CD4FF),
            ),
          );
        },
      ),
    );
  }

  ThemeData _themeData({
    required Brightness brightness,
    required Color brandColor,
    required Color accentColor,
  }) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: brandColor,
        brightness: brightness,
        primary: brandColor,
        secondary: accentColor,
        surface: isDark ? const Color(0xFF141A23) : const Color(0xFFFFFFFF),
      ),
      scaffoldBackgroundColor: isDark ? const Color(0xFF0C1118) : const Color(0xFFF3F7FB),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? const Color(0xFF243446) : const Color(0xFFE5ECF3),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1A2330) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
