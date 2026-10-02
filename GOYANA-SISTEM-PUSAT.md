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
