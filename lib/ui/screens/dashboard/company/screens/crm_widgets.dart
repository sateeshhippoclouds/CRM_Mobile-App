import 'package:flutter/material.dart';

const kCrmBlue = Color(0xff3756DF);
const kCrmBg = Color(0xffF5F5F7);

// ── Search Bar ────────────────────────────────────────────────────────────────

class CrmSearchBar extends StatelessWidget {
  const CrmSearchBar({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
  });
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xff9CA3AF), fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: Color(0xff9CA3AF), size: 20),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, v, __) => v.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Color(0xff9CA3AF)),
                    onPressed: () {
                      controller.clear();
                      onChanged?.call('');
                    },
                  )
                : const SizedBox.shrink(),
          ),
          filled: true,
          fillColor: const Color(0xffF9FAFB),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xffE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xffE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kCrmBlue),
          ),
        ),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class CrmEmptyState extends StatelessWidget {
  const CrmEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title, subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: const BoxDecoration(
              color: Color(0xffEEF1FB),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: kCrmBlue),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xff1A1F36))),
          const SizedBox(height: 6),
          Text(subtitle,
              style: const TextStyle(fontSize: 13, color: Color(0xff8E9BB5)),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Error Body ────────────────────────────────────────────────────────────────

class CrmErrorBody extends StatelessWidget {
  const CrmErrorBody({super.key, required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 13)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                  backgroundColor: kCrmBlue, foregroundColor: Colors.white),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Status Badge ──────────────────────────────────────────────────────────────

class CrmBadge extends StatelessWidget {
  const CrmBadge(this.label, {super.key, Color? bg, Color? fg})
      : _bg = bg,
        _fg = fg;

  final String label;
  final Color? _bg, _fg;

  static Color bgFor(String s) {
    final l = s.toLowerCase();
    if (l == 'active' || l == 'paid' || l == 'confirmed' || l == 'success' || l == 'low') {
      return const Color(0xffDCFCE7);
    }
    if (l == 'inactive' || l == 'cancelled' || l == 'closed' || l == 'high') {
      return const Color(0xffFEE2E2);
    }
    if (l == 'pending' || l == 'initially' || l == 'draft' || l == 'medium') {
      return const Color(0xffFFF7CD);
    }
    if (l.contains('submitted') || l.contains('quotation')) {
      return const Color(0xffE0F2FE);
    }
    return const Color(0xffEEF1FB);
  }

  static Color fgFor(String s) {
    final l = s.toLowerCase();
    if (l == 'active' || l == 'paid' || l == 'confirmed' || l == 'success' || l == 'low') {
      return const Color(0xff166534);
    }
    if (l == 'inactive' || l == 'cancelled' || l == 'closed' || l == 'high') {
      return const Color(0xff991B1B);
    }
    if (l == 'pending' || l == 'initially' || l == 'draft' || l == 'medium') {
      return const Color(0xff92400E);
    }
    if (l.contains('submitted') || l.contains('quotation')) {
      return const Color(0xff0369A1);
    }
    return kCrmBlue;
  }

  @override
  Widget build(BuildContext context) {
    final bg = _bg ?? bgFor(label);
    final fg = _fg ?? fgFor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
    );
  }
}

// ── Card Container ────────────────────────────────────────────────────────────

class CrmCard extends StatelessWidget {
  const CrmCard({super.key, required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(padding: const EdgeInsets.all(14), child: child),
      ),
    );
  }
}

// ── Info Row ─────────────────────────────────────────────────────────────────

class CrmInfoRow extends StatelessWidget {
  const CrmInfoRow(this.label, this.value, {super.key, this.icon});
  final String label, value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (value == '—' || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon!, size: 13, color: const Color(0xff9CA3AF)),
            const SizedBox(width: 4),
          ] else ...[
            Text('$label: ',
                style: const TextStyle(fontSize: 12, color: Color(0xff6B7280))),
          ],
          if (icon != null)
            Text('$label: ',
                style: const TextStyle(fontSize: 12, color: Color(0xff6B7280))),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xff1F2937))),
          ),
        ],
      ),
    );
  }
}

// ── Divider Row ───────────────────────────────────────────────────────────────

class CrmStat {
  const CrmStat(this.label, this.value);
  final String label, value;
}

class CrmDividerRow extends StatelessWidget {
  const CrmDividerRow(this.items, {super.key});
  final List<CrmStat> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xffF9FAFB),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: items.asMap().entries.map((e) {
          final isLast = e.key == items.length - 1;
          return Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : const Border(
                        right: BorderSide(color: Color(0xffE5E7EB))),
              ),
              child: Column(
                children: [
                  Text(e.value.value,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xff1A1F36))),
                  const SizedBox(height: 2),
                  Text(e.value.label,
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xff6B7280))),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── App Bar helper ────────────────────────────────────────────────────────────

AppBar crmAppBar(String title, {List<Widget>? actions}) => AppBar(
      backgroundColor: kCrmBlue,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      title: Text(title,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
      actions: actions,
    );

// ── Tab Bar helper ────────────────────────────────────────────────────────────

TabBar crmTabBar(List<String> labels, {bool scrollable = false}) => TabBar(
      isScrollable: scrollable,
      tabAlignment: scrollable ? TabAlignment.start : TabAlignment.fill,
      labelColor: kCrmBlue,
      unselectedLabelColor: const Color(0xff6B7280),
      indicatorColor: kCrmBlue,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      unselectedLabelStyle: const TextStyle(fontSize: 12),
      tabs: labels.map((l) => Tab(text: l)).toList(),
    );

// ── Filter Chip ───────────────────────────────────────────────────────────────

class CrmFilterDropdown extends StatelessWidget {
  const CrmFilterDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xffE5E7EB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<String>(
        value: value,
        underline: const SizedBox.shrink(),
        isDense: true,
        style: const TextStyle(fontSize: 12, color: Color(0xff1F2937)),
        items: items
            .map((i) => DropdownMenuItem(value: i, child: Text(i)))
            .toList(),
        onChanged: (v) => v != null ? onChanged(v) : null,
      ),
    );
  }
}

// ── Safe string helper ────────────────────────────────────────────────────────

String sv(Map<String, dynamic> m, String key, [String fallback = '—']) =>
    m[key]?.toString().trim().isEmpty == true
        ? fallback
        : m[key]?.toString() ?? fallback;
