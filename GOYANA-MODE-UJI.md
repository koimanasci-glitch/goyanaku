# Mode Uji khusus APK pengujian

- APK biasa: GOYANA-Android-Terbaru.apk, ID id.goyana.app. Tidak memuat script, menu atau password Mode Uji.
- APK uji: GOYANA-Mode-Uji.apk, nama Goyana Uji, ID id.goyana.app.uji. Bisa dipasang berdampingan; data aplikasinya terpisah.
- Buka Pengaturan → Mode Uji, masukkan password yang ditetapkan pemilik, lalu pilih paket uji (default Platinum).
- Password diverifikasi lokal dengan SHA-256. Ini hanya pembatas menu pengujian, bukan bukti identitas admin atau keamanan produksi. Password/hash/kode di APK dapat dianalisis atau dimodifikasi.
- Akses uji hanya aktif selama sesi aplikasi. Keluar Mode Uji atau memuat ulang aplikasi mengembalikan hak akses asli. Data paket berbayar dan tanggal trial tidak diubah.
- Uji akses UI tidak membuat pembayaran berhasil, tidak mengaktifkan layanan AI/WA sungguhan, dan tidak tersinkron ke server.
- Saat peluncuran gunakan build standar tanpa --test-mode. Persetujuan pembayaran, hak paket, tenant/outlet, dan akses data produksi wajib diverifikasi di server; tidak boleh mempercayai flag aplikasi.
- Workflow membuat APK standar lebih dahulu dan menyimpan hasilnya, lalu membuat APK Uji dari aset terpisah dan identitas aplikasi berbeda.
- Uji otomatis memeriksa password salah/benar, pilihan paket, akses premium, pemulihan paket asli, pemisahan build dan identitas Android.
