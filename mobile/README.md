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
- Belum: SQLite/outbox offline sync, login backend di dalam alur HTML, signing produksi.
