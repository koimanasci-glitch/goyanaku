# GOYANA — Rencana Kerja Sampai Selesai (untuk GPT work)

Ditulis Claude, 5 Oktober 2026 dini hari. Kuota Claude habis dan baru reset **Kamis**. Sampai Kamis, GPT work mengerjakan semuanya sendiri mengikuti dokumen ini. Claude mengecek semua hasil hari Kamis.

Target akhir (keputusan Koko):
1. Aplikasi Android **100% Flutter + Dart**, tanpa HTML/WebView, **tampilan sama persis dengan sekarang** (sudah fix).
2. **Dashboard web owner** memakai aplikasi HTML yang sudah ada, dilayani Laravel.
3. **Backend + panel Administrator Laravel** (pusat).
4. **WhatsApp / chatbot / nota otomatis lewat CHATKU** (layanan terpisah, server terpisah).
5. **Online di VPS**.
6. **APK/AAB siap upload ke Google Play**.

---

## 0. ATURAN WAJIB (baca dulu, berlaku untuk semua fase)

1. **Satu bagian per putaran.** Satu putaran = satu baris tabel di dokumen ini. Selesai satu bagian → laporan → lanjut bagian berikutnya.
2. **Kerjakan hanya yang diminta.** Jangan memperbaiki/menyentuh bagian lain "sekalian". Kalau melihat masalah di luar bagian, CATAT di laporan saja.
3. **Tampilan tidak boleh berubah.** Setiap perubahan Flutter wajib dibandingkan dengan golden/cermin. Beda piksel = gagal.
4. **Hitungan harus benar, bukan sekadar meniru HTML.** Kalau HTML salah hitung, jangan ditiru diam-diam: catat di bagian "Pertanyaan untuk Koko" dan pakai perilaku HTML sampai Koko memutuskan.
5. **Keputusan Koko yang sudah ada (jangan diubah):**
   - Diskon tidak berlaku untuk ongkir.
   - Berat kiloan boleh desimal dengan koma atau titik; minus atau dua pemisah ditolak dengan peringatan.
   - Tab Pesanan "Belum Bayar"; pesanan belum bayar tetap boleh Diambil.
   - Saldo AI klien tidak pernah hangus.
   - Pesan WA otomatis ke pelanggan laundry seminimal mungkin (sambutan/panduan sekali saja, tidak harian).
   - Yang bisa dikerjakan program biasa dikerjakan program; AI hanya bila program tidak bisa (hemat biaya AI).
   - Engine WhatsApp TIDAK dipasang di VPS GOYANA. Semua WA lewat CHATKU di server terpisah.
6. **Tes besar, bukan bolak-balik.** Tulis satu bagian utuh, push + CI **sekali** di akhir. Gagal → perbaiki semua sekaligus → CI sekali lagi. **Maksimal 2 CI per bagian.** Masih gagal → laporkan mentok di mana, lalu lanjut ke bagian lain yang tidak bergantung.
   - **Jatah CI dibebaskan, izin Paduka 8 Okt 2026 17:06 WIB:** "Mulai sekarang CI aku kasih bebas jatah." Batas 2 CI per bagian dan penghitung jatah di bawah tidak berlaku lagi. Tetap: jangan boros (periksa dulu sebelum push), catat run id dan hasilnya.
   - **Pengecualian A7/branding/APK, izin Paduka 6 Okt 2026 08:36 WIB:** 3 jatah CI Flutter tambahan baru, mulai **0/3 terpakai, 3 tersisa**, terpisah dari 4 CI A7 sebelumnya. Setiap run/rerun mengurangi satu jatah, tidak direset antar sesi; tidak perlu izin ulang selama jatah masih ada. Hasil/sisa wajib dicatat, berhenti bila habis. Lihat GOYANA-CATATAN-PADUKA.md. **Counter terbaru sesudah CI5 lulus: 1/3 terpakai, 2 tersisa.**
7. **Branch:**
   - Aplikasi Flutter: `flutter/native`. Selalu `git pull --rebase` sebelum mulai dan sebelum push.
   - Backend/dashboard/admin: `backend/laravel-foundation` (atau branch `backend/<bagian>` dari situ).
   - **JANGAN push ke `main`.** Penggabungan ke `main` hanya setelah dicek Claude/Koko.
   - Kalau penggabungan `shell.dart` macet: push ke branch `flutter/<bagian>` saja dan tulis di laporan. Claude yang menggabungkan Kamis.
8. **Rahasia tidak masuk repo/APK:** password, API key, keystore, `.env` produksi. Pakai `.env.example` berisi nama variabel saja.
9. **Berhenti dan tanya Koko** untuk hal yang tidak bisa dibatalkan atau butuh uang/akun: beli VPS/domain, akun Google Play, payment gateway, menghapus data, mengubah tampilan. Lihat bagian 9.
10. **Laporan wajib setiap bagian** di `GOYANA-PROGRESS.md` (commit terpisah, judul `[GPT] <kode bagian> <nama>`):
    - Status: SELESAI / SETENGAH JALAN / MENTOK
    - File yang berubah
    - Hasil CI: run id, bridge, analyze, unit, paritas, screenshot, APK
    - Commit
    - Jatah CI terpakai
    - Temuan / pertanyaan untuk Koko
    - Lalu ubah status bagian itu di tabel dokumen ini.

11. **Backend VPS dan Mode Murni selalu dikerjakan berpasangan** (permintaan Koko 8 Okt 2026, "catat"). Setiap perubahan aturan, data, atau fitur dikerjakan di dua sisi sekaligus: `backend/` (Laravel) dan `mobile/lib/pure/` (Mode Murni). Sebelum laporan, periksa dua arah: (a) data baru yang disimpan aplikasi sudah ikut sinkron ke server (`server_sync.dart` + `config/goyana.php` → `sync.collections`), dan (b) aturan baru di server sudah dikenal aplikasi. Yang sengaja belum dipasangkan wajib ditulis di laporan sebagai "belum berpasangan". HTML/Hibrida tidak ikut dikembangkan (SISTEM-PUSAT §50).

### Pelajaran dari A4 (jangan diulang)
- Label tombol/teks **harus diambil persis dari fixture**, jangan dikarang ("WhatsApp" padahal HTML "Kirim nota WA"; "Siap" padahal "Siap Ambil").
- Tipe data harus sama dengan HTML: jumlah tab adalah **teks** `'1'`, bukan angka `1`.
- Cek semua kasus fixture satu per satu sebelum push, bukan hanya kasus pertama. Flutter SDK tidak ada di cloud: bandingkan fixture dengan kode secara teliti (script Python kecil boleh) sebelum memakai jatah CI.
- Widget baru wajib punya nilai cadangan dan tidak boleh crash kalau model kosong (pola `duration_page.dart`, `pickup_page.dart`).

---

## FASE 1 — Aplikasi Android 100% Flutter

Acuan teknis: `GOYANA-DART-SOLANA.md` (bagian 4, 4b, 5). Jalur A dan B boleh dikerjakan dua sesi bersamaan. C setelah A dan B. D paling akhir.

### Jalur A — Hitungan ke Dart
| No | Bagian | Status |
|---|---|---|
| A1–A4 | Beranda, Pesanan, Tambah Transaksi, Rincian Pesanan | SELESAI |
| A3c | Nomor pesanan, estimasi, simpan | SELESAI tahap paritas + pengaman; terpasang sejak 4 Okt (0eafeb6, review Claude). Nomor/estimasi/snapshot Dart 12/12 diverifikasi ulang 6 Okt; penulisan SQLite masih HTML selama migrasi. |
| A5 | Pembayaran: Tunai, QRIS, Transfer, DP, deposit, ralat | SELESAI tahap paritas + pengaman — pembayaran/deposit/ralat; CI keempat berizin 37358031335 SUCCESS: bridge 58, analyze bersih, unit 173, screenshot 228, APK terbit. SQLite masih ditulis HTML; batas cakupan dan dua capture HTML Tutup Kasir tercatat di laporan A5 CI4 6 Okt. |
| A6 | Status otomatis: Antrian→Proses 60 menit, Telat Ambil, pengingat | SELESAI tahap paritas + pengaman — keputusan status/pengingat Dart; CI 37387857402 SUCCESS: bridge 59, analyze bersih, unit 189, screenshot 228 dan APK terbit. HTML tetap menjalankan timer/menulis data sampai D2; lihat laporan A6 6 Okt. |
| A7 | Kas & Tutup Kasir | SELESAI tahap paritas + koreksi disetujui — Deposit, pengeluaran Non-Tunai dan omzet harian WIB terverifikasi; logo/ikon/animasi terpasang. CI5 37400232867 SUCCESS: bridge 69, analyze bersih, unit 224, screenshot 228, APK build 312 terbit. Jatah baru 1/3 terpakai, 2 tersisa. HTML masih writer sampai D2; lihat laporan CI5 6 Okt. |
| A8 | Laporan (±40 laporan) — pecah per kelompok laporan, satu kelompok per putaran | belum |
| A9 | Pelanggan, CRM, poin, voucher | belum |
| A10 | Pengaturan (layanan/harga, parfum, durasi, diskon, outlet, pegawai, kurir, stok, printer, template WA) | belum |
| A11 | Sinkron ke server Laravel | setelah Fase 2 bagian F2-4 selesai |

Pola pemasangan sama dengan A3/A4: Dart hitung dulu → sama dengan HTML → layar pakai Dart; beda → tetap HTML dan catat di `goyana-parity-log`. HTML tetap yang menyimpan data sampai Jalur D.

### Jalur B — Halaman cermin jadi widget Flutter asli
| No | Halaman | Status |
|---|---|---|
| B1–B4, B7 | Parfum, Durasi, Pilih Layanan, Jemput, Harga Paket | SELESAI |
| B5 | Scan Pesanan (`orderscan`) — **jangan ubah bagian kamera `mobile_scanner`**, hanya tampilan | SELESAI |
| B6 | Status QR (`qrstatus`) | SELESAI — paritas 390/320 dan golden lulus; 1 CI tambahan diizinkan Koko |
| QR-1 | Tambahan berizin: tombol QR di Rincian Pesanan + desain web status pelanggan | SELESAI (tampilan) — CI tambahan berizin lulus; backend status publik belum tersambung |
| B8 | Checkout Paket (`checkout111`) | SELESAI — paritas 5 kondisi 390/320, 125 screenshot dan APK lulus; 2 CI awal + 1 tambahan berizin; pembelian produksi tetap diblokir |
| B9 | Tagihan (`billing`) | SELESAI — paritas 390/320, 129 screenshot dan APK lulus; 1/2 CI; menu produksi tetap menuju Riwayat Transaksi |
| B10 | Invoice (`invoice111`) | SELESAI (tampilan final kosong) — paritas 390/320, 133 screenshot dan APK lulus; 1/2 CI; invoice terisi/pembelian belum tersedia |
| WA-PAIR | Tambahan berizin: popup Hubungkan WhatsApp, pilihan Scan QR / Kode WhatsApp | SELESAI (tampilan) — 390/320, 137 screenshot dan APK lulus; 2/2 CI; QR/kode nyata menunggu API CHATKU (F5) |
| B11 | Otomasi WA (`waautomation`) → WhatsApp & Chatbot aktif | SELESAI jalur aktif sesuai pilihan Paduka — sudah NativeForm; 6 kondisi 390/320, 144 screenshot dan APK lulus; 2/2 CI. Halaman demo lama tetap tersembunyi; CHATKU menunggu F5 |
| B12 | 16 popup cermin (satu popup per putaran): gs107, cat99, f61-print, hist115, photo115, wa131, wa138, rm138s, rs139, contacts178, guide135, api135, pay111, upgrade-pay-modal, g181-modal, td175 | 16/16 SELESAI. 14 popup sisa gabungan atas izin Paduka; CI4 37341886006: lulus; bridge 53, analyze bersih, unit 123, screenshot 228, 336 paritas gambar dan APK baru. 2 CI awal + 2 tambahan berizin. |
| B12-2 | Kategori Baru (`cat99`) | SELESAI (tampilan) — 390/320, keyboard/scroll, 24 paritas gambar, 158 screenshot dan APK lulus; 1/2 CI |
| B12-3 | Pesanan Berhasil (`f61-print`) | SELESAI (tampilan) — CI 37341886006; 4 CI gabungan berizin; lihat laporan CI4 |
| B12-4 | Riwayat Status (`hist115`) | SELESAI (tampilan) — CI 37341886006; 4 CI gabungan berizin; lihat laporan CI4 |
| B12-5 | Foto Dokumentasi (`photo115`) | SELESAI (tampilan) — CI 37341886006; 4 CI gabungan berizin; lihat laporan CI4 |
| B12-6 | Nota WhatsApp (`wa131`) | SELESAI (tampilan) — CI 37341886006; 4 CI gabungan berizin; lihat laporan CI4 |
| B12-7 | Kabari Pelanggan (`wa138`) | SELESAI (tampilan) — CI 37341886006; 4 CI gabungan berizin; lihat laporan CI4 |
| B12-8 | Cucian Belum Diambil (`rm138s`) | SELESAI (tampilan) — CI 37341886006; 4 CI gabungan berizin; lihat laporan CI4 |
| B12-9 | Ralat Pembayaran (`rs139`) | SELESAI (tampilan) — CI 37341886006; 4 CI gabungan berizin; lihat laporan CI4 |
| B12-10 | Pilih Kontak HP (`contacts178`) | SELESAI (tampilan) — CI 37341886006; 4 CI gabungan berizin; lihat laporan CI4 |
| B12-11 | Panduan (`guide135`) | SELESAI (tampilan) — CI 37341886006; 4 CI gabungan berizin; lihat laporan CI4 |
| B12-12 | API GOYANA (`api135`) | SELESAI (tampilan) — CI 37341886006; 4 CI gabungan berizin; lihat laporan CI4 |
| B12-13 | Bayar Melalui (`pay111`) | SELESAI (tampilan) — CI 37341886006; 4 CI gabungan berizin; lihat laporan CI4 |
| B12-14 | Pembayaran Upgrade Lama (`upgrade-pay-modal`) | SELESAI (tampilan) — CI 37341886006; 4 CI gabungan berizin; lihat laporan CI4 |
| B12-15 | Formulir Stok dan Kurir (`g181-modal`) | SELESAI (tampilan) — CI 37341886006; 4 CI gabungan berizin; lihat laporan CI4 |
| B12-16 | Detail Administrator (`td175`) | SELESAI (tampilan) — CI 37341886006; 4 CI gabungan berizin; lihat laporan CI4 |

Pola: lihat B2/B3/B4. File `mobile/lib/native/<halaman>_page.dart`, sambungan di `shell.dart` saja, golden `screens/<halaman>_native.png` dikunci (`autoUpdateGoldenFiles = false` saat membandingkan).

### Jalur C — Isi formulir & popup native ditulis di Dart
±49 halaman formulir dan ±25 popup: tampilannya sudah Flutter, tetapi label/pilihan/nilai masih dibaca dari HTML. Tulis daftar itu di Dart, **satu kelompok halaman per putaran** (contoh: C1 Printer+Profil, C2 Pegawai+PIN, C3 Stok, C4 CRM, C5 Kurir, dst.). Buat tabel kelompoknya sendiri di sini sebelum mulai C1.

### Jalur D — Cabut HTML
| No | Bagian | Status |
|---|---|---|
| D1 | Mode uji: aplikasi jalan penuh tanpa WebView (bendera uji), semua alur utama dicoba | belum |
| D2 | Data disimpan oleh Dart (bukan HTML). Migrasi data lama dari localStorage HTML ke penyimpanan Dart **tanpa kehilangan satu data pun**, dengan tes migrasi | belum |
| D3 | Cabut WebView/HTML dari APK | **HANYA setelah A, B, C, D1, D2 selesai dan Koko setuju** |

---

## FASE 2 — Backend Laravel + panel Administrator

Acuan: `GOYANA-SISTEM-PUSAT.md` (terutama bagian 2–10, 12, 17, 19, 22–29), `GOYANA-ROADMAP.md`, `backend/README.md`. Laravel 13 / PHP 8.3. Sudah ada: daftar owner+usaha+outlet, login web, dashboard owner terbatas, admin daftar usaha + paket beta + audit, slot perangkat.

| No | Bagian | Status |
|---|---|---|
| F2-1 | Akun: verifikasi email, reset password, MFA admin, undangan staf + hak akses per outlet (kasir, kurir, supervisor, owner) | akun staf + hak akses per outlet + login PIN: SELESAI 8 Okt (branch `backend/tim-outlet-kurir`, SISTEM-PUSAT §49); sisanya lihat §39 |
| F2-2 | API Android: login token, pairing/binding perangkat (maks 2 kasir per outlet), cabut perangkat | SELESAI 8 Okt — batas HP kini per paket (2/3/4/5), HP outlet bergantian, cabut perangkat (§49) |
| F2-3 | API data operasional: pelanggan, layanan/harga, pesanan, pembayaran, kas, stok, kurir — semua dipisah per usaha/outlet (tes lintas tenant wajib) | sebagian 8 Okt — aturan pesanan per peran, kurir, tahapan, setoran, monitoring di atas sinkronisasi yang ada (§49) |
| F2-4 | Protokol sinkron offline-first: ID unik dari HP, anti-duplikat (idempotency), kirim bertahap/incremental, penanganan konflik, status sinkron (lihat SISTEM-PUSAT bagian 27–29) | belum |
| F2-5 | Panel Administrator: daftar usaha, paket manual/beta, perangkat, audit, saldo AI (tidak hangus), anggaran AI pusat, CS/bantuan, FAQ | sebagian ada, lengkapi |
| F2-6 | Paket berakhir → mode baca saja; retensi data (SISTEM-PUSAT bagian 23–24) | sebagian ada, cek |
| F2-7 | Backup database otomatis + cara pulihkan (diuji) | belum |
| F2-8 | Monitoring ringan + jadwal maintenance (SISTEM-PUSAT bagian 26) | belum |
| F2-9 | Pembayaran paket (Google Play Billing untuk Android + satu gateway web): **siapkan kode dan mode sandbox saja**, kunci live dari Koko | belum — butuh akun (bagian 9) |

Setiap bagian: tes fitur PHPUnit di `backend.yml` harus lulus. Tidak ada password bawaan, tidak ada kunci di repo.

---

## FASE 3 — Dashboard web owner

| No | Bagian | Status |
|---|---|---|
| F3-1 | Laravel melayani aplikasi HTML yang sudah ada sebagai dashboard owner (login Laravel → buka app web). Tampilan HTML **tidak diubah** | belum |
| F3-2 | Dashboard web membaca/menulis lewat API yang sama dengan Android (F2-3), bukan localStorage sendiri | belum |
| F3-3 | Pembatasan: owner hanya melihat usahanya sendiri; kasir/kurir tidak bisa membuka dashboard owner | belum |

---

## FASE 4 — Hubungkan Android ke server

| No | Bagian | Status |
|---|---|---|
| F4-1 | Login Android ke Laravel + binding perangkat (F2-2) | belum |
| F4-2 | A11: sinkron otomatis Dart ↔ server memakai protokol F2-4. Transaksi offline wajib tersimpan di HP dan terkirim saat online | belum |
| F4-3 | Tanda offline terlihat, peringatan data belum tersinkron, pengingat tidak mengganggu (SISTEM-PUSAT 28–29) | belum |
| F4-4 | Uji: dua HP satu outlet, mati internet, transaksi, nyala lagi → data sama di kedua HP dan dashboard web | belum |

---

## FASE 5 — WhatsApp & chatbot lewat CHATKU

CHATKU adalah layanan WA milik Koko di **server terpisah** (engine Node/Baileys + aplikasi Laravel). Kode CHATKU **tidak ada di repo ini**. GOYANA hanya memanggil API CHATKU. GOYANA adalah klien besar khusus CHATKU (tagihan terpisah, dukungan prioritas).

| No | Bagian | Status |
|---|---|---|
| F5-1 | **Berhenti dan minta ke Koko:** dokumentasi API CHATKU (URL, cara auth, kirim pesan teks/gambar, webhook pesan masuk, status perangkat/nomor). Jangan menebak bentuk API | belum |
| F5-2 | Adapter `ChatkuClient` di Laravel: URL dan API key dari `.env` (`CHATKU_BASE_URL`, `CHATKU_API_KEY`). Antrian (queue) + retry + idempotency. Tes memakai server palsu (fake), bukan CHATKU sungguhan | belum |
| F5-3 | Nota otomatis: kirim nota/link nota web saat pesanan dibuat/selesai — sesuai hak paket (mulai Gold). Kalau CHATKU mati, aplikasi tetap jalan dan tombol WA manual tetap ada | belum |
| F5-4 | Webhook pesan masuk dari CHATKU → balasan cepat/trigger (program biasa dulu) → chatbot AI hanya kalau trigger tidak cocok. Status pesanan hanya untuk nomor pelanggan yang cocok di outlet itu | belum |
| F5-5 | Potong saldo AI per balasan AI (saldo tidak hangus), batas anggaran, catatan pemakaian | belum |
| F5-6 | WA Blast (Platinum): opt-out, batas frekuensi, riwayat status kirim. Tidak boleh mencatat "terkirim" palsu | belum |
| F5-7 | Halaman pengaturan WA/chatbot di aplikasi (yang sekarang localStorage) disimpan di server per outlet | belum |

---

## FASE 6 — Upload ke VPS

Acuan: `deploy/README.md`, `deploy/nginx-goyana.conf`, `deploy/update.sh`. Keputusan Koko: **VPS**, bukan Jagoan Hosting. VPS **belum dibeli**.

| No | Bagian | Status |
|---|---|---|
| F6-1 | Lengkapi `deploy/README.md` jadi panduan langkah demi langkah untuk Koko (orang awam): beli VPS Ubuntu 24.04 (2 GB RAM / 40 GB SSD cukup untuk awal), arahkan domain, login SSH, satu perintah pasang | belum |
| F6-2 | Script `deploy/install.sh` sekali jalan: Nginx, PHP 8.3-FPM, MySQL/MariaDB, Composer, Redis, Supervisor (queue worker), cron scheduler, firewall (ufw), HTTPS Let's Encrypt, user non-root. Aman dijalankan ulang | belum |
| F6-3 | `.env.example` produksi lengkap (APP_ENV=production, APP_DEBUG=false, HTTPS, SESSION_SECURE_COOKIE=true, DB, mail, CHATKU, AI) — isi nilai asli dilakukan Koko di server, bukan di repo | belum |
| F6-4 | `deploy/update.sh`: tarik versi terbaru, composer, migrate, cache, restart worker, tanpa mematikan situs lama kalau gagal | sebagian ada, cek |
| F6-5 | Backup harian database + file ke lokasi terpisah, dan cara pulihkan (diuji di VPS uji) | belum |
| F6-6 | Daftar cek setelah online: login, daftar, admin, API Android, HTTPS, backup jalan | belum |

GPT **tidak** membeli VPS/domain dan **tidak** memegang password server. GPT menyiapkan script + panduan; Koko yang menjalankan.

---

## FASE 7 — Upload Android ke Google Play

| No | Bagian | Status |
|---|---|---|
| F7-1 | Build release **AAB** di CI dengan keystore dari GitHub Secrets (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `ANDROID_STORE_PASSWORD`). Keystore **tidak** masuk repo | belum |
| F7-2 | Panduan Koko membuat keystore (sekali seumur aplikasi, simpan cadangan di 2 tempat — kalau hilang aplikasi tidak bisa diperbarui) dan memasukkannya ke GitHub Secrets | belum |
| F7-3 | applicationId final, nama aplikasi, ikon, versionCode/versionName otomatis naik | belum |
| F7-4 | Kebijakan privasi + syarat layanan (halaman web di Laravel), alur hapus akun (wajib Google Play) | belum |
| F7-5 | Panduan langkah demi langkah Play Console: buat aplikasi, isi Data Safety, rating konten, upload AAB ke **Internal testing** dulu, tambahkan penguji, lalu Closed testing → Production | belum |
| F7-6 | Google Play Billing (F2-9) diuji di Internal testing | belum |

---

## 8. Urutan kerja yang disarankan

1. Sesi tampilan: B5 → B6 → B8 → B9 → B10 → B11 → B12 (popup satu per satu).
2. Sesi Dart (bersamaan): A3c terverifikasi → A5 → A6 → A7 → A8 → A9 → A10.
3. Sesi backend (bersamaan, branch backend): F2-1 → F2-2 → F2-3 → F2-4 → F2-5..F2-8 → F3 → F6-1..F6-3.
4. Setelah A, B selesai: Jalur C.
5. Setelah F2-4 dan VPS ada: F4 (A11).
6. Setelah API CHATKU diberikan Koko: F5.
7. Terakhir: D1 → D2 → (Koko setuju) D3 → F7.

Kalau satu bagian mentok, tulis laporan MENTOK lalu pindah ke bagian lain yang tidak bergantung. Jangan berhenti total.

---

## 9. Hal yang HANYA bisa dilakukan Koko (GPT berhenti dan bertanya)

- Beli VPS dan domain, beri akses server.
- Dokumentasi API + kunci CHATKU.
- Akun Google Play Console (biaya pendaftaran) dan verifikasi.
- Akun payment gateway web (Midtrans dll.) + kunci sandbox/live.
- Penyedia AI + API key + anggaran.
- Email pengirim (SMTP) dan Google sign-in.
- Keystore Android (dibuat Koko, disimpan Koko).
- Persetujuan mencabut HTML (D3).
- Setiap perubahan tampilan atau aturan bisnis baru.

---

## 10. Temuan terbuka (tanyakan ke Koko, belum diubah)

- B4 Jemput: label dan nilai di kotak hasil menyatu ("LayananReguler · 4 Kg") karena CSS HTML. Diikuti persis. Tanya Koko apakah mau dipisah sebagai perubahan tampilan terpisah.
- Durasi di HTML tidak tersimpan setelah aplikasi dibuka ulang (lihat laporan 3a). Perlu keputusan sebelum A10.
- B1 Parfum: deviasi piksel kecil (1–8 px) belum 100% identik.

---

## 11. Untuk Claude hari Kamis

Claude akan membaca `GOYANA-PROGRESS.md` dari atas laporan terakhir Claude (5 Okt 01.25 WIB), mengecek setiap bagian, menggabungkan branch yang tertunda, dan memperbaiki yang salah. Jadi **laporan harus jujur**: tulis yang belum diuji sebagai belum diuji.
