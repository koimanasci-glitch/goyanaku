# GOYANA — Instruksi Lanjutan untuk GPT/Codex

Ditulis Claude, 2 Oktober 2026. Baca file ini **sampai habis** sebelum mengubah apa pun.
Dokumen produk: `GOYANA-ROADMAP.md`, `GOYANA-SISTEM-PUSAT.md` (§38–§40 terbaru), `GOYANA-PROGRESS.md`.

---

## 0. Pembagian peran (keputusan pengguna)

- **GPT/Codex = pembangun.** Mengerjakan tugas di bagian 5 dan 7 sekarang.
- **Claude = pemeriksa & perbaikan.** Saat kuotanya tersedia lagi, Claude mengambil alih: memeriksa semua pekerjaan GPT, memperbaiki bug/tampilan, lalu melanjutkan.
- Supaya pemeriksaan cepat, **setiap selesai satu bagian GPT wajib menulis entri di `GOYANA-PROGRESS.md`** dengan format bagian 10 (apa yang diubah, file, tes, yang belum diuji). Tanpa catatan ini, pekerjaan dianggap belum siap diperiksa.

## 1. Kondisi sekarang (ringkas)

| Bagian | Status | Lokasi |
|---|---|---|
| Aplikasi HTML (58 halaman) | Jalan, sumber logika bisnis | `index.html`, `goyana-v1xx-*.js` |
| Aplikasi Android **Flutter hybrid** | Jalan. HTML dimuat di WebView, fitur HP native | `mobile/` |
| Penyimpanan HP | **SQLite** (menggantikan localStorage, otomatis) | `mobile/web_bridge/goyana-store.js`, `GoyanaStore.kt` |
| Sinkronisasi HP ↔ server | Selesai & diuji, **aktif setelah server dideploy** | `goyana-sync-core.js`, `goyana-v197-sync.js`, `backend/app/Http/Controllers/SyncController.php` |
| Backend Laravel | Akun, paket/langganan, role tim, OTP admin, API sync, dashboard owner | `backend/` |
| Halaman Flutter **native** | **Beranda ✅, Pesanan ✅**. Sisanya masih HTML | `mobile/lib/native/` |
| Deploy server | **BELUM** | — |

### Branch (penting)
```
main                      ← belum berisi pekerjaan di bawah (belum di-merge)
└ backend/laravel-foundation   (GPT, PR #1)
  └ flutter/hybrid             (Claude: shell Flutter)
    └ backend/akses-paket      (Claude: paket, role, OTP, sync, SQLite)
      └ flutter/native         ← PALING BARU. Lanjutkan dari sini.
```
Semua branch di atas bertumpuk; `flutter/native` berisi semuanya. Buat branch baru dari `flutter/native`, mis. `flutter/native-transaksi`.

APK uji otomatis terbit di GitHub Release **`flutter-uji`** setiap push ke `flutter/**` / `backend/**`.

---

## 2. Aturan wajib

1. **Jangan ubah tampilan HTML** kecuali diminta pengguna. Pengguna mengizinkan merapikan tampilan/tombol yang tidak rapi **di versi Flutter native**.
2. **Bahasa ke pengguna: Indonesia, singkat, langsung ke hasil.** Pengguna (Koko) lebih suka file/hasil siap pakai daripada instruksi manual.
3. Jangan push ke `main` langsung. Pakai branch + PR.
4. Jangan menaruh password/API key/secret di repo. (Pengecualian yang disengaja: `mobile/android/app/goyana-preview.jks` = kunci **uji** publik, jangan dipakai untuk Play Store.)
5. Jangan menyatakan fitur aktif sebelum diuji. Tulis status jujur di `GOYANA-PROGRESS.md`.
6. Setiap selesai satu bagian: jalankan tes (bagian 6), commit, push, cek CI hijau, update `GOYANA-PROGRESS.md`.

---

## 3. Arsitektur Flutter hybrid (wajib dipahami)

```
Flutter app (mobile/lib/hybrid/shell.dart)
 ├─ WebView memuat mobile/assets/web/index.html  (dibuat oleh tools/prepare_flutter_web.py)
 │    ├─ goyana-store.js   → window.localStorage = SQLite di HP (script PERTAMA di <head>)
 │    ├─ goyana-sync-core.js → terapkan data dari server sebelum app jalan
 │    ├─ capacitor.js (= mobile/web_bridge/capacitor.js) → jembatan ke Flutter
 │    └─ goyana-v197-sync.js → push/pull ke server
 ├─ lib/hybrid/bridge.dart → whitelist perintah JS → MainActivity.kt (channel id.goyana/device)
 └─ lib/native/*.dart → halaman native yang DITUMPUK di atas WebView
```

- `mobile/assets/web/` **di-generate**, jangan diedit/di-commit. Edit sumbernya (`index.html`, `goyana-v*.js`, `mobile/web_bridge/*`).
- **Saat halaman native tampil, WebView di-`Offstage`** (tetap hidup, script jalan). Jangan dihapus: menggambar Flutter di atas WebView yang terlihat membuat scroll berat (sudah terjadi & diperbaiki).
- Plugin Capacitor lama (`GoyanaDevice`, `Geolocation`, `LocalNotifications`) dijawab oleh Flutter/Kotlin. Fitur tambahan: simpan file, share gambar, print/PDF, clipboard, dialog native, tombol back.

---

## 4. Resep memindahkan 1 halaman ke Flutter native

Contoh lengkap: Beranda (`home_page.dart`) dan Pesanan (`orders_page.dart`). Ikuti pola yang sama.

### Langkah A — pelajari halaman HTML
Dump struktur & gaya pakai Playwright (lihat cara di `tests/flutter-bridge.cjs`). Catat: ukuran, warna (computed style), radius, shadow, font (Poppins 400/500/600), SVG ikon, dan **semua elemen yang bisa diklik**.

### Langkah B — model data dari HTML (JavaScript)
Di `mobile/web_bridge/capacitor.js`:
1. Tulis `fooModel()` yang membaca **teks & warna dari DOM** (bukan menghitung ulang). Contoh `ordersModel()`.
2. Daftarkan: `var NATIVE = { home: homeModel, orders: ordersModel, foo: fooModel };` (key = id `<section class="page">`).
3. `reportPage()` otomatis mengirim `{event:'native', page, model}` ke Flutter saat halaman aktif **dan tidak tertutup overlay** (sheet/modal/detail).

### Langkah C — halaman Dart
1. `lib/native/foo_page.dart`: `FooModel.fromJson`, abstract `FooActions`, widget `NativeFoo`.
2. Pakai komponen bersama `lib/native/common.dart`: `GTopBar`, `GBottomNav(active: n)`, `gText`, `gSvg`, `gShadow`, `cssColor` (parsing `rgb()` dari HTML), `gBrand`, `gInk`.
3. Bungkus dengan `Material` (kalau tidak, teks bergaris kuning).
4. List panjang → `ListView.builder`. Bagian statis → `RepaintBoundary`.

### Langkah D — sambungkan di shell (`lib/hybrid/shell.dart`)
1. `implements FooActions`, simpan `FooModel _foo`.
2. `_onEvent`: `if (page == 'foo') _foo = FooModel.fromJson(model)`.
3. Di `build`: `if (_nativePage == 'foo') Positioned.fill(child: NativeFoo(...))`.
4. Setiap aksi = **klik elemen HTML yang sama**:
   - `_tap('#foo .tombol', index)` → buka halaman/sheet (native disembunyikan dulu).
   - `_tap(sel, i, '.anak', false)` → aksi di tempat tanpa menyembunyikan (mis. tombol status).
   - Input teks → `__goyanaSearch('#selector-input', value)` (set value + event input).

Dengan cara ini logika (harga, DP, stok, dll.) **tetap dari HTML yang sudah teruji**. Memindahkan logika ke Dart adalah tahap terpisah nanti.

### Langkah E — uji
1. `tests/flutter-bridge.cjs`: tambah cek model halaman baru (data benar, aksi jalan, tersembunyi saat overlay).
2. `mobile/test/screens_test.dart`: tambah screenshot (320 & 390 px) dengan data contoh.
3. Push → CI mengirim PNG ke branch **`ci-screens`**:
   `git fetch origin +ci-screens:refs/remotes/origin/ci-screens && git show origin/ci-screens:foo_390.png > foo.png`
   Bandingkan berdampingan dengan screenshot HTML. (Kotak di emoji/ikon Material hanya terjadi di mesin tes.)

---

## 5. Urutan halaman berikutnya

| # | Halaman (id HTML) | Catatan |
|---|---|---|
| 1 | **Tambah Transaksi** (`addorder`, flow `f61-*`) + **Pembayaran** (`f61-payment`, QRIS `q118`, DP/deposit) — **langkah 1–2 sudah native (Claude, 3 Okt, `addorder_page.dart`)**; sisa: sheet opsi/pembayaran/QRIS | Alur paling kritis kasir. Banyak sheet/overlay: boleh biarkan sheet tetap HTML dulu, yang native cukup layar utamanya. Uji total harga, ongkir, DP, QRIS dinamis. |
| 2 | **Pelanggan** (`customers`, `cust59-*`) | ✅ Claude 3 Okt (`customers_page.dart`) |
| 3 | **Laporan** (`reports`, `rp170`) + **Kas** (`cashier`, `cashclose`, `cashin`, `cashout`) | Laporan ✅ Claude 3 Okt (`reports_page.dart`). **Pengaturan** (`settings_page.dart`) juga ✅. Sisa: Kas. |
| 4 | Kurir (`courier181`), Stok (`inventory`), Pengaturan (`settings`), Outlet, Pegawai, WhatsApp/Chatbot | |

Setelah semua halaman native: pindahkan logika ke Dart (layer data di `lib/core/` membaca SQLite yang sama), lalu WebView bisa dilepas.

---

## 6. Perintah tes

```bash
# web + jembatan Flutter (Playwright)
cd tests && npm install
python ../tools/prepare_flutter_web.py .. node_modules/@zxing/library/umd/index.min.js
node flutter-bridge.cjs          # jembatan, Beranda/Pesanan native, SQLite, print, back
npm test                         # regresi aplikasi HTML (harus tetap lulus)
python -m unittest discover -s . -p 'test_*.py'

# backend
cd backend && composer install && php vendor/bin/phpunit     # 42+ tes
cd tests && node sync-e2e.cjs     # 3 HP + server Laravel sungguhan (butuh vendor backend)

# Flutter (di CI: workflow "Flutter Android (hybrid)")
cd mobile && flutter analyze && flutter test --exclude-tags screens
```
`flutter analyze` di CI **gagal walau hanya info/lint** → bersihkan semua peringatan (mis. `super.key` di widget publik, import tak terpakai).

---

## 7. Backend & deploy (tugas yang bisa dikerjakan paralel)

1. **Deploy Laravel** (VPS atau Jagoan Hosting; butuh PHP 8.3+, MySQL, HTTPS, Composer/SSH). Pengguna belum memilih — **tanyakan dulu**.
2. Setelah HTTPS jalan: isi variabel GitHub **`GOYANA_API_URL`** (Settings → Variables). APK berikutnya otomatis login ke server & sinkron.
3. `.env` produksi: `APP_ENV=production`, `APP_DEBUG=false`, `GOYANA_ADMIN_MFA=true`; setelah SMTP siap `GOYANA_REQUIRE_EMAIL_VERIFICATION=true`.
4. Admin pusat dibuat via `php artisan goyana:admin` (wajib OTP saat login).
5. Belum ada: gateway pembayaran / Play Billing (sekarang admin mencatat pembayaran manual), login Google, reset password via email, layar konflik sync, retensi data §24.

6. **Dashboard owner web = aplikasi HTML yang sama** (keputusan pengguna, 2 Okt 2026). Jangan membuat ulang laporan dari nol.
   - Saat deploy, sajikan hasil `python tools/prepare_web.py . <folder> --api=https://<domain>` di server yang sama, mis. `https://app.goyana.id/app/` (folder `backend/public/app/`, atau subdomain sendiri).
   - Owner login dengan akun server → sinkronisasi menarik semua data → halaman Laporan, Laporan Keuangan, Monitor/Manajemen Cabang, Pusat Data, Audit, CRM, Pesanan, Pelanggan, Kas, Stok langsung terpakai.
   - Tambahkan `zxing.min.js` (dari `tests/node_modules/@zxing/library/umd/index.min.js`) dan `capacitor.js` kosong ke folder itu.
   - Tautkan dari dashboard Laravel owner: tombol **"Buka aplikasi GOYANA (web)"**.
   - Di laptop/PC tampilannya kolom selebar HP di tengah: boleh, perapian tampilan lebar adalah tahap berikutnya.
   - Dashboard **admin pusat** tetap Laravel (`/admin`), lengkapi sesuai `GOYANA-SISTEM-PUSAT.md` §9, §12–§16, §25–§26, §32.
   - Sudah ada (3 Okt): ringkasan/filter usaha, detail tim/HP/sinkron/saldo AI, tiket CS, pengaturan platform, audit, kesehatan sistem, perintah terjadwal. Detail di GOYANA-PROGRESS.md "Panel administrator & otomasi". **Pasang cron `schedule:run` saat deploy.**
   - Uji: login di browser sebagai owner, pastikan data dari HP (sync) muncul; jangan pakai akun platform admin (API menolaknya).

Aturan bisnis kunci (sudah diputuskan pengguna):
- Trial 2 bulan (hak Basic) → **baca saja** setelah habis. Tidak ada paket gratis permanen.
- Basic = 1 pusat + 1 cabang; Silver 2; Gold 3; Platinum 5 cabang (`backend/config/goyana.php`).
- Maks **2 HP kasir per outlet** (HP owner yang bertransaksi ikut dihitung; kurir tidak).

---

- **WhatsApp:** jangan bangun engine WA di GOYANA dan jangan pasang di VPS GOYANA. Semua WA lewat API CHATKU (VPS terpisah, GOYANA = klien besar khusus). Detail: GOYANA-SISTEM-PUSAT.md §41.

## 8. Jebakan yang sudah pernah terjadi

- `v189` mengganti `window.login167` dengan pesan "server belum terhubung" → login server dicegat di tombol (capture listener) di `goyana-v197-sync.js`. Jangan dihapus.
- Panduan awal `#ob189` menutupi login kalau server aktif → disembunyikan otomatis saat belum login.
- Setelah transaksi disimpan, app membuka detail pesanan otomatis → halaman native harus tersembunyi (overlay terdeteksi). Ini benar, bukan bug.
- Nilai SQLite dipecah per 256 KB (batas baris Android ~2 MB). Jangan ubah ke 1 baris.
- `runJavaScript` dari Flutter: escape string dengan `jsonEncode`.
- Branch `ci-screens` ditimpa (force push) setiap CI — fetch pakai `+`.

---

## 9. Cara melapor ke pengguna

- Mulai dengan hasil: apa yang sudah jadi + link APK uji:
  `https://github.com/rajabadutiklan-lab/Goyana/releases/download/flutter-uji/GOYANA-Flutter-Uji.apk`
- Sebutkan jujur apa yang belum diuji di HP sungguhan.
- Kirim gambar perbandingan HTML vs Flutter untuk halaman baru.
- Akhiri dengan satu langkah berikutnya.

---

## 10. Format catatan untuk pemeriksaan Claude (wajib)

Tambahkan di akhir `GOYANA-PROGRESS.md` setiap kali selesai satu bagian:

```markdown
## [GPT] <nama bagian> — <tanggal> (branch <nama-branch>, commit <hash>)
- Dikerjakan: <ringkas, per poin>
- File utama: <daftar path>
- Tes dijalankan & hasil: <flutter-bridge / npm test / phpunit / CI hijau?>
- Belum diuji / ragu: <jujur, mis. "belum dicoba di HP", "QRIS dinamis belum dicek">
- Keputusan yang diambil sendiri (perlu dicek Claude/pengguna): <jika ada>
- Screenshot pembanding: <nama file di ci-screens>
```

## 11. Checklist yang akan dipakai Claude saat mengambil alih

1. Baca semua entri `[GPT]` di `GOYANA-PROGRESS.md`; cocokkan dengan `git log` dan diff per branch.
2. Jalankan seluruh tes bagian 6 + CI; semua harus hijau.
3. Bandingkan screenshot HTML vs native tiap halaman baru (320/390 px): posisi, warna, tombol rapi.
4. Uji angka kritis: total, ongkir, diskon, DP, deposit, kas, laporan harus sama dengan versi HTML.
5. Cek keamanan backend: izin role/outlet di server, tidak ada secret di repo, `APP_DEBUG=false` produksi.
6. Cek dokumen tetap jujur (tidak menyebut fitur aktif yang belum diuji).
7. Perbaiki, catat sebagai entri `[Claude]` di `GOYANA-PROGRESS.md`, lalu lanjutkan pekerjaan berikutnya.
