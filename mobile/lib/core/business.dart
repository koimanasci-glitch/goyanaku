// Logika usaha GOYANA di Dart: pelanggan, pesanan, status, pembayaran, kas.
// Format simpan = format aplikasi HTML ("goyana-business177"), supaya data lama tetap terbaca
// dan selama masa transisi kedua versi melihat data yang sama.

import 'dart:convert';

import 'models.dart';
import 'money.dart';
import 'store.dart';

String _two(int n) => n.toString().padLeft(2, '0');
String _dmyHm(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year} · ${_two(d.hour)}:${_two(d.minute)}';

/// Metode bayar: nama yang dicatat di kartu (method177) & kas.
String normalizeMethod(String m) => RegExp('QRIS', caseSensitive: false).hasMatch(m)
    ? 'QRIS'
    : RegExp('Transfer', caseSensitive: false).hasMatch(m)
        ? 'Transfer'
        : RegExp('Deposit|Saldo', caseSensitive: false).hasMatch(m)
            ? 'Deposit'
            : 'Tunai';

class Business {
  Business._(this.store, this.raw, this.services, this.outlets, this.activeOutlet);

  final KvStore store;
  final Map<String, dynamic> raw;
  final List<Service> services;
  final List<Outlet> outlets;
  String activeOutlet;

  static Future<Business> load(KvStore store) async {
    Map<String, dynamic> read(String? s) {
      try {
        final v = s == null ? null : jsonDecode(s);
        return v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
      } catch (_) {
        return <String, dynamic>{};
      }
    }

    List<dynamic> readList(String? s) {
      try {
        final v = s == null ? null : jsonDecode(s);
        return v is List ? v : const [];
      } catch (_) {
        return const [];
      }
    }

    final raw = read(await store.get(Keys.business));
    raw.putIfAbsent('orders', () => <dynamic>[]);
    raw.putIfAbsent('details', () => <String, dynamic>{});
    raw.putIfAbsent('customers', () => <dynamic>[]);
    raw.putIfAbsent('deposits178', () => <String, dynamic>{});
    raw.putIfAbsent('kas', () => <String, dynamic>{'start': 0, 'sales': [], 'ins': [], 'outs': [], 'hist': []});
    final services = readList(await store.get(Keys.services)).whereType<Map>().map((e) => Service(Map<String, dynamic>.from(e))).toList();
    final outlets = readList(await store.get(Keys.outlets)).whereType<Map>().map((e) => Outlet(Map<String, dynamic>.from(e))).toList();
    var active = '';
    try {
      active = '${jsonDecode(await store.get(Keys.activeOutlet) ?? '""')}';
    } catch (_) {}
    return Business._(store, raw, services, outlets, active);
  }

  Future<bool> save() => store.set(Keys.business, jsonEncode(raw));

  // ---------- pelanggan ----------
  List<Customer> get customers => (raw['customers'] as List).whereType<Map>().map((e) => Customer.fromJson(Map<String, dynamic>.from(e))).toList();

  Customer? customerByName(String name) {
    final key = name.trim().toLowerCase();
    for (final c in customers) {
      if (c.name.trim().toLowerCase() == key) return c;
    }
    return null;
  }

  /// Nama & no HP wajib (sama dengan HTML). Mengembalikan pesan salah, atau null bila tersimpan.
  String? saveCustomer(Customer c, {String? originalName}) {
    if (c.name.trim().isEmpty || c.phone.trim().isEmpty) return 'Nama dan no handphone wajib diisi';
    final list = raw['customers'] as List;
    final key = (originalName ?? c.name).trim().toLowerCase();
    final i = list.indexWhere((e) => e is Map && '${e['name']}'.trim().toLowerCase() == key);
    if (i >= 0) {
      list[i] = c.toJson();
    } else {
      if (customerByName(c.name) != null) return 'Pelanggan ${c.name} sudah ada';
      list.add(c.toJson());
    }
    return null;
  }

  int depositOf(String name) => parseRupiah((raw['deposits178'] as Map)[name.trim().toLowerCase()] ?? (raw['deposits178'] as Map)[name]);

  // ---------- pesanan ----------
  Map<String, dynamic> get _details => raw['details'] as Map<String, dynamic>;

  List<Order> get orders {
    final out = <Order>[];
    for (final c in (raw['orders'] as List).whereType<Map>()) {
      final card = c is Map<String, dynamic> ? c : Map<String, dynamic>.from(c);
      final fields = card['fields'] is List ? card['fields'] as List : const [];
      final id = fields.length > 1 && fields[1] is List && (fields[1] as List).isNotEmpty ? '${(fields[1] as List).first}' : '';
      final d = _details[id];
      out.add(Order(card, d is Map<String, dynamic> ? d : <String, dynamic>{'id': id}));
    }
    return out;
  }

  Order? orderById(String id) {
    for (final o in orders) {
      if (o.id == id) return o;
    }
    return null;
  }

  /// "GY-YYMMDD-0NNN": nomor urut melanjutkan nomor terbesar yang sudah ada (mulai 133 seperti HTML).
  String nextOrderId(DateTime now) {
    var n = 132;
    for (final o in orders) {
      final m = RegExp(r'-(\d+)$').firstMatch(o.id);
      if (m != null) n = n > int.parse(m.group(1)!) ? n : int.parse(m.group(1)!);
    }
    return 'GY-${now.year.toString().substring(2)}${_two(now.month)}${_two(now.day)}-${(n + 1).toString().padLeft(4, '0')}';
  }

  /// Membuat pesanan dari keranjang. [payMethod]: Tunai, QRIS, Transfer, Deposit, DP, atau "Bayar Nanti".
  /// [payAmount] dipakai untuk DP (sebagian); metode lain melunasi total.
  Order createOrder({
    required String customer,
    String phone = '',
    required String dur,
    required List<OrderItem> items,
    String discKey = '0',
    int ongkir = 0,
    String perfume = 'Tanpa Parfum',
    String note = '-',
    String handover = 'Datang Langsung',
    bool priority = false,
    String payMethod = 'Bayar Nanti',
    String dpMethod = 'Tunai',
    int? payAmount,
    String kasir = 'Kasir',
    required DateTime now,
  }) {
    final id = nextOrderId(now);
    final due = now.add(Duration(hours: durationHours(dur)));
    final totals = calcTotals(items, discKey, ongkir);
    final later = RegExp('Bayar Nanti', caseSensitive: false).hasMatch(payMethod);
    final isDp = RegExp(r'^DP|Uang Muka', caseSensitive: false).hasMatch(payMethod);
    final method = isDp ? normalizeMethod(dpMethod) : normalizeMethod(payMethod);
    final int paid = later ? 0 : (isDp ? (payAmount ?? 0).clamp(0, totals.total).toInt() : totals.total);
    final antar = RegExp('Antar').hasMatch(handover);
    final pickup = RegExp('Jemput').hasMatch(handover) && items.isEmpty;
    final st = pickup ? 'jemput' : 'antrian';
    final createdIso = isoString(now);
    final payments = paid > 0 ? [{'m': method, 'a': paid, 'at': createdIso}] : <Map<String, dynamic>>[];

    final detail = <String, dynamic>{
      'id': id, 'name': customer, 'phone': phone, 'dur': dur, 'items': items.map((e) => e.toJson()).toList(), 'discKey': discKey,
      'ongkir': ongkir, 'paid': paid, 'perfume': perfume, 'note': note.isEmpty ? '-' : note, 'handover': handover,
      'masuk': createdIso, 'due': isoString(due), 'photos': {'in': [], 'out': []},
      'hist': [{'st': st, 'at': createdIso, 'by': kasir}],
    };
    final card = <String, dynamic>{
      'dataset': <String, dynamic>{
        'v108': '1', 'st': st, 'items': jsonEncode(items.map((e) => e.toJson()).toList()), 'v136': '1', 'created177': createdIso,
        'method177': method, 'paid177': '$paid', 'perfume178': perfume, 'payments178': jsonEncode(payments),
        if (activeOutlet.isNotEmpty) 'outlet180': activeOutlet, if (antar) 'antar': '1', if (totals.disc > 0) 'disc': '${totals.disc}',
      },
      'fields': [
        [dur], [id], [customer], ['Masuk · baru saja', 'Estimasi · ${_dmyHm(due)}'], <dynamic>[], <dynamic>[],
      ],
      'total': totals.total,
      'payment': '',
      'paid': false,
      'chips': [
        {'text': 'Prioritas', 'hidden': !priority},
        {'text': handover, 'hidden': false},
      ],
    };
    final order = Order(card, detail);
    _syncCard(order);
    (raw['orders'] as List).insert(0, card);
    _details[id] = detail;
    if (paid > 0) _kasSale(method, paid, id, now);
    if (customerByName(customer) == null && phone.isNotEmpty) saveCustomer(Customer(name: customer, phone: phone));
    return order;
  }

  /// Tombol status berikut (sama dengan HTML): jemput→antrian, proses→siap, siap→diantar/diambil.
  String? advance(Order o, {required DateTime now, String by = 'Kasir'}) {
    final st = o.status;
    if (st == 'diambil' || st == 'batal') return null;
    String n;
    if (st == 'jemput') {
      n = 'antrian';
      o.dataset['picked'] = '1';
    } else if (st == 'siap' || st == 'telat') {
      n = o.antar ? 'diantar' : 'diambil';
    } else if (st == 'diantar') {
      n = 'diambil';
    } else if (procStages.contains(st)) {
      n = 'siap';
    } else {
      final i = orderFlow.indexOf(st);
      n = i >= 0 && i + 1 < orderFlow.length ? orderFlow[i + 1] : 'diambil';
    }
    _setStatus(o, n, now, by);
    return n;
  }

  void _setStatus(Order o, String st, DateTime now, String by) {
    o.status = st;
    (o.detail.putIfAbsent('hist', () => <dynamic>[]) as List).add({'st': st, 'at': isoString(now), 'by': by});
    _syncCard(o);
  }

  /// Pembayaran (pelunasan / cicilan). Mengembalikan pesan salah atau null.
  String? pay(Order o, {required String method, required int amount, required DateTime now}) {
    if (o.isCancelled) return 'Pesanan sudah dibatalkan';
    final a = amount.clamp(0, o.remaining).toInt();
    if (a <= 0) return 'Nominal pembayaran belum diisi';
    final m = normalizeMethod(method);
    if (m == 'Deposit') {
      final bal = depositOf(o.name);
      if (bal < a) return 'Saldo deposit tidak cukup';
      (raw['deposits178'] as Map)[o.name.trim().toLowerCase()] = bal - a;
    }
    o.detail['paid'] = o.paid + a;
    final list = o.payments..add({'m': m, 'a': a, 'at': isoString(now)});
    o.dataset['payments178'] = jsonEncode(list);
    o.dataset['paid177'] = '${o.paid}';
    o.dataset['method177'] = m;
    _kasSale(m, a, o.id, now);
    _syncCard(o);
    return null;
  }

  String? cancel(Order o, {required String reason, required DateTime now, String by = 'Kasir'}) {
    if (reason.trim().isEmpty) return 'Pilih alasan pembatalan';
    if (o.status == 'diambil') return 'Pesanan sudah diambil';
    o.detail['cancelReason'] = reason;
    _setStatus(o, 'batal', now, by);
    return null;
  }

  /// Ubah rincian (estimasi, keterangan, parfum, diskon).
  void edit(Order o, {String? note, String? perfume, String? discKey, DateTime? due}) {
    if (note != null) o.detail['note'] = note.isEmpty ? '-' : note;
    if (perfume != null) {
      o.detail['perfume'] = perfume;
      o.dataset['perfume178'] = perfume;
    }
    if (discKey != null) o.detail['discKey'] = discKey;
    if (due != null) o.detail['due'] = isoString(due);
    _syncCard(o);
  }

  /// Kartu daftar mengikuti rincian (total, label bayar, estimasi, diskon).
  void _syncCard(Order o) {
    final t = o.totals;
    o.card['total'] = t.total;
    o.card['payment'] = o.isCancelled ? 'Batal' : o.paymentLabel;
    o.card['paid'] = o.isPaid;
    if (t.disc > 0) {
      o.dataset['disc'] = '${t.disc}';
    } else {
      o.dataset.remove('disc');
    }
    o.dataset['items'] = jsonEncode(o.items.map((e) => e.toJson()).toList());
    final due = o.due;
    final f = o.fields;
    while (f.length < 6) {
      f.add(<dynamic>[]);
    }
    if (due != null) f[3] = [if ((f[3] as List).isNotEmpty) (f[3] as List).first else 'Masuk · baru saja', 'Estimasi · ${_dmyHm(due)}'];
  }

  // ---------- kas ----------
  Map<String, dynamic> get kas => raw['kas'] as Map<String, dynamic>;

  void _kasSale(String method, int amount, String id, DateTime now) {
    (kas.putIfAbsent('sales', () => <dynamic>[]) as List).add({'m': method, 'a': amount, 'id': id, 'at': isoString(now)});
  }

  /// Kas masuk / pengeluaran manual.
  void kasEntry({required bool income, required String type, required int amount, String note = '', required DateTime now}) {
    (kas.putIfAbsent(income ? 'ins' : 'outs', () => <dynamic>[]) as List).add({'t': type, 'a': amount, 'n': note, 'at': isoString(now)});
  }

  /// Ringkasan hari ini untuk Beranda.
  DaySummary today(DateTime now) {
    bool same(DateTime? d) => d != null && d.year == now.year && d.month == now.month && d.day == now.day;
    var income = 0, inCount = 0, ready = 0, process = 0, late = 0;
    for (final s in (kas['sales'] as List? ?? const []).whereType<Map>()) {
      if (same(DateTime.tryParse('${s['at']}')?.toLocal())) income += parseRupiah(s['a']);
    }
    for (final o in orders) {
      if (o.isCancelled) continue;
      if (same(o.created)) inCount++;
      if (o.status == 'siap') ready++;
      if (procStages.contains(o.status) || o.status == 'antrian') process++;
      if (o.isLate(now)) late++;
    }
    return DaySummary(income: income, inCount: inCount, ready: ready, process: process, late: late);
  }
}

class DaySummary {
  const DaySummary({required this.income, required this.inCount, required this.ready, required this.process, required this.late});
  final int income, inCount, ready, process, late;
}
