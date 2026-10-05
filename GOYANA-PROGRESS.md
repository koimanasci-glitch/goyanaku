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
- Masuk: Pengaturan (versi lengkap) → "⚡ Coba Mode Murni (beta)". Keluar: Pengaturan mode murni → "Kembali ke versi lengkap". Penanda mode: kunci `goyana-pure-mode`.
- Belum di mode murni: Pegawai & hak akses/PIN, Kurir, Label kantong, Stok, CRM/voucher, Diskon master, WhatsApp (chatbot/otomasi/blast), Multi-outlet monitoring, Upgrade paket, Notifikasi, Pusat Bantuan.

## Revisi dari Koko (catatan)
- 3 Okt 2026: Berat cucian harus bisa desimal (koma/titik), misal 2,5 kg. Penyebab: keyboard angka Flutter tanpa tombol koma. Perbaikan: input `inputmode=decimal` di HTML → keyboard angka dengan koma di Flutter (`decimal: true`). HTML sudah menerima "2,5" (diubah ke 2.5).

## Tampilan 100% Flutter (Claude, 3 Okt 2026 malam, branch flutter/native)
- Mode murni dibatalkan; aplikasi = hybrid sebelum mode murni (2742ff0) + lanjutan di bawah. Logika masih HTML.
- Rincian Pesanan: widget khusus `lib/native/order_detail_page.dart` (model `orderDetailModel` di capacitor.js).
- "Cermin HTML" (`lib/native/mirror_sheet.dart`, `mirrorNode` di capacitor.js): elemen + computed style HTML digambar Flutter apa adanya; aksi ke elemen HTML yang sama (`__goyanaMirror` / `__goyanaForm`).
  - 14 popup (MIRROR_SHEETS) dan 9 halaman sisa (MIRROR_PAGES: pickservice, pickup, orderscan + kamera native mobile_scanner, qrstatus, plan111, checkout111, billing, invoice111, waautomation).
- Revisi Koko: berat cucian desimal. 3 Okt: keyboard angka desimal. 4 Okt: Koko lapor masih tidak bisa koma/titik → keyboard diganti `numberWithOptions(decimal: true, signed: true)` (keyboard Samsung baru menampilkan tombol titik/koma dengan signed:true).
- Aturan dari Koko: kerjakan hanya yang diminta, jangan ubah bagian lain; tampilan harus sama dengan patokan HTML.

## Keputusan Koko — 4 Okt 2026 pagi (WAJIB diikuti semua AI yang mengerjakan repo ini)
- Semua penghitungan/logika pindah MURNI ke Dart. Tampilan aplikasi sekarang sudah FIX: jangan diubah sama sekali.
- Catat dulu, lalu konsultasi ke Koko sebelum mengerjakan. Kerjakan hanya yang diminta; jangan menyentuh bagian lain.
- Cara kerja yang dipakai: per bagian, hasil Dart dicek sama persis dengan HTML (tes paritas `mobile/test/parity_test.dart`, fixture `test/fixtures/parity/`), baru dipasang. HTML jadi pengaman sampai semua bagian selesai.
- Selesai: Beranda (`lib/logic/home.dart`).
- Menunggu keputusan Koko:
  1. "Omset hari ini" di HTML = jumlah penjualan sejak tutup kasir terakhir (bukan per tanggal). Ikuti HTML atau ganti per tanggal?
  2. Pilihan Kilat/Express di Tambah Transaksi tidak mengubah estimasi selesai (selalu +3 hari). Ikuti HTML atau perbaiki (Kilat 6 jam, Express 24 jam)?
- 4 Okt (revisi Koko): koma/titik berat baru bisa setelah keyboard ditutup-buka → penyebab: kolom HTML tersembunyi mengambil fokus (keyboard WebView), ketikan masuk HTML. Perbaikan: saat layar Flutter tampil, kolom HTML tidak boleh fokus (capacitor.js `blurHidden`/focusin). Popup terlalu ke atas → popup tanpa kolom isian selalu di bawah, tidak terdorong keyboard.
- 4 Okt 07.41 — revisi Koko (disetujui, dikerjakan 4 Okt; kurir yang dihapus tetap tercatat di riwayat tugas):
  1. Popup pilih Pria/Wanita: posisi di tengah layar (khusus popup ini).
  2. Popup Tambah/Edit Kurir: saat mengetik, isi terpotong & tombol Simpan tertutup keyboard → popup dibuat tinggi penuh, tombol Simpan tetap terlihat di atas keyboard.
  3. Management Kurir: belum ada tombol Hapus kurir; tombol "+ Tambah Kurir" jangan di setiap kartu kurir, cukup satu di atas.
  4. Tambah Pelanggan: saat mengisi, kolom tertutup keyboard → halaman bisa digulir sampai kolom yang diisi kelihatan.
  Pelaksanaan: popup gp128 di tengah (form_page.dart); keyboard tidak lagi dihitung dua kali (shell: MediaQuery.removeViewInsets) sehingga popup isian tampil penuh di atas keyboard; menu bawah disembunyikan saat mengetik (GBottomNav); kurir: tombol Tambah di atas, tombol Hapus (konfirmasi, data diberi `deleted:true` agar riwayat tetap).
- 4 Okt 08.22 — Koko: "alihkan semua tanpa ganti tampilan, cukup alihkan perhitungannya saja". Artinya: urutan disetujui; aturan hitung IKUT HTML apa adanya (Omset = sejak tutup kasir; Kilat/Express tidak mengubah estimasi) kecuali Koko minta lain; HTML jadi pengaman sampai semua selesai.
- Pesanan: `lib/logic/orders.dart` lulus paritas (8 tab + pencarian, 2 skenario: jemput, antar, proses, siap, telat 9 hari, diantar, diambil, batal). Dipasang di shell (`_ordersFromDart`) dengan HTML sebagai pengaman. Perbaikan data: alamat pelanggan kini ikut tersimpan (dulu hilang setelah aplikasi dibuka ulang).

## Keputusan & laporan Koko — 4 Okt 2026 09.24 WIB (untuk SEMUA AI)
- KEPUTUSAN ESTIMASI: estimasi selesai langsung mengikuti durasi yang dipilih (Reguler / Express / Kilat sesuai jam di Pengaturan Durasi). Ini MENGGANTI aturan HTML lama yang selalu +3 hari. Berlaku untuk logika Dart Tambah Transaksi.
- Laporan masalah (belum dikerjakan, tampilan tetap patokan HTML):
  1. Pengaturan → Durasi: tidak ada cara untuk mengedit durasi (jam/nama).
  2. Ikon logo berubah (perlu dipastikan: ikon aplikasi di layar HP atau logo GOYANA di atas).
  3. Pengaturan → Parfum: ikon parfum dan pilihan ikon parfum hilang.

### [GPT] Dart — Tambah Transaksi: patokan keranjang — 4 Oktober 2026 09.25 WIB
- Status: SETENGAH JALAN
- Sudah dikerjakan: mulai ulang dari flutter/native eccfc2d; arsip lokal lama tidak dipasang. Capture dijalankan dari lokasi repo; 20 model HTML nyata + 14 kasus input jumlah. Ditulis kalkulasi jumlah/subtotal/keranjang/harga katalog dan transisi durasi Dart, belum dipasang ke shell sebelum CI paritas lulus. Tidak ada perubahan widget/tampilan, HTML, atau mobile/lib/pure/.
- File diubah: tests/parity/capture.cjs, tests/parity/addorder.cjs, mobile/test/fixtures/parity/addorder_cart.json, mobile/lib/logic/addorder.dart, mobile/test/parity_test.dart.
- Tes paritas: 0/37 terverifikasi untuk bagian baru (menunggu CI); fixture: addorder_cart.json. Capture Chromium lulus. Tes jembatan 31/31 PASS lulus. Flutter lokal tidak digunakan: pemeriksaan otomatis memblokir setup SDK yang mengakses metadata cloud; tes Dart lewat CI.
- Commit: checkpoint ini (lihat git log); hasil CI: menunggu, belum diklaim lulus.
- Belum selesai / langkah berikutnya: cek CI paritas/analyze, pasang model keranjang dengan snapshot draft satu event dan fallback HTML; lanjut diskon/ongkir/nomor pesanan/penyimpanan format HTML. Fungsi jumlah dan transisi durasi baru diuji, aksi runtime masih HTML. Estimasi simpan belum disentuh. Ada catatan keputusan baru Koko 09.24 WIB tentang estimasi mengikuti jam Pengaturan Durasi; lanjutkan pada tahap simpan sesuai keputusan tersebut, jangan mengubah UI.
- Temuan aturan HTML yang perlu ditanyakan ke Koko: input `1,2,3` diterima sebagai 1,2; tanda minus pada `-2,5` dibuang sehingga menjadi 2,5. Keduanya ditiru apa adanya; belum diperketat. Apakah nantinya ingin ditolak? Sampai ada persetujuan, perilaku tetap HTML.
- [Claude] 4 Okt: Parfum & Durasi digambar dari cermin HTML (ikon botol parfum, tombol edit/hapus, baris durasi sama seperti HTML); popup form bersama `gs107` (Tambah/Edit Parfum dengan pilihan warna ikon, Tambah Durasi, dll) dan `cat99` (Kategori Baru dengan pilihan ikon layanan) juga dari cermin HTML. Hanya tampilan, logika tetap HTML.

### [GPT] Dart — Tambah Transaksi: koreksi tes keranjang — 4 Oktober 2026
- Status: SETENGAH JALAN; belum dipasang ke runtime.
- Dikerjakan: memperjelas tipe Map pada tes perubahan nilai presentasi; tidak mengubah perhitungan atau tampilan.
- File: `mobile/test/parity_test.dart`.
- Tes: CI 37171106155: bridge lulus, analyze lulus; 17 tes jumlah/durasi baru lulus. Dua puluh tes model melewati perbandingan awal, lalu gagal karena Map dinamis pada baris pengubahan fixture. Perbaikan ini menunggu CI berikutnya.
- Belum diuji: APK/HP dan fallback runtime.
- Berikutnya: pastikan semua 37 tes baru lulus, lalu pasang perhitungan keranjang dengan pengaman HTML.

### [Claude] Tampilan — Parfum & Durasi (ikon edit/hapus) — 4 Okt 2026 10.50 WIB
- Status: SELESAI (tampilan saja, tidak menyentuh logika Dart GPT)
- Permintaan Koko: ikon parfum & pilihan ikon hilang; di Pengaturan Durasi tidak ketemu cara edit.
- Sudah dikerjakan (cermin HTML, `capacitor.js` + `mirror_sheet.dart`):
  - Ikon pensil/sampah yang di HTML digambar lewat `::after` (mask SVG) sekarang ikut tampil, sehingga tombol Edit/Hapus di Parfum dan Durasi terlihat. Edit Durasi membuka form "Edit Durasi" milik HTML.
  - Cincin warna terpilih di popup Tambah/Edit Parfum.
  - Baris Durasi: urutan CSS `order`, garis pemisah "|", min-width kolom nama, tombol rata kanan; garis tepi per sisi (pemisah antar baris).
- Tes: uji jembatan 31 PASS (ditambah cek ikon & Edit Durasi); CI lulus; golden halaman/popup lain tidak berubah.
- Commit: bc755e0, 2ae3ee1, 18c23e8, fda8e6b.
- Temuan aturan HTML (tanya Koko, BELUM diubah): daftar Durasi di HTML tidak disimpan. Saat aplikasi dibuka daftarnya kosong ("Belum ada data"), dan durasi yang ditambah hilang setelah aplikasi dibuka ulang. Pilihan Reguler/Express/Kilat di Tambah Transaksi berasal dari tempat lain, bukan dari daftar ini.

### [Claude] Pengaturan Durasi — 3 durasi utama bisa diedit — 4 Okt 2026 11.30 WIB
- Status: SELESAI
- Permintaan Koko: Reguler/Express/Kilat harus muncul di Pengaturan Durasi dan bisa diedit, karena jam tiap laundry bisa beda.
- Keputusan: yang bisa diubah hanya jam. Nama tetap karena dipakai sebagai kunci harga layanan dan laporan. Ketiganya tidak bisa dihapus; untuk mematikan, matikan per layanan di Layanan & Harga.
- Jam disimpan di `goyana-durations199` (SQLite HP). Dipakai untuk label sheet "Pilih Durasi", tab durasi di daftar layanan, label varian di Layanan & Harga, dan estimasi selesai pesanan baru (masuk + jam).
- File: `index.html` (blok v199 + 3 baris pemakai jam), `tests/flutter-bridge.cjs`, fixture `mirror_pages/duration.json`, `GOYANA-HANDOFF-DART.md` (catatan untuk GPT).
- Tes: uji jembatan 31 PASS (termasuk edit Express via Flutter); uji browser: Express diubah ke 12 jam, tetap tersimpan setelah aplikasi dibuka ulang, dan estimasi pesanan Express = masuk + 12 jam.

### [GPT] Dart — 3a Tambah Transaksi: keranjang — 4 Oktober 2026 13.27 WIB
- Status: SELESAI
- Sudah dikerjakan: jumlah, subtotal, total keranjang, dan harga per durasi dihitung Dart; harga layanan dibaca dari database HP (`Business.services`), sedangkan WebView hanya memasok draft pilihan/jumlah/durasi yang belum tersimpan. `_addorderFromDart` dipasang dengan pengaman: Dart dipakai hanya bila modelnya sama persis dengan HTML; bila beda/error, layar tetap memakai HTML dan selisih dicatat ke `goyana-parity-log`. Tidak ada perubahan widget/tampilan.
- File diubah: `mobile/lib/logic/addorder.dart`, `mobile/test/parity_test.dart`, `mobile/lib/hybrid/shell.dart`, `GOYANA-PROGRESS.md`.
- Tes paritas: 37/37 lulus; fixture: `mobile/test/fixtures/parity/addorder_cart.json`. Tes Beranda 5/5 dan Pesanan 18/18 tetap lulus.
- Uji jembatan: 31 PASS; screenshot Flutter/native berubah: TIDAK. Delapan screenshot Tambah Transaksi 320/390 dan screenshot Flutter lain byte-identik dengan patokan; dua referensi HTML lama `cashclose_html_320/390.png` di `ci-screens` dibuat dinamis oleh CI dan berubah sendiri, bukan widget Flutter atau bagian 3a.
- Commit: `c8ee173a86d75a22ccdebb58a0f0a303498c9510`; CI: lulus, run `37182400625` (bridge, analyze, unit, screenshot, APK, publikasi `flutter-uji` semua sukses).
- Langkah berikutnya: BERHENTI sesuai instruksi Koko. Bagian 3b (diskon, ongkir, nomor pesanan, simpan) belum dikerjakan; tunggu Koko mengatakan "lanjut".
- Pertanyaan untuk Koko: tidak ada temuan baru pada bagian 3a. Perilaku input `1,2,3` dan `-2,5` tetap mengikuti HTML seperti keputusan/catatan sebelumnya.

### [GPT] Dart — 3c nomor pesanan, estimasi, simpan (SESI 2, SIAPKAN) — 4 Oktober 2026 WIB
- Status: SETENGAH JALAN — terhenti sebelum fixture HTML dapat dihasilkan. BELUM dipasang ke aplikasi dan BELUM ada fungsi Dart 3c.
- Sudah dikerjakan: membaca GOYANA-DART-SOLANA.md sampai habis dan laporan terakhir; checkout terpisah flutter/native; git pull --rebase sebelum mulai. Menelusuri nextCode136, durHours199, snapshot177, ensureDetail/syncPayment178 dan hook transport183. Menyiapkan skrip mandiri tests/parity/save.cjs (empat skenario awal: Bayar Nanti Reguler, Tunai Express, QRIS Kilat, Transfer Express 12 jam). Memakai pola mk(): customerbar + pickedName136, tidak memilih pelanggan dari daftar. Capture menyimpan before/draft/now/store/code/htmlModel dan tidak dipanggil dari tes Dart.
- File diubah: tests/parity/save.cjs dan laporan ini. File 3b, shell.dart, addorder.dart, parity_test.dart, capture.cjs, HTML/JS aplikasi, tampilan dan workflow tidak disentuh.
- Tes paritas: 0/0; belum ada fixture save_*.json. node --check tests/parity/save.cjs LULUS. Skrip belum berhasil dijalankan sampai selesai, sehingga bentuk data tidak diklaim terverifikasi.
- Hambatan: Chromium 1161 berhasil diunduh, tetapi launch ditolak lingkungan pada process_singleton_posix.cc: socket() failed: Operation not permitted (1). Permintaan eksekusi require_escalated juga ditolak kebijakan sandbox_approval:false. Tidak mencoba melewati pembatasan tersebut.
- Uji jembatan: belum dapat dijalankan lokal karena hambatan browser yang sama; 31 PASS belum diverifikasi sesi ini. Screenshot: file sumber/fixture/golden tidak diubah; perbandingan hasil CI belum dijalankan.
- Commit: checkpoint sesi 2 ini (lihat git log -- tests/parity/save.cjs); CI: belum dijalankan untuk 3c. Workflow Flutter yang ada tidak menjalankan save.cjs dan perubahan script/laporan saja tidak memicunya. Tidak ada percobaan CI yang gagal.
- Temuan untuk pemeriksaan selanjutnya: nextCode136 memakai 133 + jumlah kartu .new107, dengan awalan literal '0' (bukan pad empat digit dan bukan reset harian). Ada beberapa jalur pembentukan due: kartu memakai durHours199 tetapi ensureDetail178 masih memiliki fallback +72 jam. Perlu capture membuktikan bentuk final; jangan mengubah perilaku aplikasi berdasarkan temuan statis ini.
- Langkah berikutnya: jalankan NODE_PATH=tests/node_modules node tests/parity/save.cjs pada lingkungan yang mengizinkan Chromium (opsional GOYANA_BROWSER_EXECUTABLE). Bila melalui CI perlu izin mengubah workflow, karena tidak termasuk allowlist sesi 2. Periksa fixture nyata, perluas skenario urutan/reload/pergantian hari/durasi kustom/penyerahan/parfum/ledger yang sudah ada; baru tulis mobile/lib/logic/addorder_save.dart dan mobile/test/addorder_save_test.dart. Tes Dart harus membaca fixture saja. Jangan mengintegrasikan runtime atau menulis HP. Jalankan bridge 31 PASS dan CI paritas/analyze/screenshot/APK; hanya satu percobaan CI per hambatan sesuai instruksi Koko. Pull --rebase sebelum push, berhenti bila konflik sesi 1.
- Pertanyaan untuk Koko: boleh menambahkan langkah capture save.cjs dan unggahan fixture sebagai artifact ke workflow CI, atau gunakan sesi dengan Chromium lokal yang diizinkan? Belum mengubah workflow tanpa izin.

### [GPT] Dart — 3c SIAPKAN, fungsi simpan & tes (SESI 2) — 4 Oktober 2026 17.12 WIB
- Status: SETENGAH JALAN; BERHENTI setelah satu percobaan CI gagal sesuai instruksi Koko. Belum dipasang ke aplikasi/HP.
- Sudah dikerjakan: mobile/lib/logic/addorder_save.dart berisi nomor nextCode136, jam durHours199, estimasi teks v136, dan snapshot murni kartu/details/kas/deposits/customers. mobile/test/addorder_save_test.dart membandingkan snapshot penuh dan nomor/estimasi dari empat fixture; tidak menjalankan browser. Input di-copy, bukan dimutasi.
- File sesi ini: mobile/lib/logic/addorder_save.dart, mobile/test/addorder_save_test.dart, tests/parity/save.cjs, GOYANA-PROGRESS.md. Tidak mengubah workflow, shell.dart, addorder.dart, parity_test.dart, 3b, HTML/JS aplikasi, tampilan atau fixture Claude.
- Commit kode: 06c81077a06818b2999290ecb014baf24edf4ef6. Run 37194391695 otomatis dibatalkan saat Claude push 5070d5e. Pull --rebase berhasil tanpa konflik; CI pengganti 37194400812 menguji kode tersebut dengan fixture outlet aktif 5070d5e.
- Tes: analyze LULUS; jembatan 31 PASS. Tes unit total 103 lulus / 4 gagal. Khusus 3c: 4/8 lulus (nomor + estimasi); 4 snapshot gagal karena dataset kartu baru kurang kunci outlet180. CI hanya satu percobaan yang benar-benar menjalankan tes. Screenshot/APK dilewati akibat kegagalan unit; sumber screenshot/tampilan tidak diubah, kesamaan gambar belum terverifikasi pada run ini.
- Rp20.000 BUKAN aturan pembulatan: index.html v180 f61Payment menolak tanpa outlet, meninggalkan teks bawaan f61-payamount. v107 finish menyalin teks itu ke total kartu, v137 memakainya untuk kas, sedangkan paid177 memakai f61.total. Fixture lama a8e47f0 mengalami kondisi ini. Fixture terbaru 5070d5e sudah membuat outlet: payamount/total/kas menjadi Rp17.500. Dart membaca payamount, tidak mengunci angka 20000.
- Hambatan konkret: fixture 5070d5e memuat ID outlet acak hanya di htmlModel.orders[0].dataset.outlet180. Input store hanya memiliki goyana-durations199; kasus pertama belum punya pesanan sehingga before juga tidak memuat ID. Tidak sah mengambil ID dari expected, menuliskannya sebagai konstanta, atau menghapus kunci saat pembandingan.
- Perbaikan capture disiapkan: save.cjs sekarang menyimpan goyana-active-outlet180 dan goyana-outlets180 bersama goyana-durations199, SEBELUM f61Finish. node --check LULUS. Belum dijalankan: sesuai instruksi Koko hanya Claude yang menjalankan capture, tidak mencari jalan browser lain.
- Langkah berikutnya untuk Claude: jalankan NODE_PATH=tests/node_modules node tests/parity/save.cjs (gunakan GOYANA_BROWSER_EXECUTABLE bila perlu), commit fixture save_orders.json yang lengkap. Sesudah fixture tersedia, lanjutkan Dart: baca ID dari JSON goyana-active-outlet180 sesuai v180 (validasi/fallback melalui goyana-outlets180 bila perlu), masukkan dataset.outlet180 hanya bila aktif. Lalu uji CI lagi setelah Koko mengizinkan kelanjutan. Cakupan save saat ini Datang Langsung, cart berisi, tanpa diskon/picked customer, empat metode; skenario lebih luas membutuhkan capture tambahan, bukan asumsi.
- Temuan estimasi: teks kartu memakai jam pengaturan (72/24/6, Express kustom 12), tetapi details.due yang ditulis ensureDetail178 masih +72 jam pada semua kasus. Dart sengaja meniru keduanya demi paritas; jangan pasang sebelum perbedaan ini diputuskan Koko. Tidak ada perubahan aturan HTML.
- Pertanyaan untuk Koko: minta Claude menjalankan save.cjs terbaru untuk melengkapi input outlet; setelah itu baru bisa memastikan snapshot 3c sama persis dan CI hijau.

### [GPT] Dart — 3c SIAPKAN, outlet dari fixture — 4 Oktober 2026 17.33 WIB
- Status: SETENGAH JALAN untuk validasi CI keseluruhan; tes 3c sudah LULUS. BERHENTI sesuai instruksi satu percobaan CI, karena ada kegagalan bagian 3a di luar izin sesi 2.
- Sudah dikerjakan: pull fixture 446f46a; prepareAddOrderSave membaca JSON goyana-active-outlet180 dan goyana-outlets180 dari store, memvalidasi ID aktif/fallback outlet pertama mengikuti v180, lalu memasukkan dataset.outlet180. Tidak ada ID outlet acak yang ditulis langsung di kode. Total fixture tetap 17500.
- File diubah putaran ini: mobile/lib/logic/addorder_save.dart dan GOYANA-PROGRESS.md. Fixture, tests/parity/save.cjs, workflow, addorder.dart, parity_test.dart, shell.dart, HTML/JS, tampilan dan bagian 3b tidak diubah.
- Commit kode: b46abcb59832e13d521cf8ba67ecf846578e9d24. CI sekali: https://github.com/rajabadutiklan-lab/Goyana/actions/runs/37195519868 ; job 111416457391.
- Tes paritas 3c: 8/8 lulus (4 snapshot penuh dan 4 nomor/estimasi), fixture save_orders.json dari Claude 446f46a. Tidak ada kegagalan addorder_save_test.dart. Hasil unit keseluruhan 105 lulus / 2 gagal. Flutter analyze lulus tanpa temuan.
- Uji jembatan: 31 PASS (dihitung dari log job). Screenshot/APK: dilewati karena tes unit gagal; tidak dapat mengklaim pemeriksaan screenshot selesai. Sumber/fixture/golden tampilan tidak diubah. Belum terpasang ke runtime atau menulis HP.
- Penyebab CI gagal di LUAR 3c: parity_test.dart kasus Jumlah HTML kg 1,2,3 mengharapkan Rp 0 tetapi Dart 3a menghasilkan Rp 8.400; kasus -2,5 mengharapkan Rp 0 tetapi Dart 3a menghasilkan Rp 17.500. HTML dan fixture keranjang sudah diperbarui Claude untuk menolak input salah (193c857/0dea4ae), sedangkan hitungan Dart 3a belum mengikuti. Tidak diperbaiki sesi 2 karena addorder.dart dan parity_test.dart dilarang disentuh.
- Langkah berikutnya: penanggung jawab 3a menyesuaikan validasi input dengan keputusan Koko, lalu CI semua bagian dapat dijalankan lagi. Tidak perlu menangkap ulang fixture 3c untuk masalah outlet ini. Tahap pemasangan 3c tetap belum diizinkan; cakupan empat kasus dan temuan details.due +72 jam pada laporan sebelumnya tetap berlaku. Perbedaan due perlu keputusan/penyelarasan sebelum pemasangan, bukan dibetulkan diam-diam.
- Pertanyaan untuk Koko: tidak ada untuk perbaikan ID outlet; menunggu arahan bagi pemilik bagian 3a. Sesi 2 berhenti.

### [GPT sesi 1] A3b — 4 Oktober 2026 18.47 WIB
- Status: SELESAI.
- Sudah dikerjakan: aturan keputusan Koko diterapkan di Dart 3b, yaitu diskon/voucher hanya memotong subtotal layanan dan ongkir tidak ikut menjadi dasar diskon. Kasus Rp14.000 layanan + Rp6.000 ongkir + diskon 10% menghasilkan diskon Rp1.400 dan total Rp18.600. Guard runtime 3b dipasang di `_addorderFromDart`: saat sheet Pembayaran tampil, Dart menghitung pricing dari database HP + draft transaksi lalu membandingkan `total`, `discount`, dan `transport` dengan HTML; Dart hanya dipakai jika sama. Bila berbeda, model HTML tetap dipakai dan mismatch dicatat ke `goyana-parity-log` dengan page `addorder-3b`.
- File diubah untuk A3b: `mobile/lib/logic/addorder.dart`, `mobile/lib/hybrid/shell.dart`, dan laporan ini `GOYANA-PROGRESS.md`. Tidak mengubah widget/tampilan, HTML/JS aplikasi, workflow CI, atau bagian 3c.
- Tes paritas: 11/11 lulus; fixture `mobile/test/fixtures/parity/addorder_pricing.json` dari commit Claude `7079cdd`. Seluruh tes unit CI 107/107 lulus.
- Uji jembatan: 31 PASS. `flutter analyze`: lulus tanpa temuan. Screenshot: suite 93/93 lulus dan tree screenshot `45b40c1aad3da57bd1e128afbf94e706c7a57206` identik dengan patokan stabil sebelumnya, jadi tampilan tidak berubah. Build APK, artifact, dan publikasi `flutter-uji` juga lulus.
- Commit kode: `d0729417286a651804161d4f8ca9f24210959082` (dasar diskon tanpa ongkir) dan `d6601f83db0b1d1d2f77140d9b45463c16076e8f` (guard runtime 3b). CI final guard: run `37199538437`, SUCCESS pada percobaan pertama.
- Belum selesai / langkah berikutnya: BERHENTI sesuai instruksi Koko. Jangan lanjut atau memasang bagian 3c sampai Claude selesai mengecek A3b dan Koko memberi perintah berikutnya.
- Temuan aturan HTML yang perlu ditanyakan ke Koko: tidak ada temuan baru pada A3b; keputusan diskon/voucher tidak memotong ongkir sudah menjadi patokan final.

### [GPT] A3c — 4 Oktober 2026
- Status: SELESAI; BERHENTI menunggu pemeriksaan Claude.
- Basis kerja: mulai dari `df4aaef` (fixture `save_orders.json` baru), lalu direbase bersih ke `17b610d` karena Claude menambah patokan A4/A5/A7 saat sesi berjalan. Commit Claude tidak menyentuh file A3c.
- Sudah dikerjakan: `details.due` dan teks estimasi kartu sama-sama mengikuti jam `goyana-durations199` (Reguler 72, Express 24, Kilat 6, termasuk nilai kustom seperti Express 12 jam). Nomor pesanan tetap mengikuti `nextCode136` dari fixture.
- Pengaman runtime A3c dipasang di `shell.dart`: snapshot `goyana-business177` sebelum simpan + draft transaksi disiapkan setelah guard A3b sudah sama. HTML tetap melakukan satu kali simpan. Setelah kembali ke Pesanan, Dart menyusun snapshot penuh dari timestamp yang benar-benar ditulis HTML dan membandingkan seluruh data simpanan. Jika identik, Dart mengganti key `goyana-business177` dengan snapshot yang sama, bukan menambah order/ledger kedua. Jika beda, hasil HTML tetap dipakai dan mismatch dicatat ke `goyana-parity-log` dengan page `addorder-3c`. Jalur di luar empat fixture yang belum dicapture tetap HTML.
- File kode yang diubah: `mobile/lib/logic/addorder_save.dart`, `mobile/test/addorder_save_test.dart`, `mobile/lib/hybrid/shell.dart`. Fixture `save_orders.json` milik Claude tidak diubah. Tidak menyentuh tampilan, `index.html`/JS, `capacitor.js`, workflow CI, `mobile/lib/pure/`, atau bagian lain.
- Tes A3c: 12 pemeriksaan (4 snapshot penuh + 4 nomor/estimasi + 4 `details.due` sesuai durasi). Seluruh tes unit CI: 111/111 PASS. `flutter analyze`: tanpa temuan. Uji jembatan: 31 PASS.
- Screenshot: 93/93 PASS. Delapan screenshot Tambah Transaksi 320/390 dan seluruh screenshot native byte-identik dengan baseline. Perbandingan seluruh tree menemukan hanya `cashclose_html_390.png` berubah; itu capture HTML Tutup Kasir yang dinamis dan tidak terkait A3c, bukan perubahan widget/tampilan.
- Commit kode A3c: `0eafeb65be016cf8d36455e2b3818f9ed5cc7c2e`. CI utama: run `37201634493`, SUCCESS pada percobaan pertama; build APK, artifact, dan publikasi `flutter-uji` juga sukses.
- Temuan HTML yang terasa salah: tidak ada temuan baru pada cakupan fixture A3c. Tidak ada perilaku baru yang disalin diam-diam di luar hasil fixture.
- Langkah berikutnya: jangan lanjut A4 dari sesi ini. Claude memeriksa A3c terlebih dahulu.
### [GPT tampilan] B7 Harga Paket — 4 Oktober 2026
- Status: SETENGAH JALAN; BERHENTI setelah satu percobaan CI menemui hambatan, sesuai instruksi Koko. Belum digabung ke `flutter/native` atau `main`.
- Branch kerja: `design/tampilan`. Draft PR CI #5 sudah DITUTUP tanpa merge supaya penulisan laporan tidak memicu percobaan CI kedua.
- Sudah dikerjakan: `plan111` dipisahkan dari renderer CERMIN generik dan disambungkan ke widget Flutter asli baru `mobile/lib/native/plan_page.dart`. Desain baru memakai latar putih, merah GOYANA `#E8493F`, SVG garis sederhana konsisten untuk FREE/BASIC/SILVER/GOLD/PLATINUM, aksen berbeda tiap paket, penanda paket aktif yang jelas, rail pilihan paket, kartu detail, tab Fitur/Promo/Ulasan, daftar fitur, perbandingan dan CTA native.
- Sumber data: detail paket yang sedang dibuka, fitur, tab dan aksi tetap dibaca dari model mirror `plan111`. Model mirror `plan111` saat ini tidak membawa harga/urutan/paket aktif pada pane yang terlihat; karena itu harga, urutan paket, paket aktif, indeks tombol `Detail`, dan indeks `Riwayat transaksi` dibaca dari model `upgrade` yang sudah berada di shell tepat sebelum `plan111` dibuka. Tidak ada harga atau deskripsi paket yang di-hardcode di widget. Hal ini perlu dicek Claude/Koko karena instruksi awal menyebut data plan111, sementara payload plan111 nyata tidak memuat semua field tersebut.
- Tombol: aksi tab/CTA plan111 tetap meneruskan indeks tombol mirror yang sama; pilihan paket meneruskan indeks `Detail` dari model upgrade; `Riwayat transaksi` meneruskan indeks tombol model upgrade yang sama. Logika/JS tidak diubah.
- File kode yang berubah terhadap `flutter/native` sebelum laporan: `mobile/lib/native/plan_page.dart` (baru), `mobile/lib/hybrid/shell.dart` (hanya import + sambungan khusus plan111 + mengecualikan plan111 dari renderer mirror generik), dan `mobile/test/plan_page_screens_test.dart` (baru). Tidak menyentuh `mobile/lib/logic/`, `addorder.dart`, index.html/JS/CSS, capacitor.js, workflow CI, atau halaman lain.
- Golden baru sudah ditulis sebagai tes `screens/plan111_native.png`, tetapi file gambar SESUDAH belum sempat dihasilkan karena pipeline berhenti sebelum langkah screenshot. Screenshot SEBELUM yang tersedia: `mirrorpage_plan111.png` pada branch `ci-screens`. Jangan mengklaim screenshot sesudah sudah ada.
- Uji jembatan pada CI pertama: 31 PASS. Run: `37200734540`, job `111431712251`.
- Hambatan CI pertama: `flutter analyze` gagal hanya karena satu warning `unnecessary_non_null_assertion` pada `mobile/lib/native/plan_page.dart:222:41` (`!` tidak diperlukan). `flutter pub get` lulus. Karena analyze menghentikan pipeline, tes unit, golden screenshot, build APK dan publikasi APK dilewati.
- Sesuai aturan satu percobaan CI per hambatan, warning tersebut BELUM diperbaiki dan CI kedua TIDAK dijalankan. Langkah berikutnya hanya setelah Koko memberi izin: hapus `!` yang tidak perlu, jalankan satu CI baru, lalu ambil golden SESUDAH dan minta Claude mengecek sebelum putaran berikutnya.
- Commit utama sebelum laporan: `acdb3a40f586929593c3e1eb0cd8fe2612262dfd` (widget plan), `b29cf39b47c083516d53a7f375b2d5ff59a2cbdd` (sambungan shell), `e3d1fbd9a6a615eb9cfbb7cbcbf2ba6c67a15f85` (golden test). BERHENTI.

### [Claude] Cek A3c + gabung B7 Harga Paket — 4 Okt 2026 19.45 WIB
- A3c (sesi 1, 0eafeb6): benar dan aman; satu perubahan: saat hasil Dart sama dengan HTML tidak lagi menulis ulang goyana-business177 (menghindari menimpa perubahan HTML sesaat sesudahnya).
- B7 Harga Paket (sesi tampilan): warning analyze dibetulkan (hapus `!`), CI PR lulus semua, lalu digabung ke flutter/native agar golden & APK bisa dilihat Koko. Kalau Koko tidak suka: revert merge ini, plan111 kembali ke cermin.

### [GPT tampilan] B1 Parfum — 4 Oktober 2026 21.01 WIB
- Status: FUNGSI/CI SELESAI; visual efektif sama dengan cermin, tetapi pemeriksaan piksel menemukan deviasi kecil sehingga belum 100% pixel-identik.
- Dikerjakan: halaman `perfume` tipe CERMIN dipisahkan dari renderer cermin generik dan diganti widget Flutter asli `mobile/lib/native/perfume_page.dart`. Nama parfum, warna, SVG botol, teks, dan indeks tombol dibaca dari model cermin yang sekarang; tidak ada data parfum yang di-hardcode.
- Tombol tetap memakai aksi lama: `+ Tambah Parfum` meneruskan indeks 2; edit/hapus meneruskan indeks model masing-masing (contoh Akasia 3/4), melalui `__goyanaMirror`. `shell.dart` hanya ditambah import, sambungan khusus `perfume`, dan pengecualian `perfume` dari `NativeMirrorPage`; blok pengaman Dart tidak diubah.
- Golden baru: `mobile/test/screens/perfume_native.png` dihasilkan CI dan dikirim ke branch `ci-screens`. Tes golden/aksi ada di `mobile/test/perfume_screens_test.dart`.
- Perbandingan dengan `mirrorpage_perfume.png`: teks, warna, bentuk ikon, header, dan bottom navigation cocok. Deviasi terukur: seluruh isi di bawah header turun sekitar 1 px; swatch + tombol edit/hapus bergeser sekitar 8 px ke kanan dan 1 px ke bawah; divider baris turun 1 px. Karena batas Koko maksimal 2 CI sudah habis, tidak dibuat commit koreksi tanpa verifikasi/golden baru.
- CI percobaan 1: run `37208381844`, SUCCESS untuk widget awal sebelum sambungan final. CI percobaan 2/final: run `37209036660`, SUCCESS penuh. Uji jembatan 31 PASS, `flutter analyze` tanpa temuan, unit 113/113 PASS, screenshot 95/95 PASS, build APK + artifact + publikasi `flutter-uji` sukses.
- Commit kode: `956b11136db1997567f9e44569ff43ac699d05f5` (widget Flutter asli) dan `7c9fc0eb9a400acc0da5e839cdd43a385c4daf44` (sambungan shell + golden test). File terlarang tidak disentuh: logic/hitungan, `index.html`/JS/CSS, `capacitor.js`, workflow CI, dan halaman lain.
- Langkah berikutnya: BERHENTI. Bila Koko meminta pixel-identik 100%, koreksi 1 px/8 px dilakukan pada putaran tampilan baru karena jatah dua CI B1 sudah terpakai.

### [GPT tampilan] B2 Durasi — 4 Oktober 2026
- Status: SELESAI.
- Basis kerja: `flutter/native` setelah revert Claude `37ca696`; implementasi B2 Haiku lama tidak dipakai.
- Dikerjakan: halaman `duration` tipe CERMIN dipisahkan dari renderer cermin generik dan diganti widget Flutter asli `mobile/lib/native/duration_page.dart`. `shell.dart` hanya ditambah import, sambungan khusus `duration`, dan pengecualian `duration` dari `NativeMirrorPage`; blok pengaman Dart tidak disentuh.
- Tampilan mengikuti `mobile/test/fixtures/mirror_pages/duration.json`: latar putih, tombol `+ Tambah Durasi`, Reguler/Express/Kilat sebagai baris langsung di konten tanpa kartu pembungkus, garis bawah tiap baris, pemisah nama/jam, serta tombol edit/hapus 52×40. Warna dan SVG tetap dibaca dari model cermin.
- Data/aksi: nama durasi, jam, warna, SVG, dan indeks tombol dibaca dari model yang sama. `+ Tambah Durasi` meneruskan indeks 3; Reguler edit/hapus 4/5; Express 6/7; Kilat 8/9.
- Golden baru: `mobile/test/screens/duration_native.png`, dengan tes `mobile/test/duration_screens_test.dart`; CI mengirim hasil ke branch `ci-screens`.
- CI GPT memakai 2/2 percobaan/push untuk B2. CI final run `37214923385` SUCCESS: uji jembatan 31 PASS, `flutter analyze` tanpa temuan, unit 113/113 PASS, screenshot 96/96 PASS, build APK release sukses, artifact berhasil diunggah, dan release `flutter-uji` diperbarui.
- Commit kode: `6fcea654d6f1e8315c9bafc1e7e43990b4570253` (widget) dan `526c572eec046d0c631e0157b0967b2f0b7f058c` (sambungan shell + golden test).
- File terlarang tidak disentuh: hitungan/logic, `index.html`/JS/CSS, `capacitor.js`, workflow CI, dan halaman lain.
- Langkah berikutnya: BERHENTI. Tunggu Koko/Claude mengecek B2 sebelum memulai B3.

### [GPT tampilan] B3 Pilih Layanan — 4 Oktober 2026
- Status: SELESAI; BERHENTI menunggu Claude memeriksa sebelum B4.
- Basis: `flutter/native` commit `384b883`; `git pull --rebase origin flutter/native` dilakukan sebelum kerja dan sebelum publikasi kode.
- Dikerjakan: widget Flutter asli `mobile/lib/native/pickservice_page.dart`, sesuai fixture `mobile/test/fixtures/mirror_pages/pickservice.json` dan hasil akhir HTML/CSS. `shell.dart` hanya ditambah import, sambungan `pickservice`, dan pengecualian dari `NativeMirrorPage`. Pengaman Dart dan halaman lain tidak diubah.
- Patokan final memang kosong: script `goyana-empty-transactions176` mengganti isi picker lama dengan `Belum ada layanan.`; field pencarian dan daftar layanan lama tidak ditambahkan kembali. Bentuk mengikuti cermin yang sekarang, termasuk ukuran tombol kembali 38×32 dan tata letak renderer cermin; tidak mengganti ukuran berdasarkan aturan HTML lama. Teks dan indeks tombol tetap dari model cermin, bukan katalog hardcode.
- Aksi: kembali meneruskan `_mirror('button', 1)` dari indeks model; scan header memakai indeks `scan` model (fixture 0); bottom navigation tetap memakai `nav` shell. Tes mengetuk kembali dan navigasi Pesanan lulus.
- File berubah: `mobile/lib/native/pickservice_page.dart` (baru), `mobile/lib/hybrid/shell.dart` (hanya sambungan), `mobile/test/pickservice_screens_test.dart` (baru), `GOYANA-PROGRESS.md`, `GOYANA-DART-SOLANA.md`. Status tabel jalur B untuk B1, B2, B3, B7 diperbarui menjadi SELESAI sesuai instruksi; halaman B1/B2/B7 tidak diedit.
- Golden: tes `screens/pickservice_native.png`; gambar dihasilkan CI pada branch `ci-screens`, commit `6f37971`. Tes juga merender cermin dan native dengan fixture sama, lalu membandingkan gambar langsung pada lebar 390 dan 320 px: keduanya identik piksel, bukan hanya menghasilkan golden baru. PNG 390×844 sesudah dibandingkan dengan `mirrorpage_pickservice.png` sebelum (ci-screens `99dd64e`): seluruh byte piksel RGBA sama.
- Perbandingan seluruh screenshot sebelum/sesudah: semua gambar native lama tidak berubah. Satu gambar baru `pickservice_native.png`; satu capture HTML di luar B3 berubah, `cashclose_html_390.png`, pada area navigasi bawah (y=732–823). Sumber Tutup Kasir/HTML/tes lamanya tidak disentuh; penyebab perbedaan capture ini tidak diputuskan atau diperbaiki dalam B3.
- CI pertama/final: run `37217343037`, job `111480431410`, SUCCESS. Bridge 31 PASS; `flutter analyze` tanpa temuan; unit 113/113 PASS; screenshot 98/98 PASS; build APK release, unggah artifact `GOYANA-Flutter-Uji`, dan publikasi release `flutter-uji` sukses. Workflow APK lama yang terpicu push yang sama juga SUCCESS, run `37217343080`.
- Commit kode terpublikasi: `aa8409c403eebbb490bc19334368a3800db7fae1`. Git HTTPS lokal tidak memiliki kredensial push; publikasi memakai konektor GitHub, dengan hash ketiga blob dan tree diverifikasi sama persis dengan commit lokal sebelum memperbarui branch tanpa force. Tidak ada perubahan isi karena jalur publikasi ini.
- Jatah CI: 1/2 percobaan publikasi kode terpakai; tidak ada CI kedua atau rerun. Commit laporan terpisah berjudul `[GPT tampilan] B3 Pilih Layanan` memakai penanda skip CI agar dokumentasi tidak memicu CI tambahan.
- Uji lokal: percobaan bridge terhalang sandbox Chromium (`socket() failed: Operation not permitted`); hasil bridge final diverifikasi dari log CI, bukan diklaim dari percobaan lokal. Flutter lokal tidak tersedia.
- Tidak mengubah `index.html`, JS/CSS, `capacitor.js`, workflow, fixture, hitungan/logic, atau `mobile/lib/pure/`. Tidak ada keraguan baru pada HTML B3; catatan capture Tutup Kasir di atas diserahkan untuk pemeriksaan Claude. Tidak lanjut B4.

### [GPT tampilan] B4 Jemput + cadangan B3 — 5 Oktober 2026
- Status: SELESAI; BERHENTI menunggu pemeriksaan Claude sebelum B5.
- Basis: `flutter/native` commit `954c589`; `git pull --rebase origin flutter/native` dilakukan sebelum mulai dan sebelum publikasi kode.
- B4: widget Flutter asli `mobile/lib/native/pickup_page.dart` mengikuti fixture `mirror_pages/pickup.json` dan hasil CSS final. Susunan subhead, pesan barcode cocok, kartu pelanggan, status, grid rincian, tombol Bayar dan Konfirmasi Sudah Diambil sama dengan renderer cermin. Judul tetap `Pengambilan Pesanan` sesuai patokan, bukan diganti menjadi Jemput.
- Data B4: nama, nomor/telepon, status, rincian, warna, ukuran, teks dan indeks aksi dari model cermin. Parser memeriksa tipe Map/List/num dan panjang list; nilai kosong/tidak valid punya cadangan; tidak ada `.single`, cast angka tanpa pemeriksaan, atau indeks list tanpa pemeriksaan panjang. Model kosong memakai label dasar dan tanda kosong, tanpa mengarang pelanggan/transaksi. Tombol dengan indeks tidak tersedia dinonaktifkan.
- Aksi B4: kembali meneruskan indeks 1, Bayar 2, Konfirmasi Sudah Diambil 3, melalui `_mirror('button', i)`. Scan header tetap indeks `scan` dari model (fixture 0) dan navigasi bawah tetap `nav` shell. Tes ketiga tombol dan navigasi Pesanan lulus.
- Shell: hanya import pickup, sambungan khusus pickup, dan pengecualian pickup dari `NativeMirrorPage`; pengaman Dart dan sambungan halaman lainnya tidak disentuh.
- Cadangan B3: `pickservice_page.dart` tidak lagi memakai `.single`, cast angka tanpa cek atau indeks sections/heading tanpa pemeriksaan panjang. Model `{}` tetap menampilkan `PILIH LAYANAN` dan `Belum ada layanan.` dengan gaya lama; isian gaya dan teks yang hilang punya cadangan. Indeks tombol kosong tidak dikarang.
- Golden B3 TIDAK diperbarui: PNG lama dari `ci-screens` commit `6f37971` disertakan tanpa perubahan byte pada `mobile/test/screens/pickservice_native.png` agar CI memiliki baseline yang tetap. Tes B3 mematikan `autoUpdateGoldenFiles` hanya selama pemeriksaan golden dan memulihkan nilainya setelah itu. Hash blob patokan dan hasil CI tetap `a439da7db00d4cae67795b7abb7b1c47c6d6dbda`. Golden lama lulus dengan pembaruan dimatikan. Ditambahkan satu tes B3 `{}` tidak crash.
- Golden B4: `screens/pickup_native.png` dihasilkan pada `ci-screens` commit `607b97f4e49fdd91f29105dada738ad607d08931`. Tes B4 membandingkan gambar native dan cermin langsung pada 390 serta 320 px: keduanya identik piksel. PNG 390×844 sesudah juga memiliki seluruh byte RGBA sama dengan `mirrorpage_pickup.png` sebelum. Tes B4 tambahan memeriksa model kosong dan struktur berubah tidak crash.
- Temuan HTML/cermin: label grid menyatu dengan nilainya (misalnya `LayananReguler · 4 Kg`), glyph centang tampil sebagai kotak pada renderer. Sudah ditanyakan kepada Paduka; jawaban `Ikuti cermin` diterima. Keduanya dipertahankan persis, tanpa menambahkan spasi atau mengganti ikon.
- Pemeriksaan seluruh screenshot: semua screenshot native lama, termasuk B3, tidak berubah. Gambar baru hanya `pickup_native.png`. Dua capture HTML di luar pekerjaan ini berubah: `cashclose_html_320.png` dan `cashclose_html_390.png`; sumber/tes Tutup Kasir tidak disentuh dan penyebabnya tidak diputuskan dalam B4. Catatan untuk pemeriksaan Claude.
- File berubah: `mobile/lib/native/pickup_page.dart` (baru), `mobile/lib/native/pickservice_page.dart`, `mobile/lib/hybrid/shell.dart`, `mobile/test/pickup_screens_test.dart` (baru), `mobile/test/pickservice_screens_test.dart`, `mobile/test/screens/pickservice_native.png` (salinan baseline lama tanpa perubahan byte), `GOYANA-PROGRESS.md`, `GOYANA-DART-SOLANA.md` (hanya status B4 menjadi SELESAI).
- Commit kode terpublikasi: `46c1f6c3f1d79d3d27082f250a195574745918f2`. Publikasi memakai konektor GitHub karena git HTTPS lokal tidak memiliki kredensial push; hash semua blob/tree diverifikasi sama dengan commit lokal sebelum update branch tanpa force.
- CI pertama/final: run `37220876008`, job `111490781273`, SUCCESS. Bridge 31 PASS; `flutter analyze` tanpa temuan; unit 113/113 PASS; screenshot 102/102 PASS; build APK release, artifact `GOYANA-Flutter-Uji`, dan publikasi release `flutter-uji` sukses. Workflow APK lama pada push yang sama juga SUCCESS, run `37220875938`.
- Jatah CI: 1/2 percobaan publikasi kode terpakai; tidak ada CI kedua atau rerun. Laporan dibuat dalam commit terpisah `[GPT tampilan] B4 Jemput + cadangan B3` dengan penanda skip CI, agar dokumentasi tidak menambah percobaan CI.
- Tidak mengubah hitungan/logic, `index.html`, JS/CSS, `capacitor.js`, fixture, workflow CI, `mobile/lib/pure/`, atau halaman lainnya. Flutter lokal tidak tersedia; hasil Flutter dan bridge diverifikasi melalui CI. Pertanyaan patokan B4 sudah dijawab Paduka; tidak ada keputusan desain tambahan. Tidak lanjut B5.


### [Claude] Gabung A4 Rincian Pesanan ke flutter/native — 5 Okt 2026 01.25 WIB
- Sumber: branch `flutter/a4` dari GPT sesi 1 (d5c3911 + laporan c2cb7bc, basis lama 370df2a). Digabung ke `flutter/native` setelah B4 (1944e19) tanpa konflik; sambungan B1–B4 di `shell.dart` tetap utuh.
- Diuji di branch `flutter/a4-gabung`. Tiga perbaikan agar Dart sama persis dengan patokan HTML (hitungan tidak berubah):
  1. Tes: jumlah tab "Belum Bayar" ditulis sebagai teks seperti HTML/Dart (bukan angka).
  2. Label tombol rincian: "Kirim nota WA" dan "Cetak struk" (bukan "WhatsApp"/"Cetak"); label tombol di kartu pelanggan kosong seperti HTML.
  3. Langkah status: "Siap Ambil" (bukan "Siap"); pada status Diambil semua langkah selesai dan tidak ada langkah aktif.
- CI: 37222330239 dan 37222602672 dan 37222893292 gagal di tes unit A4 (perbedaan di atas, satu per putaran); final 37223205196 SUCCESS: jembatan, analyze, unit, screenshot dan APK.
- Pengaman tetap: Dart hanya dipakai di layar bila hasilnya sama dengan HTML; beda → tetap HTML dan dicatat di goyana-parity-log. HTML tetap yang menyimpan data.
- Langkah berikutnya: sesi tampilan boleh mulai B5 dari `flutter/native` terbaru; sesi Dart menunggu perintah A5.

### [GPT] B5 Scan Pesanan — 5 Oktober 2026
- Status: SELESAI.
- Basis: `flutter/native` `3d63b62`; dokumen `GOYANA-SAMPAI-SELESAI.md` dibaca sampai habis. Urutan bagian 8 diikuti untuk sesi tampilan: B5 dahulu, kemudian B6. Satu bagian per putaran. Pull rebase dilakukan sebelum kerja dan setiap publikasi.
- Dikerjakan: widget Flutter asli `mobile/lib/native/orderscan_page.dart` mengganti cermin untuk orderscan. Bentuk layar penuh, scrim, tombol tutup, frame, garis merah, judul, petunjuk, input dan tombol Cari mengikuti fixture serta CSS final. Tidak menambahkan desain baru. Model kosong punya cadangan; Map/List/angka/indeks diperiksa sebelum dipakai.
- Kamera: callback `MobileScanner` disalin apa adanya ke sambungan widget baru. Pemeriksaan sumber membuktikan callback lama dan kedua callback pada shell sekarang identik setelah whitespace diabaikan: ekstraksi rawValue, `_scanned`, dan `_mirror('scan', 0, code)` sama. Kamera di HP nyata belum diuji dalam sesi ini; golden menggunakan pengganti video statis yang sama dengan tes cermin.
- Aksi: tutup = button 1, Cari = button 2, input = 0; seluruhnya dari model dan diteruskan melalui mirror lama. Daftar hasil pencarian (HTML `qr159-results`) tetap digambar native dan setiap pilihan memakai `b` dari model, tanpa mengarang indeks runtime. Kolom dikontrol dengan controller/focus seperti cermin, termasuk pembaruan nilai dari model ketika tidak sedang fokus.
- Fixture canonical: `mirror_pages/orderscan.json` tidak diubah. Tes membandingkan native dengan renderer cermin pada 390 dan 320 px, keduanya identik piksel. Golden `screens/orderscan_native.png` diambil byte-persis dari `mirrorpage_orderscan.png` sebelum migrasi, lalu dikunci (`autoUpdateGoldenFiles=false` selama tes), bukan diregenerasi untuk menerima perubahan.
- Keadaan pencarian lebih dari satu hasil tidak ada pada fixture canonical. Struktur HTML-nya ditemukan sesudah CI pertama dimulai; widget dan tes dilengkapi pada commit kedua. Tes tambahan memakai model sintetis yang mengikuti struktur dan style hasil HTML, membandingkannya dengan renderer cermin pada 390/320 dan memeriksa indeks pilihan. Ini bukan capture hasil HTML nyata baru; verifikasi multi-hasil di HP tetap perlu dilakukan saat pemeriksaan menyeluruh.
- Golden terkunci tetap byte-identik: blob `f30540990bd87cc958bad8a334f204328aab92e1` sebelum dan sesudah. Branch `ci-screens` final `9ca909fcd8178745fbd99c432a8f94166a8e1abc`; perbandingan seluruh tree dengan baseline `3cffa61` hanya menemukan penambahan `orderscan_native.png`, tidak ada screenshot lama berubah.
- File berubah: `mobile/lib/native/orderscan_page.dart`, `mobile/lib/hybrid/shell.dart` (import/sambungan/pengecualian orderscan), `mobile/test/orderscan_screens_test.dart`, `mobile/test/screens/orderscan_native.png` (baseline terkunci), `GOYANA-PROGRESS.md`, `GOYANA-SAMPAI-SELESAI.md`, `GOYANA-DART-SOLANA.md` (status B5). Tidak mengubah logika hitungan, HTML/JS/CSS, bridge, workflow, fixture canonical, atau halaman lain.
- Commit kode: `308c86fa5af43a018ab3d97b8a8a38c2b77378ed` (widget/sambungan/golden) dan `5e3b54c4cc3a713a39d15ba20c5ab00ef0ecd628` (hasil pencarian). Publikasi konektor GitHub; setiap blob dan tree diverifikasi sama dengan commit lokal, update branch tanpa force.
- CI 1: `37227210187`, job `111509243356`, SUCCESS; bridge 31 PASS, analyze tanpa temuan, unit 123/123, screenshot 105/105, APK/artifact/publikasi sukses. CI 2 melengkapi keadaan hasil pencarian yang terlewat pada implementasi pertama, bukan mengubah golden.
- Jatah CI: 2/2 terpakai. Tidak ada CI ketiga/rerun. Laporan commit terpisah `[GPT] B5 Scan Pesanan` dengan skip CI agar dokumentasi tidak memicu percobaan tambahan.
- Temuan/pertanyaan Koko: tidak ada perubahan desain atau aturan bisnis baru yang diputuskan. Daftar multi-hasil perlu verifikasi nyata pada uji HP (tes sintetis dijelaskan di atas). Langkah berikutnya B6 sesuai bagian 8; tidak menunggu Claude karena perintah terbaru mengizinkan lanjut setelah laporan.
- CI 2 final: `37227808466`, job `111510986876`, SUCCESS; bridge 31 PASS, analyze tanpa temuan, unit 123/123, screenshot 107/107, build APK release, artifact dan publikasi `flutter-uji` semuanya sukses.


### [GPT] B6 Status QR — 5 Oktober 2026
- Status: MENTOK. Widget asli dan sambungan sudah dibuat, tetapi belum memenuhi syarat identik piksel; jangan dianggap selesai atau siap digabung. Kedua tes paritas masih gagal. APK Flutter yang terpublikasi tetap berasal dari B5 karena kedua run B6 berhenti sebelum build APK.
- Basis: `flutter/native` `6859b754eaf6ea4d4197ac3d02adc36fdd232650`. Dokumen sampai-selesai dibaca penuh; urutan bagian 8 dan aturan bagian 0 diikuti. Pull rebase dilakukan sebelum mulai dan sebelum tiap publikasi.
- File berubah: `mobile/lib/native/qrstatus_page.dart`, `mobile/lib/hybrid/shell.dart` (import/sambungan/pengecualian qrstatus), `mobile/test/qrstatus_screens_test.dart`, `mobile/test/screens/qrstatus_native.png`, `GOYANA-PROGRESS.md`, `GOYANA-SAMPAI-SELESAI.md`, `GOYANA-DART-SOLANA.md` (status B6). HTML/JS/CSS, fixture, pengaman Dart, kamera, workflow, halaman lain tidak diubah.
- Tampilan: judul, pencarian, kartu outlet/pelanggan/order, pola kotak QR, indikator progres, status, tombol full screen dan navigasi mengikuti fixture `mirror_pages/qrstatus.json` serta CSS final. Model kosong/berubah bentuk punya cadangan; tidak memakai `.single`, cast angka tanpa cek, atau indeks list tanpa cek panjang. Controller mengikuti nilai model saat tidak fokus.
- Aksi memakai indeks dari model: back button 1, cari button 2, full screen button 3, input 0; shell meneruskan `_mirror('button', i)` dan `_mirror('input', i, v)`. Pemeriksaan ketukan setelah pembandingan piksel belum terjangkau pada kedua tes utama karena paritas gagal terlebih dahulu.
- Patokan golden baru disalin byte-persis dari screenshot cermin B5 sebelum migrasi, blob `cabf46b6afbd83f77afc3a13037fb0b4e44511f1`; golden dikunci dengan `autoUpdateGoldenFiles=false`. Golden B3 dan semua baseline lama tidak diperbarui. Pembandingan langsung native versus renderer cermin pada 390 dan 320 berjalan terpisah dari pembaruan golden otomatis.
- Commit kode: `07ec350070928b5efbd403457dd884c3c10db020` (widget/sambungan/tes/baseline), `389109d74c8a0f0f77ef47b8842b2c78cc475be9` (latar putih input seperti renderer cermin). Publikasi lewat konektor GitHub; blob/tree sama dengan commit lokal, update ref tanpa force.
- CI 1: run `37228913991`, job `111514241247`, FAILURE. Bridge 31 PASS; analyze tanpa temuan; unit 123/123 PASS. Screenshot 108 PASS, 2 FAIL; paritas 390 berbeda 3.069 piksel dan 320 berbeda 2.380 piksel. Tes model kosong/berubah bentuk PASS. APK Flutter/artifact APK/publikasi dilewati karena screenshot gagal. Pipeline lama Build APK GOYANA pada push yang sama sukses, tetapi itu bukan APK Flutter hasil B6.
- Perbaikan setelah CI 1: renderer `_MirrorField` memberi latar putih ketika style tidak menyebut bg. Widget baru sebelumnya transparan; diperbaiki tanpa mengganti baseline.
- CI 2 final: run `37229254989`, job `111515257262`, FAILURE. Bridge 31 PASS; analyze tanpa temuan; unit 123/123 PASS. Screenshot 108 PASS, 2 FAIL; paritas masih berbeda 254 piksel pada 390 dan 254 piksel pada 320. Tes cadangan model PASS. APK Flutter/artifact APK/publikasi dilewati; tidak ada APK B6 baru. Paritas piksel belum lulus, sehingga perbandingan golden terkunci dan tes aksi utama belum terjangkau.
- Jatah CI: 2/2 terpakai, tidak ada CI ketiga/rerun. Laporan commit terpisah `[GPT] B6 Status QR` memakai skip CI; tidak menyamarkan kegagalan dengan mengganti gambar, toleransi piksel, atau melewati tes.
- Temuan teknis untuk pemeriksaan berikutnya: sisa 254 piksel konstan pada kedua lebar belum dilokalisasi lewat gambar diff. Workflow sekarang tidak mengunggah gambar kegagalan `matchesReferenceImage`. Salah satu perbedaan implementasi yang perlu diperiksa adalah clipping pola QR (`ClipRect` di widget, `ClipRRect` radius nol di cermin); ini dugaan, bukan hasil yang sudah terbukti atau diperbaiki. Flutter SDK/browser lokal tidak dapat dipakai di lingkungan sesi ini, sehingga verifikasi bergantung pada CI.
- Temuan/pertanyaan Koko: HTML saat ini memakai pola kotak-kotak sebagai QR, data contoh status, dan tombol full screen menampilkan alert. Dipertahankan sesuai migrasi tampilan; tidak mengarang QR pesanan atau aturan baru. Jika ingin QR status nyata dan full screen nyata, perlu keputusan/pekerjaan terpisah. Belum diuji di HP nyata.
- Lanjutan urutan: B8 Checkout Paket membutuhkan capture fixture dahulu. B6 jangan ditandai SELESAI sebelum paritas nol piksel. CI tampilan bagian berikutnya memakai suite yang sama dan akan ikut terhalang dua tes B6 ini; tidak boleh menganggap kegagalan tersebut milik bagian baru untuk mengakali jatah CI B6.


### [GPT] B6 Status QR — penyelesaian, 5 Oktober 2026
- Status: SELESAI. Menggantikan status MENTOK pada laporan B6 sebelumnya; dua kegagalan tetap tercatat sebagai riwayat.
- Otorisasi Koko: khusus B6 boleh improve tampilan bila mentok, tidak harus identik piksel. Sesudah dijelaskan jatah awal 2/2 habis, Koko secara eksplisit mengizinkan satu CI tambahan (“Ya ijinkan”, 5 Oktober 2026 sekitar 03.31 WIB). Pengecualian ini hanya untuk B6; batas bagian lain tetap mengikuti dokumen.
- Perbaikan final: clipping pola QR memakai `ClipRRect(borderRadius: BorderRadius.zero)` seperti renderer cermin, menggantikan `ClipRect`. Selisih 254 piksel pada kedua lebar hilang; kelonggaran desain akhirnya tidak perlu dipakai. Tidak mengubah label, layout, warna, aksi, fixture, HTML/JS/CSS, halaman lain, workflow, atau toleransi tes.
- File pada penyelesaian ini: `mobile/lib/native/qrstatus_page.dart`, `GOYANA-PROGRESS.md`, `GOYANA-SAMPAI-SELESAI.md`, `GOYANA-DART-SOLANA.md`. Berkas sambungan, tes dan baseline dari dua commit B6 sebelumnya tetap berlaku tanpa perubahan tambahan.
- Commit kode final: `80321067f2c7d7f06cc96245c92e2d5649a68c02`, tree `75609fb1107ab19ab666deda1f1cf32cf480c50d`. Pull rebase sebelum publikasi; blob/tree konektor diverifikasi sama dengan commit lokal; update branch `flutter/native` tanpa force. Tidak ke main.
- CI tambahan: run `37232495189`, job `111524972143`, SUCCESS. Bridge 31 PASS; analyze tanpa temuan; unit 123/123 PASS; screenshot 110/110 PASS. Paritas native versus renderer cermin 390 dan 320 px lulus nol piksel berbeda; golden B6 terkunci lulus. Tes aksi back/cari/full-screen, input dan navigasi pada kedua lebar serta model kosong/berubah bentuk lulus.
- Golden B6 tidak diperbarui: blob `cabf46b6afbd83f77afc3a13037fb0b4e44511f1` tetap sama dengan baseline sebelum migrasi dan hasil `ci-screens` final `c368284ad12f768a0c7aa529de864eac1b8c374d`. Golden B3 dan seluruh screenshot Flutter halaman lain tetap sama dengan hasil B5.
- APK: build release sukses (53.0 MB menurut Flutter); artifact `GOYANA-Flutter-Uji` dan publikasi GitHub Release `flutter-uji` sukses. Asset `GOYANA-Flutter-Uji.apk` 53.021.031 byte; catatan release menunjuk commit `80321067f2c7d7f06cc96245c92e2d5649a68c02`. Link: https://github.com/rajabadutiklan-lab/Goyana/releases/download/flutter-uji/GOYANA-Flutter-Uji.apk . Uji pada HP nyata belum dilakukan dalam sesi ini.
- Jatah CI: 2/2 awal + 1/1 tambahan berizin = 3 total run kode B6. Tidak ada run keempat/rerun. Laporan terpisah `[GPT] B6 Status QR` dengan skip CI agar dokumentasi tidak memicu run tambahan.
- Temuan di luar scope: perbandingan seluruh tree screenshot B5→B6 hanya menambah `qrstatus_native.png` dan mengubah `cashclose_html_390.png`. Gambar Tutup Kasir HTML dari Playwright (`tests/flutter-bridge.cjs:409`) bergeser vertikal 32 px, sementara screenshot Flutter Tutup Kasir tetap sama. Kode/tes halaman tersebut tidak disentuh. Penyebab posisi scroll capture perlu pemeriksaan tersendiri; tidak dianggap perubahan produk B6 dan tidak diperbaiki sekalian.
- Batas fungsi lama tetap: gambar QR masih pola contoh HTML, bukan payload QR status pesanan nyata; tombol full screen meneruskan aksi alert HTML. Migrasi tampilan tidak mengubah aturan/fungsi itu.
- Urutan berikutnya: B8 Checkout Paket, capture fixture dahulu. Hambatan suite dari dua tes B6 sudah selesai; tidak perlu melewati atau melonggarkan tes untuk bagian berikutnya.


### [GPT] QR-1 QR Status Pesanan + web pelanggan — 5 Oktober 2026
- Status: MENTOK pada pengujian akhir. Implementasi tombol/popup Android dan desain web dibuat; bukan status backend publik aktif. Tidak ada APK baru untuk QR-1 karena CI kedua gagal di tes pembanding QR. APK Flutter terpublikasi masih commit B6 `8032106`.
- Otorisasi/scope: Koko meminta tombol QR ditaruh rapi di Rincian Pesanan dan merombak web, lalu memilih “Halaman status pelanggan”. Setelah Koko mengingatkan QR sudah ada pada nota, kode dicek: nota memang mengenkode `https://goyana.id/s/<nomor pesanan>`. Tombol baru adalah cara menampilkan QR yang sama tanpa cetak ulang, bukan penggantian QR nota atau menu tambahan di Pengaturan. Pekerjaan ini tambahan di luar urutan B8, dicatat sebagai QR-1; B8 belum dikerjakan.
- Android: tombol sekunder putih/garis abu 46 px di bawah Kirim Nota WA. Popup native memakai `qr_flutter` yang sudah menjadi dependency, nomor pesanan dan nama dari rincian aktif. ID kosong/tidak valid tidak diberi tombol; tidak ada ID demo cadangan. Shell menambahkan import dan callback popup, pengaman A4 dan indeks aksi HTML lama tidak berubah. Widget lama tanpa callback tetap memakai layout lama.
- Web: `web/customer-status.html` adalah frontend status pelanggan yang baru, terpisah dari dashboard owner dan aset APK. Ringkasan nomor/order/outlet, status/timeline, estimasi WIB, layanan, pembayaran dari payload, kontak outlet. Default tanpa payload: “Status belum tersedia”. Contoh hanya dengan `?preview=1` dan badge Pratinjau; tidak menganggap pesanan pada URL sudah selesai/tersinkron. `web/README.md` menjelaskan kontrak payload dan kebutuhan route/otorisasi/data/hosting. Tidak membuat backend publik, tidak deploy, tidak membeli VPS/domain, dan tidak mengekspose data transaksi melalui ID yang dapat ditebak. Desain web belum online.
- File berubah: `mobile/lib/native/order_detail_page.dart`, `mobile/lib/native/order_status_qr.dart`, `mobile/lib/hybrid/shell.dart`, `mobile/test/order_status_qr_screens_test.dart`, `tests/customer-status.cjs`, `tests/flutter-bridge.cjs` (memanggil tes web tambahan), `web/customer-status.html`, `web/README.md`, `GOYANA-PROGRESS.md`, `GOYANA-SAMPAI-SELESAI.md`. Tidak mengubah HTML/CSS/JS aplikasi lama, fixture, fungsi nota, logika hitungan, kamera, backend, workflow, atau dependency.
- Commit kode: `73689bee4016d719c15cf3a157c1fd4fe9d9c0ed` (fitur/frontend/tes) dan `762e81969c4a748e946dae38522a9b3264112154` (pembanding pola QR). Pull rebase dan tree/blob dicocokkan sebelum publikasi konektor; branch flutter/native, tanpa force, tidak main.
- CI 1: run `37234925719`, job `111532019510`, FAILURE di analyze karena tes mencoba getter `QrImageView.data` yang tidak tersedia. Bridge lama 31 PASS + tes web baru PASS (32 baris PASS); browser web 390/320, semua status, default kosong, mode preview eksplisit, payload berbahaya/invalid lulus. Unit/screenshot/APK Flutter dilewati setelah analyze gagal.
- CI 2: run `37235267117`, job `111532992462`, FAILURE di screenshot. Bridge 32 PASS; analyze bersih; unit 123/123 PASS; screenshot 111 PASS, 2 FAIL. Pembukaan tombol, ID pesanan aktif, dan rendering sampai sebelum pembanding QR pada kedua lebar terjangkau. Tes gagal karena `_qrPixels(expected)` memanggil `QrPainter` dengan `QrEyeStyle.color`/`QrDataModuleStyle.color` kosong, menghasilkan null-check error pada painter tes. Tidak ada bukti selisih QR produk; pembandingan dan snapshot popup belum selesai. APK Flutter/artifact APK/publikasi dilewati. B6 paritas/golden dan tes layar lain lulus; tidak melonggarkan tes atau memperbarui golden lama untuk mengakali kegagalan.
- Perbaikan berikutnya sudah disiapkan lokal: memberi warna hitam eksplisit pada eye/data module pembanding tes, sesuai warna QR aktual. Belum dipush/dijalankan karena jatah CI habis. Tidak menyebutnya sudah lulus.
- Jatah CI QR-1: 2/2 terpakai. Satu CI tambahan yang sebelumnya diizinkan Koko hanya berlaku B6 dan sudah dipakai; tidak dianggap izin CI ketiga QR-1. Laporan terpisah `[GPT] QR-1 QR Status Pesanan + web pelanggan` skip CI. Pengujian tambahan perlu izin baru.
- Koreksi laporan B6: pernyataan bahwa tombol full screen HTML hanya alert kurang tepat. Script akhir `fullQR135` menimpa onclick dan membuat QR nyata untuk URL status. Gambar pada kartu B6 tetap checker contoh. Ini tidak mengubah kesimpulan paritas B6, tetapi penting membedakan kartu contoh dari generator QR layar penuh/nota. Backend route status publik masih belum tersedia di repo.
- Lanjutan: setelah izin satu pengujian tambahan, selesaikan tes dan publikasikan screenshot tombol/popup/web serta APK. Aktivasi web status nyata memerlukan penyambungan backend terpisah; frontend ini tidak mengklaim server telah online.


### [GPT] QR-1 QR Status Pesanan + web pelanggan — penyelesaian, 5 Oktober 2026
- Status: SELESAI untuk scope tampilan yang diminta Koko (tombol/popup Android dan desain web pelanggan). Menggantikan status MENTOK pada laporan QR-1 sebelumnya; riwayat dua kegagalan tetap dipertahankan. Backend/route/otorisasi tautan/hosting web belum tersambung, sehingga ini tidak menyatakan layanan status pelanggan sudah online.
- Otorisasi: setelah dijelaskan bahwa izin tambahan sebelumnya hanya B6 dan jatah QR-1 2/2 habis, Koko memberi izin satu CI tambahan (“Ya dah saya injinkan”, 5 Oktober 2026 08.03 WIB). Izin untuk menguji, bukan mengubah halaman lain.
- Perbaikan akhir hanya dua baris di `mobile/test/order_status_qr_screens_test.dart`: warna hitam eksplisit pada `QrEyeStyle` dan `QrDataModuleStyle` pembanding tes. Tidak mengganti kode tombol, popup, desain web, QR nota, hitungan, pengaman A4, indeks aksi HTML, halaman lain, atau baseline lama.
- File pada putaran penyelesaian: `mobile/test/order_status_qr_screens_test.dart`, `GOYANA-PROGRESS.md`, `GOYANA-SAMPAI-SELESAI.md`. Implementasi delapan berkas dari dua commit QR-1 sebelumnya tetap sama. Pull rebase sebelum publikasi; blob/tree diverifikasi sesuai lokal; branch flutter/native tanpa force, tidak main.
- Commit perbaikan: `23c6be904d8216d83c59e46b4bbf6058e7acde8d`, tree `36fce26155ba6f112ebe53b73fe671c9b32e9800`. Laporan terpisah `[GPT] QR-1 QR Status Pesanan + web pelanggan` skip CI.
- CI final: run `37249960342`, job `111575421839`, SUCCESS. Bridge 31 tes lama + 1 tes web = 32 PASS; analyze tanpa temuan; unit 123/123 PASS; screenshot 113/113 PASS. Tes native 320/390 memastikan tombol, aksi nota lama, pembukaan popup dengan nomor pesanan aktif, pola QR sama dengan QR untuk URL nota pesanan tersebut, dan penutupan popup. Helper ID menolak model kosong/invalid tanpa ID contoh.
- Web browser: 390/320 tanpa overflow horizontal; seluruh status jemput/antrian/cuci/kering/setrika/packing/siap/diambil/batal, status tidak dikenal, payload kosong/invalid, URL kontak invalid, escaping teks dan mode Pratinjau eksplisit lulus. Frontend tidak memanggil API yang belum ada, tidak membuat data transaksi contoh pada mode normal, dan tidak dimasukkan ke aset APK.
- Snapshot final tersedia di branch `ci-screens` `94e27f84bacef99d5772cd30ee98e8e8cc628842`: tambahan `order_detail_with_qr_320.png`, `order_detail_with_qr_390.png`, `order_status_qr_native_320.png`, `order_status_qr_native_390.png`, `customer_status_320.png`, `customer_status_390.png`. Gambar baru adalah hasil desain berizin untuk tinjauan; bukan baseline terkunci baru yang sudah disetujui untuk pengujian regresi berikutnya. Perbandingan dengan B6 `c368284` menunjukkan seluruh screenshot Flutter lama, termasuk golden B3/B6, tetap identik.
- Temuan di luar scope masih sama: `cashclose_html_390.png` (capture HTML Playwright) berubah posisi scroll; screenshot Flutter Tutup Kasir tetap identik dan kode tidak disentuh. Font MaterialIcons tidak dimuat oleh loader screenshot tes baru (hanya Poppins), sehingga beberapa glyph ikon tampil sebagai kotak pengganti pada gambar tes. Log APK memastikan MaterialIcons-Regular.otf ikut dibundel dan tree-shaken menjadi 5.012 byte. Tampilan pada HP nyata belum diuji di sesi ini; tidak memperbaiki lingkungan font/capture halaman lain sekalian.
- APK release/artifact/publikasi `flutter-uji` sukses; asset `GOYANA-Flutter-Uji.apk` 53.053.959 byte (53.1 MB menurut Flutter), catatan release menunjuk `23c6be904d8216d83c59e46b4bbf6058e7acde8d`. Link: https://github.com/rajabadutiklan-lab/Goyana/releases/download/flutter-uji/GOYANA-Flutter-Uji.apk . Tambahan dari APK B6 32.928 byte; halaman web pelanggan tidak ikut di APK.
- Jatah CI QR-1: 2/2 awal + 1/1 tambahan berizin = 3 run kode total. Tidak ada CI keempat/rerun. Dokumentasi tidak memicu CI tambahan.
- Akses Android: Pesanan → buka Rincian Pesanan → gulir ke aksi nota → QR Status di bawah Kirim Nota WA. QR berisi URL pesanan yang sama dengan nota. Ini popup native baru untuk pesanan aktif; halaman B6 lama dengan kolom pencarian/contoh tidak ditambahkan sebagai menu terpisah.
- Batas aktivasi web: `web/customer-status.html?preview=1` untuk meninjau desain. Data sebenarnya harus diberikan adapter server sesuai kontrak `web/README.md`, dengan otorisasi tautan publik dan pemisahan usaha. Belum deploy atau membuat route publik berdasarkan nomor pesanan saja. Langkah penyambungan backend merupakan pekerjaan terpisah setelah server tersedia.


### [GPT] B8 Checkout Paket — 5 Oktober 2026
- Status: MENTOK pada batas 2 CI. Widget dan sambungan sudah ditulis, tetapi B8 BELUM dinyatakan selesai karena 3 tes screenshot masih gagal. Tidak lanjut B9 dalam putaran ini.
- Basis: `flutter/native` `14090e18fecad3676bb6e2b2edd8ce1233cd54cb`; pull rebase dilakukan sebelum mulai dan sebelum setiap publikasi. Aturan bagian 0 dan urutan bagian 8 dibaca. Paduka mengonfirmasi tetap kerjakan sesuai urutan setelah temuan checkout tersembunyi ditanyakan.
- Lingkup kode: `mobile/lib/native/checkout_page.dart` (baru), `mobile/lib/hybrid/shell.dart` (hanya import, sambungan checkout111, pengecualian NativeMirrorPage), `mobile/test/checkout_screens_test.dart` (baru), `mobile/test/fixtures/mirror_pages/checkout111.json` (baru), `mobile/test/fixtures/mirror_pages/checkout111_cases.json` (baru), `tests/parity/checkout111.cjs` (baru), `tests/flutter-bridge.cjs` (tambahan pemeriksaan B8). Laporan/tabel: `GOYANA-PROGRESS.md`, `GOYANA-SAMPAI-SELESAI.md`, `GOYANA-DART-SOLANA.md`.
- Widget memakai susunan checkout native: judul, item paket, outlet, tambahan cabang/nomor, metode, promo/kode aktivasi, rincian dan bar total. Teks, angka, warna, ukuran dan indeks aksi tetap berasal dari model HTML. Tombol memakai `_mirror('button', i)`, input memakai `_mirror('input', i, value)`. Indeks berubah saat tombol hapus promo muncul dan tetap dibaca dari model. Pengaman Dart shell terbukti identik dengan sebelum B8 setelah tiga sambungan B8 dikeluarkan dari pembandingan sumber.
- Cadangan: Map/List/angka/indeks diperiksa; tidak memakai .single atau cast angka tanpa cek. Angka non-finite/negatif, warna CSS rusak, gaya dan struktur kosong ditangani. Tes model kosong dan struktur/gaya berubah lulus. Tidak mengarang nomor pelanggan atau transaksi pada model kosong.
- Patokan: 5 kondisi × 2 lebar (390/320): plan, addons 12 bulan + VA BCA, promo HEMAT12, promo salah, kode aktivasi. Capture hanya mengaktifkan DOM checkout di browser uji terisolasi; tidak mengganti openPage/placeOrder produksi. Font Poppins dari aset Flutter dimuat eksplisit untuk menghindari metrik font cadangan host. Capture ulang + pembandingan seluruh fixture, aksi jumlah cabang, input promo uppercase, dan blokir pembelian lulus lokal.
- Temuan final HTML/JS: openPage checkout111/invoice111 masih diblokir. Patch `goyana-v190-subscription-layout.js` juga menonaktifkan placeOrder111, buyCab111 dan buyBot96; pesan akhirnya `Pembayaran Google Play dan verifikasi server belum terhubung. Paket belum diaktifkan.` Checkout tersembunyi masih memakai PRO, contoh Gramapuri/Cikarang/Bekasi, serta tambahan Rp25.000/cabang dan Rp30.000/nomor. Halaman Harga Paket aktif sudah memakai katalog baru. Ini dipertahankan sesuai konfirmasi Paduka, bukan diubah menjadi aturan paket baru. Perlu ditangani bersama backend/billing nanti. Tidak ada pembelian atau pembayaran nyata diaktifkan.
- CI 1: kode `3ff9cb622c7f8796dc263a220cbababf8cae83f7`, run `37253820396`, job `111586648069`, FAILURE. 32 pemeriksaan bridge lama/web lulus; tambahan B8 gagal deepEqual ukuran fixture karena font cadangan browser lokal dan CI berbeda (contoh lebar judul 226 vs 187). Analyze, unit, screenshot dan APK dilewati. Perbaikan font dilakukan sekaligus dengan penanganan elemen kosong dan gaya rusak.
- CI 2/final: kode `d458d23a28c4e65d78e9b91a841b271a8b6de671`, run `37254265597`, job `111587914002`, FAILURE pada screenshot. Bridge **33 PASS**, analyze **No issues found**, unit **123/123 PASS**. Screenshot **123 PASS / 3 FAIL**. Dua kegagalan native adalah kondisi promo setelah scroll ke bawah: 26.251 piksel pada 390 dan 11.192 pada 320. Tampilan atas kondisi promo lulus; 8 kondisi lain lulus penuh atas/bawah, aksi dan input. Kegagalan ketiga: tes cermin lama membaca `checkout111_cases.json` (List) sebagai satu model Map. Ini kesalahan penempatan fixture saya, bukan kegagalan halaman lain.
- Penyebab promo: pesan promo berisi anak anonim (teks berhasil) dan tombol hapus, bukan spans langsung. Cabang native saat ini mengabaikan anak pesan itu. Perbaikan sudah disiapkan lokal: render anak pesan melalui `_info(node)`; pindahkan kumpulan kasus ke `mobile/test/fixtures/parity/checkout111_cases.json` dan ubah 3 referensi alat/tes. Sintaks Dart dan JS serta pemeriksaan bentuk fixture lulus; perbaikan ini BELUM diuji Flutter/CI dan BELUM dipublikasikan. Disimpan di stash lokal `B8 prepared: relocate multi-case fixture and render promo message children` agar commit laporan tidak memasang kode yang belum diuji. Bila ada izin tambahan, terapkan kedua perbaikan bersama sebelum satu CI tambahan; jangan hanya memindahkan fixture.
- Golden: tes `screens/checkout_native.png` dibuat dan golden default 390 lulus pada runner CI 2. PNG belum dipublikasikan/dikunci di repo karena tahap kirim screenshot dilewati setelah kegagalan. Golden sumber B3/B6 tidak diperbarui; tes golden terkunci lama lulus. Tidak mengklaim seluruh byte screenshot lama identik karena hasil runner gagal tidak dikirim ke ci-screens. Branch screenshot tetap pada patokan sebelum B8 `94e27f84bacef99d5772cd30ee98e8e8cc628842`.
- APK: build/artifact/publikasi Flutter dilewati pada kedua CI. Tidak ada APK B8 baru; release flutter-uji tetap kode QR-1 `23c6be904d8216d83c59e46b4bbf6058e7acde8d` (53.053.959 byte). Workflow APK HTML lama terpisah bukan bukti build Flutter B8.
- Jatah CI: **2/2**, tidak ada CI ketiga/rerun. Publikasi menggunakan konektor GitHub tanpa force; hash semua blob/tree diverifikasi identik dengan commit lokal. Laporan dalam commit terpisah `[GPT] B8 Checkout Paket` dengan `[skip ci]`, tidak menambah jatah.
- Lokal: Chromium headless shell berjalan untuk capture. Bootstrap Flutter lokal ditolak pemeriksaan otomatis karena percobaan akses alamat metadata lingkungan yang berpotensi memuat kredensial; proses tidak dilanjutkan/dilewati dengan workaround. Formatter Dart mandiri digunakan hanya untuk sintaks; analyze/unit/screenshot diverifikasi dari CI, bukan diklaim berjalan lokal.
- Tidak mengubah index.html, patch JS/CSS produksi, capacitor.js, workflow, logika bisnis, kamera, halaman lain, atau baseline PNG lama. B8 tetap MENTOK sampai perbaikan + verifikasi mendapat jatah tambahan; bagian lain yang tidak bergantung dapat dikerjakan pada putaran berikutnya.


### [GPT] B8 Checkout Paket — penyelesaian berizin, 5 Oktober 2026
- Status: SELESAI untuk migrasi tampilan B8. Menggantikan status MENTOK sebelumnya; riwayat kedua kegagalan tetap dicatat. Tidak lanjut B9 dalam putaran ini.
- Otorisasi: setelah jatah awal 2/2 habis dan dua perbaikan dijelaskan, Paduka mengizinkan satu CI tambahan dengan “Ya”, 5 Oktober 2026 sekitar 09.22 WIB. Jatah total: 2/2 awal + 1/1 tambahan berizin = 3 run kode; tidak ada run keempat atau rerun.
- Perbaikan akhir: anak pesan promo berhasil dan tombol hapus kini dirender melalui `_info(node)` sesuai cermin. Fixture kumpulan kasus dipindahkan byte-identik dari `mobile/test/fixtures/mirror_pages/checkout111_cases.json` ke `mobile/test/fixtures/parity/checkout111_cases.json`, karena kolektor cermin lama membutuhkan satu Map per berkas. Tiga referensi alat/tes ikut diperbarui. Tidak mengganti baseline lama, melonggarkan toleransi piksel, atau melewati tes.
- File penyelesaian: `mobile/lib/native/checkout_page.dart`, `mobile/test/checkout_screens_test.dart`, `mobile/test/fixtures/parity/checkout111_cases.json` (relokasi), `tests/parity/checkout111.cjs`, `tests/flutter-bridge.cjs`, `mobile/test/screens/checkout_native.png` (baru), serta laporan/tabel `GOYANA-PROGRESS.md`, `GOYANA-SAMPAI-SELESAI.md`, `GOYANA-DART-SOLANA.md`. Implementasi/sambungan shell dan fixture canonical dari dua commit awal tetap berlaku tanpa perubahan tambahan.
- Commit perbaikan: `8b3aa5636edc583516b66d8c41aab009fe624b4a`, tree `d28c70e0e4b6cb716b8d3825889b48f7e4b10b07`. Commit golden terkunci: `f4389f4929a92a254911c8d7aec13300a2cfa43b`, tree `4f9e6801cde13b63a869619e7c0dd7bb87585533`, memakai `[skip ci]`. Laporan terpisah `[GPT] B8 Checkout Paket` juga skip CI. Pull rebase sebelum kerja/publikasi; semua blob/tree konektor diverifikasi identik dengan lokal; update flutter/native tanpa force, tidak main.
- CI tambahan final: run `37255282670`, job `111590902272`, SUCCESS. Bridge 33 PASS; analyze No issues found; unit 123/123 PASS; screenshot 125/125 PASS; build APK release, artifact dan publikasi release semuanya sukses.
- Paritas: seluruh 5 kondisi × lebar 390/320 lulus pembandingan native versus cermin pada tampilan atas dan setelah scroll ke bawah, nol piksel berbeda. Tes indeks tombol (termasuk indeks bergeser setelah promo), input, navigasi, serta model kosong/struktur/gaya berubah lulus. Capture browser memakai Poppins aset Flutter; fixture ulang, aksi jumlah tambahan, input uppercase dan pengaman pembelian produksi lulus.
- Golden baru: `mobile/test/screens/checkout_native.png` disalin byte-persis dari hasil CI yang lulus; blob `9c90f4b787d3d7f2d060e4d814976fc499164a08`, 94.923 byte. Tes mematikan autoUpdateGoldenFiles ketika baseline tersedia. Native dan cermin CI 390×844 terbukti identik RGBA. Branch ci-screens `a7035eb388262f2cf21911b4eed36efb6ff99ac9` dibanding baseline pra-B8 `94e27f84bacef99d5772cd30ee98e8e8cc628842` hanya menambah `checkout_native.png` dan `mirrorpage_checkout111.png`; seluruh screenshot lama, termasuk B3/B6, QR-1/web dan Tutup Kasir HTML, byte-identik. Tidak ada golden B3 atau gambar lama diperbarui.
- APK: asset `GOYANA-Flutter-Uji.apk` 53.152.263 byte (53.2 MB menurut Flutter); catatan release menunjuk kode `8b3aa5636edc583516b66d8c41aab009fe624b4a`. Link: https://github.com/rajabadutiklan-lab/Goyana/releases/download/flutter-uji/GOYANA-Flutter-Uji.apk . Uji HP nyata belum dilakukan dalam sesi ini.
- Temuan/batas fungsi tetap seperti laporan sebelumnya dan konfirmasi Paduka: checkout produksi masih tersembunyi/diblokir, memakai katalog PRO/contoh outlet lama; pembayaran Google Play/verifikasi server belum terhubung. Migrasi ini tidak mengaktifkan pembelian atau mengganti katalog/harga. Tampilan native tersedia untuk jalur checkout yang nantinya diaktifkan bersama billing/backend. Tidak mengubah HTML/JS/CSS produksi, pengaman Dart, logika bisnis, kamera, workflow, atau halaman lain.
- Pertanyaan untuk Paduka: tidak ada keputusan desain baru pada penyelesaian ini. Temuan katalog lama dan blokir pembelian sudah disampaikan serta diizinkan untuk tetap mengikuti urutan. Langkah berikutnya B9 sesuai bagian 8, pada putaran berikutnya.


### [GPT] B9 Tagihan — 5 Oktober 2026
- Status: SELESAI untuk migrasi tampilan halaman billing. Satu bagian per putaran; tidak lanjut B10 dalam putaran ini.
- Basis: flutter/native `670269b9ec5cde7d43c728d38f88f44b4abb3e5f`. Pull rebase sebelum mulai dan sebelum publikasi; aturan bagian 0, urutan bagian 8, peta native/cermin serta pola B8 diikuti. Sempat tertahan karena proses awal dihentikan dan percakapan “tunggu”; belum memakai CI pada jeda itu.
- File berubah: `mobile/lib/native/billing_page.dart` (baru), `mobile/lib/hybrid/shell.dart` (hanya import/sambungan/pengecualian billing), `mobile/test/billing_screens_test.dart` (baru), `mobile/test/fixtures/mirror_pages/billing.json` (baru), `mobile/test/fixtures/parity/billing_cases.json` (baru), `tests/parity/billing.cjs` (baru), `tests/flutter-bridge.cjs` (tambahan pemeriksaan B9), `mobile/test/screens/billing_native.png` (baru), serta `GOYANA-PROGRESS.md`, `GOYANA-SAMPAI-SELESAI.md`, `GOYANA-DART-SOLANA.md` (laporan/status).
- Patokan final: HTML membersihkan isi billing menjadi “Belum ada tagihan.” saat inisialisasi (`index.html` sekitar 11024). Kartu contoh invoice, metode pembayaran dan tombol cetak dari markup awal sudah dihapus oleh script final; tidak dihidupkan kembali. Judul final tetap BILLING & INVOICE. Native memakai susunan header/back dan pesan kosong ini, dengan gaya/ukuran/teks dari model. Tidak mengarang keadaan tagihan terisi yang belum ada di aplikasi final.
- Menu produksi: openPage('billing') tetap dialihkan ke txhist111 oleh patch final lama. Capture hanya mengekspos DOM billing di browser uji terisolasi; tidak menimpa openPage atau aturan produksi. Menu Riwayat Tagihan tetap membuka Riwayat Transaksi, sehingga widget billing ini tidak menambah jalur menu aktif baru. Temuan ini disampaikan kepada Paduka selama pengerjaan; persetujuan sebelumnya tetap mengikuti urutan migrasi halaman lama, tanpa mengaktifkan pembayaran.
- Aksi: back button 1, scan header 0, navigasi dari model; shell tetap memakai `_mirror('button', i)`. Capture menguji pengalihan menu, tombol kembali dan localStorage tidak berubah. Pemeriksaan sumber membuktikan seluruh shell sebelum B9 identik setelah tiga tambahan import/sambungan/pengecualian B9 dikeluarkan; pengaman Dart, logika bisnis, kamera dan indeks aksi lama tidak disentuh.
- Cadangan: Map/List/angka/indeks diperiksa, angka non-finite dan ukuran negatif ditangani, warna rusak ditangani. Tanpa .single, cast angka tanpa cek, atau akses indeks list tanpa cek panjang. Model kosong/struktur/gaya berubah tetap menampilkan BILLING & INVOICE serta Belum ada tagihan. dan tidak crash. Gaya cadangan mengikuti gaya final empty state; tidak membuat aksi back palsu ketika indeks model tidak ada.
- Lokal: capture 390/320 diulang dan identik dengan fixture; tombol kembali/pengalihan menu/storage lulus. Semua fixture canonical tetap Map, kumpulan dua kasus disimpan terpisah di parity. Parser JS, formatter/parser Dart mandiri serta git diff --check lulus. Flutter analyze/unit/screens tidak dijalankan lokal; diverifikasi dari CI. Tidak mencoba lagi bootstrap Flutter lokal yang sebelumnya ditolak pemeriksaan otomatis.
- Commit kode: `d626683df1407e999592282220113a9dce15a6eb`, tree `7203e5cc5ef0c2fcf55e7b8408e2018218cd2b87`. Golden terkunci: `996e179bd0bd17e18ac8f7efa18ce7c987b182d0`, tree `39d6ffbdd215221e33bdd221fb63cfbe4ef8a74d`, `[skip ci]`. Publikasi konektor GitHub, blob/tree sama dengan lokal, update flutter/native tanpa force; tidak main. Laporan commit terpisah `[GPT] B9 Tagihan` dengan skip CI.
- CI 1/final: run `37258574092`, job `111600732633`, SUCCESS. Bridge 34 PASS; analyze No issues found; unit 123/123 PASS; screenshot 129/129 PASS; build APK release, artifact dan publikasi release sukses.
- Paritas: native versus cermin atas/bawah pada 390 dan 320 lulus nol piksel berbeda. Tes tombol kembali, navigasi dan model kosong/berubah bentuk lulus. Golden billing default 390 dibuat pada CI yang lulus paritas, disalin byte-persis ke repo; tes mematikan autoUpdateGoldenFiles bila baseline tersedia. PNG native dan mirror hasil CI identik RGBA 390×844; blob native `7dbed7614e14c395b8ee8affa646e59b2599edc8`.
- Screenshot: ci-screens final `3c2da29eca7bfd31344ab7b76ecc986c254b9a35` dibanding pra-B9 `a7035eb388262f2cf21911b4eed36efb6ff99ac9` hanya menambah billing_native.png/mirrorpage_billing.png dan mengubah cashclose_html_390.png. Seluruh screenshot Flutter lama, termasuk golden B3/B6/B8 dan QR-1, byte-identik. Golden lama tidak diperbarui.
- Temuan di luar scope: capture HTML Tutup Kasir bergeser vertikal 15 px; pembandingan PNG setelah translasi 15 px terbukti nol piksel berbeda pada area tumpang tindih. Screenshot Flutter Tutup Kasir tetap identik, kode/tes halaman tersebut tidak diubah. Ini dicatat sebagai variasi posisi capture HTML, bukan perubahan produk B9; tidak diperbaiki sekalian.
- APK: GOYANA-Flutter-Uji.apk 53.185.031 byte (53.2 MB menurut Flutter); catatan release menunjuk kode `d626683df1407e999592282220113a9dce15a6eb`. Link: https://github.com/rajabadutiklan-lab/Goyana/releases/download/flutter-uji/GOYANA-Flutter-Uji.apk . Belum diuji di HP nyata dalam sesi ini.
- Jatah CI B9: 1/2 terpakai, tidak ada run kedua atau rerun. Commit golden/laporan skip CI. Tidak mengubah HTML/JS/CSS produksi, workflow, backend, dependency, halaman lain atau aturan pembayaran.
- Pertanyaan untuk Paduka: tidak ada keputusan desain/aturan bisnis baru. Menu billing yang dialihkan dan empty state lama dipertahankan; pembayaran nyata tetap pekerjaan backend/billing terpisah. Berikutnya B10 Invoice, tangkap fixture final dahulu, pada putaran berikutnya.


### [GPT] B10 Invoice — 5 Oktober 2026
- Status: SELESAI untuk migrasi tampilan final invoice111 saat ini (header TAGIHAN dan area kosong). Tidak menyatakan invoice terisi/pembayaran sudah tersedia. Satu bagian per putaran; B11 belum dikerjakan.
- Basis: flutter/native 642bf66c2724a8ee62dac67c6bd1e3657199abdf. Pull rebase sebelum mulai dan sebelum publikasi; aturan bagian 0 dan urutan bagian 8 diikuti. Temuan halaman lama diblokir dipertahankan sesuai izin Paduka sebelumnya untuk tetap mengikuti urutan.
- File berubah: mobile/lib/native/invoice_page.dart, mobile/lib/hybrid/shell.dart (hanya import/sambungan/pengecualian invoice111), mobile/test/invoice_screens_test.dart, mobile/test/fixtures/mirror_pages/invoice111.json, mobile/test/fixtures/parity/invoice111_cases.json, tests/parity/invoice111.cjs, tests/flutter-bridge.cjs (tambahan B10), mobile/test/screens/invoice_native.png, GOYANA-PROGRESS.md, GOYANA-SAMPAI-SELESAI.md, GOYANA-DART-SOLANA.md.
- Temuan final HTML: TX mulai kosong dan tidak disimpan ke localStorage; pembuatan transaksi placeOrder111 serta checkPay111 diblokir patch final. openPage('invoice111') juga diblokir sebelum patch lama yang mengisi pesan “Belum ada tagihan yang dibuka...” sempat berjalan. DOM final inv111 benar-benar kosong. Fixture tidak menghidupkan patch pesan lama atau kartu contoh/QRIS demo. Detail invoice menunggu backend/billing nyata dan model terisi yang disepakati; widget ini tidak mengimplementasikan kartu invoice terisi yang belum tersedia pada jalur produksi final.
- Capture: browser uji terisolasi mengekspos DOM invoice111 secara manual untuk membaca mirror. Tidak menimpa openPage, placeOrder111 atau renderer produksi. Pemeriksaan membuktikan menu Invoice tetap ditolak dengan pesan pembelian belum tersedia; back button 1 membuka Riwayat Transaksi dan storage tidak berubah. Poppins aset Flutter dimuat agar fixture tidak bergantung font host. Capture ulang 390/320 identik.
- Native: header/topbar, back, judul TAGIHAN, area abu kosong fixed dan navigasi mengikuti nilai model final, tanpa membuat nomor/nominal/status sukses palsu. Back memakai _mirror('button', 1) dari model, scan indeks 0 dari model. Pemeriksaan sumber membuktikan shell sebelum B10 identik setelah tiga tambahan import/sambungan/pengecualian dikeluarkan; pengaman Dart dan bagian lain tidak berubah.
- Cadangan: Map/List/angka/indeks diperiksa; tidak ada .single, cast angka tanpa cek, atau indeks list tanpa cek panjang. Model kosong/bentuk/gaya rusak tetap tampil judul TAGIHAN tanpa crash atau status pembayaran palsu. Nilai warna, ukuran, teks punya cadangan. Semua fixture mirror_pages tetap Map; dua kasus lebar disimpan terpisah di parity.
- Lokal: capture ulang/guard/back/storage, parser JS, formatter/parser Dart mandiri, pemeriksaan shell dan git diff --check lulus. Flutter analyze/unit/screens diverifikasi dari CI, bukan dijalankan lokal; bootstrap Flutter lokal yang pernah ditolak pemeriksaan otomatis tidak dicoba lagi.
- Commit kode: 7c7e0df2e61a8a8b0b7930dcf3253ed9c958c502, tree 711028800ec2c76b52fef9cf6afd1c918f38ea6e. Golden: bbc8df527314bdb8aa00d2df91a84735ea0fcf31, tree 22b955229ed1a9e870f806ab729a5947ebab2911, skip CI. Laporan terpisah [GPT] B10 Invoice dengan skip CI. Publikasi konektor; blob/tree diverifikasi sama dengan lokal, update flutter/native tanpa force, tidak main.
- CI 1/final: run 37264788768, job 111619183244, SUCCESS. Bridge 35 PASS; analyze No issues found; unit 123/123 PASS; screenshot 133/133 PASS; build APK release, artifact dan publikasi release sukses..
- Paritas: native versus cermin pada 390/320, atas dan setelah scroll ke bawah, nol piksel berbeda. Tes indeks back, navigasi, model kosong/berubah bentuk lulus. Golden baru dibuat hanya setelah paritas CI lulus lalu disalin byte-persis; tes menonaktifkan autoUpdateGoldenFiles bila baseline sudah ada. PNG native/mirror 390×844 identik RGBA, native 52.031 byte, blob 82e96b1eebe5cf5ea6248458969e4ef4e3ad8457.
- Screenshot: ci-screens eee76c49a66e0d29263b9b45d195e307bb309a4f dibanding pra-B10 3c2da29eca7bfd31344ab7b76ecc986c254b9a35 hanya menambah invoice_native.png dan mirrorpage_invoice111.png. Seluruh screenshot lama, termasuk golden B3/B6/B8/B9, QR-1/web dan capture HTML Tutup Kasir, byte-identik. Tidak ada golden lama diperbarui.
- APK: GOYANA-Flutter-Uji.apk 53.201.415 byte (53.2 MB menurut Flutter). Catatan release menunjuk kode 7c7e0df2e61a8a8b0b7930dcf3253ed9c958c502. Link: https://github.com/rajabadutiklan-lab/Goyana/releases/download/flutter-uji/GOYANA-Flutter-Uji.apk. Uji HP nyata belum dilakukan dalam sesi ini.
- Jatah CI B10: 1/2 terpakai, tidak ada run kedua/rerun. Golden/laporan skip CI. Tidak mengubah HTML/JS/CSS produksi, workflow, dependency, backend, kamera, hitungan, halaman lain atau aturan pembayaran.
- Pertanyaan/lanjutan: tidak ada desain/aturan bisnis baru yang diputuskan. Batas invoice kosong/diblokir disampaikan selama pengerjaan. Invoice terisi harus dilengkapi bersama aktivasi billing/backend, dengan fixture nyata baru; belum diuji/diaktifkan pada B10 ini. Berikutnya B11 Otomasi WA pada putaran berikutnya.


### [GPT] WA-PAIR Hubungkan WhatsApp QR + kode — 5 Oktober 2026
- Status: SELESAI (tampilan dan routing popup native); integrasi QR/kode nyata tetap menunggu API CHATKU pada F5. Paduka secara eksplisit meminta popup pilihan Scan QR atau kode WhatsApp dan mengizinkan pengerjaan. Ini satu putaran tambahan WA-PAIR, bukan penyelesaian B11.
- Basis: flutter/native 911d4e7b935c9dd73422701a2dbf8a78fcfe183f; pull rebase dilakukan sebelum mulai dan sebelum publikasi. Aturan bagian 0 dan urutan bagian 8 diikuti; koreksi popup sesuai permintaan terbaru Paduka didahulukan.
- File kode/tes: goyana-v195-wa-devices.js; mobile/web_bridge/capacitor.js (hanya tambahan wa195-pair pada GENERIC_SHEETS); tests/parity/wa_pair195.cjs; tests/flutter-bridge.cjs; mobile/test/fixtures/parity/wa_pair195.json; mobile/test/wa_pair_screens_test.dart. Golden baru: wa_pair_qr_390.png, wa_pair_qr_320.png, wa_pair_code_390.png, wa_pair_code_320.png di mobile/test/screens. Laporan/tabel: GOYANA-PROGRESS.md, GOYANA-SAMPAI-SELESAI.md, GOYANA-DART-SOLANA.md.
- Akses: Pengaturan → Hubungkan WhatsApp → Hubungkan pada perangkat. Popup menampilkan nomor/cabang, pilihan Scan QR dan Kode WhatsApp, petunjuk masing-masing, serta keterangan layanan belum terhubung. Pilihan aktif ditandai. Saat dibuka ulang pilihan kembali QR. Tutup, backdrop, Escape dan berpindah halaman menutup popup; fokus kembali ke tombol pemanggil.
- Android menggunakan NativeSheet/NativeForm yang sudah ada (popup bawah), web memakai dialog pusat yang sudah ada. Ini perubahan tampilan berizin, bukan klaim nol piksel terhadap popup lama yang hanya berisi pemberitahuan. Label/petunjuk masih berasal dari HTML; pemindahan definisi ke Dart termasuk jalur C. Tidak mengubah shell.dart, pengaman Dart, kamera, hitungan, API, workflow atau dependency.
- Indeks HTML popup tetap 0 Scan QR, 1 Kode WhatsApp, 2 Tutup; native memakai __goyanaForm scope wa195-pair. Penutupan native memakai close,0 yang menjalankan handler host dan membersihkan hidden/show. Registrasi sheet memastikan popup tidak mengalihkan halaman native kembali ke WebView.
- Tidak membuat QR, kode pairing, OTP atau status Terhubung palsu. Tidak mengirim pesan/permintaan ke endpoint CHATKU yang ditebak. Storage perangkat dan WA141.conn tetap tidak berubah saat memilih metode. Untuk menautkan sungguhan perlu dokumentasi API CHATKU (F5-1); engine tetap server terpisah.
- Lokal: capture empat kasus (QR/kode × 390/320) dan capture ulang byte/model stabil lulus; routing scoped, close/reopen/Escape/navigation, tidak overflow horizontal, storage/conn tidak berubah lulus. Tes perangkat lama (multi-device, validasi, edit/hapus/reload, cabang) dan alur QRIS (unggah, batal, file chooser, pencatatan pembayaran sekali) lulus. Sintaks JS, formatter/parser Dart mandiri dan git diff --check lulus. Flutter diuji di CI, bootstrap lokal yang pernah ditolak tidak dicoba lagi.
- Commit kode awal: da93286c6b316be00002984ecba0dfa011782177, tree 2ea4b3db93b0b864182ca983801ec3f7d3a3175d. Kode final: d9db2d257f677ebc416bec4b910e7fb5c38a0429, tree 051b8d4612e1f90d0a908e7d98ac44473f2a24ff. Golden: 641000c3aa0aea7cb060d78f33ab5c9ee2c07246, tree e776372cbc7869c04174afb0705a46ca99d4130b, skip CI. Laporan commit terpisah [GPT] WA-PAIR Hubungkan WhatsApp QR + kode, skip CI. Blob/tree publikasi konektor diverifikasi sama dengan lokal; update flutter/native tanpa force, tidak main.
- CI 1: run 37266456849, job 111624224324, SUCCESS. Bridge 36 PASS, analyze No issues found, unit 123/123 PASS, screenshot 137/137 PASS, build/artifact/release APK sukses. Tinjauan gambar menemukan glyph panah pada petunjuk native tampil kotak; seluruh petunjuk diubah menjadi kalimat biasa dan fixture ditangkap ulang sekaligus sebelum CI kedua. Bukan mengganti font/dependency atau memperbaiki halaman lain.
- CI 2/final: run 37267145708, job 111626246640, SUCCESS. Bridge 36 PASS; analyze No issues found; unit 123/123 PASS; screenshot 137/137 PASS; build APK release, artifact dan publikasi release sukses.
- Screenshot: ci-screens final c6ee9290f74e17d656670d512e298054cc86354e dibanding pra-putaran eee76c49a66e0d29263b9b45d195e307bb309a4f hanya menambah empat PNG popup. Seluruh screenshot lama, termasuk B3/B6/B8/B9/B10, QR-1/web dan cashclose_html_390.png, byte-identik. Snapshot CI pertama d6ce24f130d225a7ad0ba830a5b07507c67f1c92 sempat berbeda posisi scroll capture HTML Tutup Kasir; capture final kembali identik tanpa mengubah halaman/tes itu. Golden baru dikunci saat baseline sudah ada; golden lama tidak diperbarui. Snapshot native ditinjau pada 390/320; uji HP nyata belum dilakukan.
- APK: GOYANA-Flutter-Uji.apk 53.201.807 byte (53.2 MB menurut Flutter), catatan release menunjuk kode final d9db2d257f677ebc416bec4b910e7fb5c38a0429. Bertambah 392 byte dari APK B10. Link: https://github.com/rajabadutiklan-lab/Goyana/releases/download/flutter-uji/GOYANA-Flutter-Uji.apk.
- Jatah CI WA-PAIR: 2/2 terpakai (run kode awal + perbaikan petunjuk setelah tinjauan visual). Tidak ada CI ketiga/rerun. Golden/laporan skip CI.
- Temuan di luar scope: waautomation (B11) sekarang dialihkan ke whatsappbot yang sudah memakai formulir Flutter generik; tombol Hubungkan sebenarnya menuju wadevices195. B11 tetap belum dan perlu capture final berikutnya, bukan mengaktifkan ulang halaman demo ONLINE lama. Popup Tambah/Edit Device wa195-modal belum didaftarkan sebagai popup native; tidak diubah sekalian. Berikutnya kembali B11 pada putaran terpisah.
