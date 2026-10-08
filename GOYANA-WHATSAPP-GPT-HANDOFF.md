# Goyana — pekerjaan WhatsApp GPT, 8 Oktober 2026

## Status dan batas pemasangan
Persiapan pada branch lokal `codex/whatsapp-preparation`, basis `b91cc65` (salinan 6 Oktober). Belum digabung, dipasang, atau dipublikasikan. Penggabungan/pemasangan WAJIB menunggu aba-aba Paduka. Jangan menyatakan fitur sudah bekerja berdasarkan rancangan ini.

Claude menangani akun, login, peran, dan penugasan pegawai/cabang. GPT menangani perangkat WhatsApp, otomasi status, template pusat, dan persiapan AI pengusul template. Gunakan identitas usaha/outlet/login Claude; jangan membuat sistem akun kedua. Jangan mengubah CI atau fitur transaksi lain. Samakan basis terbaru sebelum integrasi.

## Keputusan pengguna
1. Tambah perangkat: nama perangkat, nomor WhatsApp, outlet. Gunakan outlet Pusat yang sah bila belum ada cabang; jangan membuat ID outlet palsu. Simpan draf offline terpisah dari perangkat server. Aksi daftar: Hubungkan, Edit, Hapus.
2. Hubungkan membuka pilihan Scan QR atau Kode Pemasangan. QR/kode asli berasal dari Chatku melalui Laravel. Jangan membuat QR atau status terhubung palsu.
3. Paket yang mendukung WA memiliki satu slot dasar sesuai pembahasan; nomor tambahan melalui slot berbayar. Tambah cabang tidak menambah slot. Verifikasi konfigurasi paket terbaru dan hak fitur sebelum menerapkan angka/nama paket. Kuota diperiksa server secara atomik, bukan hanya tombol. Draf offline tidak membuktikan hak slot.
4. UI mengikuti tema Goyana merah-oranye, putih, font/ukuran/ketebalan dan komponen aplikasi yang ada. Gambar biru hanya acuan susunan.
5. Menu Otomasi: `Balas Status WhatsApp`, centang aktif/nonaktif, keterangan `Otomatis menjawab pertanyaan status pesanan.` Berlaku per perangkat/outlet dan hak paket. Tidak sama dengan notifikasi perubahan status.
6. Balasan status tanpa AI memakai data tersinkron; nomor pelanggan harus cocok tepat setelah normalisasi, usaha/outlet harus cocok. Jangan cocokkan hanya nama atau potongan nomor. Bila banyak pesanan, minta pilihan; kode pesanan tidak melewati verifikasi kepemilikan. Estimasi bukan janji; jangan mengarang tahap proses.
7. Flutter mengelola tampilan/pengaturan/draf. Laravel menyimpan konfigurasi, memeriksa izin/kuota, mengolah pesan dan template. Chatku menjaga sambungan dan menerima/mengirim pesan. Rahasia API hanya di server.
8. Admin pusat: Template WhatsApp, tambah/edit/pratinjau/aktif-nonaktif. Template universal memakai variabel terdaftar; nilai layanan/harga/pesanan berasal dari usaha terkait. Simpan revisi dan audit, hindari duplikasi template.
9. AI pusat mengelompokkan pertanyaan tidak terjawab yang telah disamarkan, mengusulkan template universal sebagai draf. Admin meninjau sebelum aktif. Tidak memberikan akses bebas seluruh database atau mencampur data laundry.
10. Chatbot layanan mengambil layanan aktif dan harga terbaru setelah sinkronisasi. Layanan tak tercatat tidak berarti tidak tersedia; harga kosong tidak boleh ditebak. Alihkan ke admin tanpa menjanjikan tindak lanjut yang belum dibuat.

## Pembaruan implementasi
Modul persiapan dan tes telah ditulis secara terisolasi. Hasil aktual, kontrak integrasi, referensi Claude terbaru, dan penghambat tercatat di [GOYANA-WHATSAPP-IMPLEMENTASI.md](GOYANA-WHATSAPP-IMPLEMENTASI.md). Lima belas tes logika Dart lulus. Tes Laravel, widget Flutter, dan Chatku nyata belum dijalankan.

## Tahapan kerja
- [x] Salinan terisolasi dan batas pekerjaan dibuat.
- [x] Pemeriksaan awal backend: QuickReply, Assist, routes API.
- [ ] Sinkronkan basis terbaru dengan pekerjaan Claude.
- [x] Kode persiapan: Modul draf/perangkat dan popup Flutter, memakai tema yang ada.
- [x] Kode persiapan: Model/validasi/otorisasi perangkat Laravel dan kuota.
- [x] Kode persiapan: Kontrak adapter Chatku, webhook terverifikasi, antrean/idempotensi.
- [x] Kode persiapan: Balas Status WhatsApp dengan pembatasan usaha/outlet/pelanggan.
- [x] Kode persiapan: CRUD/pratinjau/revisi template administrator.
- [ ] AI pengusul template dan chatbot berbasis data.
- [ ] Tes isolasi data, kuota bersamaan, duplikasi webhook, kegagalan gateway, draf offline, dan UI.
- [x] Laporan hasil aktual dibuat; pemasangan tetap menunggu aba-aba.

## Temuan awal dan penghambat
- Salinan lokal bukan jaminan kode GitHub terbaru. Git langsung gagal autentikasi; perlu jalur konektor GitHub atau akses repo yang tersedia untuk memastikan basis.
- `backend/app/Support/QuickReply.php` sudah punya balasan berbasis aturan, tetapi membaca koleksi per usaha dan mencocokkan pesanan lewat nama; perlu diperbaiki sebelum dipakai sebagai isolasi pelanggan/outlet.
- `Assist.php` adalah bantuan admin, bukan AI pembelajar template.
- `GOYANA-SAMPAI-SELESAI.md` F5 menyatakan kode Chatku di repo lain dan kontrak API harus diperoleh, tidak boleh ditebak. URL/path, auth, payload QR/pairing, webhook/signature, status dan idempotensi belum diverifikasi. Persiapan lokal/fake dapat dikerjakan; sambungan nyata belum dapat dinyatakan selesai.
- Penyedia/model AI, kredensial dan anggaran belum diverifikasi. Jangan mengirim percakapan nyata saat pengujian.

## Verifikasi wajib sebelum siap dipasang
Isolasi dua usaha dan dua outlet, nama pelanggan sama, nomor mirip, kode pesanan milik orang lain; kuota saat request paralel; pencabutan izin; webhook berulang/tidak sah; template invalid; provider gagal; masa berlaku QR; offline dan sinkron ulang; fallback data belum tersedia. Tulis hasil tes yang benar-benar dijalankan dan keterbatasannya.
