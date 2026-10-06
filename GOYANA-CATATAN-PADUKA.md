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
