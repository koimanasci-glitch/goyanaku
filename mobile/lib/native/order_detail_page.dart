import 'package:flutter/material.dart';

import 'common.dart';

// Rincian Pesanan (HTML #g62-order-detail) digambar Flutter, ukuran & warna sama dengan HTML.
// Isi dan logika tetap dari HTML: setiap tombol menjalankan tombol HTML yang sama (indeks `b`).

String _s(Object? v) => v is String ? v.trim() : (v == null ? '' : '$v');
List<Map<String, dynamic>> _list(Object? v) =>
    v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];
Map<String, dynamic>? _map(Object? v) => v is Map ? Map<String, dynamic>.from(v) : null;
int? _b(Object? btn) => (_map(btn)?['b'] as num?)?.toInt();

const _ink = Color(0xff1e1e1e);
const _muted = Color(0xff8a8fa3);
const _soft = Color(0xfff3f4f7);
const _page = Color(0xfff6f7f9);

abstract class OrderDetailActions {
  void scan();
  /// Tombol HTML ke-[index] di dalam rincian pesanan.
  void odButton(int index);
  /// Baris yang bisa diketuk (contoh: nomor HP).
  void odTap(int index);
  void odClose();
}

class NativeOrderDetail extends StatelessWidget {
  const NativeOrderDetail({super.key, required this.model, required this.actions, this.topInset});
  final Map<String, dynamic> model;
  final OrderDetailActions actions;
  final double? topInset;

  void _press(Object? btn) {
    final i = _b(btn);
    if (i != null && i >= 0) actions.odButton(i);
  }

  @override
  Widget build(BuildContext context) {
    final top = topInset ?? MediaQuery.paddingOf(context).top;
    final m = model;
    final banner = _map(m['banner']), cust = _map(m['customer']), total = _map(m['total']);
    final steps = _list(m['steps']), items = _list(m['items']), rows = _list(m['rows']), acts = _list(m['actions']);
    return Material(
      color: _page,
      child: Column(children: [
        Expanded(
          child: CustomScrollView(slivers: [
            SliverToBoxAdapter(child: GTopBar(top: top, onScan: actions.scan)),
            SliverPersistentHeader(pinned: true, delegate: _HeadDelegate(m, this)),
            if (banner != null) SliverToBoxAdapter(child: _banner(banner)),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            if (cust != null) SliverToBoxAdapter(child: _customer(cust)),
            if (steps.isNotEmpty) SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.only(top: 12), child: _Steps(steps))),
            if (items.isNotEmpty || _s(m['itemsTitle']).isNotEmpty) SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.only(top: 12), child: _items(m, items))),
            if (rows.isNotEmpty) SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.only(top: 12), child: _rows(rows))),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(children: [for (final a in acts) _action(a)]),
              ),
            ),
          ]),
        ),
        if (total != null) _bar(total),
      ]),
    );
  }

  Widget _banner(Map<String, dynamic> b) {
    final label = _map(b['label']);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cssColor(_s(b['bg']), const Color(0xfffff8ec)),
        border: Border(bottom: BorderSide(color: cssColor(_s(b['line']), const Color(0xffffe6c2)))),
      ),
      child: Row(children: [
        Container(
          width: 22, height: 22, alignment: Alignment.center,
          decoration: BoxDecoration(color: cssColor(_s(b['ic']), const Color(0xffe0a100)), shape: BoxShape.circle),
          child: Text(_s(b['icon']), style: gText(11, w: FontWeight.w600, c: Colors.white)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_s(b['t']), style: gText(12.5, w: FontWeight.w500, c: cssColor(_s(b['c']), const Color(0xff8a4b0f)), h: 17.5)),
            if (_s(b['s']).isNotEmpty) Text(_s(b['s']), style: gText(11, c: _muted, h: 15)),
          ]),
        ),
        if (label != null) ...[
          const SizedBox(width: 8),
          _Tap(
            onTap: () => _press(label),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xffe3dcf7))),
              child: Text(_s(label['t']), style: gText(11, w: FontWeight.w500, c: const Color(0xff6b46c1), h: 15.4)),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _customer(Map<String, dynamic> c) {
    Widget square(Color bg, String svg, Object? btn) => _Tap(
          onTap: () => _press(btn),
          child: Container(
            width: 44, height: 44, alignment: Alignment.center,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(13)),
            child: gSvg(svg, 20),
          ),
        );
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(
          width: 50, height: 50, alignment: Alignment.center,
          decoration: BoxDecoration(color: const Color(0xfff3f8fc), borderRadius: BorderRadius.circular(15)),
          child: _s(c['svg']).isEmpty ? const SizedBox() : gSvg(_s(c['svg']), 34),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_s(c['name']), maxLines: 1, overflow: TextOverflow.ellipsis, style: gText(17, c: _ink, h: 23.8)),
            const SizedBox(height: 2),
            Text(_s(c['sub']), style: gText(12.5, c: _muted, h: 17.5)),
          ]),
        ),
        if (c['wa'] != null) ...[const SizedBox(width: 12), square(const Color(0xff3dbe55), _waSvg, c['wa'])],
        if (c['print'] != null) ...[const SizedBox(width: 12), square(const Color(0xffa2a8dc), _printSvg, c['print'])],
      ]),
    );
  }

  Widget _items(Map<String, dynamic> m, List<Map<String, dynamic>> items) {
    final edit = _map(m['edit']);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(children: [
        Row(children: [
          Expanded(child: Text(_s(m['itemsTitle']), style: gText(14.5, w: FontWeight.w500, c: _ink, h: 20.3))),
          if (edit != null)
            _Tap(
              onTap: () => _press(edit),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(9)),
                child: Text(_s(edit['t']), style: gText(12, w: FontWeight.w500, c: _ink, h: 16.8)),
              ),
            ),
        ]),
        for (final it in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(children: [
              Container(
                width: 46, height: 46, alignment: Alignment.center,
                decoration: BoxDecoration(color: const Color(0xfff6f7f4), borderRadius: BorderRadius.circular(13)),
                child: _s(it['svg']).isEmpty ? const SizedBox() : gSvg(_s(it['svg']), 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_s(it['t']), style: gText(15, c: _ink, h: 19.5)),
                  const SizedBox(height: 3),
                  Text(_s(it['s']), style: gText(12.5, c: _muted, h: 17.5)),
                ]),
              ),
              const SizedBox(width: 12),
              Text(_s(it['v']), style: gText(14, c: _ink, h: 19.6)),
            ]),
          ),
      ]),
    );
  }

  Widget _rows(List<Map<String, dynamic>> rows) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(children: [
        for (final r in rows)
          if (r['line'] == true)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xffedf0f3)))),
              child: Row(children: [
                Expanded(child: Text(_s(r['k']), style: gText(12, c: const Color(0xff9299a6)))),
                Text(_s(r['v']), style: gText(12, w: FontWeight.w600, c: const Color(0xff20242b))),
              ]),
            )
          else
            _Tap(
              onTap: ((r['tap'] as num?)?.toInt() ?? -1) >= 0 ? () => actions.odTap((r['tap'] as num).toInt()) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(children: [
                  Text(_s(r['k']), style: gText(14, c: _muted, h: 19.6)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: r['pill'] == true
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(color: cssColor(_s(r['bg']), const Color(0xffeef1f5)), borderRadius: BorderRadius.circular(8)),
                              child: Text(_s(r['v']), style: gText(14, c: cssColor(_s(r['c']), _ink), h: 19.6)),
                            )
                          : Text(_s(r['v']), textAlign: TextAlign.right,
                              style: gText(14, c: ((r['tap'] as num?)?.toInt() ?? -1) >= 0 ? const Color(0xff2b6aa6) : _ink, h: 19.6)),
                    ),
                  ),
                ]),
              ),
            ),
      ]),
    );
  }

  Widget _action(Map<String, dynamic> a) {
    final green = a['green'] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _Tap(
        onTap: () => _press(a),
        child: Container(
          height: 50, width: double.infinity, alignment: Alignment.center,
          decoration: BoxDecoration(color: green ? const Color(0xff22b35e) : gBrand, borderRadius: BorderRadius.circular(green ? 14 : 10)),
          child: Text(_s(a['t']).toUpperCase(), style: gText(14.5, w: FontWeight.w500, c: Colors.white, h: 20.3, ls: green ? 0 : .4)),
        ),
      ),
    );
  }

  Widget _bar(Map<String, dynamic> t) {
    final pay = _map(t['pay']);
    return Container(
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [
        BoxShadow(color: Color(0xffeceef2), offset: Offset(0, -1)),
        BoxShadow(color: Color(0x0d172235), offset: Offset(0, -8), blurRadius: 20),
      ]),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(_s(t['label']), style: gText(13, c: _muted, h: 18.2)),
                Text(_s(t['v']), style: gText(22, w: FontWeight.w600, c: _ink, h: 30.8)),
                if (_s(t['s']).isNotEmpty) Text(_s(t['s']), style: gText(10.5, c: cssColor(_s(t['c']), const Color(0xffd8323f)), h: 14.7)),
              ]),
            ),
            if (pay != null)
              _Tap(
                onTap: () => _press(pay),
                child: Container(
                  height: 49, padding: const EdgeInsets.symmetric(horizontal: 32), alignment: Alignment.center,
                  decoration: BoxDecoration(color: gBrand, borderRadius: BorderRadius.circular(10)),
                  child: Text(_s(pay['t']).toUpperCase(), style: gText(15, w: FontWeight.w500, c: Colors.white, h: 21, ls: .4)),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class _HeadDelegate extends SliverPersistentHeaderDelegate {
  _HeadDelegate(this.m, this.page);
  final Map<String, dynamic> m;
  final NativeOrderDetail page;
  @override
  double get minExtent => 62;
  @override
  double get maxExtent => 62;
  @override
  bool shouldRebuild(covariant _HeadDelegate old) => old.m != m;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final head = _list(m['head']);
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Color(0xffeceef2), offset: Offset(0, 1))]),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(_s(m['title']).toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: gText(14.5, w: FontWeight.w600, c: _ink, h: 20.3, ls: .7)),
            Text(_s(m['sub']), maxLines: 1, overflow: TextOverflow.ellipsis, style: gText(12, c: _muted, h: 16.8)),
          ]),
        ),
        for (final b in head) ...[
          const SizedBox(width: 10),
          _Tap(
            onTap: () => _s(b['t']) == '×' ? page.actions.odClose() : page._press(b),
            child: Container(
              width: 38, height: 38, alignment: Alignment.center,
              decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(12)),
              child: Text(_s(b['t']), style: gText(17, w: FontWeight.w500, c: _ink, h: 17)),
            ),
          ),
        ],
      ]),
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps(this.steps);
  final List<Map<String, dynamic>> steps;
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
      child: LayoutBuilder(builder: (context, c) {
        final col = c.maxWidth / steps.length;
        return Stack(children: [
          Positioned(left: col / 2, right: col / 2, top: 11, height: 2, child: const ColoredBox(color: Color(0xffe7eaee))),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final s in steps)
              SizedBox(
                width: col,
                child: Column(children: [
                  _dot(s),
                  const SizedBox(height: 6),
                  // Seperti HTML: kata panjang ("Penjemputan") tidak dipotong, boleh sedikit melewati kolom.
                  OverflowBox(
                    minWidth: 0, maxWidth: col + 24, fit: OverflowBoxFit.deferToChild,
                    child: Text(_s(s['t']), textAlign: TextAlign.center,
                        style: gText(10.5, c: s['done'] == true ? const Color(0xff15885d) : (s['on'] == true ? _ink : const Color(0xff9aa1ad)), h: 14.7)),
                  ),
                ]),
              ),
          ]),
        ]);
      }),
    );
  }

  Widget _dot(Map<String, dynamic> s) {
    final on = s['on'] == true, done = s['done'] == true;
    final fill = done ? const Color(0xff15885d) : (on ? gBrand : Colors.white);
    return Container(
      width: 24, height: 24, alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill, shape: BoxShape.circle,
        border: Border.all(color: done || on ? fill : const Color(0xffe1e5ea), width: 2),
        boxShadow: on ? const [BoxShadow(color: Color(0x24ef3f4d), spreadRadius: 4)] : null,
      ),
      child: Text(_s(s['n']), style: gText(11, w: FontWeight.w600, c: done || on ? Colors.white : const Color(0xff9aa1ad), h: 15.4)),
    );
  }
}

class _Tap extends StatelessWidget {
  const _Tap({required this.onTap, required this.child});
  final VoidCallback? onTap;
  final Widget child;
  @override
  Widget build(BuildContext context) => GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: child);
}

const _waSvg = '<svg viewBox="0 0 24 24"><path d="M12 3a9 9 0 0 0-7.8 13.5L3 21l4.6-1.2A9 9 0 1 0 12 3z" fill="#fff"/><path d="M8.6 8.2c.2-.4.4-.4.7-.4h.5c.2 0 .4 0 .6.5l.8 1.9c.1.2 0 .4-.1.6l-.5.6c-.1.2-.2.3 0 .6.5.9 1.4 1.8 2.4 2.3.3.1.4.1.6-.1l.7-.8c.2-.2.3-.2.6-.1l1.8.9c.3.1.4.2.4.4 0 .6-.3 1.3-1 1.6-.6.3-1.4.4-2.8-.2a9.4 9.4 0 0 1-4.3-4c-.6-1.1-.6-2 .1-2.8z" fill="#3dbe55"/></svg>';
const _printSvg = '<svg viewBox="0 0 24 24"><path d="M7 8V3h10v5" fill="none" stroke="#fff" stroke-width="2"/><rect x="2" y="8" width="20" height="9" rx="2" fill="#fff"/><rect x="7" y="14" width="10" height="7" fill="#fff" stroke="#fff" stroke-width="2"/></svg>';
