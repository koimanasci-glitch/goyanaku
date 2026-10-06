// A9 CRM Pelanggan (pengingat, poin member, voucher) dimiliki Dart. Di HTML CRM hanya demo di memori;
// di sini datanya disimpan (kunci goyana-crm203) dan poin/pengingat dihitung dari pesanan nyata (goyana-business177).
import 'dart:convert';
import 'dart:math' as math;

import '../core/store.dart';

const crmKey = 'goyana-crm203';
const _day = Duration.millisecondsPerDay;

class CrmReward {
  CrmReward(this.t, this.p, this.v);
  String t;
  int p, v; // nama, poin dibutuhkan, nilai Rp
  Map<String, Object?> toJson() => {'t': t, 'p': p, 'v': v};
}

class CrmVoucher {
  CrmVoucher({required this.code, required this.name, required this.type, required this.val, this.min = 0, this.until = '', required this.who, this.used = false, this.batch = ''});
  final String code, name, type, until, who, batch; // type: 'p' persen, 'n' nominal
  final int val, min;
  bool used;
  bool expired(DateTime now) {
    if (until.isEmpty) return false;
    final d = DateTime.tryParse('${until}T23:59:00');
    return d != null && d.isBefore(now);
  }

  String status(DateTime now) => used ? 'Terpakai' : (expired(now) ? 'Kedaluwarsa' : 'Aktif');
  Map<String, Object?> toJson() => {'code': code, 'name': name, 'type': type, 'val': val, 'min': min, 'until': until, 'who': who, 'used': used, 'batch': batch};
}

class CrmState {
  CrmState({
    this.remOn = true,
    List<int>? remDays,
    this.remLast = 14,
    this.remAfter = 30,
    this.rule = 'fee',
    this.fee = 1000,
    this.printRule = true,
    this.tpl = 'Halo {nama}, cucian Anda ({kode}) sudah siap sejak {hari} hari lalu. Total {total}. Silakan diambil di {outlet} ya 🙏',
    this.ptOn = true,
    this.per = 10000,
    this.expMonths = 12,
    List<CrmReward>? rewards,
    Map<String, int>? redeemed,
    List<CrmVoucher>? vouchers,
    Map<String, List<int>>? reminded,
  })  : remDays = remDays ?? [3, 7],
        rewards = rewards ?? [],
        redeemed = redeemed ?? {},
        vouchers = vouchers ?? [],
        reminded = reminded ?? {};

  bool remOn, printRule, ptOn;
  List<int> remDays;
  int remLast, remAfter, fee, per, expMonths;
  String rule, tpl;
  List<CrmReward> rewards;
  Map<String, int> redeemed;
  List<CrmVoucher> vouchers;
  Map<String, List<int>> reminded;

  factory CrmState.fromJson(Map j) {
    int n(Object? v, int d) => v is num ? v.toInt() : int.tryParse('$v') ?? d;
    final r = j['rem'] is Map ? j['rem'] as Map : const {};
    final p = j['pt'] is Map ? j['pt'] as Map : const {};
    final s = CrmState(
      remOn: r['on'] != false,
      remDays: [for (final d in (r['days'] as List? ?? const [3, 7])) n(d, 3)],
      remLast: n(r['last'], 14),
      remAfter: n(r['after'], 30),
      rule: '${r['rule'] ?? 'fee'}',
      fee: n(r['fee'], 1000),
      printRule: r['print'] != false,
      ptOn: p['on'] != false,
      per: math.max(1, n(p['per'], 10000)),
      expMonths: n(p['exp'], 12),
    );
    if (r['tpl'] is String) s.tpl = r['tpl'] as String;
    if (s.remDays.isEmpty) s.remDays = [3];
    for (final w in (p['rewards'] as List? ?? const []).whereType<Map>()) {
      s.rewards.add(CrmReward('${w['t']}', n(w['p'], 1), n(w['v'], 0)));
    }
    (j['redeemed'] as Map? ?? const {}).forEach((k, v) => s.redeemed['$k'] = n(v, 0));
    for (final v in (j['vouchers'] as List? ?? const []).whereType<Map>()) {
      s.vouchers.add(CrmVoucher(
        code: '${v['code']}', name: '${v['name']}', type: '${v['type']}', val: n(v['val'], 0), min: n(v['min'], 0),
        until: '${v['until'] ?? ''}', who: '${v['who']}', used: v['used'] == true, batch: '${v['batch'] ?? ''}',
      ));
    }
    (j['reminded'] as Map? ?? const {}).forEach((k, v) => s.reminded['$k'] = [for (final d in (v as List)) n(d, 0)]);
    return s;
  }

  Map<String, Object?> toJson() => {
        'rem': {'on': remOn, 'days': remDays, 'last': remLast, 'after': remAfter, 'rule': rule, 'fee': fee, 'print': printRule, 'tpl': tpl},
        'pt': {'on': ptOn, 'per': per, 'exp': expMonths, 'rewards': [for (final w in rewards) w.toJson()]},
        'redeemed': redeemed,
        'vouchers': [for (final v in vouchers) v.toJson()],
        'reminded': reminded,
      };

  String get ruleText => rule == 'fee'
      ? 'Cucian yang tidak diambil lebih dari $remAfter hari dikenakan biaya simpan ${crmRp(fee)}/hari.'
      : rule == 'donate'
          ? 'Cucian yang tidak diambil lebih dari $remAfter hari akan disumbangkan.'
          : 'Harap ambil cucian maksimal $remAfter hari setelah siap.';
}

String crmRp(num n) =>
    'Rp${n.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}';

/// Pesanan siap yang belum diambil.
class CrmUncollected {
  CrmUncollected(this.id, this.name, this.phone, this.days, this.total);
  final String id, name, phone;
  final int days, total;
}

class CrmData {
  CrmData(this.members, this.uncollected, this.customers, this.segments);
  final Map<String, int> members; // poin kotor dari pesanan lunas (sebelum dikurangi penukaran)
  final List<CrmUncollected> uncollected;
  final Map<String, String> customers; // nama -> telepon
  final Map<String, List<String>> segments; // all, setia, pasif, baru -> nama
}

int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v'.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;

/// Membaca isi `goyana-business177` (pesanan + pelanggan) untuk poin, pengingat dan segmen.
CrmData crmFromBusiness(Map business, CrmState st, DateTime now) {
  final details = business['details'] is Map ? business['details'] as Map : const {};
  final members = <String, int>{};
  final uncollected = <CrmUncollected>[];
  final orderCount = <String, int>{};
  final lastOrder = <String, DateTime>{};
  final firstOrder = <String, DateTime>{};
  for (final o in (business['orders'] as List? ?? const []).whereType<Map>()) {
    final ds = o['dataset'] is Map ? o['dataset'] as Map : const {};
    final f = o['fields'] is List ? o['fields'] as List : const [];
    String field(int i) => i < f.length && f[i] is List && (f[i] as List).isNotEmpty ? '${(f[i] as List).first}'.trim() : '';
    final id = field(1), name = field(2), stt = '${ds['st'] ?? ''}';
    if (name.isEmpty) continue;
    final created = DateTime.tryParse('${ds['created177'] ?? ''}') ?? now;
    if (stt != 'batal') {
      orderCount[name] = (orderCount[name] ?? 0) + 1;
      final l = lastOrder[name];
      if (l == null || created.isAfter(l)) lastOrder[name] = created;
      final fo = firstOrder[name];
      if (fo == null || created.isBefore(fo)) firstOrder[name] = created;
      final paid = _int(ds['paid177']);
      if (paid > 0) members[name] = (members[name] ?? 0) + paid ~/ st.per;
    }
    if (stt == 'siap' || stt == 'telat') {
      final d = details[id] is Map ? details[id] as Map : const {};
      var ready = created;
      for (final h in (d['hist'] as List? ?? const []).whereType<Map>()) {
        if (h['st'] == 'siap') ready = DateTime.tryParse('${h['at']}') ?? ready;
      }
      uncollected.add(CrmUncollected(id, name, '${d['phone'] ?? ''}', math.max(0, now.difference(ready).inMilliseconds ~/ _day), _int(o['total'])));
    }
  }
  final customers = <String, String>{
    for (final c in (business['customers'] as List? ?? const []).whereType<Map>()) '${c['name']}': '${c['phone'] ?? ''}',
  };
  final all = customers.keys.toList();
  bool recent(String n, int days) => lastOrder[n] != null && now.difference(lastOrder[n]!).inDays <= days;
  return CrmData(
    members,
    uncollected,
    customers,
    {
      'all': all,
      'setia': [for (final n in all) if ((orderCount[n] ?? 0) >= 3) n],
      'pasif': [for (final n in all) if (lastOrder[n] != null && !recent(n, 30)) n],
      'baru': [for (final n in all) if (firstOrder[n] != null && now.difference(firstOrder[n]!).inDays <= 30) n],
    },
  );
}

/// Poin yang masih bisa dipakai = poin dari pesanan lunas − poin yang sudah ditukar.
Map<String, int> crmBalances(CrmData d, CrmState st) =>
    {for (final e in d.members.entries) e.key: math.max(0, e.value - (st.redeemed[e.key] ?? 0))};

(String, String) crmStage(CrmState st, int days) {
  if (days >= st.remAfter) return ('Lewat ${st.remAfter} hari', 'red');
  if (days >= st.remLast) return ('Peringatan terakhir', 'red');
  if (days >= st.remDays.first) return ('Perlu diingatkan', 'org');
  return ('Baru siap', 'gry');
}

String crmReminderText(CrmState st, CrmUncollected u, String outlet) {
  var msg = st.tpl
      .replaceAll('{nama}', u.name)
      .replaceAll('{kode}', u.id)
      .replaceAll('{hari}', '${u.days}')
      .replaceAll('{total}', crmRp(u.total))
      .replaceAll('{outlet}', outlet);
  if (u.days >= st.remLast) msg += '\n\n⚠️ ${st.ruleText}';
  return msg;
}

String crmNewCode(CrmState st, [math.Random? rnd]) {
  const ch = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final r = rnd ?? math.Random.secure();
  while (true) {
    final c = 'GY-${List.generate(5, (_) => ch[r.nextInt(ch.length)]).join()}';
    if (!st.vouchers.any((v) => v.code == c)) return c;
  }
}

/// Buat satu kode unik per penerima. Mengembalikan jumlah kode yang dibuat.
int crmCreateVouchers(CrmState st, {required String name, required String type, required int val, required int min, required String until, required List<String> who, math.Random? rnd}) {
  for (final n in who) {
    st.vouchers.insert(0, CrmVoucher(code: crmNewCode(st, rnd), name: name, type: type, val: val, min: min, until: until, who: n, batch: name));
  }
  return who.length;
}

/// Tukar poin dengan hadiah: potong poin, buat voucher nominal. Null bila poin tidak cukup.
CrmVoucher? crmRedeem(CrmState st, Map<String, int> balances, String who, CrmReward w, {math.Random? rnd}) {
  if ((balances[who] ?? 0) < w.p) return null;
  st.redeemed[who] = (st.redeemed[who] ?? 0) + w.p;
  final v = CrmVoucher(code: crmNewCode(st, rnd), name: 'Tukar poin: ${w.t}', type: 'n', val: w.v, who: who, batch: 'Poin');
  st.vouchers.insert(0, v);
  return v;
}

class CrmStore {
  CrmStore(this.kv);
  final KvStore kv;
  Future<CrmState> load() async {
    try {
      final raw = await kv.get(crmKey);
      if (raw != null && raw.isNotEmpty) return CrmState.fromJson(jsonDecode(raw) as Map);
    } catch (_) {}
    return CrmState();
  }

  Future<void> save(CrmState s) => kv.set(crmKey, jsonEncode(s.toJson()));
  Future<Map> loadBusiness() async {
    try {
      final raw = await kv.get('goyana-business177');
      if (raw != null && raw.isNotEmpty) return jsonDecode(raw) as Map;
    } catch (_) {}
    return {};
  }
}
