# GOYANA — Serah Terima Tahap 3 (Claude → GPT/Codex)

Ditulis Claude, 11 Oktober 2026 pagi. Kuota Claude habis; lanjutkan dari sini. **Baca sampai habis sebelum mengubah apa pun.**

## 1. Posisi kode

- Repo `koimanasci-glitch/goyanaku`, branch **`backend/integrasi-whatsapp`** (commit terakhir Claude: "Tes: tombol Kelola di daftar outlet").
- Aplikasi HP: `mobile/` (Flutter **Mode Murni**, semua logika di Dart). Server: `backend/` (Laravel).
- Keputusan & riwayat: **`GOYANA-CATATAN-PADUKA.md`** (tambah catatan di paling bawah, satu baris per fitur selesai).
- Rancangan multi-cabang (dokumen Claude Docs): https://claude.ai/code/artifact/bd689e71-a1e5-44bd-8cb4-f375a07c4ad2 — **belum diperbarui**; edit sekali di akhir.

## 2. Aturan kerja Paduka (wajib)

1. Balas singkat, bahasa Indonesia. "catat" = hanya catat; "diskusi dulu" = jangan ubah kode.
2. Sentuh hanya yang diminta. **Jangan ubah tampilan utama** (Beranda, Tambah Transaksi, Pesanan, menu bawah). Fitur baru masuk **Pengaturan › Kelola Usaha** (`mobile/lib/pure/kelola_page.dart`).
3. **Selesaikan satu fitur sampai tuntas** sebelum fitur berikutnya: server + aplikasi + tes + CI hijau + audit tombol bersih + tautan APK. Lapor, tunggu "gas".
4. Jangan sentuh area sesi lain (perbaikan Chatku/QRIS di branch `backend/perbaikan-chatku`): `backend/app/WhatsApp/*`, `backend/app/Support/QuickReply.php`, QRIS (`mobile/lib/core/qris.dart` + halaman QRIS), `mobile/lib/pure/wa_pages.dart`, `wa_devices_page.dart`, `wa_link.dart`, media chatbot.
5. Paduka **tidak mau notifikasi yang bikin HP berisik** (butir notifikasi Tahap 3 dibatalkan 11 Okt).

## 3. Cara uji

- Backend lokal: `cd backend && vendor/bin/phpunit` (semua harus OK; ±160 tes).
- Flutter tidak ada di mesin Claude → diuji lewat CI GitHub Actions:
  - "Flutter Android (Mode Murni)": analyze, unit test, screens + **audit tombol** → `audit.txt` di branch `ci-screens` (`git fetch <repo> ci-screens && git show FETCH_HEAD:audit.txt`), lalu APK rilis `flutter-uji`.
  - "Backend foundation": phpunit.
- APK uji: https://github.com/koimanasci-glitch/goyanaku/releases/download/flutter-uji/GOYANA-Murni-Uji.apk
- Sebelum push: `git fetch && git rebase origin/backend/integrasi-whatsapp`.
- Tes parity membandingkan butir halaman dengan fixture HTML (`mobile/test/fixtures/pure/*.json`). Bila menambah tombol/butir di halaman lama, sesuaikan tesnya (lihat contoh "Outlet & Edit Outlet" di `test/pure_discount_test.dart`).

## 4. Pola kode penting

- Halaman: `PurePage` (`mobile/lib/pure/pages.dart`) → `items()` mengembalikan butir JSON (`title`, `hint`, `entry` + `btns`, `buttons`, `button`, `toggle`, `select`, `input`, `card`, `stats`, `hero`, `bars`, `hbars`, **`banner`** oranye baru). Kejadian: `button(i)`, `input(i,v)`, `toggle(i)`, popup `sheetItems(id)`/`sheetEvent(id, kind, index, value)`, `host.openPageSheet/closePageSheet`.
- Daftar halaman: `_pages` di `mobile/lib/pure/pure_shell.dart`; larangan per peran: `_srvDenied`.
- Sinkron: `mobile/lib/pure/server_sync.dart` (`extractLocal`, `applyRemote`, `_writeRules`, `_mayWrite`) ↔ `backend/config/goyana.php` `sync.collections` + `SyncController` (penjaga per koleksi di `app/Support/*Guard*`, `BranchTask`, `CaseGuard`, `StockGuard`, `AuditTrail`).
- Paket: `mobile/lib/pure/access.dart` (`_need`, `reportFeature`, `planAccess.has`) ↔ `backend/config/goyana.php` `plan_features` + `Business::allows()`. Trial = Basic.
- Zona waktu cabang: `Outlet::zoneOf()` di server.

## 5. Sisa pekerjaan Tahap 3 (urutan usulan, satu per satu)

1. ~~Notifikasi ke HP pemilik~~ — **dibatalkan**.
2. **Pengingat kerja di Pesanan (semua paket):** banner di atas daftar Pesanan "N cucian harus mulai dikerjakan" (tanpa bunyi). Hitung dari jatuh tempo − **lama pengerjaan per durasi** (Reguler/Express/Kilat), angka bisa diubah pemilik (mis. di Pengaturan › Durasi atau Kelola Usaha). Paduka sudah setuju banner di Pesanan.
3. **Ringkasan WA malam ke pemilik (Gold):** omzet, pesanan, telat, belum lunas, selisih kas per cabang. Kirim lewat CHATKU (jangan sentuh `app/WhatsApp/*`; buat jadwal di server) — kalau butuh ubah area WhatsApp, koordinasikan dulu.
4. **Target omset (Gold):** target per cabang per bulan + progres di Monitor Cabang.
5. **Kinerja staf (Gold):** data sudah ada di `/monitoring` (cashiers, production, couriers) — rangkuman per periode + komisi.
6. **Kapasitas & servis mesin (Silver):** daftar mesin per cabang, kapasitas kg/hari, jadwal servis + pengingat di dalam aplikasi.
7. **Rating WA (Gold):** link rating setelah cucian diambil.
8. **Cucian tidak diambil:** daftar + WA manual (semua paket); pengingat otomatis (Gold).
9. **Bandingkan & peringkat cabang + harga per cabang (Platinum).**
10. **Grafik di Monitor Cabang** (usulan, Paduka tertarik): kurva omzet harian per cabang, batang antar cabang, pesanan per tahap — pakai butir `bars`/`hbars` yang sudah ada.

## 6. Di luar tahap (menjelang rilis)

- **VPS + server online** (Docker; `deploy/`). Banyak fitur Tahap 2 (Tim, Monitor baru, halaman cabang lengkap, Kelola Cabang Ini kas, Riwayat/Koreksi) **baru tampil setelah login server**.
- Akun administrator: `php artisan goyana:admin` di server, lalu `/admin` + OTP.
- Pembayaran paket & tambahan akun via Google Play (belum tersambung).
- Perbarui dokumen rancangan sekali di akhir.

## 7. Batasan yang diketahui

- Kas "Kelola Cabang Ini" ke cabang lain masuk laci saat HP kasir cabang itu online; pengeluaran dari pemilik dianggap dari laci cabang.
- Riwayat & stok di Monitor Cabang (tab Riwayat/Stok) masih dari data HP.
- Kamera & pengecilan foto (Kotlin `MainActivity.kt`: `shrinkImage`, `captureFile`) belum diuji di HP sungguhan — minta Paduka coba.
