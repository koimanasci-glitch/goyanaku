// Riwayat Transaksi (10 Okt 2026): teks tiap kejadian dari catatan server.
import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/pure/order_history.dart';

void main() {
  test('perubahan setelah dibayar ditandai; pengisian penjemputan dan perubahan sebelum diproses tidak', () {
    final events = [
      {'kind': 'buat', 'to': 'antrian', 'by': 'Rina', 'at': '2026-10-10T03:05:00Z'},
      {'kind': 'bayar', 'details': {'amount': 21000, 'method': 'Tunai'}, 'by': 'Rina', 'at': '2026-10-10T03:06:00Z'},
      {
        'kind': 'ubah', 'by': 'Rina', 'at': '2026-10-10T06:20:00Z', 'outlet_name': 'Bekasi',
        'details': {
          'before': {'items': [{'n': 'Cuci Setrika', 'q': 3, 'p': 7000}], 'total': 21000},
          'after': {'items': [{'n': 'Cuci Setrika', 'q': 2, 'p': 7000}], 'total': 14000},
          'paid_before': 21000, 'flag': true,
        },
      },
      {'kind': 'kembali', 'details': {'amount': 7000}, 'by': 'Rina', 'at': '2026-10-10T06:21:00Z'},
      {'kind': 'ubah', 'by': 'Rina', 'at': '2026-10-10T06:30:00Z', 'details': {'before': {'items': [], 'total': 0}, 'after': {'items': [], 'total': 0}, 'paid_before': 0, 'flag': false}},
      {'kind': 'batal', 'details': {'paid': 15000}, 'by': 'Dodi', 'at': '2026-10-10T07:00:00Z'},
    ];
    expect(historyText(events[1]).$1, 'Dibayar Tunai Rp21.000');
    final change = historyText(events[2]);
    expect(change, ('Diubah · Rp21.000 → Rp14.000', 'Cuci Setrika 3 → Cuci Setrika 2', 'Setelah dibayar'));
    expect(historyText(events[3]).$3, 'Pengembalian');
    expect(historyText(events[4]).$3, '');
    expect(historyText(events[5]), ('Dibatalkan', 'sudah dibayar Rp15.000', 'Batal setelah bayar'));

    final items = historySheetItems('GY-H', events, showOutlet: true);
    final rows = items.where((e) => e['type'] == 'entry').toList();
    expect(rows.length, 6);
    expect(rows[2]['badge'], '⚠ Setelah dibayar');
    expect((rows[2]['lines'] as List).last, endsWith('· Rina · Bekasi'));
    expect(items.last['t'], 'Tutup');
  });
}
