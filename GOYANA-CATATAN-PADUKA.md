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

## 8 Oktober 2026, 17.06 WIB — jatah CI dibebaskan

Paduka: "Mulai sekarang ci aku kasih bebas jatah ke kamu." Batas 2 CI per bagian dan penghitung jatah tidak berlaku lagi. Hasil setiap run tetap dicatat di GOYANA-PROGRESS.md.

## 8 Oktober 2026, 18.08–18.18 WIB — masuk aplikasi, pembuka, administrator

- **Masuk wajib, cukup sekali.** Setelah masuk, aplikasi langsung ke Beranda setiap dibuka sampai orangnya menekan Keluar. Berlaku setelah server online; APK uji sebelum itu tetap bisa dibuka tanpa masuk.
- **Animasi pembuka dan panduan 5 slide** dari Hibrida dipasang di Mode Murni. Warna pembuka, panduan, dan layar masuk memakai warna A (sama dengan kepala Beranda, #ff6b48 ke #f0472f) karena yang lama "terlalu merah". Lima gambar panduan: merahnya digeser sedikit ke oranye (disetujui).
- **Masuk dengan Google** untuk pemilik. Email Paduka untuk akun dengan semua menu terbuka: koimanasci@gmail.com, sebagai owner berpaket tertinggi (bukan administrator pusat). Daftarnya di setelan server, bukan di APK. Password tidak pernah disimpan di repo, APK, atau catatan.
- **Aplikasi administrator** (pusat, `/admin`): nanti tampilannya disamakan dengan aplikasi Android, temanya sama.

## 8 Oktober 2026, 20.35–20.42 WIB — aplikasi administrator dan divisi marketing

- Gambar acuan tampilan administrator dikirim Paduka; ditambah permintaan monitor VPS (RAM dll.).
- "Administrator itu untuk kontrol client misal tambahkan paket."
- Marketing: mengumpulkan nomor pemilik laundry, disimpan di database, WA blast diatur sistem dan AI pusat. Sasaran: pemilik laundry (client dan calon), bukan pelanggan milik laundry.
- "Kamu bisa kan atur wa blast biar aman misal di gilir sehari jangan banyak-banyak" → angka awal disetujui ("Ok"), lalu "Gas buat". Rincian di GOYANA-SISTEM-PUSAT.md §52.
- Dijawab 8 Okt 21.57: nama paket **jangan diganti**, tetap sesuai paket kita (Basic, Silver, Gold, Platinum). Nomor WhatsApp khusus marketing: **nanti dulu**.
- Belum dijawab: sumber calon client selain isi manual dan impor file.

- 8 Oktober 2026 — Balas Status WhatsApp otomatis: mulai paket Silver (Silver, Gold, Platinum). Basic tidak dapat.
- 9 Oktober 2026 — CI hanya membangun APK Mode Murni. APK Hibrida dan APK HTML asli tidak dibangun otomatis lagi ("Pantesan kamu lama mulu"); kodenya tetap di repo. Backend Laravel tetap diuji tiap kiriman.

## 9 Oktober 2026, 07.10–07.56 WIB — Penjemputan disederhanakan ("Gas")

Masalah: menu Antar Jemput terlalu banyak tombol, dan penjemputan yang ditugaskan tidak muncul di tab Penjemputan maupun Tugas Kurir (disimpan terpisah, bukan sebagai pesanan).

- **Buat Penjemputan langsung jadi pesanan berstatus Penjemputan** → muncul di tab Penjemputan (Pesanan), Tugas Kurir HP yang ditugaskan, dan pantauan server.
- **+ Tambah Pesanan tidak diubah** (tetap ada pilihan antar jemput + timbangan di outlet). Buat Penjemputan = **timbang di lokasi**.
- **Kartu Antar Jemput**: foto avatar, nama, jadwal, alamat, kurir, label status. Tombol: **Navigasi**, **Buat Pesanan**, **WhatsApp**. Tombol **⋮** → popup Ganti kurir, Batalkan. Tugaskan / Kirim ke Kurir / Sampai Lokasi dihapus.
- **Form Buat Penjemputan**: cari pelanggan + **Tambah Pelanggan Baru**; hari (Hari ini/Besok/Lusa); jam **Secepatnya · Pagi (08–11) · Siang (11–15) · Sore (15–18)**; Pilih Kurir + **Saya sendiri** (laundry kecil, owner jemput sendiri); alamat otomatis dari pelanggan; catatan opsional.
- Belum ada kurir → popup arahkan **Buat Akun Kurir** (Pengaturan Kurir); isian form tetap tersimpan.
- Avatar memakai foto avatar yang sudah ada. Header (pilih outlet) dan menu bawah (Scan) di mockup **diabaikan**.
- Buat Pesanan bisa dipakai owner, kasir, dan kurir yang ditugaskan (asumsi disetujui).
- Data uji penjemputan lama hanya di HP, tidak dipindahkan.

## 9 Oktober 2026, 11.46 WIB — Buat Pesanan di Antar Jemput

- Tombol **Buat Pesanan** pada kartu penjemputan membuka **Tambah Transaksi yang sama persis** (Pilih Durasi → layanan → Atur Pesanan → Pembayaran), dengan pelanggan sudah terpilih.
- **Tanpa pilihan Penyerahan**: penjemputan selalu **Jemput & Antar** (ongkir mengikuti tarif antar jemput).
- Hasilnya mengisi pesanan Penjemputan yang sama (nomor nota tetap), lalu masuk Antrian.

## 9 Oktober 2026, 20.36 WIB — laporan bug (dicatat dulu, belum diperbaiki)

- **Tutup Kasir → Hitung uang fisik**: saat tombol + / − pecahan diketuk, kolom **Rp** tetap menampilkan **160000** dan tidak mengikuti hitungan pecahan. Contoh di HP Paduka: 50rb × 1 (pecahan lain 0) seharusnya Rp50.000, tetapi kolom tetap 160000, dan pesan selisih ("Kurang Rp44.200") dihitung dari 160000. Perlu dicek: kolom Rp harus = jumlah pecahan setiap kali + / − ditekan (dan isian manual tetap bisa).

## 9 Oktober 2026, 20.54 WIB — permintaan tampilan (dicatat dulu, belum dikerjakan)

- **Antar Jemput → tombol "+ Buat Penjemputan"**: jadikan tombol utama berwarna **oranye/merah GOYANA** (sama dengan tombol utama lain di aplikasi), bukan tombol putih bergaris.

## 9 Oktober 2026, 21.10 WIB — bug penjemputan masuk Antrian Rp0 (diperbaiki)

- Di Pesanan → tab Penjemputan, tombol **Jemput ›** langsung memindahkan penjemputan ke Antrian tanpa timbangan dan harga (Rp0). Sekarang penjemputan yang belum ada layanannya memakai tombol **Buat Pesanan** (Tambah Transaksi tanpa Penyerahan) di kartu Pesanan, rincian pesanan, Tugas Kurir, dan HP kurir. Penjemputan tidak bisa masuk Antrian sebelum ditimbang.
- Pesanan Rp0 yang sudah terlanjur masuk Antrian (GY-261009-0135, -0137) data uji di HP; bisa dibatalkan atau diisi lewat Edit.

## 9 Oktober 2026, 22.08 WIB — Buat Penjemputan versi ringkas

- Halaman **Buat Penjemputan** hanya: **Pilih Pelanggan** (cari), **+ Tambah Pelanggan Baru**, lalu **daftar pelanggan terdaftar** di bawahnya.
- Pilih pelanggan → popup **Jadwal Penjemputan** (Hari ini/Besok/Lusa + Secepatnya/Pagi/Siang/Sore) → popup **Pilih Kurir** (kurir + Saya sendiri; belum ada kurir → Buat Akun Kurir). Kurir dipilih = penjemputan langsung dibuat.
- Alamat otomatis dari data pelanggan; kolom alamat dan catatan di formulir dihapus.
- Tombol **+ Buat Penjemputan** di Antar Jemput jadi tombol utama warna GOYANA (permintaan 20.54).

## 10 Oktober 2026, 05.45 WIB — tutup kasir

- **Pembatalan pesanan yang sudah dibayar**: pengembalian dana dicatat **otomatis** (tunai/non-tunai = pengeluaran "Pengembalian dana", deposit kembali ke saldo pelanggan).
- **Setoran tunai kurir** yang diterima kasir dihitung sebagai **omset** (penjualan tunai) pada tutup kasir.
- Diperbaiki sekalian: kolom Rp tutup kasir mengikuti hitungan pecahan; bayar Saldo Deposit tidak lagi tercatat dua kali.

## 10 Oktober 2026, 07.40 WIB — kurir wajib untuk antar jemput

- Penjemputan yang **belum punya kurir/penjemput** tidak bisa diproses (Buat Pesanan / Jemput): muncul peringatan **"Pilih kurir dulu"** (di Antar Jemput langsung muncul popup Pilih Kurir).
- **Tambah Pesanan** dengan penyerahan **Antar** atau **Jemput & Antar**: di Atur Pesanan ada pilihan **Kurir** (Saya sendiri + daftar kurir), wajib dipilih sebelum lanjut ke Pembayaran. **Datang Langsung tetap seperti biasa** (tanpa kurir).
- Tambah Pesanan tanpa layanan → "Buat Pesanan Jemput" sekarang memakai alur Buat Penjemputan (popup Jadwal → Pilih Kurir).

## 10 Oktober 2026, 08.56 WIB — menu WhatsApp & Chatbot dirapikan

- Halaman **WhatsApp & Chatbot** memakai **tab pil** (seperti filter Laporan): **Perangkat · Otomatis · Chatbot AI · Balas Cepat · Promo**.
- Tab **Chatbot AI** punya **Pengetahuan dari laundry**: tanya-jawab yang ditulis pemilik (aturan, promo, area antar, cara bayar). AI memakainya **selain data aplikasi**. Bisa tambah, edit, hapus.
- Sakelar lama tetap di tempat penyimpanan yang sama (tidak ada pengaturan yang hilang).

## 10 Oktober 2026, 11.17 WIB — menu kurir dobel

- Di Pengaturan → Pegawai ada **Management Kurir** dan **Pengaturan Kurir** yang membuka halaman yang sama (tab Pengaturan Kurir ada di halaman Kurir). Menu **Pengaturan Kurir** terpisah dihapus; yang tersisa satu menu **Kurir** (Tugas antar-jemput, akun & PIN kurir).
- Menu tetap terpisah: **Pegawai**, **Kasir**, **Kurir** — masing-masing dengan hak aksesnya.

## Hak akses kurir per orang (10 Oktober 2026)
- Keputusan Paduka: menu Pegawai / Kasir / Kurir tetap terpisah, masing-masing dengan hak aksesnya. Menu "Pengaturan Kurir" yang dobel dihapus, tinggal satu: Pengaturan › Kurir.
- Pengaturan › Kurir › Edit punya 3 sakelar (bawaan semua nyala): Boleh menimbang di lokasi, Boleh buat transaksi di lokasi, Boleh terima pembayaran.
- Server menegakkan semuanya (kolom users.courier_limits; OrderGuard menolak bila dilanggar).
- Alur bila timbang dimatikan: kurir cukup ketuk "Sudah Dijemput" → pesanan masuk Antrian tanpa layanan → kasir menekan lanjut di Antrian → terbuka Buat Pesanan untuk menimbang di outlet.
- Bila terima pembayaran dimatikan: tombol Bayar disembunyikan di HP kurir; pelanggan membayar di outlet.
- Bila transaksi di lokasi dimatikan: tombol "+ Transaksi di Lokasi" disembunyikan.

## 10 Oktober 2026, 12.02 WIB — cabang, staf, stok
- Keputusan Paduka: **stok bahan per cabang** (masing-masing cabang punya stok sendiri). Sekarang di server stok masih satu untuk semua cabang → perlu diubah (belum dikerjakan).
- Pembukuan kasir masuk ke outlet cabangnya (sudah jalan: akun staf terkunci ke outlet tugasnya, server memaksa outlet_id).
- Usulan menunggu keputusan: staf dikelompokkan per cabang di halaman Outlet; "+ Tambah Kasir/Pegawai/Kurir" langsung dengan tugas & cabang terisi.

## 10 Oktober 2026, 12.09–12.16 WIB — rancangan cabang & hak akses (diskusi, belum dikerjakan)
- Tidak ada email/password per cabang. Pemilik 1 akun; staf masuk No HP + PIN, terkunci ke cabangnya.
- Pilihan Paduka condong ke **monitoring** (bukan switch): HP punya "cabang rumah"; pesanan baru selalu masuk cabang rumah. Cabang lain lewat Monitor Cabang › Kelola Cabang Ini (kas masuk/keluar, tarik uang, stok masuk, opname, transfer stok, koreksi pesanan) dengan pita oranye + tombol "Simpan ke Cabang X" + riwayat "oleh Pemilik (dari jauh)".
- Hak akses 3 lapis: (1) khusus pemilik, tidak bisa dibuka; (2) sakelar per cabang untuk Kasir/Pegawai/Kurir, langsung muncul saat tambah cabang (setelan aman bawaan / salin dari Pusat); (3) selalu boleh sesuai tugas.
- Keputusan Paduka: **ubah berat/jumlah tidak boleh jadi sakelar untuk pegawai** (rawan curang).
- Keputusan Paduka: koreksi kesalahan (mis. berat kiloan salah) boleh, tapi **ada batas per bulan** (contoh 3x); koreksi berikutnya (ke-4 dst) **wajib approve / kode dari pemilik**.
- 12.18 — Keputusan Paduka: kuota koreksi **per kasir, 2x per bulan**. Koreksi ke-3 dst wajib approve/kode pemilik.
- 12.19 — Diperjelas Paduka: begitu pesanan **sudah masuk sistem** (Antrian/Penjemputan) **atau sudah dibayar**, setiap perubahan = koreksi berkuota. Bebas hanya selama belum disimpan (masih di layar Tambah Transaksi). Mengisi timbangan pertama pada penjemputan kosong bukan koreksi.
- 12.56 — Keputusan Paduka: **laundry kecil tidak dibatasi fiturnya**. Fondasi sistem sama untuk kecil & besar; semua fitur (monitoring, hak akses, kuota koreksi, stok/transfer, laporan) tersedia walau 1 cabang. Buka cabang kedua = tinggal tambah cabang, tanpa pindah sistem/data.
- Rancangan lengkap: dokumen "Rancangan Multi-Cabang GOYANA" (claude.ai artifact bd689e71-a1e5-44bd-8cb4-f375a07c4ad2).
- 12.57 — Diubah Paduka: jatah koreksi **bawaan 5x per kasir per bulan**, angkanya **bisa diatur pemilik** (menggantikan 2x).
- 12.58 — Permintaan Paduka: Monitor Cabang dilengkapi **laporan lengkap** (39 laporan, per cabang / gabungan / bandingkan, dihitung di server). Ditambah usulan 10 fitur yang belum ada (komplain & klaim, foto cucian, cucian tak diambil, target omset, kehadiran & kinerja staf, harga per cabang opsional, kapasitas produksi, servis mesin, rating WA, keamanan akun) — ada di dokumen rancangan, belum dikerjakan.
- 13.01 — Keputusan Paduka: **tampilan utama jangan diubah** (Beranda, Tambah Transaksi, daftar pesanan, menu bawah tetap). Semua fitur baru dikumpulkan di **satu halaman di Pengaturan** (usulan nama: "Kelola Usaha"), dikelompokkan: Cabang & Tim · Monitor & Laporan · Kontrol · Operasional.
- 13.05 — Keputusan Paduka (notifikasi): **tanpa lonceng di Beranda**. Angka kecil di menu bawah yang ada (Pesanan = cucian mendesak/telat, Pengaturan = persetujuan); pita tipis di atas daftar Pesanan hanya saat mendesak; riwayat di Pengaturan › Kelola Usaha › Kotak Masuk; notifikasi HP Android tetap. Pengingat "harus mulai dikerjakan" dihitung mundur dari waktu proses per durasi (angka menunggu Paduka), naik tingkat pegawai → kasir → pemilik.
- 13.06 — Aturan kerja Paduka: **cek dulu yang terlewat; kerjakan satu fitur sampai tuntas** (server + aplikasi + tes + audit tombol bersih + APK) baru pindah fitur. Jangan menambah fitur lalu meninggalkan kerjaan setengah jadi. Belum mulai coding rancangan cabang.
- 13.08 — Keputusan Paduka: **zona waktu per cabang (WIB/WITA/WIT)**. Dipilih di Profil cabang (bawaan mengikuti zona HP saat cabang dibuat). Dipakai untuk deadline, pengingat, tutup omset, laporan harian, ringkasan WA malam, dan nomor nota per hari. Laporan gabungan memakai zona pemilik.
- 13.09 — Durasi bisa diedit user; tambah isian "lama dikerjakan" per durasi (editable) untuk pengingat "harus mulai dikerjakan".
- 13.12 — Keputusan Paduka: **stok & opname masuk semua paket**. Paket **tetap harus beda fitur** (ada saringan per paket), bukan hanya beda jumlah cabang/HP. Pembagian fitur per paket: usulan menunggu persetujuan.
- 13.16 — Dikoreksi Paduka: setiap paket = **1 pusat + N cabang** (Basic 1+1, Silver 1+2, Gold 1+3, Platinum 1+5; sesuai server `outlet_limit = 1 + branches`). Free = trial Basic 2 bulan. Karena Basic sudah 2 outlet, **Transfer stok & Monitor Cabang masuk semua paket** (termasuk Basic/trial).
- 13.32 — Keputusan Paduka (paket, butir 1): **Basic/Free tidak bisa Hubungkan WhatsApp**. Nota WA tetap lewat WA HP kasir (tombol WA hijau, kirim manual). Hubungkan WA mulai **Silver** (Balasan Cepat & Trigger, Balas Status); Gold: nota/status otomatis + Chatbot AI; Platinum: Blast. Perlu diperbaiki: kunci menu Hubungkan WA untuk Basic/Free, hapus teks "termasuk FREE" di Upgrade, server tolak nomor WA dari Basic.
- Cara kerja Paduka: diskusi pembagian paket satu per satu di chat, dirangkum, **baru di akhir dokumen rancangan diedit sekali** (hemat kuota).
- 13.37 — Paket butir 2 (Pelanggan) disetujui: data/riwayat/peta & deposit semua paket; loyalitas (poin, voucher, level) dan rating WA mulai Gold.
- 13.39 — Paket butir 3: Tim/kontrol/antar-jemput semua paket; kinerja & bonus mulai Gold. Keputusan Paduka: **akun staf dibatasi per paket** — Basic 2 kasir · 2 kurir · 2 pegawai; tiap naik paket +1 masing-masing (Silver 3/3/3, Gold 4/4/4, Platinum 5/5/5). (Per outlet atau per usaha: menunggu jawaban.)
- 13.43 — Keputusan Paduka: batas akun staf **per outlet**; **Kepala Cabang 1 per outlet** (tidak memakan kuota kasir); **bisa beli tambahan akun** satuan (add-on). Permintaan baru: **pembelian saldo** di sistem untuk upgrade paket (Saldo GOYANA) — rancangan didiskusikan, belum dikerjakan.
- 13.44 — Keputusan Paduka: kalau GOYANA belum berbadan usaha (syarat user choice billing Google Play), **fitur isi saldo ditiadakan**; paket & add-on dibayar lewat Google Play saja.
- 13.47 — Paket butir 4 (Uang & Stok): kas/tutup omset/QRIS/pengeluaran/ralat, stok/opname/transfer, dan **pemakaian bahan otomatis per layanan (resep) semua paket**. Silver ke atas: laporan HPP & laba per layanan, supplier/pembelian/hutang supplier, umur piutang + penagihan.
- 13.48 — Paket butir 5 (Cabang) disetujui: Monitor/Kelola/zona waktu semua paket; target omset mulai Gold; bandingkan & peringkat cabang + harga per cabang hanya Platinum.
- 13.49 — Paket butir 6 (Laporan) disetujui: laporan dasar (Keuangan, Transaksi) semua paket; laporan lengkap, Export, laba-rugi per cabang mulai Silver (Basic tidak); ringkasan WA malam mulai Gold; laba-rugi gabungan Platinum.
