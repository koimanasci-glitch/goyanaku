# Keputusan Paduka — GOYANA

## 6 Oktober 2026, 07:16 WIB

### Koreksi A7 disetujui
Paduka menyatakan: "Ok saranmu benar semua" sesudah rekomendasi tiga koreksi berikut dan satu CI tambahan.

1. Pembayaran laundry melalui Deposit masuk omzet saat saldo digunakan. Topup deposit dicatat sebagai titipan, sehingga tidak masuk omzet dua kali.
2. Pengeluaran Non-Tunai wajib tersimpan dengan metode pembayaran dan mengurangi saldo Non-Tunai. Uang tunai di laci tidak dikurangi oleh transaksi tersebut.
3. Omset harian tetap menghitung transaksi pada hari yang sama meskipun kasir menutup beberapa shift. Tutup kas mengakhiri shift, bukan menghapus omzet hari itu. Perhitungan harus menjaga tanggal transaksi dan mencegah hitung ganda.

Kerjakan ketiga koreksi dalam satu putaran dengan susunan tampilan tetap, lalu satu CI tambahan. Sesudah lulus dan dilaporkan, lanjut A8 Laporan. Persetujuan ini memenuhi kebutuhan keputusan aturan 0.4 dan tambahan CI aturan 0.6. Koreksi tersebut belum diterapkan pada saat catatan ini dibuat.

### Permintaan logo — CATAT DULU
Paduka menyatakan: "Saya mau ganti logo sama logo aplikasi biar seragam tapi catat dulu".

- Ganti logo yang tampil di dalam aplikasi dan ikon aplikasi Android agar memakai identitas visual yang seragam.
- Simpan sebagai pekerjaan berikutnya; belum menerapkan, membuat atau memilih aset logo dalam putaran pencatatan ini.
- Logo final mengikuti pilihan Paduka. Perubahan nantinya dibatasi pada aset dan penggunaan logo, menjaga susunan halaman dan fungsi yang sudah disetujui.

Catatan ini merupakan keputusan terbaru. Laporan A7 sebelumnya di GOYANA-PROGRESS.md mencatat keadaan sebelum persetujuan ini.

## 6 Oktober 2026, 07:21 WIB — aset logo dan animasi

Paduka mengirim tiga gambar dan menjelaskan fungsi masing-masing. Permintaan logo sebelumnya tetap berstatus CATAT DULU; putaran ini menyimpan spesifikasi dan referensi, belum memasang logo atau animasi.

| Aset | Penggunaan |
|---|---|
| 162919.png | Ikon aplikasi Android pada layar utama HP: simbol putih dengan latar koral/batik yang dikirim Paduka. |
| 162917.png | Logo di dalam aplikasi: ambil/potong hanya simbolnya, pertahankan transparansi; tulisan Goyana dibuat dengan widget Text Flutter, bukan memakai tulisan dalam PNG. |
| 162922.png | Acuan visual animasi pembukaan pertama: kain/air/gelembung -> terbentuk simbol -> logo dan tulisan Goyana. Gambar ini adalah storyboard tiga panel, belum merupakan file animasi bergerak. |

### Durasi dan perilaku
- Rencana animasi lengkap sekitar 3 detik pada pembukaan pertama sesudah instalasi.
- Pembukaan berikutnya cukup transisi logo singkat sekitar 300–500 ms, berjalan bersama inisialisasi aplikasi; tidak menambahkan waktu tunggu buatan jika aplikasi sudah siap.
- Simpan penanda pembukaan pertama secara lokal. Animasi panjang tidak diulang setiap membuka aplikasi, login/logout atau memperbarui versi; penanda ini terpisah dari tutorial/onboarding.
- Buat animasi lewat Flutter. Warna koral dan motif mengacu pada aset Paduka. Tulisan Goyana dibuat lewat Flutter agar tajam dan konsisten ukuran/tata letaknya.
- Perubahan berikutnya dibatasi pada ikon/logo/splash yang diminta; susunan halaman lain dan tiga koreksi A7 tidak ikut berubah oleh pekerjaan branding.

### Referensi asli
- 162919.png: Library libfile_528bc30bb964819182f940d591d0a17e; lampiran file_00000000f8cc820b8fd59ebd76d70d67; PNG RGBA 1254 x 1254.
- 162917.png: Library libfile_aaf488ae3e588191814b6a76c31eb242; lampiran file_000000000f0481fa9dab6286a924f61f; PNG RGBA 2066 x 761.
- 162922.png: Library libfile_fd6ca8ba96dc8191b7ef00ee462c195f; lampiran file_0000000036f081fa9e12683b87481b56; PNG RGB 1536 x 1024.

Ketiga berkas asli berhasil dibaca dari salinan lampiran setelah jalur upload awal tidak tersedia. Tidak membuat ulang atau mengedit gambar dalam putaran pencatatan ini.

## 6 Oktober 2026, 07:25 WIB — Gas: implementasi disetujui

Persetujuan terbaru mencakup ketiga koreksi A7 dan pemasangan ikon/logo/animasi yang sebelumnya dicatat. Kode sekarang mencatat Deposit sebagai pembayaran laundry, menyimpan pengeluaran Non-Tunai dan mengarsipkan rincian transaksi setiap tutup shift. Omzet harian memakai tanggal transaksi WIB, bukan tanggal tutup kas.

Launcher asli terpasang untuk lima kepadatan Android. Simbol PNG transparan memakai outline bersih dari ikon acuan; tulisan Goyana dibuat lewat Flutter Text. Animasi Flutter lengkap 3000ms sekali pada pembukaan pertama, berikutnya transisi 350ms bersama inisialisasi. Penanda tersimpan terpisah dari onboarding. Jeda lama 950ms telah dihapus.

Tes lokal hitungan, batas hari/bulan, dua shift, batal, kegagalan penyimpanan dan buka ulang sudah lulus. Satu CI tambahan yang disetujui akan dipakai untuk memeriksa keseluruhan Flutter dan menghasilkan APK. A8 tetap pekerjaan setelah A7 selesai dan dilaporkan.

### Hasil CI tambahan dan koreksi await
CI3 Flutter run 37395885281 (job 112051598723) menggunakan commit 9e7415bff6cd528fa892d0e6f16414fdcd750381. Browser 69 PASS; analyze berhenti pada dua peringatan unawaited_return_in_try_block di test/flutter_test_config.dart. Kedua return di dalam try telah diperbaiki menjadi return await. Tes unit, screenshot dan build APK tidak sempat dijalankan. Perbaikan/laporan disimpan dengan [skip ci]; tambahan CI yang disetujui sudah 1/1 terpakai. Perlu izin baru untuk verifikasi Flutter/APK berikutnya sesuai aturan batas CI proyek. APK terakhir masih build 309, belum memuat koreksi atau branding putaran ini.

## 6 Oktober 2026, 08:27 WIB — izin CI berikutnya

Paduka menjawab "Ijinkan" atas permintaan satu CI tambahan untuk memverifikasi perbaikan dua await dan membuat APK. Izin ini berlaku untuk tepat satu CI Flutter berikutnya (A7 CI4), pada kode terbaru yang sudah diperbaiki; bukan rerun SHA gagal sebelumnya. Tidak mengubah workflow, dependensi, atau cakupan A8.

### Hasil CI4 berizin
CI4 run 37399330785, job 112062731315, commit dd0d458f2c3abededd8ab3d682af38b23a9abadf: browser 69 PASS, flutter analyze No issues found, unit 223 lulus dan satu gagal. Gagal pada pure_test.dart:50 karena ekspektasi header lama GOYANA; widget sebenarnya memakai Goyana sesuai branding baru. Ekspektasi diperbaiki menjadi Goyana, dan pencarian seluruh tes Dart memastikan tidak ada lagi find.text GOYANA yang sama. Tes pembukaan/penanda dan hitungan A7 tidak dilaporkan gagal. Screenshot/build/publikasi APK dilewati. Izin satu CI pada 08:27 WIB sudah 1/1 terpakai; perbaikan tes dan laporan disimpan [skip ci], tidak menjalankan CI5 otomatis. APK terakhir tetap build 309.

## 6 Oktober 2026, 08:36 WIB — 3 jatah CI tambahan

Paduka menyatakan: "Sekarang aku kasih 3 jatah tulis di md".

- Tambahan baru: **3 kali CI Flutter** untuk menuntaskan verifikasi A7, branding dan APK baru. Jatah ini terpisah dari empat CI A7 yang sudah dijalankan.
- Pemakaian awal: **0/3 terpakai, 3 tersisa**. Berlaku bersama lintas putaran sampai digunakan; tidak direset tiap sesi.
- Setiap CI atau rerun mengurangi satu jatah. Gunakan kode terbaru yang sudah diperbaiki; jangan rerun SHA lama yang masih gagal.
- Tidak perlu meminta izin lagi selama masih dalam tiga jatah ini. Catat nomor run, hasil dan sisa jatah sesudah setiap pemakaian.
- Hentikan percobaan bila ketiganya habis, lalu laporkan penyebab yang tersisa. Batas ini khusus pekerjaan A7/branding/APK sekarang; tidak mengubah aturan CI bagian lain atau mengizinkan perubahan workflow/dependensi.
- Status saat dicatat: analyze terakhir bersih; unit 223 lulus/1 gagal akibat acuan GOYANA yang sudah diperbaiki menjadi Goyana. Screenshot dan APK baru masih perlu diverifikasi.

### Pemakaian jatah baru — CI5
Jatah pertama dari tiga tambahan dipakai untuk CI5 pada kode terbaru dengan acuan header Goyana yang sudah diperbaiki. Counter saat run dimulai: **1/3 terpakai, 2 tersisa**. Hasil run dan APK akan dicatat sesudah verifikasi.

### Hasil CI5 — lulus dan APK terbit
- Run 37400232867, job 112065548795, commit a0b8d5a37d19dd60770e90c3586128f918c79d4e: SUCCESS. Browser 69 PASS, analyze No issues found, unit Dart 224/224 PASS, screenshot Flutter 228/228 PASS.
- APK baru build 312 terbit pada 6 Oktober 2026 08:49:05 WIB, ukuran 55.351.167 byte. Tag flutter-uji, notes release dan artifact 11385117821 cocok dengan commit yang diuji.
- Unduh: https://github.com/rajabadutiklan-lab/Goyana/releases/download/flutter-uji/GOYANA-Flutter-Uji.apk
- **Counter tiga jatah tambahan: 1/3 terpakai, 2 tersisa.** Commit laporan [skip ci] tidak memakai jatah. Dua sisanya tetap tercatat lintas sesi; tidak menjalankan CI lain sesudah hasil ini lulus.
- A7 koreksi hitungan dan branding selesai pada tahap paritas + pengaman. Aplikasi masih hybrid dengan writer HTML sampai D2; belum mengklaim seluruh proyek murni Dart atau sudah diuji HP nyata. A8 tetap langkah berikutnya pada putaran terpisah.

## 8 Oktober 2026 — cabang, pegawai, kasir, kurir

Diskusi panjang lalu "Gas semuanya". Tiga belas keputusan tercatat lengkap di `GOYANA-SISTEM-PUSAT.md` §49. Ringkasnya:

- Login pegawai nomor HP + PIN; owner email + password.
- HP kasir per outlet: Trial/Basic 2, Silver 3, Gold 4, Platinum 5 (pilihan C).
- Admin Outlet tetap dimunculkan (pilihan C).
- Akun kurir hanya Jemput, Antar, Setoran; kurir satu outlet; kurir lama menunggu owner memilihkan outlet (pilihan B).
- Pegawai dan tahapan dibuka di Trial dan Basic; "Free" = Trial 2 bulan, tidak ada paket gratis permanen.
- Tahap per barang: server dulu, tampilan menyusul.
- Nomor nota `BKS-261008-1-0133`.
- Hibrida/HTML: pengecualian sempit saja (kunci Pegawai, tulisan Silver, label Premium tahapan).
- Flutter murni jadi acuan aturan; backend dan versi web mengikutinya.
- Ditunda: upah pegawai. Tidak dibuat: ambil di cabang lain.
- Penunjukan kurir oleh kasir (owner juga bisa). Tunai kurir disetor ke outletnya.

## 8 Oktober 2026, 15:06 WIB — arah akhir HP dan web

"Ok setuju deh": HP memakai Mode Murni saja; web owner dan administrator memakai Laravel (memantau dan mengatur, bukan transaksi); HTML dan APK Hibrida tidak dikembangkan lagi dan dipensiunkan setelah Mode Murni teruji di HP. Rincian: `GOYANA-SISTEM-PUSAT.md` §50.
