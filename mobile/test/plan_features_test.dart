// Pembagian fitur per paket (Tahap 2 fitur 8, keputusan Paduka 10 Okt 2026).
import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/pure/access.dart';

void main() {
  tearDown(() => planAccess.testPlan = null);

  test('laporan: dasar semua paket, lengkap/laba/HPP/export Silver, kinerja & poin Gold', () {
    for (final id in ['omzet', 'arus', 'piutang', 'keluar', 'semua', 'status', 'batal', 'stok', 'tutup']) {
      expect(reportFeature(id), isNull, reason: id);
    }
    expect(reportFeature('laba'), 'profit');
    expect(reportFeature('labaop182'), 'hpp');
    expect(reportFeature('hpp182'), 'hpp');
    expect(reportFeature('beli'), 'suppliers');
    expect(reportFeature('x-trx'), 'export');
    expect(reportFeature('kinerja'), 'staff_perf');
    expect(reportFeature('poin'), 'crm');
    expect(reportFeature('jam'), 'reports_full');
    final n = DateTime(2026, 10, 10);
    planAccess.testPlan = 'BASIC';
    expect(['profit', 'hpp', 'suppliers', 'export', 'reports_full', 'staff_perf', 'crm'].where((f) => planAccess.has(f, n)), isEmpty);
    expect(planAccess.has('stock', n) && planAccess.has('opname', n) && planAccess.has('transfer', n), isTrue);
    planAccess.testPlan = 'SILVER';
    expect(['profit', 'hpp', 'suppliers', 'export', 'reports_full', 'wa'].every((f) => planAccess.has(f, n)), isTrue);
    expect(planAccess.has('staff_perf', n) || planAccess.has('crm', n) || planAccess.has('profit_all', n), isFalse);
    planAccess.testPlan = 'GOLD';
    expect(planAccess.has('staff_perf', n) && planAccess.has('crm', n) && planAccess.has('ai', n), isTrue);
    expect(planAccess.has('blast', n), isFalse);
    expect(planAccess.lockedText('suppliers'), 'Supplier & belanja bahan membutuhkan paket Silver');
    expect(planAccess.lockedText('staff_perf'), 'Kinerja & komisi pegawai membutuhkan paket Gold');
    expect(planAccess.lockedText('blast'), 'WhatsApp Blast membutuhkan paket Platinum');
    expect(planAccess.lockedText('opname'), 'Stok Opname membutuhkan paket Basic');
    expect(pageGates['rank138'], 'crm');
  });
}
