import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/rate_limiter.dart';
import 'services/video_service.dart';
import 'services/auth_service.dart';
import 'core/api_client.dart';
import 'providers/video_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'ui/pages/home_page.dart';
import 'ui/pages/login_page.dart';
import 'ui/pages/splash_page.dart';

void main() => runApp(const FKDouyinApp());

class FKDouyinApp extends StatelessWidget {
  const FKDouyinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
          create: (_) => VideoProvider(
            service: VideoService(ApiClient()),
            limiter: RateLimiter(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            service: AuthService(
              baseUrl: 'https://douyin-hono.liyunfei.eu.org/api',
            ),
          )..init(),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) => MaterialApp(
          title: '抖音解析下载',
          debugShowCheckedModeBanner: false,
          themeMode: theme.mode,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF7B3306),
              background: const Color(0xFFFFFCEE),
              surface: const Color(0xFFFFFDF5),
              onSurface: const Color(0xFF7B3306),
              primary: const Color(0xFF7B3306),
              onPrimary: const Color(0xFFFFFCEE),
            ),
            scaffoldBackgroundColor: const Color(0xFFFFFCEE),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFFFFFCEE),
              foregroundColor: Color(0xFF7B3306),
              elevation: 0,
            ),
            cardTheme: const CardThemeData(
              color: Color(0xFFFFFDF5),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
            ),
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: ZoomPageTransitionsBuilder(),
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                TargetPlatform.windows: ZoomPageTransitionsBuilder(),
                TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
                TargetPlatform.linux: ZoomPageTransitionsBuilder(),
              },
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFFFFCEE),
              brightness: Brightness.dark,
              background: const Color(0xFF2D2A2E),
              surface: const Color(0xFF3D3A3E),
              onSurface: const Color(0xFFFFFCEE),
              primary: const Color(0xFFFFFCEE),
              onPrimary: const Color(0xFF2D2A2E),
            ),
            scaffoldBackgroundColor: const Color(0xFF2D2A2E),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF2D2A2E),
              foregroundColor: Color(0xFFFFFCEE),
              elevation: 0,
            ),
            cardTheme: const CardThemeData(
              color: Color(0xFF3D3A3E),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
            ),
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: ZoomPageTransitionsBuilder(),
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                TargetPlatform.windows: ZoomPageTransitionsBuilder(),
                TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
                TargetPlatform.linux: ZoomPageTransitionsBuilder(),
              },
            ),
          ),
          routes: {
            '/login': (_) => const LoginPage(),
            '/': (_) => const AuthGate(),
            '/splash': (_) => const SplashPage(),
          },
          initialRoute: '/splash',
        ),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.initialised) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (auth.isAuthed) {
      return const HomePage();
    }

    return const LoginPage();
  }
}
