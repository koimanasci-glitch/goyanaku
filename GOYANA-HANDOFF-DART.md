# Serah terima ke GPT: pindahkan SEMUA perhitungan aplikasi Android ke Dart

Branch: `flutter/native` (jangan push ke `main`). Pemilik: Koko.

## Aturan dari Koko (wajib)
1. **Tampilan sudah FIX. Jangan ubah tampilan apa pun.** Yang dipindah hanya perhitungan/logika, dari HTML/JS ke Dart.
2. Kerjakan hanya yang diminta. Jangan "sekalian membetulkan" bagian lain.
3. Aturan hitung **ikut HTML apa adanya**, termasuk:
   - "Omset hari ini" = jumlah penjualan sejak tutup kasir terakhir;
   - Kilat/Express tidak mengubah estimasi selesai.

   Kalau menemukan aturan HTML yang terasa salah, **catat dan tanya Koko dulu**.
4. Catat keputusan di `GOYANA-PROGRESS.md`, lalu konsultasi ke Koko sebelum perubahan besar.
5. Jangan menulis rahasia/password di repo. Jangan klaim sesuatu "jalan" sebelum dites.

## Keadaan sekarang
- APK = Flutter *hybrid*. Semua layar digambar Flutter, tapi HTML (`index.html` + `goyana-v*.js`) masih jalan tersembunyi di WebView sebagai "otak". Data tersimpan di SQLite HP (`GoyanaStore.kt`).
  - Kunci data: `goyana-business177`, `goyana-services158`, `goyana-outlets180`, `goyana-active-outlet180`, `goyana-couriers181`, `goyana-stock181`, dll.
- Cara layar mendapat isi: `mobile/web_bridge/capacitor.js` membaca DOM HTML lalu mengirim model JSON. Shell Flutter (`mobile/lib/hybrid/shell.dart`) menggambar model itu dengan widget di `mobile/lib/native/`:
  - widget khusus: home, orders, addorder, customers, reports, settings, cash, cashclose, services, `order_detail_page.dart`;
  - widget generik: `form_page.dart` (NativeForm/NativeSheet);
  - widget "cermin HTML": `mirror_sheet.dart` (14 popup + 9 halaman).
- Logika Dart yang sudah ada:
  - `mobile/lib/core/`: models, business, money, qris, receipt, settings, stock — dibuat saat "mode murni"; sebagian sudah dites paritas di `test/core_test.dart`.
  - `mobile/lib/logic/home.dart`: Beranda, **SELESAI**, lulus paritas, sudah dipasang.
  - `mobile/lib/logic/orders.dart`: Pesanan (8 tab + cari), **SELESAI**, lulus paritas, sudah dipasang.
  - `mobile/lib/pure/`: mode murni lama, TIDAK dipakai aplikasi. Hanya contoh logika, jangan dipasang.

## Metode wajib per bagian (jangan dilewati)
1. **Tangkap hasil HTML**: `tests/parity/capture.cjs` menjalankan HTML asli di Chromium dengan jam palsu, membuat skenario (buat pesanan, ganti status, batal, maju N hari), lalu menyimpan isi penyimpanan dan model JSON yang dikirim HTML ke layar.
   - Catatan: skrip ini baru dipindah dari folder kerja Claude dan belum dijalankan dari lokasi repo. Cek dulu.
   - Tambah langkah skenario sesuai bagian yang dikerjakan (bayar, DP, kas, laporan, dll).
2. **Buat fixture** di `mobile/test/fixtures/parity/` berisi `{now, store, <model HTML>}`.
3. **Tulis logika Dart** di `mobile/lib/logic/<bagian>.dart`. Output harus berupa JSON yang **sama persis** dengan model HTML, karena widget yang sama yang menggambarnya.
4. **Tes paritas** di `mobile/test/parity_test.dart`: `expect(dart, htmlModel)`. CI menjalankannya ("Tes unit (logika Dart)").
   - Karena Flutter SDK tidak bisa dipasang di lingkungan cloud, baca hasil lewat `gh api repos/rajabadutiklan-lab/Goyana/check-runs/<id>/annotations`.
5. **Pasang dengan pengaman.** Contoh: `_homeFromDart` dan `_ordersFromDart` di `shell.dart`.
   - Dart menghitung dari database HP.
   - Kalau sama dengan model HTML, layar memakai Dart.
   - Kalau beda, layar tetap memakai HTML dan perbedaannya dicatat di kunci `goyana-parity-log`.
6. **Bagian yang MENYIMPAN data** (buat pesanan, bayar, status, kas):
   - Dart menulis dalam **format HTML yang sama persis**: kartu `{dataset, fields, total, payment, paid, chips}` + `details` + `kas` + `deposits178`.
   - Setelah menulis, HTML di WebView harus dimuat ulang/diberi tahu supaya datanya ikut, sampai HTML dicabut.
   - Tampilan tidak boleh berubah.
7. Push ke `flutter/native` → CI menjalankan:
   - uji jembatan `tests/flutter-bridge.cjs` (harus tetap 31 PASS),
   - analyze,
   - tes unit,
   - screenshot,
   - APK ke Release `flutter-uji`.

## Urutan sisa (disetujui Koko)
1. Tambah Transaksi: total, diskon, ongkir, durasi, nomor pesanan, simpan. Rumus dasar ada di `core/business.dart` `createOrder`/`calcTotals` dan sudah cocok dengan `api115.calc`.
2. Rincian Pesanan: ganti status (`next()` v108), edit, batal, riwayat.
3. Pembayaran: Tunai, QRIS (`core/qris.dart`), Transfer, DP, deposit, ralat.
4. Status otomatis:
   - v133: Antrian → Proses setelah 60 menit;
   - v138/v140: Siap → Telat Ambil setelah N hari;
   - pengingat.
5. Kas & Tutup Kasir (KAS137).
6. Laporan (±40 laporan, rp170d/finreport).
7. Pelanggan, CRM, poin, voucher.
8. Pengaturan: layanan/harga, parfum, diskon, outlet, pegawai & hak akses, kurir, stok, printer/struk/label, template WA.
9. Sinkron ke server Laravel (setelah VPS ada; endpoint sama dengan `goyana-sync-core.js`).
10. Terakhir, setelah semua lulus dan Koko setuju: cabut WebView/HTML dari APK.

## Hal yang sudah diketahui
- HTML berlapis-lapis (`goyana-v108` … `v190` saling menimpa). Patokan = **hasil akhir yang terlihat**, bukan satu fungsi saja. Karena itu wajib tangkap hasil nyata.
- Contoh perilaku HTML yang ditiru apa adanya: chip kartu disimpan di snapshot kartu (`chips[].hidden`); "Datang Langsung" tidak ditampilkan.
- Revisi Koko yang sudah selesai (jangan dirusak):
  - berat bisa koma/titik;
  - kolom HTML tersembunyi tidak boleh mengambil keyboard;
  - popup tanpa isian tetap di bawah;
  - popup Pria/Wanita di tengah;
  - menu bawah sembunyi saat mengetik;
  - kurir: tombol Tambah di atas, ada Hapus (`deleted:true`, riwayat tetap).

## WAJIB: laporan tiap bagian (kuota bisa habis sewaktu-waktu)
Setiap kali satu bagian selesai, ATAU sebelum berhenti, ATAU kalau kuota hampir habis, tambahkan laporan di bagian paling bawah `GOYANA-PROGRESS.md`, lalu commit dan push. Pakai format ini:

```
### [GPT] Dart — <nama bagian> — <tanggal jam WIB>
- Status: SELESAI / SETENGAH JALAN / GAGAL
- Sudah dikerjakan: …
- File diubah: …
- Tes paritas: <jumlah lulus>/<jumlah total>; fixture: …
- Commit: <hash> ; hasil CI: lulus/gagal (sebutkan yang gagal)
- Belum selesai / langkah berikutnya: … (cukup jelas supaya AI lain bisa langsung lanjut)
- Temuan aturan HTML yang perlu ditanyakan ke Koko: …
```

Jangan menunggu satu bagian selesai sepenuhnya baru menulis laporan. Commit kecil-kecil, dan laporan juga ditulis untuk pekerjaan yang setengah jalan.
