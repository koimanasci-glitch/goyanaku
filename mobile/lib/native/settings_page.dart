import 'package:flutter/material.dart';

import 'common.dart';

// Pengaturan (HTML #settings). Kartu sinkron, grup akordeon, kartu paket & keluar akun native.
// Setiap item membuka halaman HTML yang sama (logika tidak diubah).

String _s(Object? v) => v is String ? v.trim() : (v == null ? '' : '$v');
List<Map<String, dynamic>> _list(Object? v) =>
    v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];
Map<String, dynamic>? _map(Object? v) => v is Map ? Map<String, dynamic>.from(v) : null;

class StItem {
  const StItem(this.index, this.icon, this.title, this.badge, this.sub);
  final int index;
  final String icon, title, badge, sub;
}

class StGroup {
  const StGroup({required this.index, this.svg = '', this.icon = '', this.title = '', this.sub = '', this.accordion = false, this.open = false, this.items = const []});
  final int index;
  final String svg, icon, title, sub;
  final bool accordion, open;
  final List<StItem> items;
}

class SettingsModel {
  const SettingsModel({
    this.title = 'Pengaturan', this.sync, this.groups = const [], this.acct, this.logout = '', this.version = '', this.tutorial = '',
  });
  factory SettingsModel.fromJson(Map<String, dynamic> j) => SettingsModel(
        title: _s(j['title']), sync: _map(j['sync']),
        groups: _list(j['groups']).map((g) => StGroup(
              index: (g['i'] as num?)?.toInt() ?? 0, svg: _s(g['svg']), icon: _s(g['icon']), title: _s(g['t']), sub: _s(g['s']),
              accordion: g['accordion'] == true, open: g['open'] == true,
              items: _list(g['items']).map((it) => StItem((it['j'] as num?)?.toInt() ?? 0, _s(it['icon']), _s(it['t']), _s(it['badge']), _s(it['s']))).toList(),
            )).toList(),
        acct: _map(j['acct']), logout: _s(j['logout']), version: _s(j['version']), tutorial: _s(j['tutorial']),
      );
  final String title, logout, version, tutorial;
  final Map<String, dynamic>? sync, acct;
  final List<StGroup> groups;
}

abstract class SettingsActions {
  void scan();
  void nav(String pageId);
  void stGroup(int index, bool accordion);
  void stItem(int group, int item);
  void stSyncUrl(String url);
  void stSyncSave();
  void stSyncNow();
  void stAcctGo();
  void stAcctAction(int index);
  void stAcctLink();
  void stLogout();
  void stTutorial();
}

const _ink = Color(0xff202024);
const _muted = Color(0xff8b94a3);

class NativeSettings extends StatefulWidget {
  const NativeSettings({super.key, required this.model, required this.actions, this.topInset});
  final SettingsModel model;
  final SettingsActions actions;
  final double? topInset;
  @override
  State<NativeSettings> createState() => _NativeSettingsState();
}

class _NativeSettingsState extends State<NativeSettings> {
  late final TextEditingController _url = TextEditingController(text: _s(_map(widget.model.sync?['url'])?['v']));
  final _focus = FocusNode();

  @override
  void didUpdateWidget(NativeSettings old) {
    super.didUpdateWidget(old);
    final v = _s(_map(widget.model.sync?['url'])?['v']);
    if (!_focus.hasFocus && _url.text != v) _url.text = v;
  }

  @override
  void dispose() {
    _url.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.model, a = widget.actions;
    final top = widget.topInset ?? MediaQuery.paddingOf(context).top;
    final rows = <Widget>[
      if (m.sync != null) _SyncCard(sync: m.sync!, controller: _url, focus: _focus, actions: a),
      for (final g in m.groups) _Group(group: g, actions: a),
      if (m.acct != null) ...[const SizedBox(height: 16), _AcctCard(acct: m.acct!, actions: a)],
      if (m.logout.isNotEmpty) ...[
        const SizedBox(height: 16),
        GestureDetector(
          onTap: a.stLogout,
          child: Container(
            height: 50, alignment: Alignment.center,
            decoration: BoxDecoration(color: gBrand, borderRadius: BorderRadius.circular(14)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(m.logout, style: gText(14.5, w: FontWeight.w500, c: Colors.white)),
            ]),
          ),
        ),
      ],
      if (m.version.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(m.version, textAlign: TextAlign.center, style: gText(11, c: const Color(0xff9aa0ac)))),
      if (m.tutorial.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Center(
            child: GestureDetector(
              onTap: a.stTutorial,
              child: Container(
                height: 42, padding: const EdgeInsets.symmetric(horizontal: 16), alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xffe6e8ec))),
                child: Text(m.tutorial, style: gText(13, w: FontWeight.w500, c: gBrand)),
              ),
            ),
          ),
        ),
    ];
    return Material(
      color: Colors.white,
      child: Stack(children: [
        Column(children: [
          RepaintBoundary(child: GTopBar(top: top, onScan: a.scan)),
          Container(
            height: 50, color: Colors.white, alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(m.title.toUpperCase(), style: gText(14.5, w: FontWeight.w600, c: const Color(0xff1e1e1e), ls: .7)),
          ),
          Expanded(
            child: ListView.builder(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
              itemCount: rows.length,
              itemBuilder: (context, i) => rows[i],
            ),
          ),
        ]),
        Positioned(left: 0, right: 0, bottom: 0, child: GBottomNav(active: 3, onTap: a.nav)),
      ]),
    );
  }
}

class _SyncCard extends StatelessWidget {
  const _SyncCard({required this.sync, required this.controller, required this.focus, required this.actions});
  final Map<String, dynamic> sync;
  final TextEditingController controller;
  final FocusNode focus;
  final SettingsActions actions;
  @override
  Widget build(BuildContext context) {
    final url = _map(sync['url']), save = _s(sync['save']), now = _s(sync['now']), who = _s(sync['who']);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xffeef0f3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(color: cssColor(_s(sync['dot']), const Color(0xff9aa0a6)), shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(_s(sync['t']), style: gText(13.5, w: FontWeight.w500, c: const Color(0xff1e1e1e))),
        ]),
        const SizedBox(height: 4),
        Text(_s(sync['line']), style: gText(13, c: const Color(0xff5b5f6e), h: 18)),
        if (who.isNotEmpty) Text(who, style: gText(12, c: const Color(0xff9aa0a6))),
        if (url != null) ...[
          const SizedBox(height: 8),
          Container(
            height: 38, padding: const EdgeInsets.symmetric(horizontal: 10), alignment: Alignment.centerLeft,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xffe6e8ec))),
            child: TextField(
              controller: controller, focusNode: focus, keyboardType: TextInputType.url, cursorColor: gBrand, style: gText(13, c: const Color(0xff1e1e1e)),
              onChanged: actions.stSyncUrl,
              decoration: InputDecoration(isCollapsed: true, border: InputBorder.none, hintText: _s(url['ph']), hintStyle: gText(13, c: const Color(0xffb4b8c4))),
            ),
          ),
        ],
        if (save.isNotEmpty) ...[
          const SizedBox(height: 6),
          _Pill(label: save, primary: true, onTap: () { focus.unfocus(); actions.stSyncSave(); }),
        ],
        if (now.isNotEmpty) ...[
          const SizedBox(height: 8),
          _Pill(label: now, primary: false, onTap: actions.stSyncNow),
        ],
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.primary, required this.onTap});
  final String label;
  final bool primary;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 34, padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: primary ? gBrand : Colors.white, borderRadius: BorderRadius.circular(10),
              border: primary ? null : Border.all(color: const Color(0xffe6e8ec))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: gText(13, w: FontWeight.w600, c: primary ? Colors.white : const Color(0xff1e1e1e))),
          ]),
        ),
      );
}

class _Group extends StatelessWidget {
  const _Group({required this.group, required this.actions});
  final StGroup group;
  final SettingsActions actions;
  @override
  Widget build(BuildContext context) {
    final g = group;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => actions.stGroup(g.index, g.accordion),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            SizedBox(width: 38, height: 38, child: Center(
              child: g.svg.isNotEmpty ? gSvg(g.svg, 38) : Text(g.icon, style: const TextStyle(fontSize: 28, height: 1.1)),
            )),
            const SizedBox(width: 13),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(g.title, style: gText(15, w: FontWeight.w500, c: _ink, h: 19.5)),
                const SizedBox(height: 3),
                Text(g.sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: gText(11, c: _muted, h: 14.85)),
              ]),
            ),
            const SizedBox(width: 8),
            Icon(g.accordion ? (g.open ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded) : Icons.chevron_right_rounded,
                size: 20, color: const Color(0xffa0a4ac)),
          ]),
        ),
      ),
      if (g.open && g.items.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(left: 55, bottom: 6),
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(color: const Color(0xfffafbfc), borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (final it in g.items)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => actions.stItem(g.index, it.index),
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 11, 14, 11),
                  child: Row(children: [
                    SizedBox(width: 34, height: 34, child: Center(child: Text(it.icon, style: const TextStyle(fontSize: 17)))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, runSpacing: 2, children: [
                          Text(it.title, style: gText(13.5, w: FontWeight.w500, c: const Color(0xff1e1e1e), h: 17.55)),
                          if (it.badge.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(color: const Color(0xfffff7ec), borderRadius: BorderRadius.circular(7), border: Border.all(color: const Color(0xffffe2b8))),
                              child: Text(it.badge, style: gText(10, c: const Color(0xffb86a14), h: 13)),
                            ),
                        ]),
                        const SizedBox(height: 1),
                        Text(it.sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: gText(11, c: const Color(0xff8a8fa3), h: 14.85)),
                      ]),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xffa0a4ac)),
                  ]),
                ),
              ),
          ]),
        ),
    ]);
  }
}

class _AcctCard extends StatelessWidget {
  const _AcctCard({required this.acct, required this.actions});
  final Map<String, dynamic> acct;
  final SettingsActions actions;
  @override
  Widget build(BuildContext context) {
    final stats = (acct['stats'] as List?)?.map(_s).where((e) => e.isNotEmpty).toList() ?? const <String>[];
    final acts = (acct['acts'] as List?)?.map(_s).toList() ?? const <String>[];
    final go = _s(acct['go']), link = _s(acct['link']);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xfff7f8fa), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xffeef0f3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          if (_s(acct['badge']).isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: gBrand, borderRadius: BorderRadius.circular(7)),
              child: Text(_s(acct['badge']), style: gText(9.5, w: FontWeight.w600, c: Colors.white)),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_s(acct['t']), style: gText(13.5, w: FontWeight.w500, c: const Color(0xff1e1e1e))),
              Text(_s(acct['s']), style: gText(12, c: const Color(0xff6b7280))),
            ]),
          ),
          if (go.isNotEmpty)
            GestureDetector(
              onTap: actions.stAcctGo,
              child: Container(
                height: 38, padding: const EdgeInsets.symmetric(horizontal: 12), alignment: Alignment.center,
                decoration: BoxDecoration(color: gBrand, borderRadius: BorderRadius.circular(11)),
                child: Text(go, style: gText(12.5, w: FontWeight.w500, c: Colors.white)),
              ),
            ),
        ]),
        if (stats.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 12, runSpacing: 4, children: [for (final st in stats) Text(st, style: gText(11.5, c: const Color(0xff5b5f6e)))]),
        ],
        if (acts.any((e) => e.isNotEmpty)) ...[
          const SizedBox(height: 10),
          Row(children: [
            for (var i = 0; i < acts.length; i++)
              if (acts[i].isNotEmpty)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
                    child: GestureDetector(
                      onTap: () => actions.stAcctAction(i),
                      child: Container(
                        height: 38, alignment: Alignment.center,
                        decoration: BoxDecoration(color: i == 0 ? gBrand : Colors.white, borderRadius: BorderRadius.circular(11),
                            border: i == 0 ? null : Border.all(color: const Color(0xffe6e8ec))),
                        child: Text(acts[i], style: gText(12.5, w: FontWeight.w500, c: i == 0 ? Colors.white : const Color(0xff1e1e1e))),
                      ),
                    ),
                  ),
                ),
          ]),
        ],
        if (link.isNotEmpty)
          GestureDetector(
            onTap: actions.stAcctLink,
            child: Padding(padding: const EdgeInsets.only(top: 10), child: Text(link, textAlign: TextAlign.right, style: gText(12, w: FontWeight.w500, c: gBrand))),
          ),
      ]),
    );
  }
}
