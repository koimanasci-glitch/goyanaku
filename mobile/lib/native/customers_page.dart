import 'dart:async';

import 'package:flutter/material.dart';

import 'common.dart';

// Pelanggan (HTML #customers, cust59). Daftar & database native; ranking pelanggan tetap HTML saat dibuka.
// Baris database ditata ulang: versi HTML memakai huruf 7–9px dan "Saldo" tampil sebagai kotak kosong.

String _s(Object? v) => v is String ? v : (v == null ? '' : '$v');
Map<String, dynamic>? _map(Object? v) => v is Map ? Map<String, dynamic>.from(v) : null;

class CustRow {
  const CustRow({required this.index, required this.name, this.avatar = '', this.lines = const [], this.spend = '', this.orders = '',
      this.last = '', this.balance = '', this.topup = '', this.edit = ''});
  factory CustRow.fromJson(Map<String, dynamic> j) => CustRow(
        index: (j['i'] as num?)?.toInt() ?? 0, name: _s(j['name']), avatar: _s(j['avatar']),
        lines: (j['lines'] as List?)?.map(_s).toList() ?? const [], spend: _s(j['spend']), orders: _s(j['orders']), last: _s(j['last']),
        balance: _s(j['balance']), topup: _s(j['topup']), edit: _s(j['edit']));
  final int index;
  final String name, avatar, spend, orders, last, balance, topup, edit;
  final List<String> lines;
}

class CustomersModel {
  const CustomersModel({
    this.title = 'Pelanggan', this.sub = '', this.search = '', this.placeholder = '', this.deposit = '', this.add = '',
    this.dbTitle, this.dbSub = '', this.dbOpen = false, this.listTitle = '', this.listSub = '', this.filter = '',
    this.rankTitle, this.rankSub = '', this.rankIcon = '', this.crmTitle, this.crmBadge = '', this.crmSub = '', this.crmIcon = '',
    this.rows = const [], this.empty = '', this.pager,
  });

  factory CustomersModel.fromJson(Map<String, dynamic> j) {
    final search = _map(j['search']), db = _map(j['db']), rank = _map(j['rank']), crm = _map(j['crm']), pager = _map(j['pager']);
    return CustomersModel(
      title: _s(j['title']), sub: _s(j['sub']), search: _s(search?['v']), placeholder: _s(search?['ph']),
      deposit: _s(j['deposit']), add: _s(j['add']),
      dbTitle: db == null ? null : _s(db['t']), dbSub: _s(db?['s']), dbOpen: db?['open'] == true,
      listTitle: _s(j['dbTitle']), listSub: _s(j['dbSub']), filter: _s(j['filter']),
      rankTitle: rank == null ? null : _s(rank['t']), rankSub: _s(rank?['s']), rankIcon: _s(rank?['icon']),
      crmTitle: crm == null ? null : _s(crm['t']), crmBadge: _s(crm?['badge']), crmSub: _s(crm?['s']), crmIcon: _s(crm?['icon']),
      rows: (j['rows'] is List ? (j['rows'] as List) : const []).whereType<Map>().map((e) => CustRow.fromJson(Map<String, dynamic>.from(e))).toList(),
      empty: _s(j['empty']), pager: pager,
    );
  }

  final String title, sub, search, placeholder, deposit, add, dbSub, listTitle, listSub, filter, rankSub, rankIcon, crmBadge, crmSub, crmIcon, empty;
  final String? dbTitle, rankTitle, crmTitle;
  final bool dbOpen;
  final List<CustRow> rows;
  final Map<String, dynamic>? pager;
}

abstract class CustomersActions {
  void scan();
  void nav(String pageId);
  void cuBack();
  void cuSearch(String text);
  void cuDeposit();
  void cuAdd();
  void cuToggleDb();
  void cuFilter();
  void cuTopUp(int index);
  void cuEdit(int index);
  void cuPage(int delta);
  void cuRank();
  void cuCrm();
}

const _ink = Color(0xff1e1e1e);
const _muted = Color(0xff8a8fa3);

class NativeCustomers extends StatefulWidget {
  const NativeCustomers({super.key, required this.model, required this.actions, this.topInset});
  final CustomersModel model;
  final CustomersActions actions;
  final double? topInset;
  @override
  State<NativeCustomers> createState() => _NativeCustomersState();
}

class _NativeCustomersState extends State<NativeCustomers> {
  late final TextEditingController _search = TextEditingController(text: widget.model.search);
  final _focus = FocusNode();
  Timer? _debounce;

  @override
  void didUpdateWidget(NativeCustomers old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && _search.text != widget.model.search) _search.text = widget.model.search;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () => widget.actions.cuSearch(v));
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.model, a = widget.actions;
    final top = widget.topInset ?? MediaQuery.paddingOf(context).top;
    final rows = <Widget>[
      _Search(controller: _search, focus: _focus, placeholder: m.placeholder, onChanged: _onSearch),
      if (m.deposit.isNotEmpty) ...[
        const SizedBox(height: 10),
        _Tap(onTap: a.cuDeposit, child: Container(
          height: 45, padding: const EdgeInsets.symmetric(horizontal: 15), alignment: Alignment.centerLeft,
          decoration: BoxDecoration(color: const Color(0xfffff6f3), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xfff0d6d1))),
          child: Row(children: [
            Expanded(child: Text(m.deposit, style: gText(12.5, w: FontWeight.w500, c: const Color(0xffd34d41)))),
            const Icon(Icons.chevron_right_rounded, color: Color(0xffd34d41), size: 20),
          ]),
        )),
      ],
      if (m.add.isNotEmpty) ...[
        const SizedBox(height: 10),
        _Tap(onTap: a.cuAdd, child: Container(
          height: 45, alignment: Alignment.center,
          decoration: BoxDecoration(color: gBrand, borderRadius: BorderRadius.circular(13)),
          child: Text('＋  ${m.add}', style: gText(13.5, w: FontWeight.w500, c: Colors.white)),
        )),
      ],
      if (m.dbTitle != null) ...[
        const SizedBox(height: 12),
        _EntryCard(icon: const Icon(Icons.storage_rounded, size: 20, color: Color(0xff5b6475)), iconBg: const Color(0xfff2f4f7),
            title: m.dbTitle!, sub: m.dbSub, open: m.dbOpen, onTap: a.cuToggleDb),
      ],
      if (m.dbOpen) ...[
        const SizedBox(height: 10),
        _DbList(model: m, actions: a),
      ],
      if (m.rankTitle != null) ...[
        const SizedBox(height: 12),
        _EntryCard(icon: Text(m.rankIcon, style: const TextStyle(fontSize: 22)), iconBg: const Color(0xffe3edff), title: m.rankTitle!, sub: m.rankSub,
            gradient: const [Color(0xfff1f6ff), Colors.white], onTap: a.cuRank),
      ],
      if (m.crmTitle != null) ...[
        const SizedBox(height: 12),
        _EntryCard(icon: Text(m.crmIcon, style: const TextStyle(fontSize: 22)), iconBg: const Color(0xfffff1d6), title: m.crmTitle!, badge: m.crmBadge,
            sub: m.crmSub, gradient: const [Color(0xfffff8ec), Colors.white], onTap: a.cuCrm),
      ],
    ];
    return Material(
      color: const Color(0xfff4f5f7),
      child: Stack(children: [
        Column(children: [
          RepaintBoundary(child: GTopBar(top: top, onScan: a.scan)),
          _SubHead(title: m.title, sub: m.sub, onBack: a.cuBack),
          Expanded(
            child: ListView.builder(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 105),
              itemCount: rows.length,
              itemBuilder: (context, i) => rows[i],
            ),
          ),
        ]),
        Positioned(left: 0, right: 0, bottom: 0, child: GBottomNav(active: 0, onTap: a.nav)),
      ]),
    );
  }
}

class _Tap extends StatelessWidget {
  const _Tap({required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;
  @override
  Widget build(BuildContext context) => GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: child);
}

class _SubHead extends StatelessWidget {
  const _SubHead({required this.title, required this.sub, required this.onBack});
  final String title, sub;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => Container(
        height: 55,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xfff1f2f5)))),
        child: Row(children: [
          _Tap(
            onTap: onBack,
            child: Container(
              width: 38, height: 32, alignment: Alignment.center,
              decoration: BoxDecoration(color: const Color(0xfff3f4f7), borderRadius: BorderRadius.circular(9)),
              child: Text('‹', style: gText(20, w: FontWeight.w500, c: _ink, h: 20)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title.toUpperCase(), style: gText(14.5, w: FontWeight.w600, c: _ink, ls: .7, h: 18.85)),
              if (sub.isNotEmpty) ...[const SizedBox(height: 3), Text(sub, style: gText(11.5, c: _muted, h: 16.1))],
            ]),
          ),
        ]),
      );
}

class _Search extends StatelessWidget {
  const _Search({required this.controller, required this.focus, required this.placeholder, required this.onChanged});
  final TextEditingController controller;
  final FocusNode focus;
  final String placeholder;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Container(
        height: 46,
        padding: const EdgeInsets.only(left: 12, right: 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xffdfe3e8))),
        child: Row(children: [
          const Icon(Icons.search_rounded, size: 18, color: Color(0xff8f98a4)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller, focusNode: focus, onChanged: onChanged, cursorColor: gBrand,
              textInputAction: TextInputAction.search, style: gText(13.5, c: _ink),
              decoration: InputDecoration(isCollapsed: true, border: InputBorder.none, hintText: placeholder, hintStyle: gText(13.5, c: const Color(0xffb4b8c4))),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, v, _) => v.text.isEmpty
                ? const SizedBox.shrink()
                : _Tap(onTap: () { controller.clear(); onChanged(''); },
                    child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.close_rounded, size: 18, color: Color(0xff929ba7)))),
          ),
        ]),
      );
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.icon, required this.iconBg, required this.title, required this.sub, required this.onTap, this.badge = '', this.gradient, this.open});
  final Widget icon;
  final Color iconBg;
  final String title, sub, badge;
  final VoidCallback onTap;
  final List<Color>? gradient;
  final bool? open;
  @override
  Widget build(BuildContext context) => _Tap(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: gradient == null ? Colors.white : null,
            gradient: gradient == null ? null : LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient!),
            borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xfff1f2f5)),
          ),
          child: Row(children: [
            Container(width: 44, height: 44, alignment: Alignment.center,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(13)), child: icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
                  Text(title, style: gText(14, w: FontWeight.w500, c: _ink, h: 19.6)),
                  if (badge.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xffc98a06), borderRadius: BorderRadius.circular(6)),
                      child: Text(badge, style: gText(9.5, c: Colors.white, h: 13.3)),
                    ),
                ]),
                if (sub.isNotEmpty) Text(sub, style: gText(11.5, c: _muted, h: 16.1)),
              ]),
            ),
            const SizedBox(width: 8),
            Icon(open == true ? Icons.expand_less_rounded : (open == false ? Icons.expand_more_rounded : Icons.chevron_right_rounded),
                color: const Color(0xff9ca4af), size: 22),
          ]),
        ),
      );
}

class _DbList extends StatelessWidget {
  const _DbList({required this.model, required this.actions});
  final CustomersModel model;
  final CustomersActions actions;
  @override
  Widget build(BuildContext context) {
    final m = model, p = m.pager;
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xfff1f2f5))),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m.listTitle, style: gText(13.5, w: FontWeight.w500, c: _ink)),
                if (m.listSub.isNotEmpty) Text(m.listSub, style: gText(11, c: _muted)),
              ]),
            ),
            if (m.filter.isNotEmpty)
              _Tap(onTap: actions.cuFilter, child: Container(
                height: 32, padding: const EdgeInsets.symmetric(horizontal: 12), alignment: Alignment.center,
                decoration: BoxDecoration(color: const Color(0xfff3f5f7), borderRadius: BorderRadius.circular(9)),
                child: Text(m.filter, style: gText(12, w: FontWeight.w500, c: _ink)),
              )),
          ]),
        ),
        for (final r in m.rows) _Row(row: r, actions: actions),
        if (m.rows.isEmpty)
          Padding(padding: const EdgeInsets.all(24), child: Text(m.empty.isNotEmpty ? m.empty : 'Belum ada pelanggan', textAlign: TextAlign.center, style: gText(13, c: _muted))),
        if (p != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(children: [
              _PagerButton(label: _s(p['prev']), enabled: p['canPrev'] == true, primary: false, onTap: () => actions.cuPage(-1)),
              Expanded(child: Text(_s(p['info']), textAlign: TextAlign.center, style: gText(11.5, c: _muted))),
              _PagerButton(label: _s(p['next']), enabled: p['canNext'] == true, primary: true, onTap: () => actions.cuPage(1)),
            ]),
          ),
      ]),
    );
  }
}

class _PagerButton extends StatelessWidget {
  const _PagerButton({required this.label, required this.enabled, required this.primary, required this.onTap});
  final String label;
  final bool enabled, primary;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Opacity(
        opacity: enabled ? 1 : .45,
        child: _Tap(
          onTap: enabled ? onTap : () {},
          child: Container(
            height: 35, padding: const EdgeInsets.symmetric(horizontal: 12), alignment: Alignment.center,
            decoration: BoxDecoration(color: primary ? gBrand : Colors.white, borderRadius: BorderRadius.circular(10),
                border: Border.all(color: primary ? gBrand : const Color(0xffe1e5ea))),
            child: Text(label, style: gText(12, w: FontWeight.w500, c: primary ? Colors.white : _ink)),
          ),
        ),
      );
}

class _Row extends StatelessWidget {
  const _Row({required this.row, required this.actions});
  final CustRow row;
  final CustomersActions actions;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xfff1f2f5)))),
        child: Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 44, height: 44, padding: const EdgeInsets.all(1),
              decoration: BoxDecoration(color: const Color(0xfff7f9fc), borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xffedf0f4)), boxShadow: [gShadow(const Color(0x0f142038), 6, 16)]),
              child: ClipRRect(borderRadius: BorderRadius.circular(13),
                  child: row.avatar.isEmpty ? const Icon(Icons.person_rounded, color: Color(0xff5c97f8)) : gSvg(row.avatar, 42)),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(row.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: gText(14, w: FontWeight.w500, c: _ink, h: 19.6)),
                for (final l in row.lines) Text(l, maxLines: 1, overflow: TextOverflow.ellipsis, style: gText(11.5, c: const Color(0xff8f98a5), h: 16)),
                if (row.spend.isNotEmpty) Text(row.spend, style: gText(11.5, w: FontWeight.w500, c: const Color(0xff15885d), h: 16)),
              ]),
            ),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${row.orders} order', style: gText(12, w: FontWeight.w500, c: _ink)),
              Text(row.last, style: gText(11, c: const Color(0xff8f98a5))),
            ]),
          ]),
          if (row.balance.isNotEmpty || row.edit.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: Text(row.balance, style: gText(12, w: FontWeight.w500, c: const Color(0xff477060)))),
              if (row.edit.isNotEmpty)
                _Tap(onTap: () => actions.cuEdit(row.index), child: Container(
                  height: 34, padding: const EdgeInsets.symmetric(horizontal: 14), alignment: Alignment.center,
                  decoration: BoxDecoration(color: const Color(0xfff6f7f9), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xffe1e5ea))),
                  child: Text(row.edit, style: gText(12, w: FontWeight.w500, c: const Color(0xff222222))),
                )),
              if (row.topup.isNotEmpty) ...[
                const SizedBox(width: 8),
                _Tap(onTap: () => actions.cuTopUp(row.index), child: Container(
                  height: 34, padding: const EdgeInsets.symmetric(horizontal: 12), alignment: Alignment.center,
                  decoration: BoxDecoration(color: const Color(0xfffff6f3), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xfff0d6d1))),
                  child: Text(row.topup, style: gText(12, w: FontWeight.w500, c: const Color(0xffd34d41))),
                )),
              ],
            ]),
          ],
        ]),
      );
}
