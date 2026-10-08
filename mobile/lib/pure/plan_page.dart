// Harga Paket (Mode Murni): tampilan kartu paket dalam grid, ikon per paket, rincian fitur per paket.
// Isi (nama, harga, batas cabang, fitur) mengikuti aturan paket yang benar-benar dipakai aplikasi (access.dart);
// pembayaran belum tersambung server, jadi tombol Pilih menampilkan rincian + keterangan jujur.

import 'package:flutter/material.dart';

import '../native/common.dart';

const _ink = Color(0xff1e1e1e);
const _muted = Color(0xff8a8fa3);
const _line = Color(0xffeceef2);

class PlanInfo {
  const PlanInfo(this.id, this.tagline, this.price, this.per, this.color, this.soft, this.icon, this.short, this.features);
  final String id, tagline, price, per, icon;
  final Color color, soft;
  /// 3 butir ringkas di kartu.
  final List<String> short;
  /// Daftar lengkap di rincian.
  final List<String> features;
}

const _plane = '<svg viewBox="0 0 24 24"><path d="M3 11.2 21 3l-6.2 18-3.2-7.4L3 11.2Z" fill="#fff"/><path d="m11.6 13.6 4-5.2" stroke="#fff" stroke-width="1.6" stroke-linecap="round"/></svg>';
const _store = '<svg viewBox="0 0 24 24"><path d="M4.5 4h15l1.5 5a2.6 2.6 0 0 1-5 .6 2.6 2.6 0 0 1-4 0 2.6 2.6 0 0 1-4 0A2.6 2.6 0 0 1 3 9l1.5-5Z" fill="#fff"/><path d="M5 12.5V20h5v-4.5h4V20h5v-7.5" fill="none" stroke="#fff" stroke-width="2" stroke-linejoin="round"/></svg>';
const _bars = '<svg viewBox="0 0 24 24"><rect x="4" y="13" width="4" height="7" rx="1.5" fill="#fff"/><rect x="10" y="9" width="4" height="11" rx="1.5" fill="#fff"/><rect x="16" y="4" width="4" height="16" rx="1.5" fill="#fff"/></svg>';
const _star = '<svg viewBox="0 0 24 24"><path d="m12 2.8 2.8 5.8 6.4.9-4.6 4.5 1.1 6.3L12 17.3l-5.7 3 1.1-6.3L2.8 9.5l6.4-.9L12 2.8Z" fill="#fff"/></svg>';
const _crown = '<svg viewBox="0 0 24 24"><path d="M3 8.5 7.5 12 12 5l4.5 7L21 8.5 19.3 18H4.7L3 8.5Z" fill="#fff"/><rect x="4.7" y="19" width="14.6" height="2" rx="1" fill="#fff"/></svg>';
const _bot = '<svg viewBox="0 0 24 24"><rect x="4" y="8" width="16" height="12" rx="4" fill="#fff"/><path d="M12 8V4.5" stroke="#fff" stroke-width="2" stroke-linecap="round"/><circle cx="12" cy="3.5" r="1.6" fill="#fff"/><circle cx="9" cy="13.5" r="1.5" fill="#7c5ce0"/><circle cx="15" cy="13.5" r="1.5" fill="#7c5ce0"/></svg>';
const _building = '<svg viewBox="0 0 24 24"><path d="M5 21V5.5L13 3v18" fill="#fff"/><path d="M13 9h6v12h-6" fill="#fff" opacity=".75"/><path d="M8 8h2M8 12h2M8 16h2" stroke="#f08a24" stroke-width="1.8" stroke-linecap="round"/></svg>';
const _chat = '<svg viewBox="0 0 24 24"><path d="M5 4h14a3 3 0 0 1 3 3v8a3 3 0 0 1-3 3h-7l-5 4v-4H5a3 3 0 0 1-3-3V7a3 3 0 0 1 3-3Z" fill="#fff"/><circle cx="8" cy="11" r="1.3" fill="#2f8fe8"/><circle cx="12" cy="11" r="1.3" fill="#2f8fe8"/><circle cx="16" cy="11" r="1.3" fill="#2f8fe8"/></svg>';
const _doc = '<svg viewBox="0 0 24 24"><rect x="5" y="3" width="14" height="18" rx="3" fill="none" stroke="#e8493f" stroke-width="2"/><path d="M9 8h6M9 12h6M9 16h3.5" stroke="#e8493f" stroke-width="2" stroke-linecap="round"/></svg>';

/// Paket GOYANA. Batas cabang & fitur sama dengan kunci paket di access.dart.
const planInfos = [
  PlanInfo('FREE', 'Trial seluruh fitur Basic selama 2 bulan', 'Gratis', '2 bulan', Color(0xff8f97a6), Color(0xfff1f3f6), _plane,
      ['Semua fitur Basic', '1 pusat + 1 cabang', 'Data tetap tersimpan'],
      ['Semua fitur Basic selama 2 bulan', 'Kasir, pesanan, pelanggan dan laporan', '1 pusat + 1 cabang', 'Nota WhatsApp manual', 'Setelah trial berakhir, data lama tetap tersimpan']),
  PlanInfo('BASIC', 'Kasir harian, kurir, peta pelanggan dan monitoring cabang', 'Rp30.000', '/bulan', Color(0xff2f8fe8), Color(0xffeaf3fe), _store,
      ['Kasir & laporan', '1 pusat + 1 cabang', 'Kurir & antar-jemput'],
      ['Kasir harian, pesanan dan pelanggan', 'Laporan usaha lengkap', 'Pegawai dan hak akses', 'Kurir dan antar-jemput', 'Peta lokasi pelanggan', 'Monitoring cabang', '1 pusat + 1 cabang', 'Nota WhatsApp manual']),
  PlanInfo('SILVER', 'Operasional lengkap, stok, HPP dan Balasan Cepat & Trigger', 'Rp65.000', '/bulan', Color(0xff7c5ce0), Color(0xfff1edfd), _bars,
      ['Semua fitur Basic', '1 pusat + 2 cabang', 'Stok bahan & HPP'],
      ['Semua fitur Basic', 'Stok bahan, opname dan HPP', 'Balasan Cepat & Trigger WhatsApp', 'Ekspor data ke Excel', '1 pusat + 2 cabang']),
  PlanInfo('GOLD', 'Nota WhatsApp otomatis dan Chatbot AI dengan top-up terpisah', 'Rp100.000', '/bulan', Color(0xfff0a020), Color(0xfffff5e2), _star,
      ['Semua fitur Silver', '1 pusat + 3 cabang', 'Nota WA otomatis & AI'],
      ['Semua fitur Silver', 'Nota WhatsApp otomatis', 'Chatbot AI (saldo AI top-up terpisah)', 'CRM: poin member, voucher, pengingat', '1 pusat + 3 cabang']),
  PlanInfo('PLATINUM', 'Seluruh fitur Goyana, termasuk WhatsApp Blast & Promo', 'Rp350.000', '/bulan', Color(0xffe8493f), Color(0xffffeeed), _crown,
      ['Semua fitur Gold', '1 pusat + 5 cabang', 'WhatsApp Blast & Promo'],
      ['Semua fitur Gold', 'WhatsApp Blast & Promo', 'Transfer stok antar cabang', '1 pusat + 5 cabang', 'Semua fitur baru berikutnya']),
];

class PlanPricing extends StatelessWidget {
  const PlanPricing({super.key, required this.current, required this.currentLabel, required this.currentSub, required this.onBack, required this.onScan, required this.onNav,
    required this.onHistory, required this.onChoose, required this.onAddon});
  /// Id paket yang sedang aktif ('FREE', 'BASIC', …).
  final String current, currentLabel, currentSub;
  final VoidCallback onBack, onScan, onHistory;
  final ValueChanged<String> onNav;
  /// Pengguna menekan "Pilih Paket Ini" di rincian.
  final ValueChanged<PlanInfo> onChoose;
  /// 0 Top-up Saldo AI, 1 Tambah Cabang, 2 Tambah Nomor Chatbot.
  final ValueChanged<int> onAddon;

  Widget _tile(String svg, Color a, Color b, double size) => Container(
        width: size, height: size,
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [a, b]), borderRadius: BorderRadius.circular(size * .3),
            boxShadow: [gShadow(b.withValues(alpha: .28), 4, 10)]),
        alignment: Alignment.center,
        child: gSvg(svg, size * .56),
      );

  Color _light(Color c) => Color.lerp(c, Colors.white, .28)!;

  /// Lembar rincian (dipakai paket & tambahan): kepala berikon, harga, daftar butir, tombol utama, Tutup.
  void _infoSheet(BuildContext context, {required Widget icon, required String title, required String sub, required String price, required String per,
      required Color soft, required Color tick, required String listTitle, required Iterable<String> points, required String action, VoidCallback? onAction}) {
    showModalBottomSheet<void>(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xffd9dde2), borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 16),
            Row(children: [
              icon,
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: gText(18, w: FontWeight.w600, c: _ink)),
                  Text(sub, style: gText(12, c: _muted, h: 17)),
                ]),
              ),
            ]),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(14)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(price, style: gText(24, w: FontWeight.w600, c: _ink)),
                const SizedBox(width: 6),
                Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(per, style: gText(12.5, c: _muted)))),
              ]),
            ),
            const SizedBox(height: 14),
            Text(listTitle, style: gText(13, w: FontWeight.w600, c: _ink)),
            const SizedBox(height: 8),
            for (final f in points)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(width: 18, height: 18, margin: const EdgeInsets.only(top: 1), alignment: Alignment.center,
                      decoration: BoxDecoration(color: soft, shape: BoxShape.circle), child: Icon(Icons.check_rounded, size: 13, color: tick)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(f, style: gText(13, c: _ink, h: 19))),
                ]),
              ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: onAction == null
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      onAction();
                    },
              child: Container(
                height: 50, alignment: Alignment.center,
                decoration: BoxDecoration(color: onAction == null ? const Color(0xffeef0f3) : gBrand, borderRadius: BorderRadius.circular(14)),
                child: Text(action, style: gText(14.5, w: FontWeight.w600, c: onAction == null ? _muted : Colors.white)),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(height: 46, alignment: Alignment.center,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: _line)), child: Text('Tutup', style: gText(14, w: FontWeight.w500, c: _ink))),
            ),
          ])),
        ),
      ),
    );
  }

  void _detail(BuildContext context, PlanInfo p) {
    final active = p.id == current;
    _infoSheet(context, icon: _tile(p.icon, _light(p.color), p.color, 52), title: 'Paket ${p.id}', sub: p.tagline, price: p.price, per: p.per, soft: p.soft, tick: p.color,
        listTitle: 'Yang didapat', points: p.features, action: active ? 'Paket Aktif' : 'Pilih Paket Ini', onAction: active ? null : () => onChoose(p));
  }

  Widget _planCard(BuildContext context, PlanInfo p, {bool wide = false}) {
    final active = p.id == current, top = p.id == 'PLATINUM';
    final button = Container(
      height: 38, alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? const Color(0xffeef0f3) : (top ? gBrand : Colors.white), borderRadius: BorderRadius.circular(11),
        border: active || top ? null : Border.all(color: const Color(0xffdfe3e9)),
      ),
      child: Text(active ? 'Paket Aktif' : 'Lihat & Pilih', style: gText(13, w: FontWeight.w600, c: active ? _muted : (top ? Colors.white : _ink))),
    );
    final checks = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final f in p.short)
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(top: 1), child: Icon(Icons.check_rounded, size: 14, color: p.color)),
            const SizedBox(width: 6),
            Expanded(child: Text(f, style: gText(11.5, c: const Color(0xff5b5f6e), h: 16))),
          ]),
        ),
    ]);
    final price = Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(p.price, style: gText(19, w: FontWeight.w600, c: _ink)))),
      const SizedBox(width: 4),
      Padding(padding: const EdgeInsets.only(bottom: 3), child: Text(p.per, style: gText(11, c: _muted))),
    ]);
    return GestureDetector(
      onTap: () => _detail(context, p),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: top ? const Color(0xfffff6f5) : Colors.white, borderRadius: BorderRadius.circular(18),
          border: Border.all(color: active ? p.color : (top ? const Color(0xffffcfca) : _line), width: active ? 1.6 : 1),
          boxShadow: [gShadow(const Color(0x0f1b2440), 4, 14)],
        ),
        child: wide
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _tile(p.icon, _light(p.color), p.color, 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(p.id, style: gText(16, w: FontWeight.w600, c: _ink)),
                        const SizedBox(width: 8),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: gBrand, borderRadius: BorderRadius.circular(20)),
                            child: Text('PALING LENGKAP', style: gText(9, w: FontWeight.w600, c: Colors.white, ls: .4))),
                      ]),
                      const SizedBox(height: 2),
                      Text(p.tagline, style: gText(11.5, c: _muted, h: 16)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(child: checks),
                  const SizedBox(width: 12),
                  SizedBox(width: 132, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [price, const SizedBox(height: 8), button])),
                ]),
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  _tile(p.icon, _light(p.color), p.color, 40),
                  const Spacer(),
                  if (active)
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: p.soft, borderRadius: BorderRadius.circular(20)),
                        child: Text('AKTIF', style: gText(9, w: FontWeight.w600, c: p.color, ls: .4))),
                ]),
                const SizedBox(height: 10),
                Text(p.id, style: gText(15, w: FontWeight.w600, c: _ink)),
                const SizedBox(height: 2),
                price,
                const SizedBox(height: 10),
                checks,
                const Spacer(),
                const SizedBox(height: 6),
                button,
              ]),
      ),
    );
  }

  /// Tambahan: [judul, harga singkat di kartu, harga di rincian, satuan, penjelasan, butir…].
  static const addons = [
    ['Top-up Saldo AI', 'Mulai Rp 50.000', 'Rp 50.000', 'minimal top-up', 'Saldo untuk jawaban Chatbot AI. Dipakai sesuai jumlah percakapan, tidak hangus tiap bulan.',
      'Minimal top-up Rp 50.000', 'Nominal bisa lebih besar sesuai kebutuhan', 'Berlaku untuk semua paket yang punya Chatbot AI'],
    ['Tambah Cabang', 'Rp 30.000/bulan', 'Rp 30.000', '/ bulan per cabang', 'Menambah satu outlet/cabang di luar kuota paket Anda.',
      'Rp 30.000 per bulan untuk tiap cabang tambahan', 'Bisa ditambah di paket apa pun', 'Data, kasir dan laporan tiap cabang terpisah'],
    ['Nomor Chatbot', 'Rp 30.000/bulan', 'Rp 30.000', '/ bulan per nomor', 'Menambah satu nomor WhatsApp untuk Chatbot & kirim nota otomatis.',
      'Rp 30.000 per bulan untuk tiap nomor tambahan', 'Untuk semua paket, termasuk FREE', 'Satu nomor bisa dipakai satu outlet'],
  ];

  void _addonDetail(BuildContext context, String svg, Color a, Color b, int i) {
    final d = addons[i];
    _infoSheet(context, icon: _tile(svg, a, b, 52), title: d[0], sub: d[4], price: d[2], per: d[3], soft: Color.lerp(a, Colors.white, .82)!, tick: b,
        listTitle: 'Rincian', points: d.skip(5), action: 'Beli Tambahan Ini', onAction: () => onAddon(i));
  }

  Widget _addon(BuildContext context, String svg, Color a, Color b, int i) => Expanded(
        child: GestureDetector(
          onTap: () => _addonDetail(context, svg, a, b, i),
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _line)),
            child: Column(children: [
              _tile(svg, a, b, 40),
              const SizedBox(height: 8),
              Text(addons[i][0], textAlign: TextAlign.center, maxLines: 2, style: gText(11.5, w: FontWeight.w600, c: _ink, h: 15)),
              const SizedBox(height: 3),
              FittedBox(fit: BoxFit.scaleDown, child: Text(addons[i][1], maxLines: 1, style: gText(10.5, w: FontWeight.w500, c: b, h: 14))),
              const Spacer(),
              const SizedBox(height: 8),
              Container(
                height: 28, alignment: Alignment.center,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(9), border: Border.all(color: const Color(0xffdfe3e9))),
                child: Text('Detail', style: gText(11.5, w: FontWeight.w500, c: _ink)),
              ),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final cur = planInfos.firstWhere((p) => p.id == current, orElse: () => planInfos.first);
    final grid = planInfos.where((p) => p.id != 'PLATINUM').toList();
    return Material(
      color: const Color(0xfff7f8fa),
      child: Stack(children: [
        Column(children: [
          RepaintBoundary(child: GTopBar(top: top, onScan: onScan)),
          Container(
            height: 55, padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xfff1f2f5)))),
            child: Row(children: [
              GestureDetector(
                onTap: onBack,
                child: Container(width: 38, height: 32, alignment: Alignment.center,
                    decoration: BoxDecoration(color: const Color(0xfff3f4f7), borderRadius: BorderRadius.circular(9)), child: Text('‹', style: gText(20, w: FontWeight.w500, c: _ink, h: 20))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text('HARGA PAKET', style: gText(14.5, w: FontWeight.w600, c: _ink, ls: .7))),
            ]),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 110), children: [
              // Paket saat ini
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xffffe9e6), Color(0xfffff6f4)]),
                  borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xffffd9d4)),
                ),
                child: Row(children: [
                  _tile(cur.icon, _light(cur.color), cur.color, 58),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                          child: Text('PAKET SAAT INI', style: gText(9.5, w: FontWeight.w600, c: gBrand, ls: .5))),
                      const SizedBox(height: 6),
                      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(currentLabel, style: gText(20, w: FontWeight.w600, c: _ink))),
                      if (currentSub.isNotEmpty) Text(currentSub, style: gText(12, c: const Color(0xff5b5f6e), h: 17)),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: onHistory,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _line)),
                  child: Row(children: [
                    Container(width: 38, height: 38, alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xffffeeed), borderRadius: BorderRadius.circular(11)), child: gSvg(_doc, 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Riwayat transaksi', style: gText(13.5, w: FontWeight.w600, c: _ink)),
                        Text('Lihat semua riwayat pembayaran paket', style: gText(11.5, c: _muted)),
                      ]),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 22, color: _muted),
                  ]),
                ),
              ),
              const SizedBox(height: 20),
              Text('Pilih Paket', style: gText(17, w: FontWeight.w600, c: _ink)),
              const SizedBox(height: 2),
              Text('Ketuk kartu untuk melihat rincian fitur tiap paket.', style: gText(12, c: _muted, h: 17)),
              const SizedBox(height: 12),
              for (var r = 0; r < grid.length; r += 2)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: IntrinsicHeight(
                    child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Expanded(child: _planCard(context, grid[r])),
                      const SizedBox(width: 10),
                      Expanded(child: r + 1 < grid.length ? _planCard(context, grid[r + 1]) : const SizedBox()),
                    ]),
                  ),
                ),
              _planCard(context, planInfos.last, wide: true),
              const SizedBox(height: 22),
              Text('Tambahan', style: gText(17, w: FontWeight.w600, c: _ink)),
              const SizedBox(height: 2),
              Text('Tersedia untuk semua paket sesuai kebutuhan.', style: gText(12, c: _muted, h: 17)),
              const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _addon(context, _bot, const Color(0xff9a82ee), const Color(0xff7c5ce0), 0),
                  const SizedBox(width: 8),
                  _addon(context, _building, const Color(0xfff6b04a), const Color(0xfff08a24), 1),
                  const SizedBox(width: 8),
                  _addon(context, _chat, const Color(0xff5fb0f5), const Color(0xff2f8fe8), 2),
                ]),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _line)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(width: 22, height: 22, alignment: Alignment.center, decoration: const BoxDecoration(color: Color(0xffeef0f3), shape: BoxShape.circle),
                      child: Text('i', style: gText(12, w: FontWeight.w600, c: const Color(0xff5b5f6e), h: 13))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Ketentuan Paket', style: gText(13, w: FontWeight.w600, c: _ink)),
                      const SizedBox(height: 3),
                      Text(
                        'Nota manual tersedia di semua paket. Nota otomatis mulai Gold; Blast hanya Platinum. AI Gold/Platinum memakai top-up terpisah. '
                        'Setiap paket mencakup 1 pusat; batas cabang mengikuti paket. Setelah masa aktif berakhir, data lama tetap tersimpan.',
                        style: gText(11.5, c: _muted, h: 17),
                      ),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
        ]),
        Positioned(left: 0, right: 0, bottom: 0, child: GBottomNav(active: 3, onTap: onNav)),
      ]),
    );
  }
}
