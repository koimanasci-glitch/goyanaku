# Pengaturan WhatsApp v191

Permintaan 1 Oktober 2026: halaman terpisah untuk pengaturan trigger balasan cepat dan chatbot AI, input gambar pada Chatbot, pengetahuan dari harga layanan/status laundry, serta WA Blast untuk promo.

## Yang diterapkan

- Halaman Chatbot lama tetap ada. Tautan baru di Chatbot dan Pengaturan membuka Balasan Cepat & Trigger, Pengaturan Chatbot AI, dan WhatsApp Blast.
- Balasan cepat: tambah/edit/hapus, aktif/nonaktif, pemicu dipisahkan koma, pencocokan kata/frasa atau pesan sama persis, teks dan gambar PNG/JPG/WebP maksimal 1 MB.
- Gambar default pada halaman Chatbot. Balasan dengan gambar khusus menggunakan gambarnya sendiri; aturan tanpa gambar menggunakan gambar default.
- Pengaturan AI: aktivasi, nama asisten, instruksi, pengetahuan tambahan, gambar dan pilihan membaca harga/status dari aplikasi.
- Uji jawaban data aplikasi membaca harga layanan aktif saat pertanyaan diajukan. Status pesanan hanya dibaca untuk outlet aktif dan nomor pelanggan yang cocok. Tidak memakai contoh harga/status fiktif.
- Pengaturan dan draft disimpan per outlet di localStorage, bukan sinkron antarperangkat.
- Balasan Cepat & Trigger mengikuti akses quick (Super Pro Chatbot); AI mengikuti akses ai (Platinum). Satuan/hak add-on tetap mengikuti batas prototype v190 dan belum terhubung entitlement server.
- WA Blast: pilih nomor pelanggan valid, deduplikasi nomor, konfirmasi persetujuan promo, teks dengan placeholder nama, gambar, simpan/hapus draft. Tidak mengirim pesan dan tidak mencatat sukses palsu.

## Belum terhubung

- Tidak ada backend/gateway WhatsApp produksi dalam repository. Pengiriman pesan, webhook inbound, penjadwalan promo dan hasil pengiriman belum berjalan. Tombol Kirim ditandai tidak tersedia.
- Uji jawaban harga/status merupakan pembacaan data lokal, bukan panggilan model AI. Pengetahuan tambahan dan instruksi tersimpan untuk integrasi AI berikutnya, belum menghasilkan jawaban model.
- Identitas nomor pengirim pada uji lokal berasal dari isian pengguna. Produksi harus menggunakan identitas pengirim terverifikasi dari webhook, tenant/outlet server, otorisasi dan pembatasan akses data.
- Harga layanan mengikuti katalog yang digunakan aplikasi saat ini; pemisahan katalog harga per outlet harus mengikuti model backend berikutnya.
- API key AI harus disimpan di server, bukan di aplikasi. Konsumsi AI, kuota/saldo dan batas biaya perlu diterapkan bersama backend.
- WA Blast membutuhkan proses pengiriman server, personalisasi placeholder, opt-out, pembatasan frekuensi, retry idempotent, dan riwayat status pengiriman sebelum digunakan untuk pelanggan.

## Validasi

- Tes browser: persistensi/edit trigger, pencocokan kata/pesan persis, upload gambar, aktivasi, isolasi outlet, harga terbaru, isolasi status berdasarkan nomor dan outlet, pembatasan paket, draft promo/persetujuan.
- Layout pada lebar 320, 360, 390 dan 430 piksel; tanpa error JavaScript.
- Tes regresi transaksi, stok/paket, dan penyisipan script build tetap dijalankan.
