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

**Keputusan pengguna 2 Oktober 2026:** tidak ada paket gratis permanen. Setelah trial 2 bulan habis, akun **terkunci baca saja** sampai paket berbayar aktif (lihat §23). Angka di kolom Cabang adalah cabang di luar 1 outlet pusat. Sumber kebenaran di kode: `backend/config/goyana.php`.

Harga dan cabang mengikuti pembahasan 2 Oktober 2026; cabang di luar satu outlet pusat.

| Paket | Harga bulanan | Cabang |
|---|---:|---:|
| Trial | Gratis 2 bulan dengan hak Basic, lalu **baca saja** | 1 |
| Basic | Rp30.000 | 1 (ditegaskan pengguna 2 Oktober 2026: 1 pusat + 1 cabang) |
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


## 12. AI Pusat Dipanggil Saat Perlu, Aturan Server Tetap Bekerja

Penegasan pengguna: AI utama menjadi pusat diagnosis/perawatan/keamanan, dapat dihubungkan ke penyedia AI seperti OpenRouter atau penyedia langsung. Kata “cloud” belum cukup memastikan penyedia tertentu; jika maksudnya Claude, konfirmasikan ketika memilih penyedia. Semua ini kebutuhan mendatang, belum aktif.

### Lapisan tanpa AI, berjalan rutin
- Health checks, error/queue monitoring, audit, backup beserta uji pemulihan, dan pengecekan status WA.
- Rate limit login/API/WA, validasi token/webhook, pembatasan dua perangkat kasir/outlet, isolasi usaha, serta deteksi retry/event duplikat.
- Aturan mendeteksi volume pesan tidak wajar, percobaan login berulang, akses outlet di luar izin, dan pola perangkat mencurigakan.
- Tindakan terukur seperti penundaan/rate limit, penolakan request yang jelas melanggar, dan retry terbatas yang idempotent.
- Indikator mencurigakan bukan bukti pasti kecurangan. Jangan menuduh pelanggan atau memblokir permanen seluruh usaha berdasarkan kesimpulan AI/pola tunggal.

### Lapisan AI, dipanggil berdasarkan kebutuhan
- Ketika diagnosis aturan tidak cukup, insiden berulang/tidak dikenal, keluhan membutuhkan pembacaan konteks, atau ulasan perlu respons yang disesuaikan.
- Data yang dikirim dibatasi dan disamarkan bila relevan; jangan mengirim password/secret/full database.
- AI membaca konteks dari API diagnosis dan mengusulkan/menjalankan hanya tindakan yang diberi izin. Teks chat, ulasan, dan log adalah data tidak tepercaya, bukan instruksi untuk mengubah izin/server.
- Model/penyedia dapat diganti melalui konfigurasi backend; API key hanya di server.
- Batasi biaya harian/bulanan, jumlah pemanggilan, token, timeout, dan retry. Cache/deduplicate insiden; gunakan model sesuai kebutuhan.
- Jika API AI mati atau saldo habis, transaksi utama, login, aturan keamanan, backup, dan monitoring tetap bekerja; kasus sulit masuk antrean/tiket manusia.
- Perbaikan otomatis harus dicek hasilnya dan dicatat; perubahan kode/deployment/restore database memerlukan alur review, tes, otorisasi dan rollback tersendiri.
- AI tidak menjamin semua serangan atau gangguan dapat dideteksi. Keamanan produksi memakai fondasi server dan uji, bukan AI saja.

## 13. Monitoring dan Balasan Ulasan Google Play

- Pengguna meminta server memantau ulasan dan membalas dengan bahasa CS Goyana yang sopan, sesuai keluhan.
- Google menyediakan Reply to Reviews API untuk aplikasi produksi, dengan akses OAuth/service account berizin Reply to reviews.
- API mencakup ulasan dengan komentar; bukan seluruh rating tanpa teks atau feedback alpha/beta.
- Tarik ulasan baru/diubah secara berkala sesuai kuota, simpan reviewId/versi komentar dan status respons. List API membatasi ulasan dibuat/diubah dalam minggu terakhir, sehingga arsip pusat harus dibangun bertahap; histori lebih lama melalui ekspor Console bila diperlukan.
- Batas respons API yang diperiksa: 350 karakter. Jangan memuat data pribadi, nomor transaksi, identitas usaha, atau log internal pada respons publik.
- Rancangan otomatis: pujian/FAQ aman menggunakan template; keluhan dianalisis AI bila diperlukan; kasus sensitif/diagnosis tidak pasti perlu eskalasi. Cegah respons ganda/berulang.
- Jangan mengklaim “sudah diperbaiki”, “sedang diperiksa”, atau tanggal selesai tanpa status pekerjaan nyata. Ulasan dapat membuat tiket, tetapi bukan bukti identitas pelanggan.
- Contoh awal bila belum ada diagnosis: “Mohon maaf atas kendala yang dialami. Agar kami dapat membantu dengan tepat, silakan hubungi CS melalui menu Bantuan dan sertakan versi aplikasi serta langkah saat kendala muncul. Jangan cantumkan data pribadi di ulasan ini. Terima kasih atas masukannya.”
- Jika insiden/perbaikan telah terverifikasi, respons dapat menyebut kondisi serta langkah yang benar, tanpa janji kosong.
- Perlu packageName aplikasi produksi dan akses Play Developer API; belum ada koneksi/otomasi balasan aktif dalam pekerjaan ini. Ini modul backend Goyana, bukan pembuatan reminder/automation eksternal ChatGPT.

Sumber tambahan resmi:
- Reply to Reviews: https://developers.google.com/android-publisher/reply-to-reviews
- Endpoint reply: https://developers.google.com/android-publisher/api-ref/rest/v3/reviews/reply
- OpenRouter API: https://openrouter.ai/docs/quickstart
- Claude API (opsi bila penyedia ini dipilih): https://platform.claude.com/docs/en/api/overview


## 14. Monitoring VPS, Kapasitas, dan Pemulihan Server

Kebutuhan pengguna: pantau kestabilan, sisa RAM/kapasitas, sarankan upgrade/tambah VPS saat beban meningkat, dan lindungi data pelanggan saat server rusak.

- Pantau CPU/load, RAM tersedia/swap/OOM, disk ruang/inode/I/O, jaringan, waktu respons/error API, database, antrean pekerjaan, koneksi WA, dan umur backup terakhir.
- Gunakan pemantau eksternal juga; proses yang berada hanya pada VPS utama tidak bisa melaporkan dengan andal ketika VPS tersebut mati.
- Tentukan ambang/periode peringatan setelah baseline beban nyata; jangan membeli VPS hanya karena satu lonjakan RAM.
- Panel menampilkan kapasitas, tren pertumbuhan, hambatan yang ditemukan, dan rekomendasi/estimasi biaya. AI dipakai untuk analisis yang perlu, bukan setiap pengukuran.
- **Upgrade VPS** menambah kapasitas mesin yang sama. **Tambah VPS** menambah mesin yang perlu deployment dan pembagian beban. Menghidupkan mesin kedua saja tidak membuat sistem otomatis lebih cepat.
- Usulan perkembangan: optimasi dan upgrade awal bila tepat; pisahkan gateway/worker WA dari aplikasi bila beban memang di sana; tambah server aplikasi dengan load balancer/shared session/storage ketika perlu. Bottleneck database memerlukan optimasi/kapasitas database tersendiri.
- Provider/API, downtime saat resize, ukuran mesin, dan biaya belum ditentukan. Jangan menjanjikan zero downtime atau failover tanpa arsitektur/uji.
- Pembelian/upgrade berbayar memerlukan persetujuan spesifik atau kebijakan anggaran otomatis yang disetujui sebelumnya (batas biaya, jumlah, cooldown, dan tindakan yang diizinkan). Permintaan merancang otomasi belum menjadi izin pengeluaran tanpa batas.

### Backup dan disaster recovery
- Server mati sementara biasanya berarti data tidak dapat diakses, bukan otomatis hilang; kegagalan disk, penghapusan, atau kompromi tetap dapat menyebabkan kehilangan.
- Simpan backup database serta file penting di luar VPS utama, dengan akun/akses terpisah, enkripsi, dan retention/versioning yang melindungi dari penghapusan/overwrite.
- Usulan awal: full backup harian dan arsip perubahan database/PITR bila mesin database serta anggaran mendukung. Frekuensi, retensi, toleransi kehilangan data (RPO), serta target waktu pulih (RTO) belum disepakati; ukur melalui restore test.
- Backup harian saja dapat kehilangan perubahan sejak backup sukses terakhir; jangan menjanjikan nol kehilangan data.
- Pantau keberhasilan dan umur backup, integritas, serta uji restore berkala di lingkungan terpisah. Status “backup ada” bukan bukti backup dapat dipulihkan.
- Siapkan runbook VPS pengganti, pemulihan database/files, secret server, DNS/routing, verifikasi transaksi dan rekonsiliasi event. AI membantu analisis, pelaksanaan mengikuti izin/konfirmasi sesuai dampak.
- Replica/server cadangan membantu ketersediaan tetapi bukan pengganti backup; penghapusan/kesalahan dapat ikut tereplikasi.
- Android offline menjaga operasional lokal terbatas; transaksi belum sync tetap berisiko hilang bila perangkat rusak/uninstall. Tidak menggantikan backup server.

Sumber referensi teknis (bukan keputusan memilih provider/database):
- Resize/vertical scaling: https://docs.digitalocean.com/products/droplets/how-to/resize/
- Metrik monitoring: https://docs.digitalocean.com/products/monitoring/concepts/metrics/
- PostgreSQL PITR: https://www.postgresql.org/docs/17/continuous-archiving.html

## 15. Bantuan Jarak Jauh kepada Pelanggan

Kebutuhan pengguna: pelanggan yang membutuhkan bantuan dapat dibantu AI/pusat secara jarak jauh; jangan menganggap kebutuhan ini sebagai izin akses ke semua HP/data.

- Tahap utama: pelanggan membuka/meminta sesi bantuan; sistem memverifikasi identitas dan membuat tiket/sesi terbatas. AI membaca status akun, outlet/device, error, sinkronisasi, dan konfigurasi yang diperlukan melalui API.
- Sertakan fungsi “Kirim Diagnostik” pada aplikasi bila dibangun: pelanggan memahami data yang dikirim; batasi/redaksi data sensitif. Screenshot/log hanya jika perlu dan diizinkan.
- Perbaikan melalui backend dapat berupa diagnosis, petunjuk, dan tindakan terbatas yang telah diotorisasi. Jangan menjanjikan bot dapat menekan seluruh tombol atau memperbaiki APK di HP dengan sendirinya.
- **Remote layar/kendali HP merupakan integrasi terpisah** dengan kemampuan Android yang sesuai. Memerlukan persetujuan eksplisit per sesi; pelanggan dapat menghentikan sesi. Melihat layar dan mengendalikan perangkat adalah izin berbeda.
- Masking/pengecualian untuk password, OTP, pembayaran, dan data sensitif; jangan meminta pelanggan menyerahkan password/OTP kepada AI.
- Catat waktu, petugas/AI, tindakan, izin, hasil dan durasi; sesi kedaluwarsa, bukan akses permanen.
- Jika server utama mati, layanan monitoring/CS yang dihosting terpisah dapat melaporkan kondisi dan membantu pemulihan menggunakan sumber eksternal. Namun tidak dapat membaca data terbaru yang hanya ada di server mati; tampilkan keterbatasan dan jangan menebak.
- Data yang dipulihkan dan transaksi lokal pending sync harus direkonsiliasi tanpa duplikasi sebelum dianggap normal kembali.
- Prioritas pertama diagnosis lewat backend dan bantuan terpandu; kendali layar penuh menyusul setelah kelayakan teknis, provider, biaya, serta izin sesi ditetapkan.


## 16. CRM Pusat dan Database untuk Pengelolaan/Marketing

Kebutuhan pengguna: pusat mengumpulkan/mengelola database klien serta pelanggan lintas outlet untuk dukungan dan kemungkinan marketing. Penyimpanan terpusat bukan otomatis izin menggunakan seluruh kontak untuk promosi.

### Dua kelompok data
- **Pelanggan usaha Goyana**: pemilik/admin laundry yang mendaftar, kontak usaha, cabang, paket/masa aktif, invoice, riwayat bantuan dan izin komunikasi. Ini dasar CRM pusat Goyana untuk onboarding, bantuan, renewal, serta kampanye yang sesuai.
- **Pelanggan akhir laundry**: nama/kontak/alamat/pesanan pelanggan setiap laundry. Simpan untuk operasional usaha terkait; tetap terikat tenant/outlet. Jangan menggabungkan kontak menjadi daftar blast lintas laundry secara otomatis.
- Owner laundry dapat melihat pelanggan outlet milik usahanya sesuai izin; laundry lain tidak dapat mengaksesnya. Akses administrator pusat untuk dukungan harus dibatasi, bertujuan jelas dan diaudit.

### Penggunaan marketing yang dirancang
- Sediakan persetujuan marketing yang terpisah dari kebutuhan operasional, dengan tujuan, pengirim, channel, waktu/sumber bukti dan mekanisme berhenti.
- Persetujuan menerima nota/reminder laundry tidak otomatis berarti setuju promosi dari platform Goyana. Izin owner laundry tidak dengan sendirinya menggantikan hak/persetujuan pelanggan akhir.
- Sebelum kampanye kepada pelanggan akhir untuk tujuan lain/lintas usaha, tetapkan dasar pemrosesan dan pemberitahuan yang sesuai serta consent yang relevan. Jangan mengekspor/menjual atau membagi kontak tanpa dasar dan otorisasi.
- Respect opt-out/STOP/BERHENTI melalui daftar penghentian promosi; pesan operasional tetap diatur terpisah sesuai tujuan/dasar yang berlaku.
- Data pusat dapat disegmentasi untuk CRM berdasarkan paket, wilayah usaha, trial/aktif/expired dan kebutuhan bantuan. Preferensikan statistik agregat untuk analisis pelanggan akhir lintas usaha.
- Atur retention, koreksi/penghapusan yang relevan, akses/ekspor, enkripsi dan audit; peran pengendali/prosesor ditetapkan dalam kebijakan/perjanjian.
- Sistem tidak menjalankan campaign, mengumpulkan kontak eksternal, atau mengirim pesan dalam pencatatan kebutuhan ini.

Referensi resmi:
- UU 27/2022 Pelindungan Data Pribadi: https://peraturan.bpk.go.id/Details/229798/uu-no-27-tahun-2022
- WhatsApp opt-in: https://developers.facebook.com/documentation/business-messaging/whatsapp/getting-opt-in
- WhatsApp Business Messaging Policy: https://whatsappbusiness.com/policy/


## 17. Saldo AI dan Top-up Android

Penegasan terbaru pengguna: top-up minimal **Rp50.000**; target keuntungan 20–30%, dengan contoh 30%. Ini rancangan backend, bukan fitur pembayaran/saldo yang sudah aktif. Tombol prototype saat ini menampilkan top-up belum terhubung.

- Saldo AI terikat akun usaha, tersimpan di server sebagai ledger, terlihat konsisten pada Android/web. Pisahkan dari deposit laundry, langganan paket, dan anggaran AI pusat.
- Untuk pembelian digital dalam Android Google Play, rancang produk sekali beli consumable melalui Play Billing, sesuai kebijakan/program yang berlaku. Backend memverifikasi status PURCHASED dan akun usaha; purchaseToken unik mencegah saldo bertambah dua kali. Pending/gagal tidak menambah saldo. Konsumsi/acknowledgment, retry, refund/revocation dan rekonsiliasi wajib ditangani.
- Web memakai gateway terpilih dengan verifikasi dan ledger yang sama; tidak memasang ajakan checkout web dalam Android tanpa dasar kebijakan yang sesuai.
- Usulan: pembayaran Rp50.000 menambah kredit pemakaian Rp50.000; keuntungan diterapkan pada tarif penggunaan, bukan dipotong diam-diam saat top-up. Harga/tarif dan perubahan diumumkan sebelum pemakaian.
- Bedakan markup dan margin: modal Rp1.000 ditambah 30% menjadi Rp1.300 (margin sekitar23,08%). Target margin30% dari harga jual memakai harga=modal/0,70; modal Rp1.000 menjadi sekitarRp1.429. Pengguna belum menetapkan apakah 30% adalah markup atau margin bersih.
- Margin bersih memperhitungkan biaya nyata model, pembelian kredit OpenRouter, kurs/konversi, biaya Play/gateway, pajak, dan infrastruktur yang relevan. Tidak menjamin untung30% hanya dengan menaikkan biaya model30%.
- OpenRouter tidak mempunyai satu tarif semua chat: tarif mengikuti model, token input/output, dan fitur tambahan. Backend mengambil katalog harga resmi/API dan mencatat model, biaya aktual, kurs bersumber/timestamp, serta versi tarif setiap pemakaian. Gunakan biaya konversi nyata untuk rekonsiliasi; kurs referensi bukan selalu kurs tagihan.
- Kurs dan harga diperbarui terjadwal; sumber kurs/provider/model belum dipilih. Jangan memakai angka kurs tetap atau menjanjikan jumlah chat tertentu untuk Rp50.000.
- Debit idempotent/atomik dengan reservasi batas biaya bila perlu, cegah saldo negatif karena chat bersamaan, tampilkan histori; retry tidak mendebit dua kali. Jika provider tetap membebankan request gagal, perlakuan biaya pelanggan harus eksplisit, bukan tersembunyi.
- Nota elektronik, reminder terjadwal, notifikasi status, dan balasan template dapat berjalan tanpa AI; tidak mengurangi saldo AI. Biaya layanan WhatsApp terpisah jika ada.
- Hak chatbot mengikuti paket; saldo positif tidak otomatis membuka fitur paket yang tidak mencakup AI. Saldo habis menghentikan pemanggilan AI berbayar, sementara operasional/template tetap berjalan.
- Tetapkan kebijakan saldo tersisa, refund, expiry dan tarif sebelum produksi; jangan menghapus saldo tanpa ketentuan yang jelas.

Referensi:
- Produk sekali beli: https://developer.android.com/google/play/billing/one-time-products
- Verifikasi backend: https://developer.android.com/google/play/billing/security
- Harga OpenRouter: https://openrouter.ai/pricing
- Katalog model/API: https://openrouter.ai/docs/api/api-reference/models/get-models

## 18. Nota Elektronik di Web dan Kode Pesanan

Penegasan pengguna: link nota membuka halaman web berisi nota, nomor/ID pesanan serta barcode/QR yang dapat dipindai, bukan harus membuka APK.

- Nota mencantumkan identitas laundry/outlet, ID pesanan yang konsisten dengan aplikasi, layanan/nominal, status pembayaran, dan status pesanan yang diizinkan.
- Kode pada nota web dan nota cetak mengarah ke pesanan yang sama. Format QR/barcode harus sesuai pemindai operasional yang dipilih; belum menyatakan format/scan prototype sekarang sudah berfungsi produksi.
- Link publik memakai token acak yang tidak dapat ditebak; nomor urut/ID internal saja tidak memberi akses. Batasi informasi pribadi, cegah akses lintas usaha dan sediakan pencabutan token bila perlu.
- Pemindaian oleh pegawai membuka pesanan sesuai login/hak akses; pelanggan hanya mendapat halaman status/nota terbatas. Membuka link atau memindai kode tidak otomatis melunasi atau menyelesaikan pesanan.
- Pengiriman link/nota menggunakan template tanpa kebutuhan AI. Jadwal/status diperbarui dari backend; jangan menampilkan data lokal belum sync sebagai status pusat.


## 19. Klien Beta dan Pengaturan Paket Manual oleh Administrator Pusat

Penegasan pengguna: administrator pusat dapat menambahkan klien dan memberikan/mengubah paket secara manual, misalnya Platinum sementara untuk teman penguji beta, lalu mengembalikan ke aturan pembayaran biasa.

- Administrator berizin dapat membuat akun usaha/outlet pusat, menetapkan kontak pemilik, dan mengirim undangan aktivasi agar pemilik menetapkan password/login Google sendiri. Jangan memberikan akun bersama atau mencatat password mentah.
- Pemilik mengakses Android melalui distribusi Google Play yang sesuai tahap beta (internal/closed/open testing sesuai konfigurasi); undangan akun usaha tidak otomatis memberi akses track Play. Tautan/akses instalasi ditampilkan sesuai distribusi nyata, bukan dijanjikan sudah tersedia.
- Sediakan grant paket manual dengan paket tujuan, waktu mulai/berakhir, alasan beta/promosi/bantuan, administrator pemberi, serta histori. Pisahkan entitlement grant dari invoice/pembelian berbayar; tidak membuat bukti pembayaran palsu.
- Contoh: grant Platinum sampai besok pada waktu yang ditentukan. Administrator dapat mencabut lebih awal. Setelah berakhir, backend menghitung kembali hak berdasarkan trial/langganan sah yang masih berlaku; bila tidak ada, tampilkan status perlu berlangganan sesuai kebijakan, tanpa menghapus transaksi.
- Grant sementara tidak membatalkan/mengubah autodebit Google Play/gateway yang sudah aktif. Tampilkan sumber langganan dan renewal agar tidak ada tagihan tak terduga; pembatalan billing mengikuti jalur resminya.
- Jangan menagih otomatis saat grant selesai tanpa persetujuan/metode pembayaran yang sah. Beri pengingat masa beta dan pilihan berlangganan.
- Jika downgrade melewati kuota cabang/perangkat, pertahankan data dan beri alur pemilihan/penonaktifan akses berlebih yang jelas; jangan menghapus cabang/pesanan. Aturan read-only/operasional saat expiry harus difinalisasi.
- Platinum sementara membuka fitur yang sesuai, tetapi tidak otomatis memberikan saldo AI tak terbatas. Kredit bonus AI beta bila diberikan dicatat terpisah dengan nominal/masa berlaku yang jelas.
- Semua override diperiksa server, tersinkron Android/web, dapat diaudit dan dicabut; staff laundry tidak boleh memberi grant platform.
- Gunakan role/permission aplikasi yang telah ada sebagai dasar setelah audit, lalu petakan konsisten ke Laravel; jangan menganggap role lokal sudah menjadi otorisasi backend.
- User menyerahkan pilihan implementasi rutin kepada pengembang dalam lingkup keputusan ini. Nominal/ketentuan yang belum ditentukan tetap diberi status belum final; tidak mengubahnya menjadi keputusan pengguna.

## 20. Batas Penyelesaian Rangkuman

Dokumen ini menjadi acuan pembangunan pusat untuk akun/role, paket/perangkat, pembayaran/top-up, WA/kurir/nota, administrator/CS/AI, monitoring/backup, bantuan jarak jauh dan CRM. Pencatatan kebutuhan telah dibuat; backend, billing, gateway, AI, dan panel produksi belum diimplementasikan oleh perubahan dokumentasi ini. Mulai dari fondasi Laravel dan administrator dasar, kemudian integrasi serta uji terarah sesuai urutan bagian10.


## 21. Penegasan Tarif AI Chat dan Batas Otomasi Pemulihan

### Tarif AI chat
- Klarifikasi pengguna: pengambilan30% berkaitan dengan pemakaian saldo AI untuk chat, bukan potongan pada harga paket laundry atau seluruh biaya platform.
- Interpretasi operasional yang dijelaskan: debit saldo pelanggan = biaya AI chat terkonversi rupiah ×1,30. Contoh modal AI Rp1.000, debit saldo Rp1.300, selisih bruto Rp300. Ini markup30% dari modal AI, bukan jaminan margin bersih30% setelah biaya pembayaran/infrastruktur/pajak.
- Saldo top-up Rp50.000 tidak dipotong30% di muka pada rancangan ini. Debit terjadi saat pemakaian AI; pesan template/nota tanpa AI tidak didebit sebagai AI.
- Biaya AI dasar meliputi pemakaian model dan konversi/biaya penyedia yang benar-benar terkait sesuai tarif transparan; biaya platform lain tidak dimasukkan diam-diam ke biaya AI. Rumus ini menggantikan usulan formula margin30% pada bagian17 untuk penjelasan harga chat. Jika pengguna menginginkan potongan30% di muka, perlu keputusan tersendiri; belum disepakati.
- Perubahan harga model/kurs tidak boleh mengubah debit historis; simpan versi tarif dan biaya setiap request.

### Otomasi, keluhan dan persetujuan
- Penegasan pengguna: sistem memonitor, menanggapi keluhan kerusakan/kinerja, dan melakukan pemulihan rutin secara otomatis. Permintaan tambahan fitur/button dikumpulkan sebagai masukan/peringatan dan menunggu persetujuan Paduka, bukan otomatis diterapkan.
- Pisahkan insiden operasional (down/lelet/error), masukan fitur/desain, dan tindakan berdampak tinggi. Laporkan anomali dengan bukti dan tingkat urgensi; jangan menyatakan tidak ada anomali tanpa monitoring nyata.
- Pemulihan otomatis hanya melalui runbook/tindakan terdaftar yang dibatasi: retry idempotent, restart worker/layanan tertentu setelah health check, atau failover yang sudah disiapkan dan diuji. Batasi jumlah percobaan/cooldown, verifikasi pulih, dan eskalasi bila gagal agar tidak terjadi restart loop.
- Saat VPS utama mati, monitoring/pemulihan eksternal diperlukan; AI yang hanya berada pada VPS mati tidak bisa memulihkan dirinya sendiri. Tidak menjamin seluruh insiden dapat ditangani otomatis.
- Perubahan fitur/kode, perubahan keamanan penting, penghapusan/reset data, restore database dengan risiko kehilangan perubahan, dan pembelian kapasitas baru memerlukan approval atau kebijakan spesifik yang telah disetujui sesuai dampak.
- Komplain menerima respons sesuai status nyata; jangan otomatis menjanjikan fitur baru atau menyebut masalah selesai sebelum diverifikasi. Simpan tiket, kategori, dampak, diagnosis, tindakan dan hasil.


## 22. Dashboard Konfigurasi AI, Etika dan Isolasi SaaS

Penegasan pengguna: dashboard administrator menyediakan pengaturan penyedia/model/API key; AI pusat dipisahkan dari AI chat pelanggan, dan data/chat usaha SaaS tidak tercampur.

- Dua profil konfigurasi independen: **AI Pusat Goyana** untuk monitoring/diagnosis/CS platform, dan **AI Chat Laundry** untuk chatbot pelanggan usaha. Setiap profil memilih provider (misalnya OpenRouter atau OpenAI langsung), model ID, credential, status aktif, timeout, batas biaya/token dan aturan perilaku.
- GPT adalah keluarga model, bukan nama gateway. Provider dan model dipilih terpisah; daftar model mengikuti dukungan provider. Admin dapat mengganti profil aktif tanpa mengubah profil lainnya. Tidak menjanjikan semua model memiliki kemampuan/tool yang sama.
- Form API key menyimpan secret terenkripsi di backend dengan akses admin khusus; tampil masked, tidak dikirim ke APK/browser setelah disimpan, tidak masuk repo/log/chat. Sediakan ganti/cabut, tes koneksi server, status konfigurasi dan audit. Tes berbayar harus menampilkan bahwa penggunaan dapat menimbulkan biaya.
- Credential/budget pusat dan chatbot pelanggan dipisahkan. Credential chatbot platform dapat dipakai bersama di sisi server dengan pencatatan pemakaian per tenant, tetapi tidak menyatukan riwayat, prompt, knowledge base atau saldo. BYOK per usaha merupakan opsi terpisah bila kelak dipilih, bukan kewajiban pengguna saat ini.
- **Etika/aturan perilaku** dapat diatur admin: sopan, jujur, tidak mengarang status/perbaikan, menjaga privasi, tidak meminta password/OTP, tidak menjanjikan fitur, eskalasi saat tidak pasti, dan batas tindakan yang boleh otomatis. Aturan keamanan inti tidak dapat dibypass hanya dengan prompt.
- Identitas usaha berasal dari sesi/token dan pemetaan device WA yang tervalidasi. Setiap query, pesan, job queue, cache, session, retrieval/knowledge base dan ledger menggunakan tenant scope; request tidak boleh memilih tenant sewenang-wenang.
- Isolasi dapat memakai database bersama dengan tenant_id dan kontrol server yang ketat atau database terpisah bila kebutuhan menuntut; keputusan fisik belum ditetapkan. Penyimpanan pusat tidak berarti akses lintas usaha terbuka.
- Riwayat percakapan dibatasi per usaha dan per pelanggan/conversation, bukan satu memori chatbot global. AI pusat hanya membaca data yang diperlukan lewat API diagnosis berizin/audit, bukan otomatis menerima semua chat laundry.
- Teks pelanggan, dokumen dan log dianggap data tidak tepercaya; instruksi di dalamnya tidak dapat mengubah scope/izin/tool. Provider/model berubah tidak mengubah identitas tenant atau memberikan akses baru.
- Versioning aturan/model/tarif, pemakaian dan audit per profil/tenant; pergantian berlaku terkontrol pada request baru. Fallback provider hanya jika telah dikonfigurasi dengan aturan data/biaya yang sesuai, bukan mengirim data diam-diam ke penyedia lain.
- Uji wajib mencoba akses silang tenant pada API, webhook, queue, cache dan pencarian konteks sebelum produksi. Pembatasan bukan hanya menu dashboard.
- Ini kebutuhan implementasi, bukan klaim bahwa form API key, engine AI atau isolasi backend telah selesai dibuat.


## 23. Paket Berakhir: Mode Baca Saja

Arahan pengguna: pelanggan usaha tetap dapat membaca data saat paket berakhir.

- Jika tidak ada trial, grant beta atau langganan sah yang masih aktif, akun usaha masuk read-only. Login, melihat pesanan/nota lama, pelanggan dan laporan historis tetap tersedia sesuai role/outlet dan aturan retensi.
- Transaksi baru serta perubahan data/status/pembayaran/stok/penugasan terkunci; konsekuensinya pesanan berjalan juga tidak dapat diubah sampai akses operasional aktif kembali. Jangan menganggap read-only tetap membolehkan edit tertentu tanpa aturan tambahan.
- Halaman langganan, bantuan dan proses pembayaran untuk mengaktifkan kembali tetap dapat diakses; role/tenant isolation tetap berlaku.
- Otomasi operasional/WA/chatbot AI berbayar ditangguhkan, termasuk pekerjaan antrean yang harus memeriksa hak saat dijalankan. Saldo AI tersisa disimpan; saldo positif saja tidak mengaktifkan fitur ketika paket tidak berlaku.
- Data dan saldo tidak otomatis dihapus saat expiry; masa retensi/hapus akun mengikuti ketentuan transparan yang masih perlu ditetapkan. Read-only bukan janji penyimpanan tanpa batas.
- Setelah pembayaran sah/grant baru tervalidasi server, akses kembali sesuai paket dan kuota. Pending payment belum mengaktifkan akses; jangan menagih otomatis tanpa persetujuan.
- Server menerapkan izin saat operasi/sync; transaksi offline dibuat ketika hak masih berlaku membutuhkan aturan rekonsiliasi tersendiri agar tidak hilang/duplikat. Kebijakan menerima pending sync belum final.


## 24. Retensi Data Operasional Setelah Paket Berakhir

Keputusan terbaru pengguna: membersihkan data operasional untuk mengurangi database, sambil mempertahankan akun/email login. Ini berbeda dari permintaan hapus akun.

- Free trial berlangsung dua bulan. Jika tidak berlangganan, data operasional tetap read-only selama **satu bulan setelah trial berakhir**, lalu masuk proses penghapusan.
- Bekas pelanggan berbayar: rancangan retensi **tiga bulan setelah paket berakhir** sebagaimana pembahasan sebelumnya; data read-only sebelum penghapusan.
- Akun usaha/login dan email pemilik tidak ikut dihapus oleh pembersihan data operasional. Simpan identitas minimal, riwayat hak/trial untuk mencegah trial berulang, serta catatan billing/saldo yang diperlukan secara terpisah. Retensi identitas dan hapus akun mengikuti kebijakan tersendiri, bukan disimpan tanpa batas tanpa tujuan.
- Saldo AI dan ledger pembayaran tidak disamakan dengan data transaksi laundry yang dibersihkan. Data pelanggan akhir laundry tidak dianggap sebagai email akun pemilik dan tidak dipertahankan otomatis untuk marketing.
- Sebelum batas penghapusan, tampilkan tanggal pasti, peringatan dan kesempatan ekspor. Aktivasi langganan sah sebelum penghapusan membatalkan jadwal; pembayaran pending belum sah.
- Setelah data operasional benar-benar dihapus, akun tetap dapat login/berlangganan tetapi data lama tidak otomatis kembali. Jangan menjanjikan pemulihan dari backup sebagai fitur pelanggan.
- Scope tabel/file/chat/konteks AI operasional yang dihapus harus dipetakan dan diuji per tenant; tidak mengosongkan seluruh database atau menghapus tenant lain. Lindungi kewajiban billing/ledger yang terpisah.
- Scheduler penghapusan memeriksa ulang paket/grant/hold dan tanggal sebelum eksekusi; cegah race dengan renewal. Catat audit penghapusan tanpa menyalin isi data yang dihapus.
- Backup mengikuti masa retensi/rotasi yang terdefinisi; restore harus menerapkan ulang daftar penghapusan agar data yang sudah dibersihkan tidak kembali aktif. Data lokal lama tidak boleh tersinkron ulang sebagai pemulihan otomatis setelah purge.
- Jangka waktu dihitung dari berakhirnya hak aktif terakhir, bukan dari tanggal daftar untuk pelanggan yang sudah upgrade. Ketentuan kalender dan timestamp harus konsisten pada server.
- Ini pencatatan kebijakan mendatang; tidak menjalankan penghapusan data sekarang.


## 25. Anggaran AI Pusat Dapat Diatur Administrator

Penegasan pengguna: batas biaya AI pusat ditentukan sendiri oleh Paduka melalui dashboard administrator, bukan nominal tetap yang ditentukan pengembang.

- Sediakan batas anggaran harian/bulanan, pemakaian periode berjalan, perkiraan sisa, ambang notifikasi dan pilihan model/provider untuk profil AI pusat.
- Anggaran AI pusat terpisah dari saldo/ledger AI chat laundry. Mengubah anggaran pusat tidak mengambil kredit pelanggan.
- Tampilkan mata uang dan dasar biaya (biaya provider dan konversi yang dicatat); jangan menyamakan saldo kredit provider dengan jumlah izin belanja pusat.
- Server menerapkan hard cap dengan reservasi perkiraan biaya maksimum request dan rekonsiliasi biaya aktual, termasuk request paralel, retry dan fallback. Jangan menjanjikan cap akurat hanya dengan laporan biaya yang terlambat.
- Saat izin biaya tidak cukup atau biaya request tidak dapat dibatasi, hentikan pemanggilan AI berbayar baru dan beri peringatan/tiket; jangan pindah provider berbayar untuk melewati batas.
- Monitoring berbasis aturan, backup, transaksi utama dan runbook pemulihan non-AI tetap bekerja. Kasus yang membutuhkan AI masuk antrean/escalation.
- Perubahan batas hanya admin berizin, dicatat audit; kenaikan batas bukan otomatis membeli/top-up kredit provider. Pembelian provider mengikuti otorisasi pembayaran tersendiri.
- Belum menetapkan nominal anggaran; form dan enforcement merupakan kebutuhan pembangunan, belum fitur aktif.


## 26. Monitoring Ringan dan Jadwal Maintenance

Penegasan pengguna: form AI pusat mencakup budget bulanan; monitoring/maintenance tidak boleh membebani RAM, pekerjaan berat dapat dijadwalkan malam.

- Form profil pusat menampilkan provider/model, credential masked, budget bulanan yang dapat diisi, pemakaian/sisa, ambang peringatan, jadwal analisis/maintenance serta zona waktu Asia/Jakarta. Dashboard tabel bukan memuat file model AI ke VPS.
- Menggunakan API provider AI yang dipilih, bukan menjalankan model besar lokal pada VPS kecil. Pemakaian aplikasi/worker tetap perlu diukur dan dibatasi; tidak menjanjikan nol beban RAM.
- Bedakan health check ringan berkala (ketersediaan API, resource dasar, umur backup/queue) dari analisis AI/log/report/backup berat terjadwal. Interval diatur sesuai kapasitas dan kebutuhan; jangan menunggu malam untuk mendeteksi outage.
- Usulan awal health check external tiap1–5menit, bukan keputusan final. Alarm dipicu setelah pola kegagalan yang cukup untuk menghindari noise; AI hanya untuk kasus yang perlu, bukan setiap sampel metrik.
- Job berat berjalan queue dengan concurrency/memori/timeout terbatas, cegah jadwal overlap, batch data dan retensi log; atur prioritas agar transaksi tidak terganggu.
- Analisis rutin/report dan pekerjaan maintenance yang layak dapat dijadwalkan di jam sepi. Jam pasti ditentukan admin setelah melihat pola penggunaan; tidak semua maintenance membutuhkan downtime.
- Backup dan arsip perubahan tetap mengikuti target pemulihan, tidak dipindah seluruhnya ke sekali malam jika itu meningkatkan risiko kehilangan data di luar target.
- Monitoring eksternal tetap dapat memberi peringatan ketika VPS utama mati. Uji beban, ukur baseline dan sesuaikan worker/jadwal sebelum produksi.
- Jadwal ini modul scheduler backend Goyana yang direncanakan, bukan automation aktif di ChatGPT atau server.


## 27. Offline dan Sinkronisasi Otomatis Wajib Diimplementasikan

Penegasan pengguna: cantumkan kemampuan offline dan sinkronisasi otomatis agar tidak terlupakan saat pembangunan. Prioritas pengalaman: cepat dan stabil; bukan klaim bahwa implementasi telah selesai.

- Simpan transaksi operasional yang didukung secara lokal terlebih dahulu dengan penyimpanan persisten yang sesuai platform. Tampilkan status/jumlah transaksi belum tersinkron dan waktu sinkronisasi terakhir.
- Saat internet dan backend kembali tersedia, kirim antrean secara otomatis dalam kondisi aplikasi/platform mengizinkan, tanpa wajib input ulang. Sediakan tombol coba sinkronisasi dan pesan kegagalan yang jelas; tidak menjamin pengiriman saat aplikasi ditutup paksa atau dibatasi OS.
- Gunakan ID operasi unik, outbox, acknowledgment server, retry terbatas/backoff dan deduplikasi agar koneksi terputus/retry tidak menggandakan transaksi/pembayaran/stok. Data pending jangan dihapus sebelum penerimaan server terkonfirmasi.
- Pisahkan server tidak tersedia dari internet tidak tersedia; UI tidak terus menunggu timeout jaringan untuk menyimpan transaksi lokal.
- Sinkronisasi hanya untuk tenant/outlet/perangkat yang berizin; perubahan bersamaan antarperangkat memerlukan aturan konflik/audit, bukan overwrite diam-diam.
- Fitur membutuhkan server (billing/verifikasi pembayaran, WA otomatis, AI, dan data lintas perangkat terbaru) tidak dianggap tersedia penuh saat offline. Tetapkan daftar fitur offline yang diuji; saldo/deposit bersama tidak boleh dibelanjakan ganda antarperangkat.
- Logout/pergantian akun/reset/update aplikasi tidak boleh diam-diam menghapus transaksi pending; beri peringatan dan jalur pemulihan/ekspor sesuai izin.
- Setelah purge operasional, data lokal lama tidak otomatis menghidupkan kembali data yang telah dihapus. Izin/paket expired dan pending sync mengikuti aturan rekonsiliasi yang disepakati.
- Backup server tetap wajib. Penyimpanan HP bukan backup semua outlet dan tidak menjamin keselamatan data jika HP rusak/penyimpanan dihapus.
- Uji perangkat nyata: mode pesawat, server down, koneksi putus saat acknowledgment, restart aplikasi dengan pending data, retry duplikat, dua perangkat mengubah data sama, perubahan izin dan update aplikasi. Ukur kecepatan simpan lokal serta kestabilan sync.
- Versi prototype saat diperiksa memakai localStorage; itu tidak membuktikan engine sinkronisasi produksi telah selesai. Implementasi harus dicatat terpisah dari status dokumentasi ini.


## 28. Pengguna Tidak Boleh Tidak Menyadari Offline Berkepanjangan

Kekhawatiran pengguna: kuota internet habis dan pengguna lupa, sehingga transaksi tersimpan di HP terus tanpa disadari.

- Tampilkan indikator tetap di layar operasional: “Offline — data tersimpan di HP”, jumlah transaksi pending dan waktu terakhir sync berhasil. Jangan menyamakan tersimpan lokal dengan tersimpan server.
- Peringatan berkala berdasarkan durasi offline/jumlah pending yang dapat dikonfigurasi; jangan spam setiap transaksi. Beri arahan cek internet/sambungkan Wi-Fi dan tombol Coba Sinkronisasi.
- Aplikasi tidak selalu mengetahui penyebab tidak terhubung (kuota habis, jaringan, backend down); jangan menyatakan kuota habis tanpa bukti.
- Ketika koneksi kembali, jalankan sinkronisasi otomatis sesuai kemampuan platform, tampilkan progres dan konfirmasi jumlah berhasil/gagal. Server tidak dapat mengetahui transaksi terbaru yang hanya berada pada HP offline; monitoring pusat paling jauh mendeteksi last-seen yang tertinggal.
- Offline tetap mematuhi izin perangkat dengan masa berlaku terbatas yang perlu ditetapkan; tidak memberikan akses operasional tanpa batas saat entitlement tidak dapat diperiksa.
- Pantau kapasitas penyimpanan lokal. Jangan menghapus/overwrite transaksi pending demi memberi ruang. Jika penyimpanan tidak dapat menjamin penulisan, blok simpan transaksi baru dengan pesan jelas dan jalur sinkronisasi/ekspor/pemulihan.
- Tidak memilih batas hari/jumlah transaksi sekarang tanpa keputusan kapasitas/izin; ambang warning dan batas izin offline harus diuji dan ditetapkan sebelum produksi.


## 29. Pengingat Sinkronisasi Tidak Mengganggu

Arahan pembahasan: pengguna mengkhawatirkan notifikasi berulang. Rekomendasi desain ini melengkapi bagian28; implementasi belum aktif.

- Indikator offline/pending tetap terlihat di dalam aplikasi, tanpa popup setiap transaksi atau setiap putus koneksi.
- Tidak mengirim notifikasi hanya karena offline bila tidak ada data pending. Saat aplikasi dibuka kembali, tampilkan ringkasan pending yang perlu perhatian.
- Notifikasi HP lokal hanya jika ada transaksi pending melewati ambang yang ditetapkan; deduplicate, cooldown dan jam tenang. Jangan menjadwalkan pengingat berulang tanpa batas.
- Notifikasi lokal dapat bekerja tanpa pesan server, sesuai izin notifikasi dan batas OS. Tidak menjamin tampil bila izin dimatikan/app force-stop; ini opsi rancangan, bukan kepastian fitur yang sudah terpasang.
- Sediakan preferensi pengingat; batalkan pengingat setelah pending selesai. Tidak mengirim notifikasi rutin untuk setiap sinkronisasi berhasil.
- Ambang durasi/cooldown belum diputuskan; pilih melalui pengujian/pola operasional. Kekurangan penyimpanan/gagal menyimpan transaksi tetap memberi peringatan segera di aplikasi.


## 30. Mandat Penyempurnaan Offline/Sync dan Efisiensi Data

Pengguna menyerahkan keputusan teknis rutin offline/sinkronisasi kepada pengembang agar mengikuti kebutuhan sistem kasir yang cepat, stabil dan tidak mengganggu.

- Gunakan sinkronisasi incremental: kirim operasi/data berubah dan tarik perubahan berdasarkan cursor/version, bukan seluruh database pada setiap sync.
- Data teks transaksi biasanya lebih ringan dari foto/lampiran; ukuran nyata bergantung isi, jumlah dan backlog. Ukur payload, jangan menjanjikan nominal kuota tertentu.
- Kirim lampiran secara terpisah dengan batas ukuran/kompresi yang sesuai. Jangan menahan pencatatan lokal transaksi hanya karena unggahan foto belum selesai; tampilkan status masing-masing.
- Batch terbatas, backoff dan retry otomatis; indikator pending/terakhir sync, deduplikasi serta aturan konflik mengikuti bagian27–29. Jika jaringan ada tetapi backend gagal, pending tetap aman dan tidak dianggap berhasil.
- Pengembang memilih parameter awal melalui uji perangkat/koneksi dan pengukuran, lalu mencatatnya sebagai konfigurasi yang dapat disesuaikan. Tidak perlu meminta pengguna menentukan setiap interval teknis.
- Tidak memperluas mandat menjadi izin menghapus data, mengubah harga atau membeli infrastruktur tanpa kebijakan yang sesuai. Implementasi offline/sync tetap belum selesai; dokumen merupakan acuan kerja.


## 31. Unggah Gambar: Kompresi Otomatis dan Maksimal 15

Arahan pengguna: gambar dikompres otomatis sebelum dikirim, tetap menjaga tampilan/detail/warna agar tidak burik, dan maksimal15gambar. Penafsiran awal batas: per sekali unggah; bukan kuota total database/akun.

- Resize proporsional dan kompres sesuai jenis gambar; pertahankan orientasi dan konsistensi warna. Gunakan profil warna yang sesuai tampilan web/mobile; tidak menjanjikan kompresi lossy identik dengan sumber.
- Jangan memperbesar gambar kecil atau mengompres ulang gambar yang sudah memenuhi batas tanpa manfaat. Sesuaikan format/kualitas hasil berdasarkan uji visual, bukan kompres ekstrem demi ukuran.
- Batasi pemilihan15gambar per sekali unggah pada UI dan validasi server. Batas ukuran per file/total serta dimensi final ditetapkan setelah pengujian; belum merupakan keputusan pengguna.
- Proses satu per satu atau concurrency kecil, tidak mendecode15gambar penuh bersamaan. Tampilkan preview/progres, ukuran hasil dan retry file gagal.
- Gambar/lampiran memakai antrean terpisah dari transaksi; kompres dan simpan hasil pending secara persisten saat offline sesuai kapasitas, upload ketika tersedia. Jangan menampilkan “terkirim” sebelum server mengonfirmasi.
- Validasi konten/tipe/ukuran server, hak tenant/outlet, ID lampiran dan deduplikasi. Buang metadata lokasi yang tidak diperlukan.
- Pertahankan keterbacaan gambar nota/barcode/QR bila termasuk unggahan; jangan menggunakan hasil kompresi yang merusak kemampuan scan.
- Uji pada foto detail pakaian, warna pekat, teks serta perangkat RAM rendah. Fitur ini baru dicatat, belum diimplementasikan.


## 32. Lima Pelengkap Dashboard Administrator

Pengguna meminta semua saran dirangkum/ditulis. Ini melengkapi dasar fitur yang sudah dibahas; belum implementasi.

1. Pusat persetujuan: antrean saran AI, permintaan fitur dan tindakan berdampak, approve/reject, alasan, identitas admin, audit serta pemeriksaan ulang izin/kondisi saat eksekusi. Persetujuan tidak mengubah keluhan fitur menjadi janji otomatis.
2. Kontrol rilis/rollback: uji perubahan pada akun beta, rollout bertahap, status versi, penghentian rollout dan runbook kembali. Rollback kode berbeda dari pemulihan database; migrasi perlu strategi kompatibilitas.
3. Rekonsiliasi pembayaran: cocokkan invoice/purchase/status provider dengan paket/saldo; tampilkan sudah bayar tetapi entitlement belum masuk, retry verifikasi yang aman serta deduplikasi. Jangan memberi kredit hanya berdasarkan screenshot.
4. Antrean pekerjaan gagal: tampilkan status WA/upload/sync/event, penyebab redacted, percobaan, retry/cancel berizin. Pending yang hanya ada di HP offline belum terlihat detail di pusat; jangan mengklaim antrean server mencakup semua data lokal.
5. Ringkasan bisnis Goyana: trial, pelanggan aktif, renewal/expiry, pendapatan terverifikasi, biaya AI dan storage. Pisahkan omzet platform dari omzet laundry, kredit AI belum terpakai dari keuntungan, serta angka estimasi dari rekonsiliasi final.

Prioritas usulan sebelumnya:1,3,4lebih dahulu; semua lima tetap tercatat sebagai rencana.

## 33. Koordinasi Pengerjaan dengan GPT/Codex dan Claude melalui GitHub

Pertanyaan pengguna: dapatkah repo dikerjakan juga dengan “cloud”. Jika maksudnya Claude, dapat menggunakan repo sama melalui Git, dengan akses yang dikonfigurasi pengguna. Tidak ada koneksi Claude atau agent lintas layanan yang dibuat oleh pencatatan ini.

- GitHub dan dokumentasi repo menjadi acuan bersama. Percakapan/memori GPT dan Claude tidak otomatis tersinkron.
- Bagi tugas dan ownership file/module. Masing-masing memakai branch/checkout terpisah, mengambil sumber terbaru sebelum mulai, dan membawa perubahan lewat PR agar review/integrasi terkontrol.
- Hindari dua alat mengedit file/main yang sama secara bersamaan. Perubahan lintas modul mengikuti kontrak API/schema dan aturan tenant/role yang sama.
- Dokumentasikan keputusan, status tugas, implementasi/pengujian dan hal belum selesai di repo; jangan menyatakan rencana sebagai fitur aktif.
- Sebelum merge, review diff, selesaikan konflik, jalankan pemeriksaan yang relevan lalu integrasikan berurutan. Konflik tidak selesai otomatis hanya karena keduanya memakai GitHub.
- Model lain tidak otomatis menerima akses repo atau credential produksi. Jangan menaruh secret/API key di handoff/repo.

## 34. Dashboard Admin di HP dan Flutter Dimulai Sekarang

Arahan lanjutan pengguna: desain dashboard konsisten, administrator dapat dipasang di HP, dan Flutter tidak perlu menunggu semua backend selesai.

- Dashboard admin memakai tema coral/putih/abu Goyana, ukuran/tombol konsisten dan layout responsif. Data dan izin admin tetap terpisah dari owner.
- Sediakan pemasangan PWA melalui browser yang mendukung setelah dashboard dihosting HTTPS. Manifest, ikon dan service worker tidak memberi akses tanpa login.
- Jangan cache halaman/data pelanggan atau secret admin untuk membuat ilusi offline. Admin tetap memerlukan server untuk membaca kondisi terbaru dan menjalankan perubahan.
- Flutter dapat dimulai bersama fondasi backend, menggunakan widget native dan API yang sama. Ini berbeda dari membungkus HTML dalam WebView.
- Tahap awal Flutter: login owner dan pembacaan profil/paket/outlet, analisis/tes widget dan APK debug. Selanjutnya migrasikan operasional, role, offline, printer/kamera dan billing bertahap.
- APK preview memiliki application ID tersendiri agar tidak menimpa prototype. APK debug bukan aplikasi final atau rilis Play Store.
- Semua kode, keputusan dan status pengujian disimpan di repo. Tes CI berjalan di GitHub terpisah dari panggilan; jangan mengklaim agent terus bekerja tanpa batas setelah sesi tugas berhenti.


## 35. Login Langsung dan Panduan Awal yang Bisa Dilewati

Keputusan pengguna 2 Oktober 2026:
- Login biasa langsung membuka beranda outlet yang memang diizinkan. Akun pusat usaha masuk ke outlet pusat; akun yang hanya punya satu outlet tidak ditanya memilih cabang.
- Bila akun memiliki beberapa outlet yang diizinkan, gunakan outlet bawaan yang valid, tampilkan nama outlet dengan jelas, dan sediakan perpindahan berizin. Jangan mengharuskan pemilihan outlet setiap login atau memberi akses ke outlet lain.
- Platform administrator tetap masuk ke dashboard administrator, terpisah dari beranda usaha.
- Owner baru wajib mengisi nama outlet saat pendaftaran. Outlet pusat dibuat satu kali bersama akun/usaha; membuka kembali aplikasi tidak membuat outlet baru atau meminta nama ulang.
- Akun pegawai/kurir yang diundang mengikuti outlet yang ditetapkan owner; tidak membuat usaha/outlet sendiri.
- Setelah pendaftaran, sediakan panduan awal bertahap dengan desain coral/putih/abu yang konsisten: profil outlet, layanan dan harga, lalu printer opsional. Tampilkan langkah aktif, Lanjut, Kembali, dan Lewati.
- Tombol Lewati hanya melewati panduan/pengaturan opsional, bukan identitas outlet wajib, autentikasi atau izin. Lewati membawa pengguna ke beranda.
- Simpan kemajuan serta status selesai/dilewati per akun dan usaha, jangan menampilkan ulang pada setiap login. Panduan dapat dibuka kembali melalui Bantuan > Panduan awal.
- Isian opsional yang belum selesai dapat dilengkapi di Pengaturan. Fitur yang bergantung pada isian itu menjelaskan kebutuhan pada saat digunakan.
- Jangan menampilkan data contoh sebagai data usaha nyata atau menandai tahap selesai sebelum penyimpanan berhasil.
- Pemeriksaan implementasi: daftar tanpa nama outlet ditolak; outlet dibuat satu kali; login langsung tanpa pemilih untuk satu outlet; akun undangan tidak membuat outlet; Lewati dan lanjut kembali mempertahankan data serta hak akses.

Status: validasi nama usaha/outlet wajib dan pembuatan outlet pusat sudah ada pada registrasi web Laravel. Flutter saat ini baru login/profil; pendaftaran native, role pegawai dan panduan bertahap persisten belum diimplementasikan.


## 36. Acuan Visual Terakhir dan Audit Tombol

Koreksi pengguna: gunakan tema/desain HTML TERAKHIR yang disetujui, bukan HTML pertama dan bukan desain baru dari nol. Cocokkan versi sumber sebelum migrasi.
- Pertahankan header, warna, tipografi, ikon, susunan kartu dan navigasi bawah pada versi terakhir saat dipindah ke Flutter; perubahan hanya untuk bug atau revisi yang diminta.
- Audit tombol/menu secara menyeluruh: tujuan navigasi, aksi simpan, validasi, batal/kembali, ekspor, QR, printer dan hak akses.
- Integrasi server yang belum tersedia harus menampilkan status jelas; jangan membuat sukses palsu.
- Uji tampilan pada ukuran HP, teks panjang, keyboard, state kosong/loading/error dan status offline.
- Catat setiap temuan serta hasil pengujian. Audit belum boleh disebut selesai hanya karena tombol mempunyai handler.


## 37. Konsistensi Desain Web, Desktop, Tablet dan HP

Arahan pengguna: web dan aplikasi HP memakai bahasa visual yang sama dari HTML terakhir yang disetujui. Jangan membuat identitas visual lain untuk Flutter.
- Gunakan warna, font, ikon, bentuk tombol/kartu, nama menu dan status yang konsisten. Posisi/layout menyesuaikan ruang layar tanpa mengubah fungsi atau hak akses.
- Layout desktop memanfaatkan lebar untuk tabel dan panel; tablet menyesuaikan kolom; HP memakai kartu/tabel adaptif tanpa overflow halaman.
- Uji lebar 320, 360, 390, 412, 600, 768, 1024 dan 1440 piksel, portrait/landscape, pembesaran font, keyboard serta safe area.
- Tombol mudah disentuh, teks panjang membungkus dengan baik, dialog dapat discroll dan aksi utama tetap terjangkau.
- Bandingkan web dan Flutter per halaman. Jangan mengganti tema/konten hanya untuk menghindari penyesuaian responsif.
- Uji navigasi, formulir dan status loading/kosong/error pada Android target serta browser desktop/tablet. Printer/kamera/scan wajib diuji di perangkat fisik yang relevan.
- Target kompatibilitas ditetapkan dan diuji; jangan menjanjikan semua tipe HP tanpa batas atau mengklaim pengujian fisik yang belum dilakukan.

Status: ketentuan disimpan sebagai kriteria penerimaan. Kesetaraan seluruh halaman Flutter/web dan matriks perangkat belum selesai diuji.

## 38. Lapisan Sinkronisasi Aplikasi Hybrid (celah yang ditemukan saat review) — 2 Oktober 2026

Hasil pemeriksaan Claude: rencana lama menulis transaksi Android disimpan di SQLite Flutter, tetapi aplikasi Android sekarang memakai **Flutter hybrid** yang menjalankan 58 halaman HTML final, dan seluruh data operasional disimpan di `localStorage` (±61 titik di kode). Backend belum memiliki tabel transaksi. Karena itu:

- [ ] Buat **lapisan sync di sisi web app** (index.html/goyana-v*.js) yang membaca/menulis data operasional melalui satu modul, menyimpan perubahan ke antrean lokal (outbox) dengan ID unik, lalu mengirimnya ke API Laravel saat online. Tampilan halaman tidak diubah.
- [ ] Penyimpanan lokal pindah dari `localStorage` ke penyimpanan yang lebih aman dan besar (SQLite native lewat jembatan Flutter atau IndexedDB), dengan migrasi data lama.
- [ ] API Laravel: pelanggan, layanan/harga, pesanan & status, pembayaran/DP/deposit, kas, stok, kurir. Setiap request membawa `client_id` (idempotent), outlet, petugas, perangkat; server memeriksa role, outlet, perangkat dan paket (baca saja menolak tulis).
- [ ] Unduh perubahan per outlet sejak cursor terakhir (incremental), bukan data penuh.
- [ ] Saat halaman dipindah ke Flutter native, modul data yang sama dipakai sehingga tidak ada dua sumber data.

## 39. Implementasi Akses, Paket, Tim dan OTP Admin — 2 Oktober 2026 (branch backend/akses-paket)

Sudah dibuat dan diuji (30 tes PHPUnit):
- `backend/config/goyana.php`: harga & batas cabang paket, 2 perangkat kasir/outlet, role & permission.
- Tabel `subscriptions` (paket berbayar, terpisah dari grant beta). Urutan akses: langganan/grant aktif (paket tertinggi) → trial Basic 2 bulan → **baca saja**.
- Admin pusat mencatat pembayaran manual (transfer/QRIS) dengan referensi unik; perpanjangan lanjut dari akhir langganan berjalan; pembatalan wajib alasan; semua masuk audit.
- Owner menambah cabang sesuai batas paket (Basic: 1 pusat + 1 cabang).
- Akun tim: Kasir, Produksi, Kurir, Admin Outlet dengan outlet tugas; ganti peran, nonaktifkan (histori tetap), aktifkan, reset password (sesi HP lama keluar). Token API mengikuti permission role; staf hanya melihat outlet tugasnya.
- OTP (aplikasi authenticator) wajib untuk admin pusat; kode tidak bisa dipakai ulang; reset lewat `php artisan goyana:admin-reset-mfa email`.
- Verifikasi email owner tersedia; diwajibkan dengan `GOYANA_REQUIRE_EMAIL_VERIFICATION=true` setelah SMTP produksi siap.

Belum: pembayaran otomatis (gateway/Play Billing), pemasangan HP ke slot perangkat, API transaksi & sync (§38), login Google, reset password mandiri via email.

## 40. Sinkronisasi HP ↔ Server Sudah Dibangun — 2 Oktober 2026 (branch backend/akses-paket)

Status §38: lapisan sync versi 1 selesai dan diuji, **tanpa mengubah tampilan**.

- **Cara kerja:** aplikasi tetap menyimpan data di HP (offline-first). `goyana-v197-sync.js` membaca penyimpanan lama, mengirim perubahan ke `POST /api/sync/push`, dan mengambil perubahan HP lain dari `GET /api/sync/pull`. Data masuk diterapkan oleh `goyana-sync-core.js` di awal `<head>` saat halaman dimuat ulang, sebelum aplikasi membaca datanya, sehingga tidak tertimpa.
- **Yang tersinkron:** pesanan (+detail/pembayaran), pelanggan, deposit, kas per kasir, layanan & harga, kurir, stok (barang, mutasi, supplier, pembelian, resep), profil outlet, setelan transport & QRIS.
- **Aman diulang:** setiap perubahan punya `op_id`; kirim ulang tidak menggandakan data. Bentrok (dua HP mengubah data yang sama) → versi server dipakai, versi HP disimpan di `sync_conflicts` (tidak hilang).
- **Hak akses di server:** izin per jenis data mengikuti role; staf hanya membaca/menulis outlet tugasnya; paket berakhir → hanya bisa tarik data.
- **Batas perangkat:** HP pertama yang menyimpan transaksi mengisi slot kasir (atau slot yang dibuat owner di dashboard). HP ketiga per outlet ditolak: "Maksimal 2 perangkat kasir per outlet." HP owner yang bertransaksi ikut dihitung; kurir tidak memakai slot.
- **Login:** layar login aplikasi memakai email & password akun server bila alamat server diisi. Outlet lokal lama dipetakan ke outlet server (`srv-<id>`). Tombol Daftar membuka pendaftaran web.
- **Status:** Pengaturan → kartu "Sinkronisasi server": Online · semua data tersinkron / Offline · N data menunggu / bermasalah.
- **Alamat server:** variabel GitHub `GOYANA_API_URL` saat build APK, atau diisi manual di kartu sinkronisasi. Kosong = mode offline seperti sebelumnya.
- **Dashboard owner web:** omzet & jumlah pesanan hari ini/bulan ini per outlet dari data yang tersinkron, status HP terpasang.
- **Uji:** 42 tes PHPUnit + uji 3 HP dengan server Laravel sungguhan (`tests/sync-e2e.cjs`): unggah, unduh, offline lalu online, tanpa unggah bolak-balik, penolakan HP ketiga.

Batasan versi 1 (dicatat, belum dikerjakan):
- Data dari HP lain diterapkan dengan memuat ulang halaman saat pengguna tidak sedang mengisi form (±6 detik diam).
- Unit sinkron adalah satu pesanan/pelanggan utuh; dua HP mengedit pesanan yang sama bersamaan → yang terakhir ditolak sebagai bentrok (tersimpan di server).
- Kas per kasir hanya dipulihkan ke HP pemiliknya; laci kas lain hanya tersimpan di server.
- Penyimpanan lokal masih `localStorage` (±5 MB). Pindah ke SQLite/IndexedDB sebelum data besar.
- Belum ada layar konflik untuk owner dan belum ada pembersihan data sesuai §24.

## 41. Keputusan Server & WhatsApp — 3 Oktober 2026

Keputusan pengguna:
- **Server dipisah.** VPS GOYANA hanya berisi Laravel, database laundry, dan web dashboard. Engine WhatsApp **tidak boleh** dipasang di VPS GOYANA, supaya VPS itu tidak cepat penuh atau lambat karena WA.
- **WhatsApp lewat CHATKU** (jasa WA gateway milik pengguna, VPS sendiri). GOYANA **tidak membangun engine WA sendiri**.
- GOYANA terdaftar di CHATKU sebagai **satu klien besar khusus**:
  - API key sendiri.
  - Perhitungan atau tagihan terpisah dari pelanggan CHATKU biasa.
  - Prioritas admin/antrean di CHATKU.
- Alur:
  - GOYANA → API CHATKU: QR sambung nomor, status nomor, kirim pesan.
  - CHATKU → webhook GOYANA: pesan masuk dan status terkirim.
  - Chatbot AI laundry dijawab oleh GOYANA (data laundry ada di GOYANA), lalu balasannya dikirim lewat CHATKU.
- Pengiriman WA dari GOYANA wajib lewat **antrean (queue)** dengan retry: kasir tidak menunggu WA terkirim, dan bila CHATKU sedang down, aplikasi laundry tetap jalan dan pesan dikirim ulang otomatis.
- Data yang disimpan GOYANA hanya catatan ringkas (id pesan, tujuan, status). Sesi WA, media, dan riwayat lengkap tersimpan di CHATKU.
- Hak paket tetap diatur GOYANA (nota otomatis mulai Gold, Blast hanya Platinum). CHATKU hanya menjalankan.
- Spek awal VPS GOYANA cukup 2 GB RAM. Pilihan VPS vs Jagoan Hosting untuk GOYANA tetap **tanya pengguna sebelum deploy**.
- Syarat sebelum integrasi:
  - Engine CHATKU sudah online di server.
  - API kirim/QR/status dan webhook pesan masuk sudah tersedia.
  - API key khusus GOYANA sudah dibuat.
- Simpan API key CHATKU di `.env` server. Jangan di repo atau APK.

## 42. AI CS Pusat & Pesan Otomatis untuk Klien Laundry — 3 Oktober 2026

Permintaan pengguna: AI yang menjawab klien bila ada masalah, serta pesan otomatis (panduan, dll.) sejak klien mendaftar atau instal.

**Prinsip hemat AI (keputusan pengguna): kerjakan dengan program dulu, AI hanya bila program tidak bisa.**
- Pengecekan, jadwal, dan pemicu (ulasan baru, paket habis, status sinkron/WA) = program biasa/scheduler, **tanpa AI**.
- CS:
  1. Menu angka dan kata kunci (contoh: "1 cek paket", "2 printer", "3 sinkron", "reset").
  2. FAQ yang dicocokkan dengan kata kunci.
  3. Data akun langsung dari database.
  4. **Baru AI** bila pertanyaan tidak cocok satu pun.
- Jawaban AI yang sering muncul dijadikan FAQ/template, supaya pertanyaan berikutnya tidak memakai AI lagi.
- Ulasan Play Store: bintang 4–5 tanpa teks/pujian umum dibalas **template** (acak beberapa variasi). AI hanya untuk ulasan berisi keluhan/pertanyaan, dan tetap menunggu persetujuan admin.
- Batas biaya AI per hari dapat diatur di panel admin. Bila habis, CS kembali ke menu/FAQ plus tiket ke admin.

**A. AI CS pusat (melengkapi §9)**
- Nomor WA pusat GOYANA (lewat CHATKU, lihat §41) dijawab AI 24 jam.
- AI mengenali pengirim dari nomor terdaftar (owner/kasir) dan usahanya. Nomor tak dikenal hanya mendapat info umum.
- Sumber jawaban:
  - Panduan/FAQ resmi.
  - Data akun: paket, masa aktif, status sinkron, status nomor WA, cabang/HP.
  - API diagnosis terbatas.
- Bisa menjalankan pemulihan yang terdaftar dan aman: kirim ulang link reset, cek sinkron, kirim ulang nota, cara sambung ulang WA.
- Tidak boleh: ubah paket/uang, hapus data, atau reset akses tanpa verifikasi atau admin.
- Tidak yakin, klien marah, atau masalah pembayaran → **eskalasi ke admin manusia** (masuk tiket di panel admin plus notifikasi).
- Semua percakapan tercatat di tiket/riwayat klien (CRM pusat §17).

**B. Pesan otomatis ke klien — HEMAT (keputusan pengguna: jangan sering, klien bisa kabur)**

| Pemicu | Isi | Berapa kali |
|---|---|---|
| Daftar/instal | Selamat datang + **satu** link panduan lengkap (atur harga, transaksi pertama, printer) + kontak CS | **1x saja** |
| Trial/paket tinggal 3 hari | Pengingat + link pilih/perpanjang paket | 1x |
| Trial/paket habis | Info "baca saja", data aman, cara aktifkan lagi | 1x |
| Bayar/upgrade berhasil | Bukti bayar/terima kasih | 1x per pembayaran |

Aturan:
- **Tidak ada** pesan harian, tips berkala, atau sapaan "tidak aktif".
- Panduan lain tetap tersedia di aplikasi (Bantuan > Panduan) dan dijawab AI CS bila klien bertanya.
- Tidak dikirim pukul 21.00–07.00 WIB. Template dan on/off dapat diubah di panel admin.
- Balasan klien masuk ke AI CS (bagian A). Dikirim lewat antrean Laravel → CHATKU.

**C. Balas ulasan Play Store**
- Pakai Google Play Developer API (Reviews: list/reply) dengan service account yang dihubungkan ke Play Console. Kredensial disimpan di server, bukan di repo.
- Scheduler mengambil ulasan baru beberapa kali sehari, karena API hanya menampilkan ulasan 7 hari terakhir.
- Balasan disusun dari template (bintang 4–5) atau AI (keluhan/pertanyaan), batas sekitar 350 karakter, sopan, tanpa data pribadi.
  - Bintang 4–5 tanpa keluhan → boleh terkirim otomatis.
  - Bintang 1–3 atau ada keluhan → masuk antrean persetujuan admin di panel. Admin bisa edit lalu kirim.
- Jika pengulas cocok dengan klien terdaftar, buat tiket CS dan tawarkan bantuan lewat WA (bagian A).
- Semua ulasan dan balasan tercatat; statistik rating per versi aplikasi ditampilkan di panel admin.

Status: **rencana**, belum dibangun. Bergantung pada: server di-deploy, API CHATKU (§41), dan panel admin (tiket, template), dan untuk bagian C: aplikasi terbit di Play Store + service account Play Console.

## 43. Visi: GOYANA Berjalan Otomatis, Pemilik Cukup Sedikit Terlibat — 3 Oktober 2026

Keputusan pengguna: sistem harus berjalan sendiri tanpa staf. Pemilik platform hanya terlibat sedikit, dan sistem juga mengerjakan marketing, termasuk SEO/AEO website. Prinsip hemat AI §42 tetap berlaku: program dulu, AI terakhir.

| Area | Otomatis oleh sistem | Pemilik terlibat |
|---|---|---|
| Pendaftaran & trial | Daftar, verifikasi, trial, panduan 1x (§35, §42B) | — |
| Billing | Tagihan, bayar (gateway/Play), aktif otomatis, kunci "baca saja", pengingat 1x | Atur harga/promo |
| CS | Menu/FAQ/data akun → AI → tiket (§42A) | Tiket yang dieskalasi |
| Monitoring & pemulihan | Cek server/sinkron/antrean/WA; restart/ulang otomatis; backup harian + uji restore | Notifikasi bila gagal pulih |
| Ulasan Play Store | Template/AI (§42C) | Setujui balasan keluhan |
| Website & SEO/AEO | Landing page cepat, schema FAQ/HowTo/SoftwareApplication, halaman per kota/fitur, FAQ dari pertanyaan CS nyata, sitemap & pengecekan teknis otomatis | Setujui artikel/halaman baru sebelum terbit |
| Konten marketing | Draf artikel/post dari pertanyaan & fitur yang sering dipakai (terjadwal, jumlah dibatasi) | Setujui sebelum terbit |
| Referral | Kode referral per klien, bonus masa aktif otomatis saat yang diajak membayar | Atur besaran bonus |
| Laporan | Ringkasan mingguan ke WA/email pemilik: klien baru, bayar, churn, tiket, biaya AI/server, rating | Baca 5 menit/minggu |

Batas otomatis (wajib persetujuan manusia):
- Uang: refund, ubah harga, diskon besar.
- Hapus/reset data klien.
- Konten publik baru (artikel, iklan, balasan keluhan).
- Blast ke banyak klien.
- Iklan berbayar hanya dengan batas anggaran yang ditetapkan pemilik.

Marketing tidak boleh spam: WA hanya ke klien yang sudah daftar (§42B hemat). Tidak ada pesan massal ke nomor yang tidak pernah setuju dihubungi.

Urutan: inti produk + server + billing → CS & monitoring → laporan mingguan → website SEO/AEO + referral → konten & ulasan otomatis.
Status: **visi/rencana**.

## 44. Saldo AI Klien: Top-up, Margin 25%, Kurs & Harga Model Otomatis — 3 Oktober 2026

Keputusan pengguna:
- **Top-up saldo AI minimal Rp50.000.**
- **Untung 25% di atas modal.**
- Penyedia AI contohnya **OpenRouter** (harga dalam USD per token).
- Kurs dan harga AI harus ter-update otomatis supaya tidak rugi.

Cara hitung (program, tanpa AI):
- Saldo disimpan dalam **Rupiah**. Setiap pemakaian dipotong sesuai biaya nyata:
  `potong_rp = biaya_usd × kurs_hari_ini × 1,25`
- `biaya_usd` diambil dari data `usage`/cost yang dikembalikan OpenRouter per permintaan (biaya sebenarnya), bukan tebakan.
- **Kurs harian**: scheduler mengambil kurs USD→IDR setiap hari dari sumber resmi/API kurs. Pakai **kurs jual + cadangan 2%** supaya aman bila rupiah melemah di hari yang sama. Bila sumber kurs gagal, pakai kurs terakhir yang lebih tinggi (tidak pernah turun karena error).
- **Harga model**: scheduler membaca daftar harga model OpenRouter setiap hari. Jika harga model naik, potongan otomatis ikut naik. Jika model dihapus atau terlalu mahal, pindah ke model cadangan yang ditetapkan di panel admin.
- **Biaya payment gateway** ditanggung di luar margin 25% (ditambahkan sebagai biaya admin top-up atau diperhitungkan di harga). Margin bersih tetap 25%.
- Saldo tidak boleh minus: permintaan AI ditolak sopan bila saldo kurang dari perkiraan biaya. Pengingat **1x** saat saldo menipis (§42B hemat).
- Panel admin menampilkan:
  - Modal USD, kurs yang dipakai, pendapatan, dan untung per hari/bulan.
  - Pengaturan margin, minimal top-up, cadangan kurs, dan model utama/cadangan.
- Klien melihat riwayat pemakaian dan sisa saldo dalam Rupiah.
- Masa berlaku saldo: **tidak hangus**. Saldo berlaku sampai habis terpakai (keputusan pemilik, 3 Okt 2026). Paket berakhir tidak menghapus saldo; saldo bisa dipakai lagi saat paket aktif.
- API key OpenRouter hanya di `.env` server.

Status: **rencana**.

## 45. Maintenance Sistem Dibantu AI — 3 Oktober 2026

Melengkapi §9 dan §43. Prinsip hemat AI berlaku: program dulu, AI terakhir.

**Level 1 — program (tanpa AI), setiap menit/jam:**
- Health check: server hidup, API, database, antrean/queue, scheduler, ruang disk, RAM/CPU, sertifikat SSL, koneksi CHATKU dan OpenRouter, sinkron HP yang macet, lonjakan error.
- Perbaikan otomatis dari daftar resep yang aman:
  - Restart queue worker/PHP.
  - Ulang job gagal (idempotent).
  - Bersihkan cache dan log lama.
  - Kompres/rotasi log.
  - Perpanjang SSL.
  - Pindah ke model AI cadangan.
- Backup database harian + uji restore mingguan otomatis ke server terpisah.
- Update keamanan OS terjadwal (patch keamanan saja). Update besar menunggu persetujuan.

**Level 2 — AI, hanya bila Level 1 gagal atau ada error baru yang belum dikenal:**
- AI membaca **ringkasan** log/error, metrik, dan perubahan terakhir. Tidak membaca data pribadi klien.
- AI menulis diagnosis singkat (penyebab, dampak, saran perbaikan) ke WA/email pemilik dan panel admin.
- Diagnosis yang terbukti benar disimpan sebagai resep baru di Level 1, supaya kejadian serupa berikutnya tanpa AI.

**Level 3 — perbaikan kode (bug):**
- AI pengembang (Claude/GPT) membuat perbaikan di **branch + PR GitHub**.
- CI menjalankan semua tes. Pemilik cukup menyetujui atau merge.
- Deploy otomatis setelah merge.
- Bila error naik setelah deploy → **rollback otomatis** ke versi sebelumnya.

Batas keamanan:
- AI **tidak diberi akses shell bebas** ke server produksi. Hanya resep terdaftar yang boleh dijalankan.
- Hapus data, ubah database manual, dan ubah uang/paket wajib persetujuan pemilik.
- Semua tindakan otomatis tercatat di audit log.

Laporan: insiden penting langsung ke WA pemilik. Sisanya masuk laporan mingguan (§43).
Status: **rencana**.

## 46. Remote Bantuan Klien (Admin & AI) — 3 Oktober 2026

Permintaan pengguna: admin dan AI bisa "remote" klien untuk membantu setting dan sejenisnya.

Pendekatan: **remote pengaturan lewat server**, bukan mengambil alih layar HP. Kontrol layar penuh butuh izin Accessibility/MediaProjection, rawan ditolak Google Play, berat, dan berisiko privasi.

**Mode Bantuan (dengan izin klien):**
- Klien menekan **"Izinkan Bantuan"** di aplikasi (Bantuan) atau membalas "YA" di WA CS.
- Akses berlaku **30 menit** (bisa dihentikan kapan saja) dan terlihat jelas di aplikasi ("Sedang dibantu CS").
- Selama aktif, admin/AI bisa melihat:
  - Profil outlet, layanan & harga, paket, cabang/HP/kasir.
  - Pengaturan nota/printer, status sinkron & WA, log error aplikasi.
- **Data pelanggan laundry & uang tidak ditampilkan** kecuali klien mengizinkan khusus.
- Admin/AI bisa **mengubah pengaturan dari server**: harga/layanan, template nota, jam operasional, paket, perbaikan data sinkron. Perubahan masuk ke HP lewat sinkron biasa (§40) dalam hitungan detik.
- Setiap perubahan tercatat di audit log (siapa, apa, sebelum/sesudah) dan bisa dibatalkan (undo).

**Panduan tunjuk tombol (tanpa remote layar):**
- Admin/AI mengirim **link panduan** yang membuka aplikasi di halaman yang tepat dan menyorot tombol yang harus ditekan (overlay langkah demi langkah).
- Contoh kebutuhan: sambung printer Bluetooth, izin kamera/lokasi. Ini harus dilakukan di HP fisik, jadi tidak bisa dari server.
- Klien bisa mengirim **tangkapan layar** dari menu Bantuan langsung ke tiket CS.

**Aturan AI (hemat & aman, §42/§45):**
- AI memakai resep pengaturan yang terdaftar. Program yang mengeksekusi, AI hanya memilih dan menjelaskan.
- AI wajib minta konfirmasi klien ("Saya ubah harga Cuci Kiloan jadi Rp7.000, setuju?") sebelum menyimpan.
- Hapus data, uang, dan paket tetap lewat persetujuan pemilik platform.

Status (3 Okt): **bagian server sudah dibangun & diuji**.
- Owner menekan "Izinkan Bantuan 30 menit" di `/support`.
- Admin membuka `/admin/businesses/{id}/assist` untuk mengubah harga layanan & profil outlet. Perubahan menjadi data sinkron baru (rev naik), lalu HP menerimanya. Setiap perubahan diaudit + bisa dibatalkan.
- Pesanan, pelanggan & uang tidak bisa diubah.
- Belum: tulisan "Sedang dibantu CS" di aplikasi HP, panduan tunjuk tombol, kirim screenshot, dan AI yang memakai resep ini.

## 47. Balasan Cepat Pintar untuk Pelanggan Laundry (tanpa AI) — 3 Oktober 2026

Permintaan pengguna: logika Balasan Cepat diintegrasikan dengan data GOYANA. Bila pelanggan laundry bertanya ("baju saya sudah jadi?"), sistem sudah tahu nomor itu milik pelanggan laundry mana dan status pesanannya, sehingga bisa langsung membalas.

Alur (program, tanpa AI):
1. Pesan masuk ke nomor WA laundry → CHATKU → webhook GOYANA (§41).
2. Kenali **laundry** dari nomor WA yang tersambung.
3. Kenali **pelanggan** dari nomor pengirim di data pelanggan laundry itu. Nomor dinormalkan: 08…/62…/+62….
4. Kenali **maksud** dari kata kunci, lalu balas dengan template + data nyata:

| Maksud (contoh kata kunci) | Balasan berisi |
|---|---|
| Status ("sudah jadi", "baju", "cucian", "kapan", "status") | Daftar pesanan aktif: no. nota, layanan, tahap (Antrian/Proses/Siap diambil/Diantar), perkiraan selesai |
| Tagihan ("berapa", "total", "bayar", "sisa") | Total, DP, sisa bayar, metode bayar/QRIS laundry |
| Nota ("nota", "struk", "invoice") | Link nota digital |
| Jam & lokasi ("buka", "jam", "alamat", "lokasi") | Jam operasional, alamat, link Maps outlet |
| Harga ("harga", "kiloan", "satuan") | Daftar harga layanan dari pengaturan laundry |
| Antar jemput ("jemput", "antar") | Tarif & cara pesan antar jemput |
| Balasan Cepat buatan owner (trigger + gambar) | Sesuai yang diatur owner |

- Banyak pesanan aktif → tampilkan semua (maks. 5) + total.
- Nomor tidak dikenal → menu umum (harga, jam, lokasi, cara order) tanpa data pribadi.
- **Hanya data milik pengirim sendiri** yang dibalas. Tidak pernah data pelanggan lain.
- Tidak cocok kata kunci mana pun →
  - Gold+ dengan saldo AI: Chatbot AI (§44).
  - Selain itu: diteruskan ke kasir/owner (notifikasi di aplikasi) dengan balasan "Pesan diteruskan ke admin laundry".
- **Ambil alih manusia**: bila kasir/owner membalas manual, bot berhenti untuk chat itu selama **15 menit** (keputusan pemilik; dihitung ulang dari balasan manual terakhir, bisa diubah owner).
- Batas: maksimal beberapa balasan otomatis per menit per pelanggan (anti-loop dengan bot lain). Hormati jam operasional (opsional: di luar jam tetap balas status).
- Owner dapat menyalakan/mematikan tiap maksud dan mengubah kalimat template di menu Balasan Cepat.

Hak paket: Balasan Cepat & Trigger saat ini Silver. Katalog §19/v190 menaruh "AI mengecek status laundry pelanggan" di Gold. Karena cek status versi program tidak memakan biaya AI, **tanyakan pemilik**: cek status otomatis masuk Silver atau tetap Gold.

Status: **mesin jawaban sudah dibangun & diuji** (`backend/app/Support/QuickReply.php`: status, tagihan, nota, jam/alamat, harga, antar-jemput; hanya data milik pengirim). Bisa dicoba di detail usaha admin → "Uji Balasan Cepat WhatsApp". Belum: webhook CHATKU, jeda bot 15 menit, dan hak paket (Silver/Gold, tunggu keputusan pemilik).

## 48. Keputusan Deploy — 3 Oktober 2026

- GOYANA dideploy di **VPS** (bukan Jagoan Hosting). VPS **belum dibeli**.
- Spek awal: Ubuntu 24.04, 2 vCPU, 2 GB RAM, SSD 40–60 GB, lokasi Jakarta/Singapura.
- Panduan: `deploy/README.md` bagian A.
- CHATKU tetap di VPS terpisah (§41).

## 49. Cabang, Tim, Login PIN, Kurir, Tahapan, Uang dan Monitoring — 8 Oktober 2026 (branch backend/tim-outlet-kurir)

Keputusan pengguna 8 Oktober 2026. Yang bertentangan dengan bagian lama **menggantikan** bagian itu: batas 2 HP kasir (§4, ROADMAP §37), tampilan kurir (ROADMAP §37), kurir di beberapa outlet (ROADMAP §4), dan kunci menu Pegawai di Silver.

### Keputusan
1. **Login.** Owner: email + password. Kasir, pegawai, kurir, admin outlet: **nomor HP + PIN 6 angka** yang dibuatkan owner. Akun lama email + password tetap bisa masuk.
2. **HP kasir per outlet mengikuti paket:** Trial/Basic 2, Silver 3, Gold 4, Platinum 5 (termasuk pusat). Pegawai dan kurir tidak memakai jatah ini.
3. **Peran:** owner, kasir, pegawai (`produksi` di kode), kurir. **Admin Outlet tetap ada sebagai pilihan** (hak di atas kasir, laporan outletnya sendiri, tidak bisa mengelola pegawai/cabang).
4. **Penempatan:** setiap orang selain owner terikat **tepat satu outlet**. Hanya owner yang menambah, menempatkan, memindahkan, menonaktifkan. Kasir otomatis punya kemampuan pegawai.
5. **Kurir satu outlet.** Akun kurir hanya melihat Jemput, Antar, Setoran dan hanya tugas yang ditunjuk kasir/owner. Kurir lama yang tercentang banyak outlet atau "Semua Outlet" **belum bisa menerima tugas** sampai owner memilihkan satu outlet.
6. **Kurir di lokasi:** boleh membuat transaksi saat jemput (harga dari daftar harga, tanpa diskon), menimbang, dan menerima pembayaran. Transaksi kurir menunggu **konfirmasi timbangan kasir**.
7. **Tahapan:** Cuci → Kering → Setrika → Packing → **Selesai Proses** (baru) → Siap Ambil. Pegawai memajukan satu tahap sampai Selesai Proses. **Siap Ambil hanya kasir/admin outlet/owner**, yang juga boleh melompat; tahap yang dilompati dicatat. Tahap mengikuti "Alur proses" tiap layanan. **Tahap per barang** disimpan server; tampilan aplikasi tetap per nota dulu.
8. **Uang:** tunai yang diterima kurir tercatat "dipegang kurir" sampai disetor ke **kasir outletnya** dan dikonfirmasi; selisih tercatat atas nama kurir. Hutang jadi setelan usaha (bawaan: boleh).
9. **Paket:** menu Pegawai dan hak tahapan dibuka di **Trial dan Basic**. "Free" = Trial 2 bulan; tetap tidak ada paket gratis permanen (§5). Batas cabang tidak berubah.
10. **Nomor nota:** `KODE-YYMMDD-HP-NNNN`, contoh `BKS-261008-1-0133` (kode cabang, tanggal, kode HP, nomor urut). Kode HP = slot HP kasir, atau `K<id>` untuk HP kurir. Nota lama tidak diubah.
11. **Monitoring owner lengkap** antar cabang + peringatan otomatis. Laporan lengkap hanya owner; kasir/pegawai/kurir melihat ringkasan miliknya. Upah **ditunda**: hanya dicatat siapa mengerjakan apa.
12. **Tidak dibuat:** ambil cucian di cabang lain.
13. **Acuan aturan = Flutter murni.** Backend menjadi sumber aturan tunggal; versi web (`/app/`, HTML) mengikuti. Pengecualian sempit yang disetujui untuk HTML: kunci Pegawai ke Basic, tulisan fitur Silver, label "Khusus Paket Premium" pada hak tahapan. Perubahan HTML lain menunggu daftar perbedaan yang disetujui pengguna.

### Sudah dibangun di backend (106 tes PHPUnit + uji sinkron 2 HP lulus di lokal)
- **Celah sinkronisasi ditutup** (`App\Support\OrderGuard`): server tidak lagi menerima isi pesanan utuh dari akun yang hanya boleh mengubah status. Pegawai/kurir tidak bisa mengubah harga, diskon, pembayaran, atau isi pesanan. Kiriman yang tidak diterima dikembalikan ke HP sebagai versi server (`status: conflict` + `message`); status otomatis aplikasi dari HP yang tidak berhak diabaikan tanpa memantul.
- **Yang dikirim ke HP mengikuti peran:** kurir hanya menerima tugasnya (dengan alamat pelanggan), bukan database pelanggan; pegawai menerima pesanan tanpa harga, pembayaran, dan nomor HP pelanggan.
- **Login PIN** (`POST /api/session/pin`): kunci 15 menit setelah 5 kali salah, satu akun pegawai aktif di satu HP, sesi 30 hari, pencabutan seketika. **HP outlet bergantian:** owner mengikat HP ke outlet, pegawai memilih nama + PIN.
- **Kelola Pegawai dan Cabang lewat API** (sebelumnya hanya dashboard web); aturan satu sumber di `App\Support\Team` dan `Outlets`. Cabang: kode nota, alamat, WA, aktif/nonaktif, tempat pengerjaan (sendiri atau dikirim ke outlet lain).
- **Akun kurir = data kurir** (koleksi sinkron `couriers`) dengan tepat satu outlet; data kurir lama bisa disambungkan ke akun.
- **Catatan milik server** yang tidak bisa diubah dari HP: `order_index`, `order_events` (buat, maju, lompat, mundur, batal, timbang, bayar), `courier_ledger`.
- **Monitoring** `GET /api/monitoring` dan peringatan: cucian telat, siap ambil tak diambil, tunai lama dipegang kurir, selisih setoran, HP belum sinkron, kurir tanpa outlet. Dashboard web owner menampilkan peringatan.
- Rincian endpoint: `backend/README.md`.

### Sisi aplikasi yang sudah dikerjakan 8 Oktober (izin pengguna: "Lanjut satu dan dua")
- **Kunci Pegawai dibuka di Trial/Basic** di Mode Murni dan HTML; label "(Khusus Paket Premium)" pada hak tahapan dihapus; daftar fitur paket disesuaikan (pengecualian sempit butir 13).
- **Mode Murni tersambung ke server** (`mobile/lib/pure/server_sync.dart`): Pengaturan → kartu "Sinkronisasi server" → isi alamat → "Simpan & masuk" → lembar masuk (email + password untuk pemilik, nomor HP + PIN untuk kasir/pegawai/kurir). Sinkronisasi dua arah otomatis (setelah menyimpan, tiap 60 detik, dan tombol "Sinkronkan sekarang") dengan protokol yang sama seperti HTML; data server diterapkan saat pengguna tidak sedang mengisi sesuatu. Tugas penjemputan ikut tersinkron. "Keluar Akun" mengakhiri sesi tanpa menghapus data HP.
- **Paket dan peran dari server berlaku di aplikasi:** fitur terbuka mengikuti paket server; akun selain pemilik tidak bisa membuka Cabang, Pegawai, Kasir, Paket, Pusat Data, dan (tanpa izin) Laporan, Harga/Setelan, Stok.
- Alamat server bawaan bisa ditanam saat build dengan `--dart-define=GOYANA_API_URL=…` (workflow CI belum diubah; tanpa itu alamat diisi di Pengaturan).

### Belum (sisi aplikasi, putaran berikutnya)
- Halaman Pegawai, Outlet, Kurir, dan Monitor Cabang di Mode Murni masih menulis/membaca data HP; belum memanggil API Kelola Pegawai/Cabang/Monitoring. Sementara ini akun pegawai dibuat owner di dashboard web.
- Tampilan tiga menu kurir, tombol Selesai Proses, tampilan tahap per barang, popup konfirmasi timbangan, penomoran nota baru, pengikatan HP outlet, layar masuk saat aplikasi pertama dibuka.
- Sesi server disimpan di penyimpanan aplikasi (SQLite privat), belum di secure storage. Di HP yang dipakai bergantian, data pengguna sebelumnya masih ada di HP setelah keluar akun.
- Alasan wajib saat mundur tahap: server siap (`goyana.orders.require_reason_for_backward`), dinyalakan setelah aplikasi mengirim alasan.
- "Diskon terbatas" kasir belum ditegakkan server. Ongkir pada transaksi kurir belum dicocokkan dengan tarif. Belum diuji di MySQL (tes memakai SQLite).
