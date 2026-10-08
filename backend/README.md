# Fondasi backend Goyana

Laravel 13 / PHP 8.3+. Tahap pertama dari GOYANA-SISTEM-PUSAT.md. Aplikasi Android lama tidak diubah.

Sudah ditulis:
- Pendaftaran owner + usaha + outlet pusat secara transaksional, trial Basic dua bulan.
- Login/logout sesi web, hash password, CSRF, regenerasi sesi dan pembatasan percobaan login.
- Dashboard owner terbatas usaha miliknya; platform admin dipisahkan dan hanya dibuat lewat terminal.
- Dashboard administrator daftar usaha, grant paket beta bertanggal WIB, pencabutan dan audit.
- Status trial/beta berakhir menjadi read-only tanpa menghapus data.
- Registrasi maksimal dua slot perangkat kasir per outlet, pencabutan dan audit. Ini registry slot, belum pairing/authentication HP atau perlindungan endpoint transaksi.

## Menjalankan pengujian lokal

```sh
cd backend
composer install
cp .env.example .env
php artisan key:generate
touch database/database.sqlite
php artisan migrate
composer test
php artisan goyana:admin
php artisan serve
```

Buka /register untuk membuat owner, /login untuk masuk dan /admin memakai akun pusat. Command admin menanyakan password secara tersembunyi; tidak ada password bawaan. SQLite hanya untuk pengembangan/tes awal; uji database produksi dan konkurensi perangkat dengan mesin pilihan sebelum produksi.

GitHub Actions backend.yml menjalankan Composer, lint PHP, daftar route, kompilasi Blade dan 16 tes fitur pada SQLite sementara. Status workflow menjadi bukti pengujian, bukan keberhasilan deployment. Workflow APK lama tetap terpisah. Composer lock hasil resolusi CI disimpan di repo untuk pemasangan dependency yang dapat direproduksi. Uji mesin database produksi dan hardening tetap diperlukan.

## Belum siap produksi

- Verifikasi email, reset password, Google sign-in, MFA admin, undangan staff/permission per outlet.
- API Android/token/device binding, transaksi, offline sync, printer/kamera dan Flutter.
- Langganan berbayar/verifikasi payment, top-up/ledger AI, WA/webhook/jadwal kurir.
- AI profiles/budget, monitoring eksternal, backup/restore, retensi/purge, dukungan/CRM/Play review.
- Production hardening TLS, secure cookie, origin/CORS, Redis/shared sessions, database backup dan pengujian lintas tenant seluruh modul.

Jangan deploy publik sebagai produk selesai. Untuk uji, gunakan data buatan. Produksi membutuhkan APP_ENV=production, APP_DEBUG=false, APP_URL HTTPS, SESSION_SECURE_COOKIE=true dan konfigurasi layanan sah; kunci tidak masuk repo.

## Handoff GPT / Claude
Fondasi ini adalah langkah pertama, bukan implementasi semua 33 bagian MD. Lanjutkan dari kode/hasil CI terbaru. Prioritas berikutnya: verifikasi/reset akun, role staff dan kontrak API/sync. Keputusan harga/kuota di dokumen induk tidak diubah oleh patch ini.

## Dashboard admin di HP
Dashboard responsif memakai tema coral/putih/abu yang konsisten. Manifest dan service worker tanpa cache data privat disediakan untuk pemasangan PWA pada browser yang mendukung. Setelah tersedia melalui HTTPS, buka /admin dan pilih Instal/Tambahkan ke layar utama. Tidak perlu memasukkan admin platform ke APK laundry. PWA tetap membutuhkan koneksi untuk data/operasi; instalasi dan izin aktual harus diuji di HP. Belum ada domain/deployment aktif.

## API owner untuk Flutter
POST /api/session (email/password) mengeluarkan token Sanctum business:read, berlaku 24 jam. GET /api/me membaca profil/paket/outlet usaha pemilik token, tidak menerima pemilihan tenant dari klien. DELETE /api/session mencabut token aktif. Admin pusat tidak mendapat token laundry. API ini belum menjalankan transaksi atau pairing perangkat kasir. Gunakan HTTPS, token hanya untuk pemakaian yang diizinkan; Google login/MFA/email belum selesai.

## Akses, paket, tim dan OTP admin (2 Oktober 2026)

- Aturan paket, role dan permission ada di `config/goyana.php`. Trial Basic 2 bulan, lalu baca saja sampai paket aktif.
- Admin pusat: setelah login password, wajib OTP authenticator (`/admin/mfa`). Reset OTP: `php artisan goyana:admin-reset-mfa email@admin`.
- Admin mencatat pembayaran manual di halaman usaha → paket aktif. Owner mengelola cabang dan akun tim di `/dashboard`.
- `.env` produksi: `GOYANA_ADMIN_MFA=true`; setelah SMTP siap `GOYANA_REQUIRE_EMAIL_VERIFICATION=true`.
- Jalankan migrasi baru: `php artisan migrate`.

## Sinkronisasi aplikasi Android

- `GET /api/sync/pull?cursor=N` dan `POST /api/sync/push` (token Sanctum). Aturan per jenis data di `config/goyana.php` → `sync`.
- Uji end-to-end dengan server sungguhan: `cd tests && npm install && node sync-e2e.cjs` (butuh `composer install` di backend).
- APK membaca alamat server dari variabel GitHub `GOYANA_API_URL` saat build. API butuh HTTPS di produksi; CORS `api/*` terbuka karena aplikasi memakai token, bukan cookie.

## Tim, cabang, kurir, tahapan, uang, monitoring (8 Oktober 2026)

Keputusan dan batasannya: `GOYANA-SISTEM-PUSAT.md` §49. Jalankan `php artisan migrate`, lalu sekali `php artisan goyana:reindex-orders` bila server sudah berisi pesanan.

Semua endpoint di bawah memakai token Sanctum (`Authorization: Bearer …`) kecuali yang bertanda *terbuka*. Usaha dan outlet selalu ditentukan server dari akun, tidak dari kiriman aplikasi.

| Endpoint | Siapa | Guna |
|---|---|---|
| `POST /api/session` *terbuka* | owner, akun lama | Login email + password |
| `POST /api/session/pin` *terbuka* | kasir, pegawai, kurir, admin outlet | Login `phone` + `pin` + `device_id`; di HP outlet: `user_id` + `pin` + `device_id` + `device_secret` |
| `POST /api/devices/roster` *terbuka* | HP outlet yang diikat | Daftar nama pegawai outlet itu (`device_id`, `device_secret`) |
| `GET /api/me?device_id=` | semua | Profil, paket, outlet, `note.prefix` + `note.device` untuk nomor nota |
| `POST /api/me/pin`, `POST /api/me/password` | semua | Ganti PIN/password sendiri (wajib yang lama) |
| `GET /api/me/summary` | kasir, pegawai, kurir | Ringkasan milik sendiri hari ini |
| `POST /api/devices/claim` | kasir, admin outlet, owner | Mengisi slot HP kasir sebelum transaksi pertama |
| `GET/POST /api/team`, `PATCH /api/team/{id}` | owner | Kelola Pegawai: `name, role, outlet_id, phone, pin, email, password, courier_key` |
| `POST /api/team/{id}/pin`, `/password`, `/deactivate`, `/activate` | owner | Ganti PIN/password, nonaktif/aktif |
| `GET/POST /api/outlets`, `PATCH /api/outlets/{id}` | owner | Kelola Cabang: `name, code, address, phone, process_outlet_id` |
| `POST /api/outlets/{id}/deactivate`, `/activate` | owner | Status cabang |
| `GET /api/devices`, `POST /api/devices/shared`, `DELETE /api/devices/shared/{id}`, `DELETE /api/devices/cashier/{id}` | owner | HP kasir dan HP outlet bergantian (ikat/cabut) |
| `PATCH /api/business` | owner | `allow_debt` (boleh hutang) |
| `GET /api/monitoring?outlet_id=&from=&to=` | owner; admin outlet (outletnya) | Monitoring lengkap |
| `GET /api/monitoring/alerts` | owner; admin outlet | Peringatan otomatis |
| `GET /api/courier/cash` | kurir | Tunai yang dipegang dan riwayatnya |
| `GET /api/courier-cash`, `POST /api/courier-cash/{kurir}/deposit` | kasir/admin outlet (outletnya), owner | Daftar tunai dipegang kurir; terima setoran (`amount`, `note` wajib bila selisih) |

Sinkronisasi (`/api/sync/push`):
- Hasil `conflict` kini bisa membawa `message`: kiriman tidak diterima sesuai hak peran dan HP harus memakai `record` dari server. Klien lama mengabaikan `message` dan tetap benar.
- Koleksi baru `pickups` (tugas penjemputan, per outlet). `customers` tidak lagi dikirim ke kurir dan pegawai.
- Pesanan boleh membawa tahap per barang di `detail.items[i].st` dan status baru `selesaiproses`.
- Aturan ada di `config/goyana.php` (`orders`, `pin`, `alerts`, `packages.*.cashier_devices`).
