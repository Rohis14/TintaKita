import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api_service.dart';
import '../core.dart';
import '../widgets.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  // null = semua status
  static const _filters = <(String, List<OrderStatus>?)>[
    ('Semua', null),
    ('Menunggu', [OrderStatus.pending]),
    ('Diproses', [OrderStatus.designVerified, OrderStatus.printing]),
    ('Siap', [OrderStatus.ready]),
    ('Selesai', [OrderStatus.completed]),
    ('Ditolak', [OrderStatus.rejected]),
  ];

  int _tab = 0;
  int _filter = 0;
  List<dynamic> _products = [];
  List<dynamic> _orders = [];
  bool _loading = true;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _load(silent: true),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false, bool toast = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final r = await Future.wait([
        ApiService.getProducts(includeInactive: true),
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

  bool _inStatuses(dynamic o, List<OrderStatus>? statuses) =>
      statuses == null || statuses.contains(OrderStatus.from('${o['status']}'));

  int _count(List<OrderStatus>? statuses) =>
      _orders.where((o) => _inStatuses(o, statuses)).length;

  // ── Form produk ─────────────────────────────────────────────
  Future<void> _openProductForm({Map<String, dynamic>? product}) async {
    final msg = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => _ProductFormSheet(product: product),
    );
    if (msg == null || !mounted) return;
    showSnack(context, msg);
    _load(silent: true);
  }

  Future<void> _confirmDelete(Map<String, dynamic> product) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus produk?'),
        content: Text('Yakin ingin menghapus "${product['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD92D20)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final res = await ApiService.deleteProduct(product['id']);
    if (!mounted) return;
    showSnack(context, msgOf(res, 'Produk dihapus'),
        isError: res['success'] != true);
    _load(silent: true);
  }

  // ── Tampilan ────────────────────────────────────────────────
  Widget _stat(IconData icon, Color color, String value, String label) {
    return Expanded(
      child: AppCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.textSoft),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ordersTab() {
    final statuses = _filters[_filter].$2;
    final list = _orders.where((o) => _inStatuses(o, statuses)).toList()
      ..sort((a, b) => toNum(b['id']).compareTo(toNum(a['id'])));

    final income = _orders
        .where((o) => OrderStatus.from('${o['status']}') == OrderStatus.completed)
        .fold<num>(0, (sum, o) => sum + toNum(o['total_harga']));

    return RefreshList(
      onRefresh: _refresh,
      error: _error,
      header: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          children: [
            Row(
              children: [
                _stat(Icons.hourglass_top_rounded, OrderStatus.pending.color,
                    '${_count([OrderStatus.pending])}', 'Menunggu'),
                const SizedBox(width: 8),
                _stat(
                    Icons.print_rounded,
                    OrderStatus.printing.color,
                    '${_count([OrderStatus.designVerified, OrderStatus.printing])}',
                    'Diproses'),
                const SizedBox(width: 8),
                _stat(Icons.payments_outlined, OrderStatus.ready.color,
                    rupiah(income), 'Pendapatan'),
              ],
            ),
            const SizedBox(height: 16),
            FilterBar(
              labels: [
                for (final x in _filters) '${x.$1} (${_count(x.$2)})',
              ],
              selected: _filter,
              onSelected: (i) => setState(() => _filter = i),
            ),
          ],
        ),
      ),
      emptyIcon: Icons.receipt_long_outlined,
      emptyTitle: 'Tidak ada pesanan',
      emptySubtitle: 'Pesanan dengan status ini belum ada.',
      children: [
        for (final o in list) OrderCard(order: o, showCustomer: true),
      ],
    );
  }

  Widget _productsTab() {
    return RefreshList(
      onRefresh: _refresh,
      error: _error,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      emptyIcon: Icons.inventory_2_outlined,
      emptyTitle: 'Belum ada produk',
      emptySubtitle: 'Ketuk "Tambah Produk" untuk membuat produk pertama.',
      children: [
        for (final p in _products)
          Builder(builder: (_) {
            final active = isTrue(p['is_active']);
            return AppCard(
              padding: const EdgeInsets.all(12),
              child: Opacity(
                opacity: active ? 1 : 0.55,
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 64,
                        height: 64,
                        child: NetImage(p['thumbnail_url'],
                            icon: Icons.inventory_2_outlined),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${p['name']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                '${rupiah(p['harga'])} / ${p['unit']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.navy,
                                ),
                              ),
                              Pill(
                                active ? 'Aktif' : 'Nonaktif',
                                color: active
                                    ? const Color(0xFF12A150)
                                    : AppColors.textSoft,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'edit') _openProductForm(product: p);
                        if (v == 'delete') _confirmDelete(p);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Hapus')),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: brandAppBar(
        subtitle: 'Admin',
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
          : (_tab == 0 ? _ordersTab() : _productsTab()),
      floatingActionButton: _tab == 1
          ? FloatingActionButton.extended(
              onPressed: () => _openProductForm(),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Produk'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Pesanan',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Produk',
          ),
        ],
      ),
    );
  }
}

class _ProductFormSheet extends StatefulWidget {
  const _ProductFormSheet({this.product});

  final Map<String, dynamic>? product;

  @override
  State<_ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<_ProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _priceCtrl;
  late bool _isActive;
  XFile? _thumb;
  Uint8List? _preview;
  bool _saving = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl = TextEditingController(text: '${p?['name'] ?? ''}');
    _descCtrl = TextEditingController(text: '${p?['deskripsi'] ?? ''}');
    _unitCtrl = TextEditingController(text: '${p?['unit'] ?? 'pcs'}');
    _priceCtrl = TextEditingController(
      text: p == null ? '' : toNum(p['harga']).round().toString(),
    );
    _isActive = p == null ? true : isTrue(p['is_active']);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _unitCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    try {
      final img = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (img == null) return;
      final bytes = await img.readAsBytes();
      if (!mounted) return;
      setState(() {
        _thumb = img;
        _preview = bytes;
      });
    } catch (_) {
      if (mounted) setState(() => _err = 'Tidak dapat membuka galeri.');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _err = null;
    });
    final res = await ApiService.saveProduct(
      id: widget.product?['id'],
      name: _nameCtrl.text.trim(),
      deskripsi: _descCtrl.text.trim(),
      unit: _unitCtrl.text.trim(),
      harga: _priceCtrl.text.trim(),
      isActive: _isActive,
      thumbnailFile: _thumb,
    );
    if (!mounted) return;
    if (res['success'] == true) {
      Navigator.pop(context, msgOf(res, 'Produk tersimpan'));
    } else {
      setState(() {
        _saving = false;
        _err = msgOf(res, 'Gagal menyimpan produk');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.product != null;

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
              Text(
                isEdit ? 'Edit Produk' : 'Tambah Produk Baru',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  InkWell(
                    onTap: _pick,
                    borderRadius: BorderRadius.circular(14),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 84,
                        height: 84,
                        child: _preview != null
                            ? Image.memory(_preview!, fit: BoxFit.cover)
                            : NetImage(
                                widget.product?['thumbnail_url'],
                                icon: Icons.add_photo_alternate_outlined,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Foto produk',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        SizedBox(height: 2),
                        Text(
                          'Ketuk gambar untuk memilih foto (opsional).',
                          style: TextStyle(
                              fontSize: 12.5, color: AppColors.textSoft),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Nama produk'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi bahan / cetak',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _unitCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Satuan',
                        hintText: 'pcs / meter',
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Harga (Rp)',
                      ),
                      validator: (v) {
                        final n = double.tryParse(v ?? '');
                        return (n == null || n <= 0) ? 'Harga harus > 0' : null;
                      },
                    ),
                  ),
                ],
              ),
              if (isEdit)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Produk aktif'),
                  subtitle:
                      const Text('Produk nonaktif tidak tampil di katalog'),
                  value: _isActive,
                  onChanged: (val) => setState(() => _isActive = val),
                ),
              if (_err != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _err!,
                    style:
                        const TextStyle(color: Color(0xFFD92D20), fontSize: 13),
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const ButtonSpinner()
                      : const Text('Simpan Produk'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
