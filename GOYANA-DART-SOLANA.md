# GOYANA: perintah kerja Dart (mode SOLANA, satu per satu)

Untuk AI yang melanjutkan migrasi logika ke Dart. Baca sampai habis sebelum mulai.

## 0. Mode kerja: SOLANA, bukan ASTRA
- Pakai **Solana**. **Jangan pakai Astra** (jangan mengerjakan banyak bagian sekaligus atau paralel).
- **Satu bagian per putaran kerja.** Selesaikan, tes, commit, tulis laporan, lalu BERHENTI dan tunggu Koko bilang "lanjut".
- Jangan menyentuh bagian lain "sekalian". Kalau menemukan masalah di luar bagian yang dikerjakan, cukup **catat** di laporan.

## 1. Cadangan & branch
- Kerja HANYA di branch **`flutter/native`**. Jangan push ke `main`.
- Titik aman sebelum serah terima: branch **`backup/flutter-native-2026-10-04-1300`** (commit `ba50d41`, CI lulus). Kalau ada yang rusak, bandingkan atau kembalikan dari sini. Branch cadangan itu jangan diubah.
- Selalu `git pull --rebase origin flutter/native` sebelum mulai dan sebelum push. Claude juga sesekali push ke branch ini.

## 2. Larangan keras
1. **Tampilan sudah FIX.** Jangan ubah file berikut:
   - `mobile/lib/native/*`, `mobile/lib/hybrid/shell.dart` (kecuali bagian pengaman, lihat langkah 5);
   - `mobile/web_bridge/capacitor.js`, `index.html`, `goyana-v*.js`, file CSS;
   - golden/screenshot.
2. Jangan sentuh `mobile/lib/pure/` (mode lama, tidak dipakai).
3. Jangan ubah hasil hitung jadi "lebih benar" menurut AI sendiri. Patokannya **hasil HTML apa adanya**. Kalau terasa salah, catat dan tanya Koko.
4. Jangan klaim "sudah jalan" sebelum CI lulus.
5. Jangan menulis password atau rahasia ke repo.

## 3. File yang BOLEH diubah
- `mobile/lib/logic/<bagian>.dart` (baru atau yang sedang dikerjakan)
- `mobile/test/parity_test.dart`
- `mobile/test/fixtures/parity/<bagian>_*.json`
- `tests/parity/*.cjs` (alat tangkap hasil HTML)
- `mobile/lib/hybrid/shell.dart`: **hanya** fungsi pengaman `_<bagian>FromDart` (contoh: `_homeFromDart`, `_ordersFromDart`)
- `GOYANA-PROGRESS.md` (laporan)

Kalau perlu mengubah file di luar daftar ini, **berhenti dan tanya Koko dulu**.

## 4. Urutan bagian (kerjakan berurutan, satu per satu)
| No | Bagian | Status |
|---|---|---|
| 1 | Beranda (`logic/home.dart`) | SELESAI, terpasang |
| 2 | Pesanan 8 tab + cari (`logic/orders.dart`) | SELESAI, terpasang |
| 3a | Tambah Transaksi: keranjang (jumlah, subtotal, harga per durasi) | SETENGAH JALAN (`logic/addorder.dart`, 37 tes). Pastikan semua lulus di CI, lalu pasang dengan pengaman. |
| 3b | Tambah Transaksi: diskon, ongkir | belum |
| 3c | Tambah Transaksi: nomor pesanan, estimasi selesai, simpan | belum |
| 4 | Rincian Pesanan: ganti status, edit, batal, riwayat | belum |
| 5 | Pembayaran: Tunai, QRIS, Transfer, DP, deposit, ralat | belum |
| 6 | Status otomatis: Antrian→Proses 60 menit, Telat Ambil, pengingat | belum |
| 7 | Kas & Tutup Kasir | belum |
| 8 | Laporan | belum |
| 9 | Pelanggan, CRM, poin, voucher | belum |
| 10 | Pengaturan (layanan/harga, parfum, diskon, outlet, pegawai, kurir, stok, printer, template WA) | belum |
| 11 | Sinkron ke server Laravel (setelah VPS ada) | belum |
| 12 | Cabut WebView/HTML: HANYA setelah semua lulus dan Koko setuju | belum |

Bagian besar dipecah kecil (contoh 3a/3b/3c). **Satu putaran = satu baris tabel.**

## 5. Langkah wajib untuk setiap bagian
1. **Tangkap hasil HTML** dengan `tests/parity/capture.cjs` (jam palsu, skenario nyata).
2. **Buat fixture** di `mobile/test/fixtures/parity/` berisi `{now, store, model HTML}`.
3. **Tulis Dart** di `mobile/lib/logic/<bagian>.dart`. Output harus **sama persis** dengan model HTML.
4. **Tes paritas** di `parity_test.dart`: `expect(dart, htmlModel)`. Flutter SDK tidak ada di cloud, jadi baca hasil CI:
   `gh api repos/rajabadutiklan-lab/Goyana/check-runs/<id>/annotations`
5. **Pasang dengan pengaman** di `shell.dart`:
   - Dart menghitung dulu.
   - Kalau hasilnya sama dengan HTML, layar memakai Dart.
   - Kalau beda, layar tetap memakai HTML dan perbedaannya dicatat di `goyana-parity-log`.
6. **Bagian yang menyimpan data:**
   - Tulis dalam format HTML yang sama persis: kartu `{dataset, fields, total, payment, paid, chips}` + `details` + `kas` + `deposits178`.
   - Setelah menulis, HTML harus dimuat ulang atau diberi tahu.
7. **Cek tidak merusak yang lain.** Sebelum push:
   - `GOYANA_BROWSER_EXECUTABLE=/opt/pw-browsers/chromium-1194/chrome-linux/chrome NODE_PATH=tests/node_modules node tests/flutter-bridge.cjs` harus **31 PASS**.
   - Tes paritas bagian sebelumnya (home, orders, addorder) harus tetap lulus.
8. **Push.** CI harus lulus semua: uji jembatan, analyze, tes unit, screenshot, APK. **Screenshot tidak boleh berubah**, karena bagian ini hanya mengubah logika.
9. **Tulis laporan** (format di bawah), commit, push, lalu **BERHENTI**.

## 6. Aturan hitung yang sudah diputuskan Koko
- Omset hari ini = jumlah penjualan sejak tutup kasir terakhir (ikut HTML).
- **Estimasi selesai = waktu masuk + jam durasi yang dipilih.** Jam diambil dari Pengaturan Durasi, kunci `goyana-durations199`, contoh `{"Reguler":72,"Express":24,"Kilat":6}`. Kunci yang tidak ada berarti bawaan 72/24/6. HTML memakai `durHours199(nama)`, dan Dart wajib memakai sumber yang sama.
- Berat kiloan boleh desimal, pakai koma atau titik.
- Input `1,2,3` dan `-2,5` saat ini ikut perilaku HTML. Menunggu keputusan Koko, jangan diubah.

## 7. Revisi Koko yang sudah selesai (JANGAN dirusak)
- Berat bisa koma/titik sejak ketikan pertama.
- Kolom HTML tersembunyi tidak mengambil keyboard.
- Popup tanpa isian tetap di bawah. Popup Pria/Wanita di tengah.
- Menu bawah sembunyi saat mengetik.
- Kurir: tombol Tambah di atas, ada Hapus (`deleted:true`, riwayat tetap).
- Parfum & Durasi: ikon edit/hapus tampil. 3 durasi utama tampil dan jamnya bisa diedit.

## 8. Format laporan (wajib, tiap bagian atau sebelum kuota habis)
Tambahkan di paling bawah `GOYANA-PROGRESS.md`:
```
### [GPT] Dart — <nomor & nama bagian> — <tanggal jam WIB>
- Status: SELESAI / SETENGAH JALAN / GAGAL
- Sudah dikerjakan: …
- File diubah: … (harus di dalam daftar "file yang boleh diubah")
- Tes paritas: <lulus>/<total>; fixture: …
- Uji jembatan: 31 PASS? ; screenshot berubah? (harus TIDAK)
- Commit: <hash> ; CI: lulus/gagal (sebutkan yang gagal)
- Langkah berikutnya: … (cukup jelas supaya AI lain bisa langsung lanjut)
- Pertanyaan untuk Koko: …
```
Kuota hampir habis? Tulis laporan SETENGAH JALAN dulu, commit, push. Jangan meninggalkan kode yang belum di-commit.
