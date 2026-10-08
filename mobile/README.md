# GOYANA Android — Flutter hybrid

Aplikasi Android Flutter yang menjalankan **tampilan HTML final GOYANA apa adanya** (index.html + semua patch goyana-v*.js), sehingga desain, posisi, dan alur 100% sama dengan prototype. Fitur HP dikerjakan oleh Flutter/Android native, bukan Capacitor.

Ini tahap 1 dari rencana Hybrid (lihat GOYANA-ROADMAP.md, P2 Flutter Android): halaman dipindah ke widget Flutter native satu per satu tanpa membuat aplikasi berhenti dipakai.

## Cara kerja

```text
Flutter (lib/hybrid/shell.dart)
  └─ WebView memuat assets/web/index.html (offline, tanpa server)
       └─ capacitor.js = jembatan (mobile/web_bridge/capacitor.js)
            └─ GoyanaNative → lib/hybrid/bridge.dart → MainActivity.kt (channel id.goyana/device)
```

HTML tidak diubah. Panggilan lama `Capacitor.registerPlugin('GoyanaDevice' | 'Geolocation' | 'LocalNotifications')` dijawab oleh Flutter.

| Fitur | Capacitor lama | Flutter hybrid |
|---|---|---|
| Izin kamera/kontak/lokasi/Bluetooth/notifikasi | ✅ | ✅ |
| Printer Bluetooth (pasang, hubungkan, tes) | ✅ | ✅ (+ `printText`) |
| GPS | ✅ | ✅ |
| Pengingat antrean | ✅ | ✅ |
| Simpan struk/CSV/QR (`<a download>`) | ❌ hilang di WebView | ✅ ke Download/GOYANA |
| Bagikan struk sebagai gambar | ❌ | ✅ (WA, dll) |
| Cetak / simpan invoice PDF (`window.print`) | ❌ | ✅ layanan cetak Android |
| Upload foto/QRIS (`<input type=file>`) | ✅ | ✅ |
| Tombol kembali HP | keluar aplikasi | tutup pop-up → kembali → Beranda → tekan 2x untuk keluar |
| Dialog konfirmasi hapus | WebView | dialog Android |
| Ukuran huruf HP besar | layout bisa rusak | dikunci 100% agar posisi tetap |
| Link WhatsApp/Maps/telepon | ✅ | ✅ dibuka di aplikasinya |

## Membangun

```sh
cd tests && npm install && cd ..
python tools/prepare_flutter_web.py . tests/node_modules/@zxing/library/umd/index.min.js
cd mobile
flutter pub get && flutter analyze && flutter test
flutter build apk --release --target-platform android-arm,android-arm64
```

`assets/web/` dibuat ulang setiap build (tidak disimpan di git), jadi setiap perubahan index.html/goyana-v*.js otomatis ikut ke APK Flutter.

Workflow **Flutter Android (hybrid)** menguji jembatan di browser (`tests/flutter-bridge.cjs`), menjalankan analyze/test Flutter, lalu menerbitkan **GOYANA-Flutter-Uji.apk** di GitHub Release `flutter-uji` (prerelease, tidak menggantikan `android-latest`).

## Catatan

- Application ID `id.goyana.preview.goyana_flutter`: terpasang **berdampingan** dengan APK lama. Data uji di APK lama tidak ikut pindah.
- APK uji ditandatangani `android/app/goyana-preview.jks` (password ada di build.gradle.kts) agar pembaruan bisa dipasang tanpa hapus data. **Kunci ini publik — jangan dipakai untuk Play Store.**
- Layar login/dashboard native untuk Laravel (`lib/app.dart`, `lib/api.dart`) tetap ada dan diuji; akan disambungkan saat API transaksi & sinkronisasi siap.
- Sudah: SQLite di HP, sinkronisasi ke server (goyana-v197-sync.js), login server di layar login. Belum: signing produksi.

## Penyimpanan data di HP: SQLite

`window.localStorage` diganti oleh `web_bridge/goyana-store.js` yang memakai database SQLite di HP (`GoyanaStore.kt`, file `goyana.db`). Kode aplikasi tidak berubah. Data lama dari WebView dipindah otomatis sekali. Nilai besar dipecah per 256 KB sehingga snapshot pesanan tidak terkena batas baris Android (~2 MB). Kapasitas mengikuti sisa memori HP, bukan lagi ±5 MB.

## Migrasi ke halaman Flutter native (bertahap)

Halaman dipindah satu per satu ke `lib/native/`. Selama transisi:
- Aplikasi HTML tetap berjalan di bawah dan menjadi sumber logika & data (SQLite yang sama).
- `web_bridge/capacitor.js` melaporkan isi halaman (angka, teks) dan kapan halaman itu tampil; Flutter menggambar versi native hanya saat itu.
- Setiap tombol native menjalankan aksi elemen HTML yang sama (`__goyanaTap`), sehingga alur & hasil identik. Jika ada masalah, versi HTML tetap terlihat di bawahnya.
- CI merender halaman native (320/390/412 px) dan mengirim PNG ke branch `ci-screens` untuk dibandingkan dengan HTML.

| Halaman | Status |
|---|---|
| Beranda | ✅ native (logika masih dari HTML) |
| Pesanan | ✅ native (cari, tab status, kartu, tombol status; logika dari HTML) |
| Tambah Transaksi | ✅ langkah 1–2 native (pilih pelanggan, layanan + total). Durasi, jumlah, opsi, pembayaran & QRIS masih sheet HTML |
| Toast/notifikasi HTML | ✅ tampil native saat halaman native terbuka |
| Pelanggan | ✅ native (daftar & database ditata ulang; ranking/podium masih HTML saat dibuka) |
| Laporan | ✅ native (ringkasan, KPI, aksi cepat, cari, daftar; angka dari HTML). Detail laporan & tanggal kustom masih HTML |
| Pengaturan | ✅ native (kartu sinkron, grup akordeon, kartu paket, keluar akun). Halaman tujuan masih HTML |
| Kas Masuk & Pengeluaran | ✅ native (formulir; simpan lewat logika HTML) |
| Tambah Transaksi langkah 3–4 | ✅ sheet Atur Pesanan & Pembayaran native. Popup tunai/QRIS/transfer/DP/deposit masih HTML |
| Tutup Kasir | ✅ native (GPT, direview Claude) |
| Layanan | ✅ native (saklar durasi, cari). Edit/tambah kategori masih sheet HTML |
| Printer & Nota, Profil | ✅ lewat **formulir generik** (`form_page.dart`). Halaman form sederhana lain cukup ditambah ke `formModel` + `_formPages` |
| Pegawai, Outlet, Kurir, Stok, CRM, WhatsApp, dll. | berikutnya |
| Pengaturan, stok, kurir, WhatsApp, dll. | bertahap |

## Mode Murni tersambung ke server (8 Oktober 2026)

`lib/pure/server_sync.dart` adalah padanan Dart dari `goyana-sync-core.js` + `goyana-v197-sync.js`: memetakan penyimpanan lokal (kunci yang sama dengan HTML) ke koleksi server, masuk ke server, dan menjalankan putaran tarik → kirim. Status dan sesinya memakai kunci `goyana-psync-*`, terpisah dari mesin sinkron HTML; id perangkat (`goyana-sync-device`) dan alamat server (`goyana-api-url`) dipakai bersama.

- Masuk: Pengaturan → "Sinkronisasi server" → alamat server → "Simpan & masuk". Email + password (pemilik) atau nomor HP + PIN (kasir, pegawai, kurir).
- Uji tanpa jaringan: `test/server_sync_test.dart` memakai server tiruan (pemetaan data, masuk, kirim sekali tanpa bolak-balik, bentrok, ditolak, offline, sesi dicabut).
- Belum diuji dengan server sungguhan dari HP. Butuh server yang sudah online (HTTPS) untuk uji itu.
