import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api_service.dart';
import '../core.dart';
import '../widgets.dart';

class PelangganScreen extends StatefulWidget {
  const PelangganScreen({super.key});

  @override
  State<PelangganScreen> createState() => _PelangganScreenState();
}

class _PelangganScreenState extends State<PelangganScreen> {
  int _tab = 0;
  List<dynamic> _products = [];
  List<dynamic> _orders = [];
  bool _loading = true;
  String? _error;
  String _nama = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadName();
    _load();
    // Pembaruan otomatis tiap 20 detik agar progres terlihat tanpa refresh manual
    _timer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _load(silent: true),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadName() async {
    final s = await ApiService.getSession();
    if (mounted) setState(() => _nama = '${s?['nama'] ?? ''}');
  }

  /// silent = tanpa loading layar penuh. toast = tampilkan snackbar jika gagal.
  Future<void> _load({bool silent = false, bool toast = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final r = await Future.wait([
        ApiService.getProducts(),
        ApiService.getOrders(),
      ]);
      if (!mounted) return;
      setState(() {
        _products = r[0];
        _orders = r[1];
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent) setState(() => _error = errText(e));
      if (toast) showSnack(context, errText(e), isError: true);
    } finally {
      if (mounted && _loading) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() => _load(silent: true, toast: true);

  // ── Form pesan ──────────────────────────────────────────────
  Future<void> _openOrderSheet(Map<String, dynamic> product) async {
    final msg = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => _OrderSheet(product: product),
    );
    if (msg == null || !mounted) return;
    showSnack(context, msg);
    setState(() => _tab = 1);
    _load(silent: true);
  }

  Future<void> _confirmCancel(dynamic orderId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan pesanan?'),
        content: Text(
          'Pesanan #$orderId akan dibatalkan dan dihapus permanen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tidak'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD92D20),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, batalkan'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final res = await ApiService.cancelOrder(orderId);
    if (!mounted) return;
    showSnack(
      context,
      msgOf(res, 'Pesanan dibatalkan'),
      isError: res['success'] != true,
    );
    _load(silent: true);
  }

  // ── Tampilan ────────────────────────────────────────────────
  Widget _productCard(Map<String, dynamic> p) {
    return AppCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      onTap: () => _openOrderSheet(p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SizedBox(
              width: double.infinity,
              child: NetImage(p['thumbnail_url'], icon: Icons.print_outlined),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${p['name']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${p['deskripsi'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSoft,
                  ),
                ),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    text: rupiah(p['harga']),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                    ),
                    children: [
                      TextSpan(
                        text: ' / ${p['unit']}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSoft,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(38),
                  ),
                  onPressed: () => _openOrderSheet(p),
                  child: const Text('Pesan'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _catalogTab() {
    final greeting = Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _nama.isEmpty ? 'Halo!' : 'Halo, $_nama 👋',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          const Text(
            'Mau cetak apa hari ini?',
            style: TextStyle(color: AppColors.textSoft),
          ),
        ],
      ),
    );

    if (_products.isEmpty) {
      return RefreshList(
        onRefresh: _refresh,
        header: greeting,
        error: _error,
        emptyIcon: Icons.storefront_outlined,
        emptyTitle: 'Belum ada produk',
        emptySubtitle: 'Produk cetak akan muncul di sini.',
        children: const [],
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(child: greeting),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 240,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.62,
              ),
              itemCount: _products.length,
              itemBuilder: (_, i) => _productCard(_products[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ordersTab() {
    final sorted = [..._orders]
      ..sort((a, b) => toNum(b['id']).compareTo(toNum(a['id'])));

    return RefreshList(
      onRefresh: _refresh,
      error: _error,
      emptyIcon: Icons.receipt_long_outlined,
      emptyTitle: 'Belum ada pesanan',
      emptySubtitle: 'Pilih produk di Katalog untuk mulai memesan.',
      children: [
        for (final o in sorted)
          OrderCard(
            order: o,
            actions: [
              if (OrderStatus.from('${o['status']}') == OrderStatus.pending)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFD92D20),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => _confirmCancel(o['id']),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Batalkan'),
                ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final siap = _orders
        .where((o) => OrderStatus.from('${o['status']}') == OrderStatus.ready)
        .length;

    return Scaffold(
      appBar: brandAppBar(
        subtitle: 'Pelanggan',
        actions: [
          IconButton(
            tooltip: 'Keluar',
            onPressed: () => logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_tab == 0 ? _catalogTab() : _ordersTab()),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Katalog',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: siap > 0,
              label: Text('$siap'),
              child: const Icon(Icons.receipt_long_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: siap > 0,
              label: Text('$siap'),
              child: const Icon(Icons.receipt_long),
            ),
            label: 'Pesanan Saya',
          ),
        ],
      ),
    );
  }
}

class _OrderSheet extends StatefulWidget {
  const _OrderSheet({required this.product});

  final Map<String, dynamic> product;

  @override
  State<_OrderSheet> createState() => _OrderSheetState();
}

class _OrderSheetState extends State<_OrderSheet> {
  final _formKey = GlobalKey<FormState>();
  final _qtyCtrl = TextEditingController(text: '1');
  final _notesCtrl = TextEditingController();
  XFile? _design;
  Uint8List? _preview;
  bool _submitting = false;
  String? _err;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    try {
      final img = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (img == null) return;
      final bytes = await img.readAsBytes();
      if (!mounted) return;
      setState(() {
        _design = img;
        _preview = bytes;
        _err = null;
      });
    } catch (_) {
      if (mounted) setState(() => _err = 'Tidak dapat membuka galeri.');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_design == null) {
      setState(() => _err = 'Pilih file desain terlebih dahulu.');
      return;
    }
    setState(() {
      _submitting = true;
      _err = null;
    });
    final res = await ApiService.createOrder(
      produkId: widget.product['id'],
      quantity: _qtyCtrl.text.trim().replaceAll(',', '.'),
      notes: _notesCtrl.text.trim(),
      designFile: _design!,
    );
    if (!mounted) return;
    if (res['success'] == true) {
      Navigator.pop(context, msgOf(res, 'Pesanan berhasil dibuat!'));
    } else {
      setState(() {
        _submitting = false;
        _err = msgOf(res, 'Gagal membuat pesanan');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final jumlah = double.tryParse(_qtyCtrl.text.replaceAll(',', '.')) ?? 0;
    final total = toNum(p['harga']) * jumlah;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: NetImage(
                        p['thumbnail_url'],
                        icon: Icons.print_outlined,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${p['name']}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${rupiah(p['harga'])} / ${p['unit']}',
                          style: const TextStyle(color: AppColors.textSoft),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Jumlah (${p['unit']})',
                ),
                validator: (v) {
                  final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                  return (n == null || n <= 0)
                      ? 'Jumlah harus lebih dari 0'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Catatan ukuran / finishing (opsional)',
                  hintText: 'Contoh: 3 x 1 m, laminasi doff',
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pick,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: _preview == null
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.cloud_upload_outlined,
                              size: 36,
                              color: AppColors.navy,
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Unggah file desain (JPG/PNG)',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'Ketuk untuk memilih dari galeri',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSoft,
                              ),
                            ),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Image.memory(
                            _preview!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        ),
                ),
              ),
              if (_design != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${_design!.name} • ketuk gambar untuk mengganti',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSoft,
                    ),
                  ),
                ),
              if (_err != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _err!,
                    style: const TextStyle(
                      color: Color(0xFFD92D20),
                      fontSize: 13,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Estimasi total'),
                    Text(
                      rupiah(total),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const ButtonSpinner()
                      : const Text('Kirim Pesanan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
