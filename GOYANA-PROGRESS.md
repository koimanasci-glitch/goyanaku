# Status pembangunan — 2 Oktober 2026

Branch: backend/laravel-foundation. Review: https://github.com/rajabadutiklan-lab/Goyana/pull/1
Perubahan belum digabung ke main atau dideploy ke VPS.

## Hasil yang sudah ditulis dan diuji
- Backend Laravel: registrasi owner/usaha/outlet + trial Basic dua bulan; auth sesi, hash password, CSRF dan rate limit.
- Pemisahan owner/platform admin; admin dibuat lewat terminal, tanpa password bawaan.
- Daftar usaha dan grant paket beta bertanggal WIB, pencabutan, audit, expiry/read-only.
- Maksimal dua slot kasir/outlet, pencabutan, audit dan pemeriksaan kepemilikan. Slot belum menjadi pairing Android.
- API Sanctum read-only untuk owner: login, profil/paket/outlet dan logout; token 24 jam, admin platform ditolak.
- Dashboard admin responsif dan metadata PWA tanpa cache data privat. Instalasi fisik/HTTPS belum diuji.
- CI backend lulus 16 tes / 97 assertions, lint PHP, route list dan kompilasi Blade. Mesin uji SQLite; PostgreSQL/MySQL produksi serta konkurensi belum diuji.
- Composer lock diambil dari hasil CI dan disimpan untuk resolusi dependency yang sama.

## Flutter sedang divalidasi
- Widget native login dan dashboard akun/paket/outlet, tema coral/putih/abu.
- HTTP API HTTPS; token hanya di memori. Form tidak mengklaim login sukses tanpa respons backend.
- Flutter analyze lulus, tujuh tes lulus termasuk layout pada 320/600/800/1280 piksel. Build APK pertama gagal karena konflik manifest debug/main untuk cleartext; override debug diperbaiki dan build ulang diperlukan. Belum ada APK Flutter berhasil dibangun.
- Aplikasi lama tidak dimigrasikan penuh; transaksi/offline/role/printer/kamera belum tersedia.

## Lanjutan yang belum selesai
1. Verifikasi/reset email, Google login, MFA admin dan role/undangan pegawai.
2. API transaksi/keuangan/stok/kurir + protokol offline/sinkronisasi, batas perangkat nyata.
3. Semua halaman operasional Flutter dan pengujian HP/printer/kamera.
4. Billing/top-up/ledger, WhatsApp/webhook/jadwal, AI profiles/budget.
5. Monitoring eksternal, backup/restore, retention/purge, CS/remote/CRM/Play reviews.

Domain, VPS, layanan email, produk Play, merchant gateway, WA dan API key produksi belum dikonfigurasi. Jangan menandai integrasi itu aktif atau seluruh roadmap selesai. Jangan menghapus data/pembelian/deploy produksi dalam kelanjutan rutin ini.

## Flutter hybrid — Claude, 2 Oktober 2026 (branch flutter/hybrid)
- Pendekatan disetujui pengguna: **Hybrid**. Flutter memuat HTML final (index.html + goyana-v*.js) tanpa perubahan; fitur HP lewat jembatan Flutter/Kotlin (mobile/web_bridge/capacitor.js → lib/hybrid/bridge.dart → MainActivity.kt).
- Ditambah dibanding Capacitor: simpan file/CSV/struk, bagikan gambar struk, cetak/PDF invoice, clipboard, dialog native, tombol kembali HP, ukuran huruf terkunci.
- goyana-v196-small-screen.js: perbaikan luapan di HP 320px (Penambahan/Pengurangan Kas, Tutup Kasir, Ralat). Audit 58 halaman di 320/360/412/768/1280px: tanpa luapan.
- CI "Flutter Android (hybrid)": uji jembatan di browser, flutter analyze/test, APK release → GitHub Release `flutter-uji` (prerelease). Kunci tanda tangan preview publik, bukan untuk Play Store.
- Koordinasi: Claude memegang mobile/ (Flutter). Jika GPT mengubah index.html/goyana-v*.js, APK Flutter otomatis ikut. Layar native Laravel (lib/app.dart) dibiarkan utuh.
- Belum: uji di HP fisik (printer, kamera, GPS), SQLite/outbox sync, halaman native Flutter tahap 2.

## Backend akses & paket — Claude, 2 Oktober 2026 (branch backend/akses-paket, di atas flutter/hybrid)
- Keputusan pengguna: trial habis → **baca saja**; Basic = 1 pusat + 1 cabang.
- Ditambah: langganan berbayar (catat manual oleh admin), batas cabang per paket, akun tim + role/permission, nonaktif/reset password, OTP admin pusat, verifikasi email (opsional sampai SMTP siap). Rincian: GOYANA-SISTEM-PUSAT.md §39.
- Celah arsitektur dicatat di §38: data HTML masih di localStorage; perlu lapisan sync + API transaksi sebelum launching.
- Tes backend: 30 tes / 188 assertion lulus (SQLite). Belum di-deploy.

## Sinkronisasi HP ↔ server — Claude, 2 Oktober 2026 (branch backend/akses-paket)
- API `GET /api/sync/pull`, `POST /api/sync/push` + modul `goyana-sync-core.js` (head) & `goyana-v197-sync.js`. Rincian: GOYANA-SISTEM-PUSAT.md §40.
- Uji: 42 PHPUnit, `tests/sync-e2e.cjs` (3 HP + server), semua tes browser lama tetap lulus.
- Untuk mengaktifkan di APK: isi variabel GitHub `GOYANA_API_URL` setelah server dideploy.

## Flutter native bertahap — Claude, 2 Oktober 2026 (branch flutter/native)
- SQLite di HP menggantikan localStorage WebView (data lama dipindah otomatis).
- Beranda digambar native Flutter (lib/native/home_page.dart), identik dengan HTML; logika & aksi masih dari HTML (aman, fallback otomatis). Font Poppins ditanam di APK.
- Urutan berikutnya: Pesanan → Tambah Transaksi/Pembayaran → Pelanggan → Laporan/Kas → sisanya.

## Panel administrator & otomasi — Claude, 3 Oktober 2026 (branch flutter/native)
Diuji: PHPUnit 56 tes lulus, dicek tampilannya di 360 px dan 1200 px. CI backend sekarang juga jalan di branch flutter/**.
- **/admin (Usaha)**:
  - Ringkasan: total, berbayar, beta, trial, baca saja, daftar 7 hari, pemasukan bulan ini, HP tersambung, konflik.
  - Daftar yang berakhir dalam 7 hari.
  - Cari (nama/email/ID) dan filter status.
- **Detail usaha**:
  - Tim, outlet & HP kasir (admin bisa **cabut HP hilang** dengan alasan, tercatat di audit), statistik sinkron & konflik.
  - Saldo AI + top-up manual, pesan otomatis terkirim, aktivitas terakhir.
- **Tiket CS** (`/support` untuk klien, `/admin/tickets` untuk admin):
  - Balasan, catatan internal, prioritas, status. Tiket privat per usaha (staf hanya melihat tiket miliknya).
- **Pengaturan platform** (`/admin/settings`):
  - Untung AI %, minimal top-up, cadangan kurs, batas biaya AI CS/hari.
  - Model AI utama/cadangan, nomor WA CS, menit bot diam, on/off pesan otomatis. Ada riwayat perubahan.
- **Audit** (`/admin/audit`): filter jenis, usaha, hanya admin.
- **Kesehatan sistem** (`/admin/system`): database, migrasi, debug, HTTPS, mailer, OTP, disk, storage, sinkron, penjadwal.
- **Otomatis** (butuh cron `* * * * * php artisan schedule:run`):

  | Perintah | Jadwal | Fungsi |
  |---|---|---|
  | `goyana:health` | tiap 5 menit | Email admin saat ada gangguan baru atau sudah pulih (tidak spam) |
  | `goyana:prune` | harian | Bersihkan data teknis lama |
  | `goyana:weekly-report` | Senin 07.00 | Laporan mingguan |
  | `goyana:fx-update` | 2x sehari | Kurs USD→IDR. Kalau gagal pakai kurs terakhir; di hari yang sama dipakai yang lebih tinggi |
  | `goyana:ai-prices` | harian | Harga model OpenRouter; email admin bila model dipakai naik harga atau hilang |
  | `goyana:lifecycle` | tiap jam 08–20 WIB | Pesan hemat sekali saja: selamat datang, H-3 paket habis, baca saja, bukti bayar/top-up (sekarang email; WA setelah CHATKU) |

- **Saldo AI** (`App\Support\AiBilling`):
  - Saldo dalam Rupiah. Potongan = biaya USD × kurs × (1 + cadangan) × (1 + untung), dibulatkan ke atas.
  - Idempoten per request, tidak bisa minus. `canAfford()` dipakai sebelum memanggil AI.
- **Belum**:
  - Pemanggilan AI sungguhan (CS/Chatbot) dan WA lewat CHATKU.
  - Gateway pembayaran (top-up/paket masih dicatat manual).
  - FAQ otomatis, remote bantuan (§46), balas ulasan Play (§42C).

## Lanjutan 3 Oktober (Claude, branch flutter/native)
- **Lupa password**: reset lewat email (link 60 menit, semua sesi HP ikut keluar, admin pusat hanya lewat terminal). Tombol "Lupa password?" di aplikasi membuka halaman server.
- **FAQ otomatis** (`/admin/faqs`): tiket baru dicocokkan dengan kata kunci, dijawab tanpa AI, dan pertanyaan soal paket dilengkapi status akun. Ada 5 FAQ awal.
- **Deploy**: lihat `deploy/README.md` (VPS & cPanel/Jagoan), `deploy/nginx-goyana.conf`, `deploy/update.sh`.
  - `deploy/build-web-app.sh` membangun **aplikasi web owner** di `/app/` (HTML yang sama, tersinkron).
  - Dashboard owner punya tombol "Buka aplikasi GOYANA (web)".
- **Flutter native Tambah Transaksi** langkah 1–2 (`mobile/lib/native/addorder_page.dart`).
  - Sheet HTML (durasi, jumlah, opsi, pembayaran) otomatis menutupi halaman native.
  - Toast HTML kini tampil native.
  - Nama pelanggan di bar layanan diperbesar (di HTML hanya 10px/8px).
- **Perbaikan HTML v198** (`goyana-v198-flow-fixes.js`): kolom "Cari nama / no handphone" di langkah 1 sebelumnya tidak menyaring daftar pelanggan.
- **Flutter native** (Claude, 3 Okt) juga: **Pelanggan**, **Laporan**, **Pengaturan**. Keempat tab bawah (Beranda, Pesanan, Laporan, Pengaturan) sekarang native.
  - Semua aksi tetap memanggil elemen HTML yang sama.
  - Lihat screenshot di branch `ci-screens`.
- **Kas Masuk & Pengeluaran native** (`cash_page.dart`).
  - v198: saldo kas di atas formulir langsung diperbarui setelah simpan. Sebelumnya baru berubah setelah halaman dibuka ulang.
- Tes jembatan (`tests/flutter-bridge.cjs`) mencakup semua halaman native: data, aksi, serah-terima ke sheet HTML, dan toast.
- **Balasan Cepat pintar (§47)**: mesin jawaban tanpa AI dari data sinkron + simulator di admin. Menunggu CHATKU untuk dipasang ke WhatsApp.
- **Mode Bantuan (§46)** bagian server: owner mengizinkan 30 menit, admin mengubah harga/profil outlet lewat data sinkron, ada audit + batalkan.

## [GPT] Tutup Kasir native — 3 Oktober 2026 (branch flutter/native-kasir, commit lihat riwayat bagian ini)
- Dikerjakan: layar #cashclose native, ringkasan per metode, modal awal, pecahan uang +/−/isian, uang fisik, rekonsiliasi QRIS/transfer, setor, catatan dan riwayat. Setiap aksi memakai __goyanaTap / __goyanaSearch; semua angka tetap dibaca dari HTML.
- File utama: mobile/lib/native/cashclose_page.dart, mobile/lib/hybrid/shell.dart, mobile/web_bridge/capacitor.js, tests/flutter-bridge.cjs, mobile/test/screens_test.dart, mobile/test/fixtures/cashclose.json.
- Tes dijalankan & hasil: flutter analyze tanpa temuan; 11 tes Flutter lulus; 19 tes screenshot lulus (termasuk Tutup Kasir 320/390, atas/bawah); flutter-bridge lulus termasuk selisih Rp10.000, sisa modal Rp110.000, validasi catatan dan riwayat; 4 tes Python lulus. Regresi npm dan CI sedang berjalan, hasil dicatat setelah selesai.
- Belum diuji / ragu: belum dicoba di HP fisik; kirim WhatsApp ke owner sungguhan belum diuji; PHP/backend tidak tersedia di mesin lokal dan diperiksa melalui CI.
- Keputusan yang diambil sendiri (perlu dicek Claude/pengguna): konfirmasi penutupan dan ringkasan setelah tutup tetap sheet HTML. Tombol bawah mengikuti urutan formulir dalam list agar tetap terjangkau di layar kecil. Branch lama diarsipkan dan tidak dipakai ulang.
- Screenshot pembanding: cashclose_html_320.png, cashclose_html_390.png, cashclose_320.png, cashclose_390.png, cashclose_bottom_320.png, cashclose_bottom_390.png di ci-screens.

## Review Claude atas [GPT] Tutup Kasir — 3 Oktober 2026
- **Diterima & digabung** ke `flutter/native` (PR #2), bersama perbaikan lokasi & QRIS dari `flutter/fix-lokasi`.
- **Perbaikan**:
  - Error di model halaman native sekarang tidak bisa merusak aplikasi (otomatis kembali ke halaman HTML).
  - Pengaman bila elemen hilang.
  - Teks "belum dibayar" dan judul jumlah transaksi tidak lagi menempel.
- **Catatan**: pekerjaan GPT soal sheet pembayaran native belum ter-push saat kuotanya habis. Bila ada di lokal GPT, push dulu ke branch baru dari `flutter/native` terbaru.

## Lanjutan Claude 3 Oktober (pagi)
- **Halaman native baru**:
  - Sheet Atur Pesanan & Pembayaran (`addorder_sheet.dart`)
  - Layanan (`services_page.dart`)
  - Formulir generik untuk Printer & Nota + Profil (`form_page.dart`)
- **Cara menambah halaman form sederhana**:
  1. Tambahkan `formModel('<id>')` ke `NATIVE` di `capacitor.js`.
  2. Tambahkan `<id>` ke `_formPages` di `shell.dart`.
  3. Cek hasilnya. Halaman dengan visual khusus (preview label, kartu kurir) jangan dipakai form generik.
- **CI**: error tes jembatan, analyze, dan screenshot kini tampil sebagai anotasi.
  - Tes yang memakai jeda tetap diganti polling (CI lebih lambat dari lokal).
- **Jumlah halaman native**: 55 dari 66 (sisa HTML: Scan kamera, Administrator dalam app, Detail/Checkout/Invoice paket, pickservice lama, dan 5 halaman lama yang tidak lagi dibuka) (termasuk detail 40 laporan) halaman HTML (+ 2 sheet transaksi). Baru: **Tambah Pelanggan** (popup jenis kelamin tetap HTML) dan **Pusat Bantuan**, lalu **Outlet, Edit Outlet, Antar-Jemput, Pengaturan QRIS**, lewat formulir generik (daftar entri, pilihan kartu, isian Rp/km, pratinjau gambar, upload file lewat pemilih file Android) (kini juga mendukung baris berjudul+subjudul, deretan tombol kecil, ikon emoji).
  - Tambahan 3 Okt siang: Kasir, Pengingat, Pengeluaran, Koneksi Printer, Tentang GOYANA, Audit Log, Otomasi, Pusat Data, Perangkat WA, WhatsApp Bot, Monitoring Cabang (formulir generik: kartu angka, kotak omzet, pasangan label-nilai). Gambar golden tiap halaman dari model nyata: `mobile/test/fixtures/forms/*.json`.
  - Lalu: Pegawai, Stok, CRM, Chatbot AI, Blast, Balasan Cepat, Trigger, Audit, Integrasi (halaman paket berbayar; saat terkunci tetap HTML). Isian di dalam label, saklar tanpa teks, dan input file terlihat kini dikenali.
  - Sheet serbaguna HTML (`#gs107`: Tambah Kurir/Durasi/Kategori, konfirmasi hapus, dll) kini digambar native di atas halaman native.
  - **Rincian Pesanan** (detail order) kini sheet native penuh: langkah status, item, info, tombol aksi, bar total & Bayar. Popup lanjutan (⋯, QRIS, struk) tetap HTML.
  - Popup pembayaran kini sheet native: Tunai (kembalian dihitung HTML), Transfer, QRIS (gambar QR dinamis dikirim sebagai gambar), Upload QRIS, DP, Deposit, Foto (kamera/galeri lewat pemilih file Android), Struk.


## Mode Murni Flutter (tanpa WebView) — Claude, 3 Oktober 2026 siang
- Tujuan: aplikasi murni Flutter (lebih ringan). Logika dipindah ke Dart: `mobile/lib/core/` (models, business, money, qris, receipt, settings, store).
  Data tetap disimpan dengan format HTML lama (`goyana-business177`, `goyana-services158`, deposit `phone:62…`) di SQLite yang sama → data lama terbaca, dan versi lengkap (hybrid) tetap bisa dipakai bergantian.
- Paritas dengan HTML dites: `mobile/test/core_test.dart` (hitung total/diskon dari `api115.calc`, QRIS dinamis/CRC, struk, status, bayar/DP/deposit, batal, kas, pelanggan) + `mobile/test/pure_test.dart` (alur kasir lengkap di layar).
- Mode murni (`mobile/lib/pure/`): Beranda, Tambah Transaksi (pelanggan, durasi, layanan, jumlah, opsi, Tunai/QRIS+QR/Transfer/DP/Deposit/Bayar Nanti, pesanan jemput), Pesanan (tab, cari, rincian, status, bayar, batal, edit, riwayat, isi layanan, cetak struk, WA, Maps), Scan barcode kamera, Pelanggan (+ isi saldo deposit), Laporan, Kas & Tutup Kasir, Hari Ini, Pengaturan (Profil Struk, Printer Bluetooth, QRIS, Rekening, Layanan & Harga, Parfum, Outlet, Pusat Data ekspor/backup).
- Tambahan: Pegawai & PIN, Kurir, Label kantong (cetak N label per pesanan), Stok bahan (masuk/pemakaian/opname), CRM (pengingat cucian belum diambil via WA, poin member, voucher → muncul di pilihan Diskon), Diskon master, WhatsApp (template nota + tawaran kirim nota setelah transaksi), Cabang & monitoring + ganti outlet aktif, Notifikasi, Paket, Pusat Bantuan, setup outlet pertama kali.
- **Mulai versi 0.3.0 APK 100% Flutter**: WebView, `assets/web`, `lib/hybrid`, `mobile/web_bridge`, `tools/prepare_flutter_web.py`, `tests/flutter-bridge.cjs` dihapus. Tidak ada lagi tombol pindah mode. HTML (index.html) tetap dipakai untuk web/dashboard.
- Masih menunggu server (VPS): chatbot WA otomatis/blast (CHATKU), pembayaran paket online, sinkronisasi multi-HP.
