# GOYANA: perintah kerja (satu bagian per putaran)

Untuk AI yang melanjutkan migrasi logika ke Dart. Baca sampai habis sebelum mulai.

## 0. Mode kerja
- Mode Solana atau Astra boleh, ikut setelan yang dipakai Koko (contoh: mode work = Astra).
- Apa pun modenya: **jangan mengerjakan banyak bagian sekaligus atau paralel dalam satu sesi.**
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
3. **Hitungan harus BENAR, bukan sekadar sama dengan HTML** (keputusan Koko 4 Okt). Patokan awalnya tetap hasil HTML. Kalau ketemu hitungan HTML yang SALAH:
   - JANGAN ditiru dan JANGAN dibetulkan diam-diam;
   - catat di laporan bagian "Temuan salah hitung": contoh angka HTML, angka yang benar, dan usulan aturan;
   - tunggu Koko setuju;
   - setelah disetujui, aturan yang benar dipasang di Dart DAN di HTML (HTML masih jalan di aplikasi), lalu fixture ditangkap ulang. HTML diubah oleh Claude, bukan GPT.
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

## 4. Peta lengkap sampai SEMPURNA (Flutter murni, tanpa HTML)
Target akhir (keputusan Koko 4 Okt: "saya mau perfek semuanya"): aplikasi 100% Flutter + Dart, HTML/WebView dicabut, tampilan sama dengan sekarang, dan semua hitungan BENAR.
Ada 4 jalur. Jalur A dan B boleh jalan bersamaan oleh sesi berbeda. C dan D di akhir.

### Jalur A: Hitungan ke Dart (sesi Dart)
| No | Bagian | Status |
|---|---|---|
| A1 | Beranda (`logic/home.dart`) | SELESAI, terpasang |
| A2 | Pesanan 8 tab + cari (`logic/orders.dart`) | SELESAI, terpasang |
| A3a | Tambah Transaksi: keranjang | SELESAI, terpasang; input berat salah ketik ditolak (4 Okt) |
| A3b | Tambah Transaksi: diskon, ongkir | Keputusan Koko: ongkir TIDAK ikut didiskon (HTML & fixture sudah). Sesuaikan Dart, pasang pengaman |
| A3c | Tambah Transaksi: nomor pesanan, estimasi, simpan | SIAP (8/8 tes), belum dipasang; dipasang sesudah A3b |
| A4 | Rincian Pesanan: ganti status, edit, batal, riwayat | belum |
| A5 | Pembayaran: Tunai, QRIS, Transfer, DP, deposit, ralat | belum |
| A6 | Status otomatis: Antrian→Proses 60 menit, Telat Ambil, pengingat | belum |
| A7 | Kas & Tutup Kasir | belum |
| A8 | Laporan (±40) | belum |
| A9 | Pelanggan, CRM, poin, voucher | belum |
| A10 | Pengaturan (layanan/harga, parfum, durasi, diskon, outlet, pegawai, kurir, stok, printer, template WA) | belum |
| A11 | Sinkron ke server Laravel (setelah VPS ada) | belum |

### Jalur B: Halaman & popup "cermin" jadi widget Flutter asli (sesi tampilan)
Sekarang bentuknya dibaca dari HTML tersembunyi (`mirror_sheet.dart`). Harus ditulis ulang sebagai widget Flutter biasa dengan bentuk PERSIS sama (bandingkan golden sebelum/sesudah, piksel harus sama atau beda tak terlihat). Satu halaman per putaran.
| No | Halaman cermin | Status |
|---|---|---|
| B1 | Parfum (`perfume`) | belum |
| B2 | Durasi (`duration`) | belum |
| B3 | Pilih Layanan (`pickservice`) | belum |
| B4 | Jemput (`pickup`) | belum |
| B5 | Scan Pesanan (`orderscan`) | belum |
| B6 | Status QR (`qrstatus`) | belum |
| B7 | Harga Paket (`plan111`) | belum (tunggu hasil sesi desain dulu) |
| B8 | Checkout Paket (`checkout111`) | belum |
| B9 | Tagihan (`billing`) | belum |
| B10 | Invoice (`invoice111`) | belum |
| B11 | Otomasi WA (`waautomation`) | belum |
| B12 | 16 popup cermin: gs107, cat99, f61-print, hist115, photo115, wa131, wa138, rm138s, rs139, contacts178, guide135, api135, pay111, upgrade-pay-modal, g181-modal, td175 (satu popup per putaran) | belum |

### Jalur C: Isi halaman formulir & popup native ke Dart
±49 halaman formulir (Printer, Profil, Pegawai, Stok, CRM, Kurir, dst.) dan ±25 popup native: tampilannya sudah Flutter, tapi daftar isian (label, pilihan, nilai) masih dibaca dari HTML. Tulis daftar itu di Dart, satu kelompok halaman per putaran, bersamaan dengan bagian Jalur A yang terkait.

### Jalur D: Cabut HTML
| D1 | Uji penuh di HP nyata tanpa WebView (mode uji) | belum |
| D2 | Cabut WebView/HTML dari APK: HANYA setelah A, B, C selesai dan Koko setuju | belum |

Bagian besar dipecah kecil. **Satu putaran = satu baris tabel.**

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
- **Diskon & voucher hanya memotong harga layanan; ongkir tidak ikut didiskon** (keputusan Koko 4 Okt).
- **Estimasi selesai = waktu masuk + jam durasi yang dipilih.** Jam diambil dari Pengaturan Durasi, kunci `goyana-durations199`, contoh `{"Reguler":72,"Express":24,"Kilat":6}`. Kunci yang tidak ada berarti bawaan 72/24/6. HTML memakai `durHours199(nama)`, dan Dart wajib memakai sumber yang sama.
- Berat kiloan boleh desimal, pakai koma atau titik.
- Input berat: hanya angka dengan satu koma/titik (`2,5`, `1.5`, `,5`). Minus (`-2,5`) dan dua pemisah (`1,2,3`) DITOLAK dengan peringatan (keputusan Koko 4 Okt).

### Temuan salah hitung (menunggu keputusan Koko)
| No | Temuan | HTML sekarang | Usulan benar | Status |
|---|---|---|---|---|
| 1 | Diskon persen "Semua layanan" ikut memotong ongkir | Rp14.000 + ongkir Rp6.000, diskon 10% → potong Rp2.000 | Diskon hanya dari layanan → potong Rp1.400, ongkir tetap Rp6.000 | DISETUJUI Koko 4 Okt; HTML dibetulkan (diskon & voucher), fixture 3b diperbarui |
| 2 | Input berat `1,2,3` | diterima sebagai 1,2 | ditolak, minta isi ulang | DISETUJUI Koko 4 Okt; HTML sudah dibetulkan (toast "Angka tidak sah") |
| 3 | Input berat `-2,5` | minus dibuang jadi 2,5 | ditolak (berat tidak boleh minus) | DISETUJUI Koko 4 Okt; HTML sudah dibetulkan (toast "Berat tidak boleh minus") |

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
