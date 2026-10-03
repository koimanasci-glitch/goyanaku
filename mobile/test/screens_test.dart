// Renders native Flutter pages to PNG so they can be compared with the HTML design.
// CI: flutter test --tags screens --update-goldens (pushes test/screens/*.png to branch ci-screens).
@Tags(['screens'])
library;

import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/native/addorder_page.dart';
import 'package:goyana_flutter/native/cash_page.dart';
import 'package:goyana_flutter/native/cashclose_page.dart';
import 'package:goyana_flutter/native/customers_page.dart';
import 'package:goyana_flutter/native/form_page.dart';
import 'package:goyana_flutter/native/home_page.dart';
import 'package:goyana_flutter/native/orders_page.dart';
import 'package:goyana_flutter/native/reports_page.dart';
import 'package:goyana_flutter/native/services_page.dart';
import 'package:goyana_flutter/native/settings_page.dart';

class _NoActions implements HomeActions {
  @override
  void scan() {}
  @override
  void slide(int index) {}
  @override
  void tile(int index) {}
  @override
  void manageOutlet() {}
  @override
  void qr() {}
  @override
  void monthly() {}
  @override
  void helpChat() {}
  @override
  void nav(String pageId) {}
}

Future<void> _loadFonts() async {
  final loader = FontLoader('Poppins');
  for (final f in ['Regular', 'Medium', 'SemiBold']) {
    final bytes = File('assets/fonts/Poppins-$f.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

class _NoOrderActions implements OrdersActions {
  @override
  void scan() {}
  @override
  void nav(String pageId) {}
  @override
  void autoSettings() {}
  @override
  void addOrder() {}
  @override
  void search(String text) {}
  @override
  void tab(int index) {}
  @override
  void openCard(int index) {}
  @override
  void cardAction(int index) {}
  @override
  void openMaps(String url) {}
}

Map<String, dynamic> _card(int i, String id, String name, String status, String sbg, String sc, String action, {String? auto, List<String> chips = const [], String gender = 'male', String pay = 'Belum Bayar'}) => {
      'i': i, 'id': id, 'name': name, 'amount': 'Rp14.000', 'gender': gender,
      'dur': {'t': 'Reguler', 'bg': 'rgb(241, 242, 245)', 'c': 'rgb(91, 95, 110)'},
      'status': {'t': status, 'bg': sbg, 'c': sc},
      'pay': pay == 'Lunas'
          ? {'t': 'Lunas', 'bg': 'rgb(232, 247, 238)', 'c': 'rgb(31, 150, 90)'}
          : {'t': pay, 'bg': 'rgb(255, 240, 241)', 'c': 'rgb(216, 50, 63)'},
      'auto': auto == null ? null : {'t': auto, 'bg': 'rgb(238, 244, 255)', 'c': 'rgb(43, 106, 166)'},
      'chips': [for (final c in chips) {'t': c, 'bg': 'rgb(241, 242, 245)', 'c': 'rgb(91, 95, 110)'}],
      'action': {'t': action, 'bg': 'rgb(232, 73, 63)', 'c': 'rgb(255, 255, 255)'},
      'lines': <String>[],
    };

final _orders = OrdersModel.fromJson({
  'title': 'Pesanan', 'auto': {'t': 'Otomatis', 'on': true}, 'search': '', 'placeholder': 'Cari nama / ID / no HP',
  'tabs': [
    {'t': 'Penjemputan', 'n': '0', 'on': false}, {'t': 'Antrian', 'n': '3', 'on': true}, {'t': 'Proses', 'n': '1', 'on': false},
    {'t': 'Siap Ambil', 'n': '0', 'on': false}, {'t': 'Diantar', 'n': '0', 'on': false},
  ],
  'cards': [
    _card(0, 'GY-261002-0135', 'Andi Wijaya', 'Antrian', 'rgb(255, 240, 241)', 'rgb(232, 73, 63)', 'Proses', auto: '⏱ 1j'),
    {..._card(1, 'GY-261002-0134', 'Sari Dewi', 'Proses', 'rgb(238, 244, 255)', 'rgb(43, 106, 166)', 'Tandai Siap ›', chips: ['Antar'], gender: 'female'), 'maps': 'https://www.google.com/maps/search/?api=1&query=Bekasi'},
    _card(2, 'GY-261002-0133', 'Budi Santoso Pratama Wijayakusuma', 'Antrian', 'rgb(255, 240, 241)', 'rgb(232, 73, 63)', 'Proses', auto: '⏱ 1j', pay: 'Lunas'),
  ],
});

class _NoAddActions implements AddOrderActions {
  @override
  void scan() {}
  @override
  void aoBack() {}
  @override
  void aoSearchCustomer(String text) {}
  @override
  void aoAddCustomer() {}
  @override
  void aoPickCustomer(int index) {}
  @override
  void aoDuration(int index) {}
  @override
  void aoSearchService(String text) {}
  @override
  void aoCategory(int index) {}
  @override
  void aoService(int index) {}
  @override
  void aoNext() {}
  @override
  void aoSheetSelect(int field, int option) {}
  @override
  void aoSheetSwitch(int field) {}
  @override
  void aoSheetNote(String text) {}
  @override
  void aoSheetMain() {}
  @override
  void aoSheetClose() {}
  @override
  void aoPay(int index) {}
  @override
  void aoPayCancel() {}
}

const _avatar = '<svg viewBox="0 0 64 64"><path d="M17 54c1.2-8.4 6.1-12.6 15-12.6S45.8 45.6 47 54" fill="#5C97F8"/><circle cx="32" cy="26" r="11" fill="#FFD6B3"/><path d="M21 24.5c0-8.5 4.5-13.5 11-13.5 6.6 0 11 5 11 13.5v2.1H21v-2.1z" fill="#26384D"/><circle cx="28" cy="26" r="1.3" fill="#26384D"/><circle cx="36" cy="26" r="1.3" fill="#26384D"/><path d="M29 31c1.6 1.6 4.4 1.6 6 0" stroke="#D58A78" stroke-width="1.7" fill="none" stroke-linecap="round"/></svg>';
const _basket = '<svg viewBox="0 0 48 48"><rect x="12" y="7" width="24" height="6" rx="2.5" fill="#E8493F"/><rect x="10" y="11.5" width="28" height="6" rx="2.5" fill="#ffc857"/><path d="M7 19h34l-3.6 20.5A3 3 0 0 1 34.4 42H13.6a3 3 0 0 1-3-2.5z" fill="#3b82c4"/><rect x="5" y="17" width="38" height="5" rx="2.5" fill="#2b6aa6"/></svg>';
const _bed = '<svg viewBox="0 0 48 48"><rect x="4" y="16" width="4" height="26" rx="1.5" fill="#c68a55"/><rect x="40" y="24" width="4" height="18" rx="1.5" fill="#c68a55"/><rect x="8" y="26" width="32" height="10" rx="2" fill="#ffffff"/><path d="M18 24h20a2 2 0 0 1 2 2v10H18z" fill="#5aa9e6"/><rect x="4" y="36" width="40" height="3" fill="#9c6a3c"/></svg>';

final _addCustomer = AddOrderModel.fromJson({
  'title': 'Pilih Pelanggan', 'step': 'Langkah 1 dari 5', 'stage': 'customer', 'search': {'v': '', 'ph': 'Cari nama / no handphone'}, 'add': 'Tambah Pelanggan',
  'people': [
    {'i': 0, 'name': 'Sari Dewi', 'avatar': _avatar, 'lines': ['☎ 081200000002', '⌖ Jakarta'], 'btn': 'Pilih'},
    {'i': 1, 'name': 'Budi Santoso Pratama Wijayakusuma', 'avatar': _avatar, 'lines': ['☎ 081200000001', '⌖ Jl. Raya Bekasi No. 12, Jakarta Timur'], 'btn': 'Pilih'},
  ],
});

final _addServicesJson = <String, dynamic>{
  'title': 'Tambahkan Layanan', 'step': 'Langkah 2 dari 5', 'stage': 'services', 'search': {'v': '', 'ph': 'Cari layanan Express'},
  'customer': {'name': 'Sari Dewi', 'sub': 'Express · 24 Jam', 'avatar': _avatar},
  'durations': [{'t': 'Reguler', 's': '72 Jam', 'on': false}, {'t': 'Express', 's': '24 Jam', 'on': true}, {'t': 'Kilat', 's': '6 Jam', 'on': false}],
  'cats': [{'t': 'Semua', 'on': true, 'svg': ''}, {'t': 'Kiloan', 'on': false, 'svg': _basket}, {'t': 'Satuan', 'on': false, 'svg': _bed}, {'t': 'Meteran', 'on': false, 'svg': _bed}],
  'items': [
    {'h': 1, 'svg': _basket, 't': 'Kiloan · Express', 's': 'Cuci ››› Kering ››› Setrika'},
    {'i': 0, 'svg': _basket, 't': 'Cuci Baju', 's': 'Rp 10.500 / kg · 24 Jam', 'btn': '3 kg', 'on': true},
    {'i': 1, 'svg': _basket, 't': 'Setrika', 's': 'Rp 7.500 / kg · 24 Jam', 'btn': 'Pilih', 'on': false},
    {'h': 1, 'svg': _bed, 't': 'Satuan · Express', 's': 'Cuci ››› Kering ››› Packing'},
    {'i': 2, 'svg': _bed, 't': 'Sprei', 's': 'Rp 22.500 / pcs · 24 Jam', 'btn': 'Pilih', 'on': false},
  ],
  'footer': {'name': 'Sari Dewi', 'sum': '3 kg · 0 pcs · 0 m', 'label': 'Total Layanan', 'total': 'Rp 31.500', 'btn': 'LANJUT ›'},
};
final _addServices = AddOrderModel.fromJson(_addServicesJson);

class _NoCustActions implements CustomersActions {
  @override
  void scan() {}
  @override
  void nav(String pageId) {}
  @override
  void cuBack() {}
  @override
  void cuSearch(String text) {}
  @override
  void cuDeposit() {}
  @override
  void cuAdd() {}
  @override
  void cuToggleDb() {}
  @override
  void cuFilter() {}
  @override
  void cuTopUp(int index) {}
  @override
  void cuEdit(int index) {}
  @override
  void cuPage(int delta) {}
  @override
  void cuRank() {}
  @override
  void cuCrm() {}
}

Map<String, dynamic> _custRow(int i, String name, String line, String spend, String orders, String last) => {
      'i': i, 'name': name, 'avatar': _avatar, 'lines': [line], 'spend': spend, 'orders': orders, 'last': last,
      'balance': 'Saldo Rp0', 'topup': 'Top Up Saldo', 'edit': 'Edit',
    };

final _customers = CustomersModel.fromJson({
  'title': 'Pelanggan', 'sub': 'Kelola data pelanggan laundry', 'search': {'v': '', 'ph': 'Cari nama / no handphone'},
  'deposit': 'Saldo Pelanggan · Top Up & Riwayat', 'add': 'Tambah Pelanggan',
  'db': {'t': 'Database Pelanggan', 's': '3 pelanggan tersimpan', 'open': true},
  'rank': {'t': 'Ranking Pelanggan', 's': 'Transaksi terbanyak & belanja terbesar', 'icon': '🏆'},
  'crm': {'t': 'CRM Pelanggan', 'badge': 'PLATINUM', 's': 'Pengingat cucian · Poin member · Voucher kode unik', 'icon': '💎'},
  'dbTitle': 'Daftar Pelanggan', 'dbSub': 'Database pelanggan outlet', 'filter': 'Filter ▾',
  'rows': [
    _custRow(0, 'Budi Santoso', '081200000001 · Jakarta', 'Belanja Rp245.000', '12', '2 hari lalu'),
    _custRow(1, 'Sari Dewi Kusumawardhani Pratiwi', '081200000002 · Jl. Raya Bekasi No. 12, Jakarta Timur', 'Belanja Rp0', '0', 'Baru'),
  ],
  'pager': {'prev': '‹ Sebelumnya', 'next': 'Berikutnya ›', 'info': 'Hal 1 dari 3', 'canPrev': false, 'canNext': true},
});

class _NoReportActions implements ReportsActions {
  @override
  void scan() {}
  @override
  void nav(String pageId) {}
  @override
  void rpOutlet() {}
  @override
  void rpPeriod(int index) {}
  @override
  void rpKpi(int index) {}
  @override
  void rpQuick(int index) {}
  @override
  void rpSearch(String text) {}
  @override
  void rpCategory(int index) {}
  @override
  void rpOpen(int index) {}
}

Map<String, dynamic> _it(int i, String icon, String t, String s, String v) => {'i': i, 'icon': icon, 'bg': 'rgb(255, 244, 229)', 't': t, 's': s, 'v': v};

final _reports = ReportsModel.fromJson({
  'title': 'Laporan', 'outlet': '',
  'periods': [{'t': 'Hari ini', 'on': false}, {'t': '7 hari', 'on': false}, {'t': '30 hari', 'on': true}, {'t': 'Bulan ini', 'on': false}, {'t': 'Bulan lalu', 'on': false}, {'t': 'Pilih tanggal', 'on': false}],
  'hero': {'label': 'Omzet · 30 hari', 'big': 'Rp12.450.000', 'sub': '312 pesanan · rata-rata Rp39.904',
    'pm': [{'t': 'Tunai', 'v': 'Rp6.200.000'}, {'t': 'QRIS', 'v': 'Rp4.100.000'}, {'t': 'Transfer', 'v': 'Rp1.900.000'}, {'t': 'Deposit', 'v': 'Rp250.000'}]},
  'kpis': [
    {'icon': '↘', 'bg': 'rgb(255, 240, 241)', 't': 'Pengeluaran', 'v': 'Rp3.120.000', 's': '18 catatan'},
    {'icon': '＝', 'bg': 'rgb(234, 247, 228)', 't': 'Laba bersih', 'v': 'Rp9.330.000', 's': ''},
    {'icon': '⏳', 'bg': 'rgb(255, 246, 223)', 't': 'Belum dibayar', 'v': 'Rp420.000', 's': 'piutang berjalan'},
    {'icon': '＋', 'bg': 'rgb(243, 239, 255)', 't': 'Pelanggan baru', 'v': '24 orang', 's': '30 hari'},
  ],
  'quick': [
    {'icon': '＋', 'bg': 'rgb(234, 247, 228)', 't': 'Kas Masuk'}, {'icon': '−', 'bg': 'rgb(255, 240, 241)', 't': 'Pengeluaran'},
    {'icon': '✓', 'bg': 'rgb(234, 242, 253)', 't': 'Tutup Kasir'}, {'icon': '✎', 'bg': 'rgb(243, 239, 255)', 't': 'Ralat'},
  ],
  'search': {'v': '', 'ph': 'Cari laporan… (mis. piutang, pegawai, stok)'},
  'cats': [{'t': 'Semua', 'on': true, 'bg': 'rgb(30, 30, 30)', 'c': 'rgb(255, 255, 255)'}, {'t': '💰 Keuangan', 'on': false, 'bg': 'rgb(255, 255, 255)', 'c': 'rgb(91, 95, 110)'}, {'t': '🧾 Transaksi', 'on': false, 'bg': 'rgb(255, 255, 255)', 'c': 'rgb(91, 95, 110)'}],
  'sections': [
    {'t': '💰 Keuangan', 'items': [
      _it(0, '📈', 'Omzet', 'Total nilai transaksi (tidak termasuk batal)', 'Rp12.450.000'),
      _it(1, '🔄', 'Arus Kas', 'Uang masuk vs uang keluar', 'Rp9.330.000'),
      _it(2, '⏳', 'Piutang (Belum Bayar)', 'Pesanan yang belum dibayar pelanggan', 'Rp420.000'),
    ]},
  ],
});

class _NoSettingsActions implements SettingsActions {
  @override
  void scan() {}
  @override
  void nav(String pageId) {}
  @override
  void stGroup(int index, bool accordion) {}
  @override
  void stItem(int group, int item) {}
  @override
  void stSyncUrl(String url) {}
  @override
  void stSyncSave() {}
  @override
  void stSyncNow() {}
  @override
  void stAcctGo() {}
  @override
  void stAcctAction(int index) {}
  @override
  void stAcctLink() {}
  @override
  void stLogout() {}
  @override
  void stTutorial() {}
}

final _settings = SettingsModel.fromJson({
  'title': 'Pengaturan',
  'sync': {'dot': 'rgb(47, 158, 85)', 't': 'Sinkronisasi server', 'line': 'Tersinkron 1 menit lalu · 0 menunggu', 'who': 'owner@laundry.test', 'url': null, 'save': '', 'now': 'Sinkronkan sekarang'},
  'groups': [
    {'i': 0, 'svg': _avatar, 't': 'Profil', 's': 'Konfigurasi Profil', 'accordion': true, 'open': false, 'items': []},
    {'i': 1, 'svg': _basket, 't': 'Layanan', 's': 'Konfigurasi Layanan', 'accordion': true, 'open': true, 'items': [
      {'j': 0, 'icon': '🧺', 't': 'Layanan', 'badge': '', 's': 'Jenis layanan, satuan dan harga'},
      {'j': 1, 'icon': '⏱', 't': 'Durasi Layanan', 'badge': '', 's': 'Reguler, Express, Kilat dan estimasi'},
      {'j': 2, 'icon': '🤖', 't': 'WhatsApp & Chatbot', 'badge': '🔒 Chatbot', 's': 'Jawaban AI untuk pelanggan'},
    ]},
    {'i': 2, 'svg': _bed, 't': 'Hubungkan WhatsApp', 's': 'Tambah perangkat dan pilih cabang WhatsApp', 'accordion': false, 'open': false, 'items': []},
    {'i': 3, 'svg': '', 'icon': '🗄', 't': 'Pusat Data', 's': 'Import, ekspor, backup dan restore', 'accordion': false, 'open': false, 'items': []},
  ],
  'acct': {'badge': 'FREE', 't': 'Masa Aktif Paket', 's': 'Trial Basic sampai 3/12/2026', 'go': 'Perpanjang', 'stats': [], 'acts': ['', ''], 'link': ''},
  'logout': 'Keluar Akun', 'version': 'GOYANA Laundry · versi 2.7', 'tutorial': 'Panduan awal Goyana',
});

class _NoCashActions implements CashActions {
  @override
  void scan() {}
  @override
  void nav(String pageId) {}
  @override
  void caBack() {}
  @override
  void caType(String option) {}
  @override
  void caAmount(String text) {}
  @override
  void caNote(String text) {}
  @override
  void caSubmit() {}
}

final _cash = CashModel.fromJson({
  'title': 'Penambahan Kas', 'heading': 'Saldo Kas',
  'stats': [{'icon': r'$', 'kind': 'cash', 't': 'Saldo Tunai', 'v': 'Rp1.250.000'}, {'icon': '◌', 'kind': 'noncash', 't': 'Saldo Non-Tunai', 'v': 'Rp3.480.000'}],
  'type': {'v': 'Tunai', 'options': ['Tipe Kas', 'Tunai', 'Non-Tunai'], 'index': 1},
  'amount': {'v': '50.000', 'ph': 'Jumlah'}, 'note': {'v': '', 'ph': 'Keterangan'}, 'submit': 'Tambah Kas', 'subtract': false,
});

class _NoCashCloseActions implements CashCloseActions {
  @override
  void scan() {}
  @override
  void nav(String pageId) {}
  @override
  void ccTap(String selector, int index, String? child) {}
  @override
  void ccType(String selector, String value) {}
}

const _cashIcon = '<svg viewBox="0 0 24 24"><rect x="3" y="6" width="18" height="12" rx="2" fill="none" stroke="#15a36b" stroke-width="2"/><circle cx="12" cy="12" r="2.5" fill="#15a36b"/></svg>';
final _addPayment = AddOrderModel.fromJson({
  ..._addServicesJson,
  'sheet': {'kind': 'payment', 'title': 'Pembayaran', 'label': 'Total Tagihan', 'total': 'Rp 31.500', 'id': 'GY-261003-0133', 'cancel': 'Batalkan Pesanan',
    'methods': [
      {'i': 0, 't': 'Tunai', 'svg': _cashIcon, 'bg': 'rgb(230, 247, 238)', 'ic': 'rgb(21, 163, 107)', 's': ''},
      {'i': 1, 't': 'QRIS', 'svg': _cashIcon, 'bg': 'rgb(255, 240, 241)', 'ic': 'rgb(232, 73, 63)', 's': ''},
      {'i': 2, 't': 'Transfer', 'svg': _cashIcon, 'bg': 'rgb(234, 242, 253)', 'ic': 'rgb(43, 127, 212)', 's': ''},
      {'i': 3, 't': 'Bayar Nanti', 'svg': _cashIcon, 'bg': 'rgb(255, 245, 220)', 'ic': 'rgb(201, 138, 6)', 's': ''},
      {'i': 10, 't': 'DP / Uang Muka', 'svg': '', 'icon': '½', 'ic': 'rgb(232, 73, 63)', 's': ''},
      {'i': 11, 't': 'Saldo Deposit', 'svg': '', 'icon': '◈', 'ic': 'rgb(232, 73, 63)', 's': 'Saldo Rp50.000'},
    ]},
});
final _addOptions = AddOrderModel.fromJson({
  ..._addServicesJson,
  'sheet': {'kind': 'options', 'title': 'Atur Pesanan', 'main': 'Buat Pesanan', 'note': {'v': '', 'ph': 'Catatan: jumlah pakaian, no rak, kondisi'},
    'fields': [
      {'k': 0, 'type': 'select', 'label': 'Parfum', 'options': ['Tanpa Parfum', 'Lavender'], 'index': 1},
      {'k': 1, 'type': 'select', 'label': 'Penyerahan', 'options': ['Datang Langsung', 'Antar ke Pelanggan'], 'index': 0},
      {'k': 2, 'type': 'switch', 'label': 'Jadikan Prioritas', 'sub': 'naik ke atas antrian', 'on': true},
      {'k': 3, 'type': 'select', 'label': 'Diskon', 'options': ['Tidak', 'Diskon manual (Rp)…'], 'index': 0},
    ]},
});

class _NoServicesActions implements ServicesActions {
  @override
  void scan() {}
  @override
  void nav(String pageId) {}
  @override
  void svBack() {}
  @override
  void svSearch(String text) {}
  @override
  void svAdd() {}
  @override
  void svEdit(int index) {}
  @override
  void svToggle(int index, int variant) {}
}

Map<String, dynamic> _svc(int i, String name, String unit, List<int> prices, {bool kilatOff = false}) => {
      'i': i, 'svg': _basket, 't': name, 's': 'Per $unit', 'edit': true,
      'chain': [{'t': 'Cuci', 'on': true}, {'t': 'Kering', 'on': true}, {'t': 'Setrika', 'on': unit == 'kg'}, {'t': 'Packing', 'on': true}],
      'vars': [
        {'j': 0, 't': 'Reguler', 's': '72 jam', 'price': 'Rp${prices[0]} / $unit', 'on': true, 'toggle': true},
        {'j': 1, 't': 'Express', 's': '24 jam', 'price': 'Rp${prices[1]} / $unit', 'on': true, 'toggle': true},
        {'j': 2, 't': 'Kilat', 's': '6 jam', 'price': kilatOff ? 'Nonaktif' : 'Rp${prices[2]} / $unit', 'on': !kilatOff, 'toggle': true},
      ],
    };

final _services = ServicesModel.fromJson({
  'title': 'Layanan', 'search': {'v': '', 'ph': 'Cari layanan…'}, 'add': '+ Kategori',
  'cats': [_svc(0, 'Cuci Baju', 'kg', [7000, 10500, 14000]), _svc(1, 'Bedcover', 'pcs', [30000, 45000, 60000], kilatOff: true)],
  'note': 'Alur proses menentukan tahap produksi & hak akses pegawai.',
});

class _NoFormActions implements FormActions {
  @override
  void scan() {}
  @override
  void nav(String pageId) {}
  @override
  void fmBack() {}
  @override
  void fmInput(int index, Object value) {}
  @override
  void fmToggle(int index) {}
  @override
  void fmRadio(int index) {}
  @override
  void fmButton(int index) {}
  @override
  void fmFile(String inputId) {}
  @override
  void fmScoped(String scope, String kind, int index, [Object? value]) {}
}

final _printerForm = FormModel.fromJson('printer', {
  'title': 'Printer & Nota',
  'items': [
    {'type': 'card', 't': 'Printer Bluetooth', 's': 'Hubungkan printer thermal dan cek izin perangkat', 'svg': '', 'i': 0},
    {'type': 'title', 't': 'Profil Nota'},
    {'type': 'label', 't': 'Profil Nota (Header)'}, {'type': 'input', 'v': 'Goyana Laundry', 'ph': '', 'i': 0},
    {'type': 'label', 't': 'Alamat Outlet'}, {'type': 'input', 'v': 'Perum GCC Cluster Sakura Blok F36 No 39', 'ph': '', 'multiline': true, 'i': 1},
    {'type': 'hint', 't': 'Catatan: hindari emoticon pada teks nota agar kompatibel dengan printer thermal.'},
    {'type': 'row', 't': 'Menampilkan Logo', 'btn': 'Konfigurasi', 'i': 1},
    {'type': 'toggle', 't': 'Menampilkan QR Code', 'on': false, 'i': 0},
    {'type': 'toggle', 't': 'Menampilkan Estimasi Selesai', 'on': true, 'i': 1},
    {'type': 'choice', 't': 'Ukuran Printer', 'options': [{'t': '58 mm', 'on': true, 'i': 0}, {'t': '80 mm', 'on': false, 'i': 1}]},
    {'type': 'button', 't': 'SIMPAN', 'primary': true, 'i': 2},
  ],
});

final _customerAddForm = FormModel.fromJson('customeradd', {
  'title': 'TAMBAH PELANGGAN',
  'items': [
    {'type': 'button', 't': 'Pilih dari Kontak HP', 'primary': true, 'i': 0},
    {'type': 'row', 't': 'Wanita', 's': 'Jenis kelamin · untuk avatar', 'btn': 'Ganti', 'svg': '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="10" fill="#f8b4c0"/></svg>', 'i': 1},
    {'type': 'input', 'v': 'Sari', 'ph': 'Nama Pelanggan', 'i': 0},
    {'type': 'input', 'v': '', 'ph': 'No Handphone', 'numeric': true, 'i': 1},
    {'type': 'input', 'v': '', 'ph': 'Alamat', 'i': 2},
    {'type': 'input', 'v': '', 'ph': 'Lokasi pelanggan / tautan Maps (opsional)', 'i': 3},
    {'type': 'buttons', 'options': [{'t': 'Pilih Titik di Peta', 'i': 4}, {'t': '📍 Lokasi saya', 'i': 5}, {'t': '📋 Tempel link', 'i': 6}]},
    {'type': 'button', 't': 'Tambahkan', 'primary': true, 'i': 7},
    {'type': 'hint', 't': 'Nama dan no handphone wajib diisi. Alamat dan Maps boleh dikosongkan.'},
  ],
});

final _helpForm = FormModel.fromJson('helpcenter', {
  'title': 'Pusat Bantuan',
  'items': [
    {'type': 'title', 't': 'Ada yang bisa kami bantu?'},
    {'type': 'hint', 't': 'Panduan penggunaan GOYANA untuk operasional laundry.'},
    {'type': 'input', 'v': '', 'ph': 'Cari bantuan...', 'i': 0},
    {'type': 'card', 't': 'Membuat Pesanan', 's': 'Layanan, berat, durasi dan pembayaran', 'svg': '', 'ic': '🧾', 'i': 0},
    {'type': 'card', 't': 'Pembayaran & QRIS', 's': 'Tunai, transfer, QRIS dan status pembayaran', 'svg': '', 'ic': '▦', 'i': 2},
    {'type': 'button', 't': 'Hubungi Support GOYANA', 'primary': false, 'i': 7},
  ],
});

final _deliveryForm = FormModel.fromJson('delivery', {
  'title': 'Antar-Jemput',
  'items': [
    {'type': 'title', 't': 'Tarif Transportasi'},
    {'type': 'choice', 't': '', 'options': [
      {'t': '1. Gratis Transportasi', 's': 'Default. Tidak menambah biaya ke pesanan.', 'on': false, 'i': 0},
      {'t': 'Tarif Tetap', 's': 'Satu tarif untuk order yang memakai transportasi.', 'on': true, 'i': 1},
    ]},
    {'type': 'input', 'label': 'Ongkir flat', 'pre': 'Rp', 'suf': '', 'v': '5.000', 'numeric': true, 'i': 0},
    {'type': 'input', 'label': 'Jarak maksimal', 'pre': '', 'suf': 'km', 'v': '10', 'numeric': true, 'i': 1},
    {'type': 'toggle', 't': 'Layanan Antar-Jemput', 's': 'Matikan jika outlet hanya melayani pelanggan datang langsung', 'on': true, 'i': 1},
    {'type': 'entry', 't': 'Andi', 'lines': ['0857-2233-4455 · motor'], 'badge': 'Aktif', 'avatar': 'A', 'svg': '', 'btns': []},
    {'type': 'entry', 't': 'Outlet Uji', 'lines': ['Jakarta', 'WA 081234567890'], 'badge': '', 'avatar': '', 'svg': '', 'btns': [{'t': 'Monitoring', 'i': 2}, {'t': 'Edit', 'i': 3}]},
    {'type': 'image', 'src': '', 'svg': '', 'mark': '▦', 't': 'QRIS Outlet', 's': 'Upload QRIS untuk menerima pembayaran'},
    {'type': 'button', 't': 'Simpan Pengaturan', 'primary': true, 'i': 2},
  ],
});

void main() {
  setUpAll(_loadFonts);

  for (final width in [320.0, 390.0, 412.0]) {
    testWidgets('Beranda native at $width px', (tester) async {
      tester.view.physicalSize = Size(width * 2, 844 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: const Key('screen'),
          child: NativeHome(model: const HomeModel(badge: '3'), actions: _NoActions(), topInset: 0),
        ),
      ));
      // flutter_svg decodes asynchronously.
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
      await expectLater(find.byKey(const Key('screen')), matchesGoldenFile('screens/home_${width.toInt()}.png'));
    });
  }

  for (final width in [320.0, 390.0]) {
    testWidgets('Pesanan native at $width px', (tester) async {
      tester.view.physicalSize = Size(width * 2, 844 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: const Key('screen'),
          child: NativeOrders(model: _orders, actions: _NoOrderActions(), topInset: 0),
        ),
      ));
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
      await expectLater(find.byKey(const Key('screen')), matchesGoldenFile('screens/orders_${width.toInt()}.png'));
    });
  }

  for (final width in [320.0, 390.0]) {
    for (final entry in {'addorder_customer': _addCustomer, 'addorder_services': _addServices, 'addorder_options': _addOptions, 'addorder_payment': _addPayment}.entries) {
      testWidgets('Tambah Transaksi ${entry.key} at $width px', (tester) async {
        tester.view.physicalSize = Size(width * 2, 844 * 2);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: const Key('screen'),
            child: NativeAddOrder(model: entry.value, actions: _NoAddActions(), topInset: 0),
          ),
        ));
        for (var i = 0; i < 5; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
          await tester.pump();
        }
        expect(tester.takeException(), isNull);
        await expectLater(find.byKey(const Key('screen')), matchesGoldenFile('screens/${entry.key}_${width.toInt()}.png'));
      });
    }
  }

  for (final width in [320.0, 390.0]) {
    testWidgets('Pelanggan native at $width px', (tester) async {
      tester.view.physicalSize = Size(width * 2, 1100 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: const Key('screen'),
          child: NativeCustomers(model: _customers, actions: _NoCustActions(), topInset: 0),
        ),
      ));
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
      await expectLater(find.byKey(const Key('screen')), matchesGoldenFile('screens/customers_${width.toInt()}.png'));
    });
  }

  for (final width in [320.0, 390.0]) {
    testWidgets('Laporan native at $width px', (tester) async {
      tester.view.physicalSize = Size(width * 2, 1200 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: const Key('screen'),
          child: NativeReports(model: _reports, actions: _NoReportActions(), topInset: 0),
        ),
      ));
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
      await expectLater(find.byKey(const Key('screen')), matchesGoldenFile('screens/reports_${width.toInt()}.png'));
    });
  }

  for (final width in [320.0, 390.0]) {
    testWidgets('Pengaturan native at $width px', (tester) async {
      tester.view.physicalSize = Size(width * 2, 1100 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: const Key('screen'),
          child: NativeSettings(model: _settings, actions: _NoSettingsActions(), topInset: 0),
        ),
      ));
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
      await expectLater(find.byKey(const Key('screen')), matchesGoldenFile('screens/settings_${width.toInt()}.png'));
    });
  }

  for (final width in [320.0, 390.0]) {
    testWidgets('Kas Masuk native at $width px', (tester) async {
      tester.view.physicalSize = Size(width * 2, 844 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: const Key('screen'),
          child: NativeCash(model: _cash, actions: _NoCashActions(), topInset: 0),
        ),
      ));
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
      await expectLater(find.byKey(const Key('screen')), matchesGoldenFile('screens/cashin_${width.toInt()}.png'));
    });
  }
  for (final width in [320.0, 390.0]) {
    testWidgets('Tutup Kasir native at $width px', (tester) async {
      tester.view.physicalSize = Size(width * 2, 844 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final model = jsonDecode(File('test/fixtures/cashclose.json').readAsStringSync()) as Map<String, dynamic>;
      await tester.pumpWidget(MaterialApp(home: RepaintBoundary(key: const Key('screen'), child: NativeCashClose(model: model, actions: _NoCashCloseActions(), topInset: 31))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(find.byKey(const Key('screen')), matchesGoldenFile('screens/cashclose_${width.toInt()}.png'));
      await tester.drag(find.byType(ListView), const Offset(0, -900));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(find.byKey(const Key('screen')), matchesGoldenFile('screens/cashclose_bottom_${width.toInt()}.png'));
    });
  }


  for (final width in [320.0, 390.0]) {
    testWidgets('Layanan native at $width px', (tester) async {
      tester.view.physicalSize = Size(width * 2, 1000 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: const Key('screen'),
          child: NativeServices(model: _services, actions: _NoServicesActions(), topInset: 0),
        ),
      ));
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
      await expectLater(find.byKey(const Key('screen')), matchesGoldenFile('screens/services_${width.toInt()}.png'));
    });
  }

  for (final width in [320.0, 390.0]) {
    testWidgets('Formulir generik (Printer) at $width px', (tester) async {
      tester.view.physicalSize = Size(width * 2, 1000 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: const Key('screen'),
          child: NativeForm(model: _printerForm, actions: _NoFormActions(), topInset: 0),
        ),
      ));
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
      await expectLater(find.byKey(const Key('screen')), matchesGoldenFile('screens/printer_${width.toInt()}.png'));
    });
  }

  // Every real page model captured from the HTML (test/fixtures/forms/*.json) rendered by the generic native form.
  final fixtures = Directory('test/fixtures/forms').listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in fixtures) {
    final id = f.uri.pathSegments.last.replaceAll('.json', '');
    testWidgets('Formulir generik fixture $id', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 1400 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final model = FormModel.fromJson(id, Map<String, dynamic>.from(jsonDecode(f.readAsStringSync()) as Map));
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(key: const Key('screen'), child: NativeForm(model: model, actions: _NoFormActions(), topInset: 0)),
      ));
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
      await expectLater(find.byKey(const Key('screen')), matchesGoldenFile('screens/form_$id.png'));
    });
  }

  for (final entry in {'customeradd': _customerAddForm, 'helpcenter': _helpForm, 'delivery': _deliveryForm}.entries) {
    testWidgets('Formulir generik (${entry.key}) at 390 px', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 900 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(key: const Key('screen'), child: NativeForm(model: entry.value, actions: _NoFormActions(), topInset: 0)),
      ));
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
      await expectLater(find.byKey(const Key('screen')), matchesGoldenFile('screens/${entry.key}_390.png'));
    });
  }
}
