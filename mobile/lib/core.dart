import 'package:flutter/material.dart';

import 'api_service.dart';
import 'screens/admin_screen.dart';
import 'screens/login_screen.dart';
import 'screens/operator_screen.dart';
import 'screens/pelanggan_screen.dart';

// ─────────────────────────────────────────────────────────────
// WARNA — navy "tinta" + aksen CMYK (cyan, magenta, kuning)
// ─────────────────────────────────────────────────────────────
class AppColors {
  AppColors._();

  static const navy = Color(0xFF14264F);
  static const cyan = Color(0xFF00A9E0);
  static const magenta = Color(0xFFE6007E);
  static const yellow = Color(0xFFF7B500);

  static const bg = Color(0xFFF4F6FB);
  static const border = Color(0xFFE2E7F1);
  static const textSoft = Color(0xFF6B7794);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.navy,
  ).copyWith(
    primary: AppColors.navy,
    onPrimary: Colors.white,
    secondary: AppColors.cyan,
  );

  final radius = BorderRadius.circular(12);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.navy, width: 1.8),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 46),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 44),
        foregroundColor: AppColors.navy,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.cyan,
      foregroundColor: AppColors.navy,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: AppColors.cyan.withValues(alpha: 0.2),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// STATUS PESANAN — satu tempat untuk kode, label, warna, urutan
// ─────────────────────────────────────────────────────────────
enum OrderStatus {
  pending(
    'PENDING',
    'Menunggu Verifikasi',
    'Diterima',
    'Pesanan diterima. Desain sedang menunggu dicek operator.',
    Color(0xFFD98E00),
  ),
  designVerified(
    'DESIGN_VERIFIED',
    'Desain Disetujui',
    'Disetujui',
    'Desain disetujui. Pesanan masuk antrean cetak.',
    Color(0xFF0090C8),
  ),
  printing(
    'PRINTING',
    'Sedang Dicetak',
    'Dicetak',
    'Pesananmu sedang dalam proses cetak.',
    AppColors.magenta,
  ),
  ready(
    'READY',
    'Siap Diambil',
    'Siap',
    'Sudah selesai dicetak, silakan ambil pesananmu!',
    Color(0xFF12A150),
  ),
  completed(
    'COMPLETED',
    'Selesai',
    'Selesai',
    'Pesanan sudah diambil. Terima kasih!',
    Color(0xFF5B6B8C),
  ),
  rejected(
    'REJECTED',
    'Ditolak',
    'Ditolak',
    'Desain ditolak.',
    Color(0xFFD92D20),
  );

  const OrderStatus(
    this.code,
    this.label,
    this.shortLabel,
    this.hint,
    this.color,
  );

  final String code;
  final String label;
  final String shortLabel;
  final String hint;
  final Color color;

  static OrderStatus from(String code) =>
      values.firstWhere((s) => s.code == code, orElse: () => pending);

  /// Tahap berikutnya untuk tombol aksi operator (null = sudah final).
  OrderStatus? get next => switch (this) {
        pending => designVerified,
        designVerified => printing,
        printing => ready,
        ready => completed,
        _ => null,
      };

  /// Teks tombol operator untuk pindah ke tahap berikutnya.
  String get actionLabel => switch (this) {
        pending => 'Verifikasi Desain',
        designVerified => 'Mulai Cetak',
        printing => 'Tandai Siap Diambil',
        ready => 'Tandai Sudah Diambil',
        _ => '',
      };
}

// ─────────────────────────────────────────────────────────────
// HELPER UMUM
// ─────────────────────────────────────────────────────────────
num toNum(dynamic v) => num.tryParse('$v') ?? 0;

bool isTrue(dynamic v) => v == true || v == 1 || v == '1' || v == 'true';

/// 50000 -> "Rp 50.000"
String rupiah(dynamic v) {
  final n = toNum(v).round();
  final s = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return 'Rp ${n < 0 ? '-' : ''}$buf';
}

/// 2.0 -> "2", 1.5 -> "1.5"
String qty(dynamic v) {
  final n = toNum(v);
  return n == n.roundToDouble() ? n.toInt().toString() : n.toString();
}

String errText(Object e) => e.toString().replaceFirst('Exception: ', '');

String msgOf(Map<String, dynamic> res, String fallback) {
  final m = res['message']?.toString() ?? '';
  return m.isEmpty ? fallback : m;
}

void showSnack(BuildContext context, String msg, {bool isError = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isError ? const Color(0xFFD92D20) : const Color(0xFF12A150),
      ),
    );
}

Widget homeForRole(String? role) => switch (role) {
      'ADMIN' => const AdminScreen(),
      'OPERATOR' => const OperatorScreen(),
      _ => const PelangganScreen(),
    };

Future<void> logout(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Keluar dari akun?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Keluar'),
        ),
      ],
    ),
  );
  if (ok != true) return;

  await ApiService.clearSession();
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (_) => false,
  );
}
