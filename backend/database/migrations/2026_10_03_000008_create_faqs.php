<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\{DB, Schema};
/** FAQ untuk jawaban otomatis CS tanpa AI (§42 prinsip hemat). Admin dapat mengubahnya di /admin/faqs. */
return new class extends Migration {
    public function up(): void {
        Schema::create('faqs', function (Blueprint $t) {
            $t->id();
            $t->string('question', 200);
            $t->string('keywords', 500); // dipisah koma; frasa boleh berspasi
            $t->text('answer');
            $t->boolean('active')->default(true);
            $t->unsignedInteger('hits')->default(0);
            $t->timestamps();
        });
        $now = now();
        DB::table('faqs')->insert(array_map(fn ($r) => ['question' => $r[0], 'keywords' => $r[1], 'answer' => $r[2], 'active' => true, 'hits' => 0, 'created_at' => $now, 'updated_at' => $now], [
            ['Printer tidak mau mencetak', 'printer, cetak, struk tidak keluar, bluetooth',
                "1. Pastikan printer menyala dan kertas terpasang.\n2. Nyalakan Bluetooth & lokasi HP.\n3. Buka Pengaturan > Printer, pilih printer lalu Tes Cetak.\n4. Bila tetap gagal: matikan-nyalakan printer, lalu hubungkan ulang."],
            ['Data tidak muncul di HP lain', 'sinkron, tidak muncul, tidak masuk, data hilang, beda data',
                "Data dikirim ke server otomatis setiap ±20 detik saat ada internet.\n1. Pastikan kedua HP online dan login dengan akun usaha yang sama.\n2. Buka Pengaturan > Sinkronisasi, tekan Sinkron sekarang.\n3. Data dari HP yang offline akan terkirim begitu HP itu online kembali."],
            ['Lupa password', 'lupa password, lupa kata sandi, tidak bisa login, gagal login',
                "Owner: gunakan Lupa password di halaman login. Pegawai: minta owner mereset password dari dashboard web > Akun tim."],
            ['Menambah kasir atau HP', 'tambah kasir, tambah pegawai, hp baru, perangkat, slot',
                "Owner membuat akun pegawai di dashboard web > Akun tim. Tiap outlet maksimal 2 HP kasir; cabut HP lama di dashboard bila ganti HP."],
            ['Paket habis / perpanjang', 'paket, perpanjang, langganan, masa aktif, habis, baca saja, terkunci',
                "Setelah paket habis data tetap aman (baca saja). Pilih paket di aplikasi: Pengaturan > Paket. Setelah pembayaran diterima, akun langsung aktif kembali."],
        ]));
    }
    public function down(): void { Schema::dropIfExists('faqs'); }
};
