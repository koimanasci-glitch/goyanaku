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
  /// Ubah outlet aktif (atau buat yang pertama).
  Future<bool> saveOutlet({required String name, String address = '', String phone = ''}) async {
    var o = outlets.where((x) => x.id == activeOutlet).firstOrNull ?? outlets.firstOrNull;
    if (o == null) {
      o = Outlet({'id': 'outlet180-${DateTime.now().microsecondsSinceEpoch}', 'logo': ''});
      outlets.add(o);
      activeOutlet = o.id;
      await store.set(Keys.activeOutlet, jsonEncode(activeOutlet));
    }
    o.raw
      ..['name'] = name
      ..['address'] = address
      ..['phone'] = phone;
    return store.set(Keys.outlets, jsonEncode(outlets.map((e) => e.raw).toList()));
  }

  /// Isi saldo deposit pelanggan (dicatat juga sebagai kas masuk).
  String? topUpDeposit(String name, int amount, {required String method, required DateTime now}) {
    if (amount <= 0) return 'Isi nominal';
    _depositMove(name, amount, 'topup', method, now);
    kasEntry(income: true, type: 'Titipan deposit $name', amount: amount, method: method, now: now);
    return null;
  }

  Future<bool> saveServices() => store.set(Keys.services, jsonEncode(services.map((e) => e.raw).toList()));

  /// Harga & status aktif layanan per durasi.
  void setServicePrice(Service s, String dur, int price) => (s.raw.putIfAbsent('prices', () => <String, dynamic>{}) as Map)[dur] = price;
  void toggleService(Service s, String dur) {
    final en = s.raw.putIfAbsent('enabled', () => <String, dynamic>{}) as Map;
    en[dur] = !(en[dur] != false);
  }

  /// Layanan baru (kategori): harga Express 1,5×, Kilat 2× dari Reguler (sama dengan HTML).
  String? addService(String name, String unit, int regular) {
    if (name.trim().isEmpty || regular <= 0) return 'Isi nama dan harga';
    if (services.any((e) => e.name.toLowerCase() == name.trim().toLowerCase())) return 'Layanan $name sudah ada';
    services.add(Service({
      'key': name.trim().toLowerCase(), 'name': name.trim(), 'unit': unit,
      'prices': {'Reguler': regular, 'Express': (regular * 1.5).round(), 'Kilat': regular * 2},
      'enabled': {'Reguler': true, 'Express': true, 'Kilat': true}, 'proc': ['Cuci', 'Kering', 'Setrika', 'Packing'],
    }));
    return null;
  }

  // ---------- tutup kasir ----------
  /// Ringkasan shift berjalan: penjualan per metode, kas masuk/keluar, saldo tunai seharusnya.
  ShiftSummary shift() {
    final k = kas;
    final byMethod = <String, int>{'Tunai': 0, 'QRIS': 0, 'Transfer': 0, 'Deposit': 0};
    for (final s in (k['sales'] as List? ?? const []).whereType<Map>()) {
      final m = '${s['m']}';
      byMethod[m] = (byMethod[m] ?? 0) + parseRupiah(s['a']);
    }
    // Kas tunai hanya dari kas masuk tunai (titipan deposit lewat QRIS/transfer tidak masuk laci).
    final ins = (k['ins'] as List? ?? const []).whereType<Map>().where((e) => '${e['m'] ?? 'Tunai'}' == 'Tunai').fold<int>(0, (a, e) => a + parseRupiah(e['a']));
    final outs = (k['outs'] as List? ?? const []).whereType<Map>().fold<int>(0, (a, e) => a + parseRupiah(e['a']));
    final start = parseRupiah(k['start']);
    return ShiftSummary(start: start, byMethod: byMethod, ins: ins, outs: outs, cashExpected: start + (byMethod['Tunai'] ?? 0) + ins - outs);
  }

  /// Tutup kasir: catat riwayat shift lalu mulai shift baru.
  void closeShift({required int physical, required String note, required DateTime now, String kasir = 'Kasir'}) {
    final s = shift();
    (kas.putIfAbsent('hist', () => <dynamic>[]) as List).insert(0, {
      'at': isoString(now), 'kasir': kasir, 'start': s.start, 'sales': s.byMethod, 'ins': s.ins, 'outs': s.outs,
      'expected': s.cashExpected, 'physical': physical, 'diff': physical - s.cashExpected, 'note': note,
    });
    kas
      ..['start'] = 0
      ..['sales'] = <dynamic>[]
      ..['ins'] = <dynamic>[]
      ..['outs'] = <dynamic>[]
      ..['openAt'] = isoString(now);
  }

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
    int find(String name) => list.indexWhere((e) => e is Map && '${e['name']}'.trim().toLowerCase() == name.trim().toLowerCase());
    if (originalName == null) {
      if (find(c.name) >= 0) return 'Pelanggan ${c.name} sudah ada';
      list.add(c.toJson());
      return null;
    }
    final i = find(originalName);
    final clash = find(c.name);
    if (clash >= 0 && clash != i) return 'Pelanggan ${c.name} sudah ada';
    if (i >= 0) {
      list[i] = c.toJson();
    } else {
      list.add(c.toJson());
    }
    return null;
  }

  // ---------- deposit (format HTML: kunci "phone:62…" atau "name:…", {name, phone, balance, history}) ----------
  static String normalizedPhone(String p) {
    var n = p.replaceAll(RegExp(r'\D'), '');
    if (n.startsWith('0')) n = '62${n.substring(1)}';
    return n;
  }

  String depositKey(String name) {
    final c = customerByName(name);
    final p = normalizedPhone(c?.phone ?? '');
    return p.isNotEmpty ? 'phone:$p' : 'name:${name.trim().toLowerCase()}';
  }

  Map<String, dynamic> _depositRecord(String name) {
    final d = raw['deposits178'] as Map<String, dynamic>;
    final v = d[depositKey(name)];
    if (v is Map) return Map<String, dynamic>.from(v);
    final c = customerByName(name);
    return {'name': name, 'phone': c?.phone ?? '', 'balance': 0, 'history': <dynamic>[]};
  }

  int depositOf(String name) => parseRupiah(_depositRecord(name)['balance']);

  void _depositMove(String name, int amount, String type, String method, DateTime now) {
    final r = _depositRecord(name);
    r['balance'] = parseRupiah(r['balance']) + amount;
    (r.putIfAbsent('history', () => <dynamic>[]) as List).add({'type': type, 'amount': amount.abs(), 'at': isoString(now), 'method': method});
    (raw['deposits178'] as Map<String, dynamic>)[depositKey(name)] = r;
  }

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
      if (depositOf(o.name) < a) return 'Saldo deposit tidak cukup';
      _depositMove(o.name, -a, 'pay', 'Deposit', now);
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

  /// Isi layanan & berat setelah cucian dijemput/ditimbang.
  void setItems(Order o, List<OrderItem> items) {
    o.detail['items'] = items.map((e) => e.toJson()).toList();
    _syncCard(o);
  }

  /// CSV pesanan (dibuka di Excel/Sheets).
  String ordersCsv() {
    String q(Object? v) => '"${'$v'.replaceAll('"', '""')}"';
    final rows = <String>['ID,Tanggal,Pelanggan,Telepon,Durasi,Layanan,Subtotal,Diskon,Total,Dibayar,Status,Pembayaran'];
    for (final o in orders) {
      final t = o.totals;
      rows.add([
        q(o.id), q(o.created == null ? '' : isoString(o.created!)), q(o.name), q(o.phone), q(o.dur),
        q(o.items.map((e) => '${e.name} ${qtyText(e.qty)}${e.unit}').join('; ')), t.sub, t.disc, t.total, o.paid,
        q(statusLabel[o.status] ?? o.status), q(o.paymentLabel),
      ].join(','));
    }
    return rows.join('\n');
  }

  String customersCsv() {
    String q(Object? v) => '"${'$v'.replaceAll('"', '""')}"';
    return ['Nama,Telepon,Alamat,Saldo Deposit', for (final c in customers) [q(c.name), q(c.phone), q(c.address), depositOf(c.name)].join(',')].join('\n');
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
  void kasEntry({required bool income, required String type, required int amount, String note = '', String method = 'Tunai', required DateTime now}) {
    (kas.putIfAbsent(income ? 'ins' : 'outs', () => <dynamic>[]) as List)
        .add({'m': method == 'Tunai' ? 'Tunai' : 'Non-Tunai', 'actualMethod178': method, 't': type, 'a': amount, 'n': note, 'at': isoString(now)});
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

class ShiftSummary {
  const ShiftSummary({required this.start, required this.byMethod, required this.ins, required this.outs, required this.cashExpected});
  final int start, ins, outs, cashExpected;
  final Map<String, int> byMethod;
  int get sales => byMethod.values.fold(0, (a, b) => a + b);
}

class DaySummary {
  const DaySummary({required this.income, required this.inCount, required this.ready, required this.process, required this.late});
  final int income, inCount, ready, process, late;
}
