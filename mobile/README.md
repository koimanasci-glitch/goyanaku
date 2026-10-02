# Flutter Goyana — tahap pertama

Native Flutter, bukan WebView. Login owner dan dashboard paket/outlet memakai API Laravel di backend/. Tema awal coral, putih dan abu, responsif. Ini bukan migrasi semua fitur prototype.

## Uji Android
```sh
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=GOYANA_API_URL=https://alamat-server-uji
```

Host Android dan pubspec.lock hasil SDK 3.47.2 disimpan di repo. Workflow Flutter foundation menjalankan analisis/tes dan menghasilkan APK debug di artifact goyana-flutter-foundation-apk. Package preview terpisah dari APK prototype sehingga tidak mengganti aplikasi lama.

Buat akun owner pada web backend /register. Isi alamat HTTPS backend di aplikasi lalu login. Tanpa backend yang dihosting, form dapat dicoba tetapi login tidak akan berhasil. URL bawaan tidak mengarah ke server fiktif. Admin platform menggunakan PWA web; API Flutter menolak akun admin pusat.

Token berlaku 24 jam dan hanya di memori; aplikasi restart meminta login ulang. Token tidak ditulis ke log/preferences. Persistent login dengan secure storage merupakan tahap berikutnya. Debug emulator memperbolehkan localhost/127.0.0.1/10.0.2.2; host lain harus HTTPS. Tidak menonaktifkan validasi TLS.

Transaksi, offline outbox, role staff/kurir, printer, kamera, pembayaran dan semua UI operasional belum tersedia di aplikasi Flutter awal ini. Data dashboard berasal dari API, tidak memakai data pelanggan rekaan sebagai hasil server. APK debug bukan rilis Play Store. Host memakai application ID preview, permission internet, backup dimatikan dan HTTPS untuk build non-debug. Signing produksi belum dikonfigurasi.
