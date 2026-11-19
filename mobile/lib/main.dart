import 'package:flutter/material.dart';

import 'api_service.dart';
import 'core.dart';
import 'screens/login_screen.dart';
import 'widgets.dart';

void main() {
  runApp(const TintaKitaApp());
}

class TintaKitaApp extends StatelessWidget {
  const TintaKitaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TintaKita',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const SplashRouter(),
    );
  }
}

class SplashRouter extends StatefulWidget {
  const SplashRouter({super.key});

  @override
  State<SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<SplashRouter> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final session = await ApiService.getSession();
    if (!mounted) return;

    final target = session == null
        ? const LoginScreen()
        : homeForRole(session['role'] as String?);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => target),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.navy,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandLogo(),
            SizedBox(height: 36),
            CircularProgressIndicator(color: AppColors.cyan),
          ],
        ),
      ),
    );
  }
}
