import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/rate_limiter.dart';
import 'services/video_service.dart';
import 'core/api_client.dart';
import 'providers/video_provider.dart';
import 'providers/theme_provider.dart';
import 'ui/pages/home_page.dart';

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
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) => MaterialApp(
          title: '抖音解析下载',
          debugShowCheckedModeBanner: false,
          themeMode: theme.mode,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepOrange,
              brightness: Brightness.dark,
            ),
          ),
          home: const HomePage(),
        ),
      ),
    );
  }
}
