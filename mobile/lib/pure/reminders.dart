// Reminder Pekerjaan (Pengaturan → Reminder): pengingat internal untuk pemilik/kasir, bukan WhatsApp pelanggan.
// Empat aturan (sakelar di halaman Reminder): 0 dua jam sebelum deadline, 1 order terlambat, 2 stok bahan minimum,
// 3 pesanan belum dibayar. Hasilnya dijadwalkan sebagai notifikasi HP (alarm Android, tetap muncul walau aplikasi ditutup)
// dan ditampilkan di halaman Reminder.

import '../core/business.dart';
import '../core/models.dart';
import '../core/money.dart';
import '../core/stock.dart';

class Reminder {
  const Reminder({required this.id, required this.kind, required this.title, required this.body, required this.at, this.immediate = false, this.orderId});

  /// Nomor notifikasi (tetap untuk pesanan/aturan yang sama supaya bisa diganti atau dibatalkan).
  final int id;

  /// 'due' | 'late' | 'stock' | 'unpaid'
  final String kind;
  final String title, body;
  final DateTime at;

  /// Langsung tampil (bukan dijadwalkan untuk nanti).
  final bool immediate;
  final String? orderId;

  /// Tanda isi: notifikasi hanya dijadwalkan ulang bila tanda ini berubah.
  String get signature => '$title|$body|${immediate ? 'now' : at.millisecondsSinceEpoch}';
}

int _hash(String s) {
  var h = 0;
  for (final c in s.codeUnits) {
    h = (h * 31 + c) % 900000;
  }
  return h;
}

String _two(int n) => n.toString().padLeft(2, '0');
String _hm(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';
String _dm(DateTime d) => '${_two(d.day)}/${_two(d.month)}';

const _done = {'siap', 'telat', 'diantar', 'diambil', 'batal'};

/// Daftar pengingat menurut aturan yang menyala ([on] = nilai sakelar 0–3).
List<Reminder> buildReminders({required Business b, StockBook? stock, required bool Function(int) on, required DateTime now}) {
  final out = <Reminder>[];
  final active = b.activeOutlet;
  bool mine(Order o) => active.isEmpty || o.outlet.isEmpty || o.outlet == active;
  for (final o in b.orders) {
    final due = o.due?.toLocal();
    if (due == null || _done.contains(o.status) || !mine(o)) continue;
    final what = '${o.id} · ${o.name}';
    if (due.isAfter(now)) {
      if (on(0)) {
        final at = due.subtract(const Duration(hours: 2));
        final soon = !at.isAfter(now);
        out.add(Reminder(id: 1000000 + _hash(o.id), kind: 'due', title: 'Deadline 2 jam lagi', body: '$what · harus selesai ${_dm(due)} ${_hm(due)}', at: soon ? now : at, immediate: soon, orderId: o.id));
      }
      if (on(1)) out.add(Reminder(id: 2000000 + _hash(o.id), kind: 'late', title: 'Pesanan terlambat', body: '$what · lewat deadline ${_dm(due)} ${_hm(due)}', at: due, orderId: o.id));
    } else if (on(1)) {
      out.add(Reminder(id: 2000000 + _hash(o.id), kind: 'late', title: 'Pesanan terlambat', body: '$what · lewat deadline ${_dm(due)} ${_hm(due)}', at: now, immediate: true, orderId: o.id));
    }
  }
  if (on(2) && stock != null) {
    final outlet = active.isNotEmpty ? active : (b.outlets.isEmpty ? 'default' : b.outlets.first.id);
    final low = [
      for (final e in stock.items)
        if (stock.balance('${e['id']}', outlet) <= ((e['min'] as num?) ?? 0)) '${e['name']} (sisa ${qtyText(stock.balance('${e['id']}', outlet))} ${e['unit']})',
    ];
    if (low.isNotEmpty) out.add(Reminder(id: 3000001, kind: 'stock', title: 'Stok bahan menipis', body: low.join(', '), at: now, immediate: true));
  }
  if (on(3)) {
    final unpaid = b.orders.where((o) => !o.isCancelled && !o.isPaid && o.total > 0 && mine(o)).toList();
    if (unpaid.isNotEmpty) {
      final nine = DateTime(now.year, now.month, now.day, 9);
      final at = now.isBefore(nine) ? nine : nine.add(const Duration(days: 1));
      out.add(Reminder(
        id: 3000002, kind: 'unpaid', title: 'Pesanan belum dibayar',
        body: '${unpaid.length} pesanan · total ${rp(unpaid.fold<int>(0, (a, o) => a + o.remaining))}', at: at,
      ));
    }
  }
  return out;
}

/// Selisih dengan yang sudah dijadwalkan ([prev] = id → tanda isi): (yang dibatalkan, yang dijadwalkan, peta baru).
(List<int>, List<Reminder>, Map<String, String>) diffReminders(Map prev, List<Reminder> list) {
  final next = {for (final r in list) '${r.id}': r.signature};
  final cancel = [for (final k in prev.keys) if (!next.containsKey('$k')) int.tryParse('$k') ?? -1].where((e) => e >= 0).toList();
  final add = [for (final r in list) if (prev['${r.id}'] != r.signature) r];
  return (cancel, add, next);
}
