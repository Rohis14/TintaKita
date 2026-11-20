import 'package:flutter/material.dart';

import 'core.dart';

// ─────────────────────────────────────────────────────────────
// BRAND
// ─────────────────────────────────────────────────────────────
class BrandWord extends StatelessWidget {
  const BrandWord({super.key, this.size = 20});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(
            text: 'Tinta',
            style: TextStyle(color: Colors.white),
          ),
          TextSpan(
            text: 'Kita',
            style: TextStyle(color: AppColors.cyan),
          ),
        ],
      ),
      style: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
    );
  }
}

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.tagline});
  final String? tagline;

  @override
  Widget build(BuildContext context) {
    const dots = [
      AppColors.cyan,
      AppColors.magenta,
      AppColors.yellow,
      Colors.white,
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Icon(
            Icons.print_rounded,
            size: 38,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 16),
        const BrandWord(size: 32),
        const SizedBox(height: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final c in dots)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(color: c, shape: BoxShape.circle),
              ),
          ],
        ),
        if (tagline != null) ...[
          const SizedBox(height: 14),
          Text(
            tagline!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ],
    );
  }
}

PreferredSizeWidget brandAppBar({
  String? subtitle,
  List<Widget> actions = const [],
}) {
  return AppBar(
    backgroundColor: AppColors.navy,
    foregroundColor: Colors.white,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BrandWord(size: 20),
        if (subtitle != null)
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Colors.white70,
            ),
          ),
      ],
    ),
    actions: actions,
  );
}

/// Layout autentikasi responsif: split-screen di Desktop/Web (>= 760px),
/// header navy melengkung di HP.
class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.child, this.showBack = false});

  final Widget child;
  final bool showBack;

  static const _tagline =
      'Pesan cetak lebih mudah,\nprogres terpantau langsung.';

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
                    child: const Center(child: BrandLogo(tagline: _tagline)),
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
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          final top = MediaQuery.paddingOf(context).top;
          return SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(
                    24,
                    top + (showBack ? 12 : 48),
                    24,
                    40,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(32),
                    ),
                  ),
                  child: Column(
                    children: [
                      if (showBack)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            tooltip: 'Kembali',
                            color: Colors.white,
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back),
                          ),
                        ),
                      const BrandLogo(tagline: _tagline),
                    ],
                  ),
                ),
                Padding(padding: const EdgeInsets.all(24), child: child),
              ],
            ),
          );
        },
      ),
    );
  }
}

class NavItem {
  const NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.badgeCount = 0,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final int badgeCount;

  Widget _icon(IconData data) => Badge(
        isLabelVisible: badgeCount > 0,
        label: Text('$badgeCount'),
        child: Icon(data),
      );
}

/// Scaffold responsif: NavigationBar di HP, NavigationRail di Desktop/Web (>= 720px).
class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({
    super.key,
    required this.subtitle,
    required this.body,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    this.floatingActionButton,
  });

  final String subtitle;
  final Widget body;
  final List<NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;

    return Scaffold(
      appBar: brandAppBar(
        subtitle: subtitle,
        actions: [
          IconButton(
            tooltip: 'Keluar',
            onPressed: () => logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: wide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onSelect,
                  backgroundColor: Colors.white,
                  indicatorColor: AppColors.cyan.withValues(alpha: 0.2),
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final item in items)
                      NavigationRailDestination(
                        icon: item._icon(item.icon),
                        selectedIcon: item._icon(item.selectedIcon),
                        label: Text(item.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1, color: AppColors.border),
                Expanded(child: body),
              ],
            )
          : body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: onSelect,
              destinations: [
                for (final item in items)
                  NavigationDestination(
                    icon: item._icon(item.icon),
                    selectedIcon: item._icon(item.selectedIcon),
                    label: item.label,
                  ),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// KOMPONEN DASAR
// ─────────────────────────────────────────────────────────────
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: margin,
      elevation: 0,
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});
  final OrderStatus status;

  @override
  Widget build(BuildContext context) => Pill(status.label, color: status.color);
}

class ButtonSpinner extends StatelessWidget {
  const ButtonSpinner({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 20,
    height: 20,
    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
  );
}

class NetImage extends StatelessWidget {
  const NetImage(
    this.url, {
    super.key,
    this.icon = Icons.image_outlined,
    this.fit = BoxFit.cover,
  });
  final Object? url;
  final IconData icon;
  final BoxFit fit;

  Widget _placeholder() => Container(
    color: const Color(0xFFE8ECF5),
    child: Center(child: Icon(icon, color: AppColors.textSoft, size: 28)),
  );

  @override
  Widget build(BuildContext context) {
    final u = url == null ? '' : '$url';
    if (u.isEmpty) return _placeholder();
    return Image.network(
      u,
      fit: fit,
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : _placeholder(),
      errorBuilder: (_, _, _) => _placeholder(),
    );
  }
}

void showImagePreview(BuildContext context, String title, Object? url) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
          SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.5,
            width: double.infinity,
            child: InteractiveViewer(child: NetImage(url, fit: BoxFit.contain)),
          ),
          const Padding(
            padding: EdgeInsets.all(10),
            child: Text(
              'Cubit dua jari untuk memperbesar',
              style: TextStyle(fontSize: 12, color: AppColors.textSoft),
            ),
          ),
        ],
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.navy.withValues(alpha: 0.06),
            child: Icon(icon, size: 34, color: AppColors.navy),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSoft),
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
            ),
          ],
        ],
      ),
    );
  }
}

/// ListView dengan tarik-untuk-refresh, tampilan kosong, dan tampilan error.
class RefreshList extends StatelessWidget {
  const RefreshList({
    super.key,
    required this.onRefresh,
    required this.children,
    required this.emptyIcon,
    required this.emptyTitle,
    this.emptySubtitle,
    this.header,
    this.error,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 24),
    this.maxWidth = 840,
  });

  final Future<void> Function() onRefresh;
  final List<Widget> children;
  final IconData emptyIcon;
  final String emptyTitle;
  final String? emptySubtitle;
  final Widget? header;
  final String? error;
  final EdgeInsetsGeometry padding;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: padding,
            children: [
              ?header,
              if (children.isEmpty)
                error != null
                    ? EmptyState(
                        icon: Icons.wifi_off_rounded,
                        title: 'Gagal memuat data',
                        subtitle: error,
                        onRetry: () => onRefresh(),
                      )
                    : EmptyState(
                        icon: emptyIcon,
                        title: emptyTitle,
                        subtitle: emptySubtitle,
                      )
              else
                ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class FilterBar extends StatelessWidget {
  const FilterBar({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final sel = i == selected;
          return ChoiceChip(
            label: Text(labels[i]),
            selected: sel,
            showCheckmark: false,
            backgroundColor: Colors.white,
            selectedColor: AppColors.navy,
            side: BorderSide(color: sel ? AppColors.navy : AppColors.border),
            labelStyle: TextStyle(
              color: sel ? Colors.white : AppColors.navy,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            onSelected: (_) => onSelected(i),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// STEPPER PROGRES — inti dari "transparansi progres cetak"
// ─────────────────────────────────────────────────────────────
class StatusStepper extends StatelessWidget {
  const StatusStepper(this.status, {super.key});
  final OrderStatus status;

  static const _steps = [
    OrderStatus.pending,
    OrderStatus.designVerified,
    OrderStatus.printing,
    OrderStatus.ready,
    OrderStatus.completed,
  ];

  static const _grey = Color(0xFFD3DAE8);

  Widget _dot(int i, int current) {
    final isLast = i == _steps.length - 1;
    if (i < current || (i == current && isLast)) {
      return Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.navy,
        ),
        child: const Icon(Icons.check, size: 14, color: Colors.white),
      );
    }
    if (i == current) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: AppColors.cyan, width: 2),
        ),
        child: Center(
          child: Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.cyan,
            ),
          ),
        ),
      );
    }
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: _grey, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = _steps.indexOf(status);
    final last = _steps.length - 1;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _steps.length; i++)
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 3,
                        color: i == 0
                            ? Colors.transparent
                            : (i <= current ? AppColors.navy : _grey),
                      ),
                    ),
                    _dot(i, current),
                    Expanded(
                      child: Container(
                        height: 3,
                        color: i == last
                            ? Colors.transparent
                            : (i < current ? AppColors.navy : _grey),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _steps[i].shortLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: i == current
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: i <= current ? AppColors.navy : AppColors.textSoft,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// KARTU PESANAN — dipakai Pelanggan, Operator, dan Admin
// ─────────────────────────────────────────────────────────────
class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    this.showCustomer = false,
    this.actions = const [],
  });

  final Map<String, dynamic> order;
  final bool showCustomer;
  final List<Widget> actions;

  Widget _info(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textSoft),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5))),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final status = OrderStatus.from('${order['status']}');
    final notes = '${order['notes'] ?? ''}'.trim();
    final reason = '${order['reject_reason'] ?? ''}'.trim();
    final created = formatDate(order['created_at']);
    final custName = '${order['pelanggan_nama'] ?? ''}'.trim();
    final opName = '${order['operator_nama'] ?? ''}'.trim();
    final compact = VisualDensity.compact;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      created.isEmpty
                          ? 'Pesanan #${order['id']}'
                          : 'Pesanan #${order['id']} • $created',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSoft,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${order['produk_name'] ?? '-'}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(status),
            ],
          ),
          const SizedBox(height: 10),
          _info(
            Icons.inventory_2_outlined,
            '${qty(order['quantity'])} ${order['produk_unit'] ?? ''} • ${rupiah(order['total_harga'])}',
          ),
          if (showCustomer)
            _info(
              Icons.person_outline,
              '${custName.isEmpty ? '-' : titleCase(custName)} • ${order['pelanggan_hp'] ?? '-'}',
            ),
          if (showCustomer && opName.isNotEmpty)
            _info(Icons.badge_outlined, 'Operator: ${titleCase(opName)}'),
          if (notes.isNotEmpty) _info(Icons.sticky_note_2_outlined, notes),
          const SizedBox(height: 14),
          if (status == OrderStatus.rejected)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: status.color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, size: 18, color: status.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reason.isEmpty ? 'Desain ditolak.' : 'Alasan: $reason',
                      style: TextStyle(color: status.color, fontSize: 13.5),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            StatusStepper(status),
            if (!showCustomer) ...[
              const SizedBox(height: 12),
              Text(
                status.hint,
                style: const TextStyle(fontSize: 13, color: AppColors.textSoft),
              ),
            ],
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(visualDensity: compact),
                onPressed: () => showImagePreview(
                  context,
                  'Desain',
                  order['design_image_url'],
                ),
                icon: const Icon(Icons.image_outlined, size: 18),
                label: const Text('Desain'),
              ),
              if (order['result_image_url'] != null)
                TextButton.icon(
                  style: TextButton.styleFrom(visualDensity: compact),
                  onPressed: () => showImagePreview(
                    context,
                    'Hasil Cetak',
                    order['result_image_url'],
                  ),
                  icon: const Icon(Icons.verified_outlined, size: 18),
                  label: const Text('Hasil Cetak'),
                ),
              ...actions,
            ],
          ),
        ],
      ),
    );
  }
}
