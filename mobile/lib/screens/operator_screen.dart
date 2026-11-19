import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api_service.dart';
import '../core.dart';
import '../widgets.dart';

class OperatorScreen extends StatefulWidget {
  const OperatorScreen({super.key});

  @override
  State<OperatorScreen> createState() => _OperatorScreenState();
}

class _OperatorScreenState extends State<OperatorScreen> {
  // Filter antrean kerja operator
  static const _filters = <(String, List<OrderStatus>)>[
    ('Menunggu', [OrderStatus.pending]),
    ('Produksi', [OrderStatus.designVerified, OrderStatus.printing]),
    ('Siap Diambil', [OrderStatus.ready]),
    ('Riwayat', [OrderStatus.completed, OrderStatus.rejected]),
  ];

  List<dynamic> _orders = [];
  bool _loading = true;
  String? _error;
  int _filter = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
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

  Future<void> _load({bool silent = false, bool toast = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await ApiService.getOrders();
      if (!mounted) return;
      setState(() {
        _orders = data;
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

  int _countFor(List<OrderStatus> statuses) => _orders
      .where((o) => statuses.contains(OrderStatus.from('${o['status']}')))
      .length;

  // ── Sheet ubah status ───────────────────────────────────────
  Future<void> _openUpdateSheet(
      Map<String, dynamic> order, OrderStatus target) async {
    final msg = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => _UpdateOrderSheet(order: order, target: target),
    );
    if (msg == null || !mounted) return;
    showSnack(context, msg);
    _load(silent: true);
  }

  // ── Tampilan ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final f = _filters[_filter];
    final list = _orders
        .where((o) => f.$2.contains(OrderStatus.from('${o['status']}')))
        .toList()
      ..sort((a, b) {
        final c = toNum(a['id']).compareTo(toNum(b['id']));
        // Antrean aktif: yang terlama dulu. Riwayat: yang terbaru dulu.
        return _filter == _filters.length - 1 ? -c : c;
      });

    return Scaffold(
      appBar: brandAppBar(
        subtitle: 'Operator Produksi',
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
          : RefreshList(
              onRefresh: _refresh,
              error: _error,
              header: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: FilterBar(
                  labels: [
                    for (final x in _filters) '${x.$1} (${_countFor(x.$2)})',
                  ],
                  selected: _filter,
                  onSelected: (i) => setState(() => _filter = i),
                ),
              ),
              emptyIcon: Icons.inbox_outlined,
              emptyTitle: 'Tidak ada pesanan di sini',
              emptySubtitle: 'Tarik ke bawah untuk memuat ulang.',
              children: [
                for (final o in list)
                  Builder(builder: (_) {
                    final status = OrderStatus.from('${o['status']}');
                    final next = status.next;
                    final canReject = status == OrderStatus.pending ||
                        status == OrderStatus.designVerified;
                    return OrderCard(
                      order: o,
                      showCustomer: true,
                      actions: [
                        if (next != null)
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(64, 40),
                            ),
                            onPressed: () => _openUpdateSheet(o, next),
                            icon: const Icon(Icons.arrow_forward, size: 18),
                            label: Text(status.actionLabel),
                          ),
                        if (canReject)
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(64, 40),
                              foregroundColor: const Color(0xFFD92D20),
                              side: const BorderSide(color: Color(0xFFF1B5AF)),
                            ),
                            onPressed: () =>
                                _openUpdateSheet(o, OrderStatus.rejected),
                            child: const Text('Tolak'),
                          ),
                      ],
                    );
                  }),
              ],
            ),
    );
  }
}

class _UpdateOrderSheet extends StatefulWidget {
  const _UpdateOrderSheet({required this.order, required this.target});

  final Map<String, dynamic> order;
  final OrderStatus target;

  @override
  State<_UpdateOrderSheet> createState() => _UpdateOrderSheetState();
}

class _UpdateOrderSheetState extends State<_UpdateOrderSheet> {
  final _reasonCtrl = TextEditingController();
  XFile? _photo;
  Uint8List? _preview;
  bool _saving = false;
  String? _err;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource src) async {
    try {
      final img = await ImagePicker().pickImage(source: src);
      if (img == null) return;
      final bytes = await img.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photo = img;
        _preview = bytes;
        _err = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _err =
            'Tidak dapat membuka ${src == ImageSource.camera ? 'kamera' : 'galeri'}.');
      }
    }
  }

  Future<void> _save() async {
    final isReject = widget.target == OrderStatus.rejected;
    final needPhoto = widget.target == OrderStatus.ready;

    if (isReject && _reasonCtrl.text.trim().isEmpty) {
      setState(() => _err = 'Alasan penolakan wajib diisi.');
      return;
    }
    if (needPhoto && _photo == null) {
      setState(() => _err = 'Foto bukti hasil cetak wajib diunggah.');
      return;
    }
    setState(() {
      _saving = true;
      _err = null;
    });
    final res = await ApiService.updateOrderStatus(
      orderId: widget.order['id'],
      status: widget.target.code,
      rejectReason: _reasonCtrl.text.trim(),
      resultFile: _photo,
    );
    if (!mounted) return;
    if (res['success'] == true) {
      Navigator.pop(context, msgOf(res, 'Status diperbarui'));
    } else {
      setState(() {
        _saving = false;
        _err = msgOf(res, 'Gagal memperbarui status');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReject = widget.target == OrderStatus.rejected;
    final needPhoto = widget.target == OrderStatus.ready;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isReject
                  ? 'Tolak desain #${widget.order['id']}'
                  : 'Pesanan #${widget.order['id']}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Text('Status baru: ',
                    style: TextStyle(color: AppColors.textSoft)),
                StatusBadge(widget.target),
              ],
            ),
            const SizedBox(height: 16),
            if (isReject)
              TextField(
                controller: _reasonCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Alasan penolakan (wajib)',
                  hintText: 'Contoh: resolusi terlalu rendah, mohon kirim ulang',
                ),
              ),
            if (needPhoto) ...[
              const Text(
                'Foto bukti hasil cetak (wajib)',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (!kIsWeb) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pick(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Kamera'),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pick(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(kIsWeb ? 'Pilih Foto Hasil Cetak' : 'Galeri'),
                    ),
                  ),
                ],
              ),
              if (_preview != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _preview!,
                    height: 170,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ],
            if (!isReject && !needPhoto)
              const Text(
                'Pelanggan akan langsung melihat perubahan status ini.',
                style: TextStyle(color: AppColors.textSoft),
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
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                style: isReject
                    ? FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFD92D20))
                    : null,
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const ButtonSpinner()
                    : Text(isReject ? 'Tolak Pesanan' : 'Simpan Perubahan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
