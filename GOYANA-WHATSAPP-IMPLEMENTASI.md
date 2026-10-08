# Goyana — handoff implementasi WhatsApp

Tanggal: 8 Oktober 2026. Branch lokal: `codex/whatsapp-preparation`.

**Status 8 Oktober 2026 (pembaruan Claude): sudah dipasang atas aba-aba Paduka di branch `backend/integrasi-whatsapp`. Provider terdaftar, menu HP dan administrator tersambung, tes Laravel dan Flutter dijalankan di CI. Belum diuji dengan Chatku nyata; saklar `GOYANA_WHATSAPP_ENABLED` bawaan mati. Ringkasan pemasangan: `GOYANA-SISTEM-PUSAT.md` §53. Isi di bawah adalah catatan asli GPT sebelum pemasangan.**

## Yang sudah dibuat

| Bagian | Implementasi | Batas aktual |
|---|---|---|
| Perangkat Flutter | Form nama, nomor, outlet; draf offline; Hubungkan/Edit/Hapus; pilihan QR/kode; tema Poppins putih dan coral Goyana | Widget belum dimasukkan ke navigasi aplikasi |
| Draf offline | Terpisah per akun, nomor dinormalisasi, duplikasi ditolak, gagal simpan tidak menghilangkan draf | Outlet wajib benar-benar ada; outlet belum sinkron tidak bisa didaftarkan ke server |
| Perangkat Laravel | Pemilik usaha, outlet milik usaha, kuota terkunci dalam transaksi, UUID untuk pengulangan pendaftaran, versi perubahan | Pengujian Laravel belum dijalankan |
| Chatku | Kontrak adapter internal, pemeriksaan identitas nomor, masa berlaku QR/kode, webhook terautentikasi melalui adapter | Adapter HTTP Chatku nyata belum tersedia. Adapter bawaan memberi 503, bukan QR/status palsu |
| Balas status | Query indeks usaha + outlet + nomor pelanggan tepat; banyak pesanan meminta kode; kode tetap diperiksa kepemilikannya | Data harus tersinkron. Hak paket balas status belum diputuskan dan dinonaktifkan secara bawaan |
| Balas layanan/harga | Membaca katalog tersinkron yang aktif; layanan tidak ditemukan diarahkan ke admin | Pencocokan kata deterministik, bukan percakapan AI bebas |
| Antrean | Deduplicasi event, outbox terenkripsi, batas percobaan/umur, kunci pengiriman tetap, pemeriksaan ulang hak/perangkat | Jaminan tidak mengirim ganda memerlukan idempotensi nyata di Chatku |
| Admin template | Tambah/edit template berdasarkan tujuan, pratinjau, aktif/nonaktif, revisi, pemeriksaan versi | Provider dan tautan menu admin belum diaktifkan |
| Usulan AI pusat | Kontrak penyedia AI; statistik topik yang diizinkan; usulan disimpan tidak aktif; persetujuan admin sebelum dipakai | Belum ada penyedia/model/kredensial. Klasifikasi topik masih daftar terbatas, bukan pembelajaran bebas |
| Nomor tambahan | Tabel hak slot berbayar dan masa berlaku; tambahan cabang tidak menambah slot | Belum dihubungkan ke pembayaran nyata; jangan menambah hak dari input klien |

Modul ini belum mencakup pengiriman blast, gambar, migrasi aturan trigger lama, atau notifikasi proaktif ketika status pesanan berubah. “Balas Status WhatsApp” menjawab pertanyaan masuk, bukan notifikasi perubahan status.

## Dasar pemeriksaan dan pekerjaan Claude

Salinan lokal berbasis `b91cc6599b03cae0c3d45863f4c9112176b92c99`. Referensi diperiksa melalui konektor GitHub:

- Flutter murni `flutter/panduan-baru`: `a98ebd68475aabce3247f36901edf53ab12dd136`.
- Backend Claude `backend/tim-outlet-kurir`: mula-mula `d17dbda61b5b93af28b5aa228cb3184b0971a1f5`, lalu perubahan dibandingkan sampai `a00c5c428e485d05105ec1e962fc2dec35e4cb33`.
- `mobile/lib/pure/wa_pages.dart` pada `a00c5c4` masih menyatakan pengiriman WhatsApp/AI belum terhubung. Perangkat hanya menampilkan pemberitahuan server belum aktif; jawaban AI uji memakai data lokal. Ini tidak membuktikan sambungan Chatku sudah bekerja.

Belum melakukan merge/rebase. Modul memakai kontrak User/Business/Outlet Claude dan `order_index`, bukan membuat login atau penugasan pegawai kedua. File login, pegawai, outlet, PureShell, halaman WA lama, konfigurasi paket utama, CI, dan bootstrap provider tidak diubah.

## Peta file

- `mobile/lib/whatsapp/device_store.dart`: logika draf, permintaan API, kuota, pemasangan, penyimpanan.
- `mobile/lib/whatsapp/kv_storage.dart`: adapter KvStore aplikasi.
- `mobile/lib/whatsapp/devices_page.dart`: halaman perangkat dan popup pemasangan.
- `mobile/lib/whatsapp/automation_tile.dart`: komponen “Balas Status WhatsApp”.
- `backend/app/WhatsApp/`: provider opsional, perangkat, balasan, webhook, antrean, template, statistik, kontrak gateway/AI, konfigurasi, view dan migrasi.
- `backend/tests/WhatsApp/ModuleTest.php`: skenario Laravel dengan gateway tiruan khusus tes.
- `mobile/test/whatsapp/device_store_check.dart`: tes Dart mandiri.
- `mobile/test/whatsapp/devices_page_test.dart`: tes widget Flutter.

## Kontrak integrasi Goyana

Seluruh endpoint berikut milik Laravel Goyana, **bukan URL API Chatku**. Endpoint baru hanya didaftarkan ketika provider terpasang dan `whatsapp.enabled=true`.

| Metode | Path | Kegunaan |
|---|---|---|
| GET | `/api/whatsapp/devices` | Daftar perangkat dan kuota dari server |
| POST | `/api/whatsapp/devices` | Daftar draf: UUID, nama, nomor, outlet_id sah |
| PUT | `/api/whatsapp/devices/{id}` | Edit dengan versi terkini |
| DELETE | `/api/whatsapp/devices/{id}` | Putuskan remote lalu hapus; kegagalan mempertahankan reservasi |
| POST | `/api/whatsapp/devices/{id}/pairing` | `method` bernilai `qr` atau `code` |
| POST | `/api/whatsapp/devices/{id}/refresh` | Baca status sambungan aktual dari gateway |
| PUT | `/api/whatsapp/devices/{id}/automation` | Boolean `reply_status` dan `reply_services` |
| POST | `/api/whatsapp/chatku/events` | Pesan masuk; adapter wajib memverifikasi request asli |
| GET/POST | `/admin/whatsapp/templates` | Daftar/simpan template universal |
| POST | `/admin/whatsapp/templates/preview` | Pratinjau dengan data contoh |
| GET | `/admin/whatsapp/templates/{id}/revisions` | Riwayat revisi |
| POST | `/admin/whatsapp/templates/propose` | Usulan AI tidak aktif, bila penyedia tersedia |

API perangkat memakai Sanctum dan pemeriksaan pemilik usaha. Template memakai middleware administrator platform termasuk kebijakan MFA yang sudah ada. Endpoint webhook tidak memakai login pengguna; autentikasinya harus berasal dari kontrak resmi Chatku.

### Flutter setelah izin pemasangan

1. Ambil outlet yang sah dari sistem Claude. Petakan key lokal ke ID server, termasuk `srv-ID` bila memang diberikan sinkronisasi. Jangan menebak ID numerik atau membuat outlet Pusat palsu.
2. Buat store dengan `WaKvStorage`, identitas akun/usaha yang stabil, daftar outlet sah, dan `WaRequest` dari transport sesi Goyana yang sudah ada. Buat ulang store saat berganti akun; jangan mempertahankan callback token lama.
3. Adapter request harus mengurai respons JSON, menerjemahkan 401/403/409/422/503 ke kesalahan yang ditampilkan dengan aman, dan menangani DELETE 204 sebagai map kosong.
4. Integrasikan satu halaman perangkat pada tujuan `wadevices195`. Integrasikan komponen checkbox ke halaman Otomasi. Jangan membiarkan dua sumber pengaturan WA aktif yang berbeda tanpa migrasi yang jelas.
5. `onBuySlots` hanya diisi bila checkout tambahan nomor sudah benar-benar tersedia. Draf offline tidak berarti kuota server tersedia.
6. Ikuti `gBrand`, `gText`, dan Poppins aplikasi. Jalankan widget test dan pemeriksaan tampilan Android/web setelah dependensi tersedia.

### Laravel setelah izin pemasangan

1. Gabungkan hanya modul baru setelah menyamakan basis dengan Claude. Pastikan model/metode dan migrasi `order_index` tersedia; jangan menjalankannya pada basis lama tanpa pemeriksaan.
2. Daftarkan `WhatsAppServiceProvider` secara eksplisit. Migrasi modul berada di direktori modul dan akan ikut ditemukan setelah provider didaftarkan, walau flag endpoint masih mati. Tinjau migrasi sebelum menjalankan migrate.
3. Pasang adapter Chatku resmi melalui binding `ChatkuGateway`. Batasi timeout di bawah timeout worker; beberapa operasi gateway masih berada dalam transaksi yang mengunci usaha.
4. Tetapkan hak paket. Referensi terbaru memakai Basic/Silver/Gold/Platinum. Konfigurasi persiapan memberi satu slot dasar pada Silver/Gold/Platinum; layanan pada Gold/Platinum. `status_packages=[]` sengaja belum diaktifkan sampai hak balas status non-AI diputuskan. Jangan memakai nama Pro/Super Pro dari mockup lama sebagai fakta konfigurasi.
5. Hubungkan pembayaran slot ke transaksi pembayaran terverifikasi di server; payment_reference harus unik. Cabang dan nomor WA mempunyai batas terpisah.
6. Aktifkan queue worker dan jadwalkan `goyana:wa-retry` tiap menit. Gunakan APP_KEY yang stabil, penyimpanan queue/cache yang sesuai, dan kebijakan pembersihan event/statistik. Penghapusan payload outbox sudah tersedia, tetapi pemangkasan riwayat tabel belum dibuat.
7. Tambahkan tautan menu template pusat, pasang penyedia `TemplateProposer` bila disepakati, baru aktifkan flag AI. Usulan tetap draf sampai ditinjau.
8. Jalankan seluruh pengujian sebelum mengaktifkan endpoint. Jangan push branch persiapan bila workflow mobile dapat otomatis menerbitkan APK.

## Kontrak Chatku yang masih diperlukan

Diperlukan dokumentasi/kode resmi tentang base URL, autentikasi, pembuatan/pemulihan sesi, QR/kode dan kedaluwarsanya, pemeriksaan nomor yang benar-benar tersambung, pemutusan sesi, pengiriman dan idempotensi setelah timeout, payload webhook, verifikasi signature atas body asli, timestamp/replay, identitas akun provider serta identitas pesan unik. Token tetap di Laravel.

Jangan mengisi endpoint atau bentuk signature berdasarkan tebakan. Bila Chatku tidak mendukung idempotensi pengiriman, desain pemulihan timeout harus disepakati dahulu; outbox saja tidak menjamin tepat satu pengiriman.

## Hasil verifikasi aktual

| Pemeriksaan | Hasil |
|---|---|
| Tes Dart mandiri | **15 lulus** pada 8 Oktober 2026 |
| Analisis statis file inti Dart secara terpisah | Tidak ada masalah pada pemeriksaan yang dijalankan |
| Pemformatan Dart | Berhasil; dependensi flutter_lints belum tersedia di lingkungan ini |
| Tes widget/render Android/web | **Belum dijalankan**; Flutter/dependensi aplikasi belum siap |
| Tes Laravel/PHP | **Belum dijalankan**; PHP/Composer tidak tersedia |
| Koneksi Chatku, webhook asli, pengiriman nyata, pembayaran | **Belum diuji** |
| Uji kuota serentak pada database produksi sejenis | **Belum dijalankan**; adanya lock bukan bukti tes konkurensi lulus |

Tes Dart meliputi simpan/muat draf, normalisasi nomor, kegagalan penyimpanan, pemisahan akun, nomor ganda, outlet palsu/tidak sinkron, penolakan kuota, retry setelah provisioning berhasil tetapi pairing gagal, QR kedaluwarsa, payload pairing tidak disimpan, status cache menjadi unknown, kegagalan hapus, nomor invalid, penyimpanan rusak tidak ditimpa, dan kuota cache dibuang saat refresh gagal.

Pemeriksaan otomatis menolak pemasangan alat PHP karena dianggap perubahan paket sistem di luar cakupan yang disetujui. Pemasangan tidak diteruskan. Tes Laravel yang disediakan bukan hasil kelulusan.

Perintah untuk lingkungan uji yang sudah tersedia:

```sh
# dari mobile/
dart test/whatsapp/device_store_check.dart
flutter test test/whatsapp/devices_page_test.dart
flutter analyze lib/whatsapp

# dari backend/ setelah dependensi dan database uji siap
php vendor/bin/phpunit tests/WhatsApp
```

## Gerbang sebelum dipasang

- Tes isolasi dua usaha/outlet, nomor mirip, nama sama, dan kode pesanan orang lain.
- Tes kuota paralel, downgrade, perubahan outlet/izin, pengulangan pembayaran, webhook berulang/palsu/terlambat.
- Tes worker crash dan timeout provider sebelum/sesudah provider menerima pesan; verifikasi idempotensi nyata.
- Tes penonaktifan otomasi/penghapusan saat pesan sedang dikirim. Pesan yang sudah diterima provider mungkin tidak dapat ditarik kembali; pemeriksaan sebelum send bukan pembatalan atomik di provider.
- Tes katalog dan order_index terhadap skema/data terbaru Claude, termasuk data belum sinkron.
- Tes visual, aksesibilitas, dialog dan QR pada Android/web; verifikasi aturan cache/session browser.
- Tetapkan paket balas status, harga slot, penyedia AI/anggaran, retensi data, dan kontrak Chatku.
- Dapatkan aba-aba Paduka sebelum merge/pemasangan/deploy. Tidak ada pesan nyata yang dikirim dalam pekerjaan ini.
