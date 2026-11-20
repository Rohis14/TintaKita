import 'package:flutter/material.dart';

import '../api_service.dart';
import '../core.dart';
import '../widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _hpCtrl = TextEditingController();

  bool _isRegister = false;
  bool _isLoading = false;
  bool _hidePass = true;

  @override
  void dispose() {
    _namaCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _hpCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      if (_isRegister) {
        final res = await ApiService.register(
          _namaCtrl.text.trim(),
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
          _hpCtrl.text.trim(),
        );
        if (!mounted) return;
        if (res['success'] == true) {
          showSnack(context, msgOf(res, 'Registrasi berhasil! Silakan masuk.'));
          _passwordCtrl.clear();
          setState(() => _isRegister = false);
        } else {
          showSnack(context, msgOf(res, 'Registrasi gagal'), isError: true);
        }
      } else {
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
      }
    } catch (e) {
      if (mounted) showSnack(context, errText(e), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _isRegister ? 'Buat akun pelanggan' : 'Selamat datang',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _isRegister
                ? 'Daftar untuk mulai memesan cetak.'
                : 'Masuk untuk memesan dan memantau pesananmu.',
            style: const TextStyle(color: AppColors.textSoft),
          ),
          const SizedBox(height: 24),
          if (_isRegister) ...[
            TextFormField(
              controller: _namaCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nama lengkap',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Nama wajib diisi'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _hpCtrl,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nomor WhatsApp / HP',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Nomor HP wajib diisi'
                  : null,
            ),
            const SizedBox(height: 14),
          ],
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
              child: _isLoading
                  ? const ButtonSpinner()
                  : Text(_isRegister ? 'Daftar Sekarang' : 'Masuk'),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _isRegister = !_isRegister),
              child: Text(
                _isRegister
                    ? 'Sudah punya akun? Masuk'
                    : 'Belum punya akun? Daftar',
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 760) {
            return Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Container(
                    color: AppColors.navy,
                    padding: const EdgeInsets.all(40),
                    child: const Center(
                      child: BrandLogo(
                        tagline:
                            'Pesan cetak lebih mudah,\nprogres terpantau langsung.',
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 6,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: AppCard(
                          padding: const EdgeInsets.all(28),
                          margin: EdgeInsets.zero,
                          child: _buildForm(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                // ── Header brand ──
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(
                    24,
                    MediaQuery.of(context).padding.top + 48,
                    24,
                    40,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(32),
                    ),
                  ),
                  child: const BrandLogo(
                    tagline:
                        'Pesan cetak lebih mudah,\nprogres terpantau langsung.',
                  ),
                ),

                // ── Form ──
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: _buildForm(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
