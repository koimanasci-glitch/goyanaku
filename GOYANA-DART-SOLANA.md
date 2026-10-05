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
| A3b | Tambah Transaksi: diskon, ongkir | SELESAI, terpasang (sesi 1, d6601f8); ongkir tidak ikut didiskon |
| A3c | Tambah Transaksi: nomor pesanan, estimasi, simpan | SIAP, belum dipasang. Fixture save_orders.json diperbarui 4 Okt: details.due kini ikut jam durasi (dulu selalu +72 jam). Sesuaikan Dart lalu pasang |
| A4 | Rincian Pesanan: ganti status, edit, batal, riwayat | SELESAI, terpasang dengan pengaman (5 Okt, CI 37223205196) |
| A5 | Pembayaran: Tunai, QRIS, Transfer, DP, deposit, ralat | belum. PATOKAN SIAP untuk DP, pelunasan transfer, lunas QRIS (part=A5). Deposit & ralat: minta Claude tambah skenario |
| A6 | Status otomatis: Antrian→Proses 60 menit, Telat Ambil, pengingat | belum |
| A7 | Kas & Tutup Kasir | belum. PATOKAN SIAP: tutup kasir (part=A7), termasuk model layar Tutup Kasir & Beranda sebelum/sesudah |
| A8 | Laporan (±40) | belum |
| A9 | Pelanggan, CRM, poin, voucher | belum |
| A10 | Pengaturan (layanan/harga, parfum, durasi, diskon, outlet, pegawai, kurir, stok, printer, template WA) | belum |
| A11 | Sinkron ke server Laravel (setelah VPS ada) | belum |

### Jalur B: Halaman & popup "cermin" jadi widget Flutter asli (sesi tampilan)
Sekarang bentuknya dibaca dari HTML tersembunyi (`mirror_sheet.dart`). Harus ditulis ulang sebagai widget Flutter biasa dengan bentuk PERSIS sama (bandingkan golden sebelum/sesudah, piksel harus sama atau beda tak terlihat). Satu halaman per putaran.
| No | Halaman cermin | Status |
|---|---|---|
| B1 | Parfum (`perfume`) | SELESAI |
| B2 | Durasi (`duration`) | SELESAI |
| B3 | Pilih Layanan (`pickservice`) | SELESAI |
| B4 | Jemput (`pickup`) | SELESAI |
| B5 | Scan Pesanan (`orderscan`) | SELESAI |
| B6 | Status QR (`qrstatus`) | SELESAI |
| B7 | Harga Paket (`plan111`) | SELESAI |
| B8 | Checkout Paket (`checkout111`) | SELESAI — paritas 5 kondisi 390/320, 125 screenshot dan APK lulus; 2 CI awal + 1 tambahan berizin; pembelian produksi tetap diblokir |
| B9 | Tagihan (`billing`) | SELESAI — paritas 390/320, 129 screenshot dan APK lulus; 1/2 CI; menu produksi tetap menuju Riwayat Transaksi |
| B10 | Invoice (`invoice111`) | SELESAI (tampilan final kosong) — paritas 390/320, 133 screenshot dan APK lulus; 1/2 CI; invoice terisi/pembelian belum tersedia |
| WA-PAIR | Tambahan berizin: popup Hubungkan WhatsApp, pilihan Scan QR / Kode WhatsApp | SELESAI (tampilan) — 390/320, 137 screenshot dan APK lulus; 2/2 CI; QR/kode nyata menunggu API CHATKU (F5) |
| B11 | Otomasi WA (`waautomation`) → WhatsApp & Chatbot aktif | SELESAI jalur aktif sesuai pilihan Paduka — sudah NativeForm; 6 kondisi 390/320, 144 screenshot dan APK lulus; 2/2 CI. Halaman demo lama tetap tersembunyi; CHATKU menunggu F5 |
| B12 | 16 popup cermin: gs107, cat99, f61-print, hist115, photo115, wa131, wa138, rm138s, rs139, contacts178, guide135, api135, pay111, upgrade-pay-modal, g181-modal, td175 (satu popup per putaran) | 2/16 SELESAI. 14 popup sisa gabungan atas izin Paduka; CI3 37321200324 bridge/analyze/unit lulus; 226/228 screenshot lulus, dua tes key kurir gagal; APK tertahan. 2 CI awal + 1 tambahan berizin. |
| B12-2 | Kategori Baru (`cat99`) | SELESAI (tampilan) — 390/320, keyboard/scroll, 24 paritas gambar, 158 screenshot dan APK lulus; 1/2 CI |
| B12-3 | Pesanan Berhasil (`f61-print`) | SETENGAH JALAN (tampilan/tes lulus; APK bersama tertahan) — CI 37321200324; 2 CI awal + 1 tambahan berizin; lihat laporan CI3 |
| B12-4 | Riwayat Status (`hist115`) | SETENGAH JALAN (tampilan/tes lulus; APK bersama tertahan) — CI 37321200324; 2 CI awal + 1 tambahan berizin; lihat laporan CI3 |
| B12-5 | Foto Dokumentasi (`photo115`) | SETENGAH JALAN (tampilan/tes lulus; APK bersama tertahan) — CI 37321200324; 2 CI awal + 1 tambahan berizin; lihat laporan CI3 |
| B12-6 | Nota WhatsApp (`wa131`) | SETENGAH JALAN (tampilan/tes lulus; APK bersama tertahan) — CI 37321200324; 2 CI awal + 1 tambahan berizin; lihat laporan CI3 |
| B12-7 | Kabari Pelanggan (`wa138`) | SETENGAH JALAN (tampilan/tes lulus; APK bersama tertahan) — CI 37321200324; 2 CI awal + 1 tambahan berizin; lihat laporan CI3 |
| B12-8 | Cucian Belum Diambil (`rm138s`) | SETENGAH JALAN (tampilan/tes lulus; APK bersama tertahan) — CI 37321200324; 2 CI awal + 1 tambahan berizin; lihat laporan CI3 |
| B12-9 | Ralat Pembayaran (`rs139`) | SETENGAH JALAN (tampilan/tes lulus; APK bersama tertahan) — CI 37321200324; 2 CI awal + 1 tambahan berizin; lihat laporan CI3 |
| B12-10 | Pilih Kontak HP (`contacts178`) | SETENGAH JALAN (tampilan/tes lulus; APK bersama tertahan) — CI 37321200324; 2 CI awal + 1 tambahan berizin; lihat laporan CI3 |
| B12-11 | Panduan (`guide135`) | SETENGAH JALAN (tampilan/tes lulus; APK bersama tertahan) — CI 37321200324; 2 CI awal + 1 tambahan berizin; lihat laporan CI3 |
| B12-12 | API GOYANA (`api135`) | SETENGAH JALAN (tampilan/tes lulus; APK bersama tertahan) — CI 37321200324; 2 CI awal + 1 tambahan berizin; lihat laporan CI3 |
| B12-13 | Bayar Melalui (`pay111`) | SETENGAH JALAN (tampilan/tes lulus; APK bersama tertahan) — CI 37321200324; 2 CI awal + 1 tambahan berizin; lihat laporan CI3 |
| B12-14 | Pembayaran Upgrade Lama (`upgrade-pay-modal`) | SETENGAH JALAN (tampilan/tes lulus; APK bersama tertahan) — CI 37321200324; 2 CI awal + 1 tambahan berizin; lihat laporan CI3 |
| B12-15 | Formulir Stok dan Kurir (`g181-modal`) | MENTOK (widget dibuat; verifikasi gabungan belum lulus) — CI 37309074537; 2/2 gabungan; lihat laporan |
| B12-16 | Detail Administrator (`td175`) | MENTOK (widget dibuat; verifikasi gabungan belum lulus) — CI 37309074537; 2/2 gabungan; lihat laporan |

### Jalur C: Isi halaman formulir & popup native ke Dart
±49 halaman formulir (Printer, Profil, Pegawai, Stok, CRM, Kurir, dst.) dan ±25 popup native: tampilannya sudah Flutter, tapi daftar isian (label, pilihan, nilai) masih dibaca dari HTML. Tulis daftar itu di Dart, satu kelompok halaman per putaran, bersamaan dengan bagian Jalur A yang terkait.

### Jalur D: Cabut HTML
| D1 | Uji penuh di HP nyata tanpa WebView (mode uji) | belum |
| D2 | Cabut WebView/HTML dari APK: HANYA setelah A, B, C selesai dan Koko setuju | belum |

Bagian besar dipecah kecil. **Satu putaran = satu baris tabel.**

## 4b. Peta halaman: NATIVE atau CERMIN (cek ini sebelum mengubah tampilan apa pun)
| Jenis | Halaman | Bentuk diatur di | Cara mengubah tampilan |
|---|---|---|---|
| Native khusus | Beranda, Pesanan, Tambah Transaksi, Pelanggan, Laporan, Pengaturan, Kas, Tutup Kasir, Layanan, Rincian Pesanan | `mobile/lib/native/*_page.dart` | ubah widget Dart di file itu |
| Native formulir | ±49 halaman di `_formPages` (shell.dart): Printer, Profil, Pegawai, Stok, CRM, Kurir, dll. | `mobile/lib/native/form_page.dart` (isi dari HTML) | ubah `form_page.dart` (berlaku ke semua formulir) |
| CERMIN | perfume, duration, pickservice, pickup, orderscan, qrstatus, plan111 (Harga Paket), checkout111, billing, invoice111, waautomation + 16 popup di `MIRROR_SHEETS` (capacitor.js) | HTML/CSS tersembunyi, digambar `mirror_sheet.dart` | JANGAN ubah lewat CSS. Kalau perlu desain baru, tulis ulang jadi widget Flutter asli (Jalur B) sekaligus dengan desain barunya |

Catatan B11 (pilihan Paduka 5 Okt): jalur produksi `waautomation` dialihkan ke `whatsappbot` yang sudah memakai NativeForm. B11 mengunci halaman aktif; HTML cermin demo lama tetap tersembunyi dan belum dihapus. Definisi formulir masih berasal dari HTML sampai jalur C/D.

## 5. Langkah wajib untuk setiap bagian
**CARA CEPAT (keputusan Koko 4 Okt): TES BESAR, JANGAN BOLAK-BALIK.**
- Patokan HTML (fixture) disiapkan Claude lebih dulu untuk beberapa bagian sekaligus. Jangan menangkap sendiri.
- Tulis Dart untuk SATU BAGIAN UTUH (contoh seluruh A4), tanpa push/CI di tiap langkah kecil.
- Push dan jalankan CI SEKALI di akhir bagian. Kalau gagal, perbaiki semua yang gagal sekaligus, lalu CI sekali lagi.
- Maksimal 2 kali CI per bagian. Kalau masih gagal setelah 2 kali, lapor (mentok di mana, kenapa).
- Kode yang BELUM dipasang ke aplikasi boleh menumpuk dulu. Yang TIDAK boleh: memasang ke aplikasi (shell.dart) sebelum tes bagian itu lulus.

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
- **Pesanan belum bayar BOLEH diambil** (piutang). Tab Pesanan baru **"Belum Bayar"** (paling akhir, kunci `unpaid`) = semua pesanan belum lunas (Belum Bayar/DP) dari semua status kecuali batal. Sudah di HTML & `logic/orders.dart` (keputusan Koko 4 Okt).
- **Kurir bisa menerima pembayaran:** tugas kurir (selain penjemputan) yang belum lunas punya tombol **Bayar** → membuka Terima Pembayaran pesanan itu (keputusan Koko 4 Okt).
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
