import 'package:flutter/material.dart';
import 'common.dart';

// All amounts and reconciliation messages are read from HTML, never calculated here.
abstract class CashCloseActions {
  void scan();
  void nav(String pageId);
  void ccTap(String selector, int index, String? child);
  void ccType(String selector, String value);
}

String _s(dynamic v) => v?.toString() ?? '';
List<Map<String, dynamic>> _list(dynamic v) => (v is List ? v : const [])
    .whereType<Map>()
    .map((e) => Map<String, dynamic>.from(e))
    .toList();

class NativeCashClose extends StatelessWidget {
  const NativeCashClose({
    super.key,
    required this.model,
    required this.actions,
    this.topInset,
  });
  final Map<String, dynamic> model;
  final CashCloseActions actions;
  final double? topInset;

  Widget _text(dynamic t, [double size = 13, Color? color]) =>
      Text(_s(t), style: gText(size, c: color ?? gInk));
  Widget _field(Map m) => DomTextField(
    key: ValueKey(m['sel']),
    value: _s(m['v']),
    hint: _s(m['ph']),
    multiline: m['multiline'] == true,
    onChanged: (v) => actions.ccType(_s(m['sel']), v),
  );
  Widget _badge(Map m) => Container(
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: cssColor(_s(m['bg'])),
      borderRadius: BorderRadius.circular(8),
    ),
    child: _text(m['t'], 11, cssColor(_s(m['c']))),
  );
  Widget _section(Map<String, dynamic> s) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xffeceef4)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_s(s['title']), style: gText(14, w: FontWeight.w600)),
        if (_s(s['sub']).isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: _text(s['sub'], 11, Colors.grey),
          ),
        if (_list(s['methods']).isNotEmpty)
          Row(
            children: [
              for (final m in _list(s['methods']))
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(top: 8, right: 4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xfff6f7f9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _text(m['t'], 11, Colors.grey),
                        _text(m['v'], 13, cssColor(_s(m['c']))),
                        _text(m['s'], 10, Colors.grey),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        if (_s(s['unpaid']).isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _text(s['unpaid'], 11, const Color(0xff9a6a2a)),
          ),
        for (final r in _list(s['rows']))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              children: [
                Expanded(child: _text(r['t'], 12)),
                const SizedBox(width: 8),
                if (r['input'] is Map)
                  SizedBox(width: 115, child: _field(r['input']))
                else
                  _text(r['v'], 13, cssColor(_s(r['c']))),
              ],
            ),
          ),
        if (_list(s['denominations']).isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: LayoutBuilder(
              builder: (context, box) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in _list(s['denominations']))
                    SizedBox(
                      width: (box.maxWidth - 8) / 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xfff6f7f9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: _text(d['t'], 11)),
                            SizedBox(
                              width: 26,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                iconSize: 16,
                                tooltip: 'Kurangi ${d['t']}',
                                onPressed: () => actions.ccTap(
                                  '#kc-den label',
                                  d['i'],
                                  'button:first-of-type',
                                ),
                                icon: const Icon(Icons.remove),
                              ),
                            ),
                            SizedBox(
                              width: 30,
                              child: DomTextField(
                                key: ValueKey('den${d['i']}'),
                                value: _s(d['v']),
                                compact: true,
                                onChanged: (v) => actions.ccType(
                                  '#kc-den label:nth-child(${d['i'] + 1}) input',
                                  v,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 26,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                iconSize: 16,
                                tooltip: 'Tambah ${d['t']}',
                                onPressed: () => actions.ccTap(
                                  '#kc-den label',
                                  d['i'],
                                  'button:last-of-type',
                                ),
                                icon: const Icon(Icons.add),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (s['physical'] is Map)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                _text('Rp', 18),
                const SizedBox(width: 8),
                Expanded(child: _field(s['physical'])),
              ],
            ),
          ),
        if (s['diff'] is Map)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _badge(s['diff']),
          ),
        for (final r in _list(s['reconcile']))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _text(r['t']),
                          _text(r['s'], 10, Colors.grey),
                        ],
                      ),
                    ),
                    SizedBox(width: 100, child: _field(r['input'])),
                  ],
                ),
                const SizedBox(height: 4),
                _badge(r['badge']),
              ],
            ),
          ),
        if (s['note'] is Map) _field(s['note']),
        for (final r in _list(s['history']))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _text('${r['date']} · ${r['t']}'),
                _text(r['s'], 11, Colors.grey),
                _badge(r['badge']),
              ],
            ),
          ),
        if (_s(s['empty']).isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: _text(s['empty'], 12, Colors.grey),
          ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final sections = _list(model['sections']);
    return Material(
      color: const Color(0xfff6f7f9),
      child: Column(
        children: [
          GTopBar(
            top: topInset ?? MediaQuery.paddingOf(context).top,
            onScan: actions.scan,
          ),
          Container(
            color: Colors.white,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => actions.ccTap('#cashclose .back', 0, null),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    _s(model['title']).toUpperCase(),
                    style: gText(15, w: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(15),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xff1e1e1e), Color(0xff2c3e5c)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _text(model['date'], 11, Colors.white70),
                      _text(model['total'], 26, Colors.white),
                      _text(model['label'], 11, Colors.white70),
                      const SizedBox(height: 8),
                      _text(model['status'], 11, const Color(0xff6ee7b7)),
                      _text(model['meta'], 11, Colors.white70),
                    ],
                  ),
                ),
                for (var i = 0; i < sections.length; i++) ...[
                  if (i == sections.length - 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: gBrand,
                          minimumSize: const Size.fromHeight(52),
                        ),
                        onPressed: () {
                          FocusScope.of(context).unfocus();
                          actions.ccTap('#cashclose .kc137-go', 0, null);
                        },
                        child: Text(
                          _s(model['submit']),
                          textAlign: TextAlign.center,
                          style: gText(14, c: Colors.white, w: FontWeight.w600),
                        ),
                      ),
                    ),
                  _section(sections[i]),
                ],
              ],
            ),
          ),
          GBottomNav(active: 2, onTap: actions.nav),
        ],
      ),
    );
  }
}

/// Preserve the caret while the bridge returns formatted values; adopt HTML changes on blur.
class DomTextField extends StatefulWidget {
  const DomTextField({
    super.key,
    required this.value,
    required this.onChanged,
    this.hint = '',
    this.multiline = false,
    this.compact = false,
  });
  final String value, hint;
  final bool multiline, compact;
  final ValueChanged<String> onChanged;
  @override
  State<DomTextField> createState() => _DomTextFieldState();
}

class _DomTextFieldState extends State<DomTextField> {
  late final _controller = TextEditingController(text: widget.value);
  final _focus = FocusNode();
  @override
  void initState() {
    super.initState();
    _focus.addListener(_sync);
  }

  void _sync() {
    if (!_focus.hasFocus && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void didUpdateWidget(DomTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    focusNode: _focus,
    onChanged: widget.onChanged,
    keyboardType: widget.multiline
        ? TextInputType.multiline
        : TextInputType.number,
    maxLines: widget.multiline ? 3 : 1,
    style: gText(widget.compact ? 12 : 13),
    textAlign: widget.compact ? TextAlign.center : TextAlign.start,
    decoration: InputDecoration(
      hintText: widget.hint,
      isDense: true,
      contentPadding: EdgeInsets.all(widget.compact ? 2 : 9),
      border: widget.compact
          ? InputBorder.none
          : OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}
