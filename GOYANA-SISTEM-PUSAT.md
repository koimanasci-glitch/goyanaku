# GOYANA — Acuan Sistem Pusat, Akun, Pembayaran, dan Otomasi
Tanggal: 2 Oktober 2026.

Dokumen ini merangkum pembahasan terbaru dan melengkapi GOYANA-ROADMAP.md bagian 37–42. Ini adalah acuan implementasi, bukan pernyataan bahwa backend telah selesai. Keputusan terbaru di sini menggantikan label/harga paket lama yang bertentangan; usulan belum final tetap diberi label.

## 1. Status dan arsitektur

- APK sekarang adalah prototype HTML/CSS/JavaScript dengan Capacitor dan banyak penyimpanan lokal.
- Flutter adalah target Android produksi; belum berarti APK sekarang sudah Flutter.
- Backend pusat menggunakan Laravel/PHP, database pusat, queue, scheduler, dan API.
- Dashboard web menggunakan halaman HTML/CSS/JavaScript yang dilayani/terhubung ke Laravel; Laravel bukan pengganti HTML.
- Android produksi, dashboard owner, dan dashboard administrator memakai layanan bisnis pusat yang sama dengan pemisahan akses dan data per usaha.
- Usulan struktur proyek: satu repo Goyana berisi Android, backend beserta dashboard, dan dokumentasi. Layanan gateway dapat terpisah secara proses/deployment.
- Chatku adalah calon gateway WhatsApp yang dapat digunakan kembali; periksa kode dan API terbaru dahulu. Node.js/JavaScript dapat digunakan bila mesin gateway yang dipilih memerlukannya, bukan prasyarat seluruh sistem.

## 2. Tiga kelompok pengguna

| Bagian | Pengguna | Fungsi |
|---|---|---|
| Android | Owner/admin laundry, kasir, produksi, kurir | Operasional usaha |
| Web owner | Owner/admin laundry berizin | Kelola usaha, cabang, laporan, akun dan paket |
| Web administrator Goyana | Paduka dan tim platform | Kelola pelanggan usaha, billing, bantuan dan kesehatan layanan |

Administrator platform tidak dimasukkan ke APK pelanggan. Administrator laundry berbeda dari administrator platform. Pelanggan akhir laundry menerima WA/status pesanan; tidak wajib memakai aplikasi tersendiri.

## 3. Pendaftaran dan login

- Daftar owner melalui email/password atau login Google. “Login Gmail” berarti Sign in with Google; aplikasi tidak meminta password Gmail.
- Daftar meminta nama usaha/outlet pusat dan nomor kontak; backend membuat usaha/outlet satu kali, bukan duplikat saat retry.
- Email/password: verifikasi email, hash password, reset lewat token sekali pakai dengan masa berlaku, pengaturan sesi dan logout.
- Login Google: validasi identitas/token pada backend dan alur penautan akun yang terverifikasi agar email sama tidak membuat usaha duplikat atau mengambil alih akun.
- Login gagal menampilkan pesan singkat seperti “Email atau password tidak sesuai”; jangan membocorkan apakah email tertentu terdaftar.
- Jangan mengirim email setiap satu kali salah password. Terapkan rate limit; notifikasi keamanan untuk kejadian relevan seperti perangkat baru/percobaan mencurigakan.
- Pengguna belum mempunyai email pengirim layanan. Pembangunan bisa memakai pengujian email; produksi perlu alamat/domain pengirim dan layanan SMTP/API yang terverifikasi, termasuk SPF/DKIM/DMARC bila relevan.
- Owner/admin berizin membuat/mengundang kasir, pegawai, kurir dengan akun sendiri, role, permission, dan cabang.
- Tampilan kasir tetap seperti aplikasi sekarang; menu tidak diizinkan terlihat terkunci. Server tetap menolak operasi dan tidak mengirim isi data tanpa izin.
- Akun nonaktif tidak menghapus histori. Password/token/secret tidak tampil di chat CS atau log publik.

## 4. Cabang dan perangkat

- Batas disepakati: maksimal **dua perangkat kasir yang diizinkan per outlet**, termasuk pusat.
- Akun kasir tambahan tidak menambah slot perangkat. Owner bertransaksi memakai slot; monitoring saja tidak.
- Owner melihat daftar perangkat, pengguna, outlet, terakhir aktif, dan dapat mencabut akses untuk ganti HP.
- Perangkat kurir terpisah dan tidak memperoleh akses kasir.
- Server memeriksa role, outlet, perangkat, dan paket pada operasi serta sinkronisasi; catat audit.
- Batas lima akun kasir/produksi dan dua kurir per outlet hanya usulan, belum keputusan.
- Satu sesi aktif per akun kasir dan periode izin offline perlu finalisasi. Lindungi data lokal yang belum sync ketika perangkat dicabut.

## 5. Katalog terbaru

Harga dan cabang mengikuti pembahasan 2 Oktober 2026; cabang di luar satu outlet pusat.

| Paket | Harga bulanan | Cabang |
|---|---:|---:|
| Free | Gratis, trial Basic 2 bulan | 1 |
| Basic | Rp30.000 | Usulan sebelumnya 1; belum ditegaskan pengguna |
| Silver | Rp65.000 | 2 |
| Gold | Rp100.000 | 3 |
| Platinum | Rp350.000 | 5 |

- Monitoring, kurir, antar-jemput, dan lokasi mengikuti batas outlet.
- Basic: koordinasi WA manual.
- Silver: Balasan Cepat.
- Gold: WA otomatis dan Chatbot AI; AI memakai top-up terpisah.
- Platinum: seluruh fitur termasuk blast; AI tetap memakai top-up.
- Harga terlihat di Harga Paket; detail paket fokus daftar fitur centang/silang.
- Backend menjadi sumber trial, paket, masa aktif, kuota cabang/perangkat, dan saldo AI; mode uji lokal bukan entitlement produksi.
- Harga add-on, kuota WA/AI/device bawaan, dan syarat tambahan yang belum final jangan diisi berdasarkan asumsi.
- Masa trial, upgrade/downgrade, expiry, refund, grace period, dan kuota saat downgrade perlu aturan terpusat; jangan menghapus data bisnis saat paket berakhir.

## 6. Pisahkan dua jenis pembayaran

### A. Pelanggan usaha membayar paket Goyana

Android dari Google Play:
- Rencana memakai Google Play Billing untuk paket digital yang dibeli dalam aplikasi.
- Backend memverifikasi pembelian, mengaitkannya dengan akun usaha, mengelola notifikasi renewal/expiry/refund/revocation, dan membuka hak sesuai hasil verifikasi.
- Restore pembelian dan pencegahan langganan ganda wajib dirancang.
- Jangan mengaktifkan paket hanya karena callback tampilan sukses atau screenshot bayar.
- Aturan Google yang diperiksa pada 2 Oktober 2026: fitur/cloud software digital yang dibeli dalam aplikasi memakai Play Billing kecuali pengecualian/program berlaku; layanan fisik seperti cleaning memakai jalur lain.
- Dokumentasi metode bayar Indonesia menyatakan QRIS tidak dapat membayar subscriptions Google Play. Jangan menjanjikan langganan Play via QRIS.
- Tautan/ajakan membeli paket di web dari Android harus mengikuti program dan aturan yang berlaku untuk app/region. Halaman bantuan/WA tidak boleh dipakai sebagai jalur terselubung menuju pembayaran yang dilarang.
- Akses lintas perangkat/platform menggunakan hak akun yang tervalidasi; sinkronisasi hak tidak otomatis memberi izin menaruh checkout web di Android.

Web:
- Pilih **satu** payment gateway dahulu: Midtrans atau Xendit; merchant akun belum dikonfigurasi oleh pengguna.
- Usulan tahap awal: invoice per periode dengan pembayaran aktif pelanggan, lalu aktivasi otomatis setelah backend memverifikasi status pembayaran.
- Autodebit adalah tahap tersendiri: metode yang mendukung, persetujuan pelanggan, tokenisasi, penanganan gagal dan pembatalan.
- Midtrans Subscription API yang diperiksa mendukung credit_card dan gopay; bukan berarti semua metode checkout dapat autodebit.
- Xendit Subscriptions memerlukan channel aktif yang mendukung Merchant-Initiated Transactions; metode/aktivasi bergantung pada akun dan channel.
- Verifikasi webhook, cocokkan akun/invoice/nominal/currency, cek status bila perlu, dan cegah duplikasi event.
- Satu status paket pusat untuk web/Android; simpan sumber pembayaran, referensi invoice, dan masa aktif. Jika sudah punya langganan aktif, jangan diam-diam menjual renewal kedua di jalur lain.
- Nominal di UI Android harus cocok dengan Play checkout; harga daftar sekarang bukan konfigurasi Play Console yang sudah aktif.

### B. Pelanggan laundry membayar cucian

Tunai, transfer, QRIS, DP, piutang, dan deposit adalah transaksi jasa laundry; pisahkan dari pendapatan langganan Goyana dan saldo AI.

- QRIS menampilkan nominal bukan bukti pembayaran otomatis terverifikasi.
- Auto-lunas memerlukan integrasi/acquirer/gateway dan bukti status yang tervalidasi, dengan pemetaan merchant/outlet yang benar.
- Jangan memakai satu merchant langganan Goyana untuk semua penerimaan laundry tanpa rancangan settlement dan onboarding merchant yang tepat.
- Idempotency untuk pembayaran/DP/refund/deposit; audit dan rekonsiliasi.
- Deposit top-up bukan langsung omzet; piutang, kas diterima, omzet, HPP, dan laba dipisahkan.

## 7. Data, offline, dan operasional

- Isolasi usaha dan outlet pada backend; identitas usaha ditentukan token, bukan dipercaya dari request klien.
- Android Flutter menyimpan transaksi lokal dengan SQLite, outbox, ID unik, retry, acknowledgment server, dan penanganan konflik.
- Offline terbatas pada data/izin yang telah tersedia; login pertama, billing, pesan WA, dan data cabang terbaru memerlukan koneksi.
- Backup otomatis di lokasi terpisah, retention, serta uji restore. Tampilkan data pending sync.
- Pertahankan alur transaksi, produksi, scan, nota, printer, DP/deposit, tutup kas, stok, opname, transfer, dan laporan.
- Stok ledger per outlet, konfirmasi penerimaan transfer, audit; pembatalan setelah produksi tidak otomatis mengembalikan bahan habis terpakai.
- Uji printer/kamera/GPS dan update APK pada Android fisik, bukan hanya tes browser.

## 8. WhatsApp, chatbot dan kurir

- Setiap device terikat usaha/outlet; tambah device bukan berarti sudah paired. Status berasal dari gateway nyata.
- Gateway/Chatku menangani koneksi dan pengiriman; webhook membawa pesan masuk ke backend.
- Tampilan kurir memakai struktur/alur sekarang dengan kartu lebih lega, peta lebih baik, tombol berwarna dan label penerima jelas.
- Navigasi/WhatsApp Pelanggan menuju pelanggan tugas terkait; Hubungi Outlet bila ditambahkan merupakan tombol berbeda.
- Saat masuk Penjemputan, paket otomatis mengirim pertanyaan jadwal ke pelanggan; Basic tetap manual.
- Balasan “jam lima sore” menjadi 17.00 pada tugas terkait; pastikan tanggal dan minta penjelasan bila ambigu. Pisahkan jadwal jemput/antar.
- Notifikasi ke kurir hanya ke kurir yang ditugaskan, berisi alamat, lokasi dan jadwal. Kurir jemput/antar boleh berbeda.
- Jangan menggandakan pesan karena retry, webhook ulang, reload, atau upgrade. Penugasan ulang/pembatalan memperbarui akses dan pemberitahuan.
- Chatbot hanya memakai data laundry yang benar; status pesanan pelanggan memerlukan pemeriksaan identitas/kepemilikan yang sesuai.

## 9. Administrator, CS dan AI pusat

Panel Paduka mencakup akun usaha, trial/paket, invoice, cabang, users/devices, status WA, tiket, audit, kesehatan API/queue/sync, dan backup.
- Akun administrator platform memakai izin khusus dan pengamanan lebih kuat seperti MFA; bukan akun laundry biasa.
- Nomor pusat/marketing/CS punya fungsi dan akses berbeda.
- AI pusat mengidentifikasi pelapor terverifikasi, membaca API diagnosis terbatas, menjawab berdasarkan bukti, dan menjalankan pemulihan yang terdaftar.
- Monitoring proaktif mendeteksi gangguan tanpa menunggu laporan.
- Retry aman/idempotent dan verifikasi hasil; scan ulang WA tetap membutuhkan pemilik nomor.
- Reset akses/data/uang dan tindakan berdampak luas memerlukan otorisasi khusus atau eskalasi manusia. Bot tidak diberi shell server tanpa batas.
- AI pusat terpisah dari chatbot laundry serta kuota AI pelanggan; biaya AI pusat perlu anggaran tersendiri.

## 10. Urutan pembangunan

1. Audit sumber terbaru Goyana/Chatku; finalisasi schema, permission, dan rincian paket yang belum pasti.
2. Bangun Laravel auth, usaha/outlet, users, devices, paket, audit, dan administrator dasar.
3. API operasional, transaksi/keuangan/stok/kurir serta protokol sync dan backup.
4. Hubungkan Android produksi Flutter dan web owner ke API yang sama.
5. Billing sandbox Google Play dan satu gateway web; uji renewal, expiry, duplikasi, refund, restore, dan perpindahan jalur.
6. Integrasi WA/Chatku, webhook, jadwal, dan chatbot sesuai hak paket.
7. Monitoring/CS diagnosis, lalu pemulihan otomatis bertahap.
8. Uji keamanan/isolas/data recovery dan perangkat nyata sebelum peluncuran produksi.

## 11. Yang perlu disiapkan, bukan penghalang membuat fondasi

- Domain/DNS dan server produksi beserta akses deployment yang sesuai.
- Alamat email pengirim dan penyedia SMTP/API; konfigurasi Google sign-in.
- Akun/produk dan akses verifikasi Google Play Console.
- Akun merchant salah satu gateway web, channel pembayaran aktif, sandbox/live keys dan webhook.
- Sumber/akses Chatku terbaru, konfigurasi gateway WA dan nomor pusat/CS.
- Penyedia AI, anggaran, secret server serta aturan penggunaan.
- Kebijakan privasi, syarat layanan, alur hapus akun dan ketentuan paket.
- Jangan menaruh secret produksi di APK/repo; konfigurasi server/environment.

## Sumber resmi yang diperiksa 2 Oktober 2026

- Google Play Payments: https://support.google.com/googleplay/android-developer/answer/9858738?hl=en
- Google Play Payments FAQ: https://support.google.com/googleplay/android-developer/answer/10281818?hl=en
- Metode pembayaran Indonesia: https://support.google.com/googleplay/answer/2651410?co=GENIE.CountryCode%3DID&hl=en
- Play subscription lifecycle: https://developer.android.com/google/play/billing/subscriptions
- Midtrans Subscription API: https://docs.midtrans.com/reference/create-subscription
- Xendit Subscriptions: https://docs.xendit.co/docs/how-subscriptions-work

Aturan dan channel dapat berubah; periksa kembali ketika implementasi/peluncuran.
