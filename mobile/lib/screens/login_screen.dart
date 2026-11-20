import 'package:flutter/material.dart';

import '../api_service.dart';
import '../core.dart';
import '../widgets.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;
  bool _hidePass = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final res = await ApiService.login(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
      );
      if (!mounted) return;
      if (res['success'] == true) {
        await ApiService.saveSession(res['token'], res['data']);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => homeForRole(res['data']['role'] as String?),
          ),
        );
      } else {
        showSnack(
          context,
          msgOf(res, 'Email atau password salah'),
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) showSnack(context, errText(e), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openRegister() async {
    final result = await Navigator.push<(String, String)>(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
    if (result != null && mounted) {
      _emailCtrl.text = result.$1;
      _passwordCtrl.clear();
      showSnack(context, result.$2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Selamat datang',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Masuk untuk memesan dan memantau pesananmu.',
              style: TextStyle(color: AppColors.textSoft),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              validator: (v) => v == null || !v.contains('@')
                  ? 'Masukkan email yang valid'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _hidePass,
              onFieldSubmitted: (_) => _isLoading ? null : _submit(),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _hidePass
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _hidePass = !_hidePass),
                ),
              ),
              validator: (v) =>
                  v == null || v.length < 6 ? 'Minimal 6 karakter' : null,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading ? const ButtonSpinner() : const Text('Masuk'),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _openRegister,
                child: const Text('Belum punya akun? Daftar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
