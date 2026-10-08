<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Keputusan pengguna 8 Oktober 2026:
 * - Kasir, pegawai, dan kurir login nomor HP + PIN (owner tetap email + password).
 * - Cabang punya kode (awalan nomor nota), alamat, nomor WA, status aktif, dan tempat pengerjaan.
 * - HP outlet bisa diikat owner untuk dipakai bergantian.
 */
return new class extends Migration {
    public function up(): void {
        Schema::table('users', function (Blueprint $t) {
            $t->string('email')->nullable()->change();     // pegawai dengan PIN tidak wajib punya email
            $t->string('password')->nullable()->change();
            $t->string('phone', 20)->nullable()->unique();  // 62812…, hanya angka
            $t->string('pin')->nullable();                  // hash, tidak pernah dikirim ke klien
            $t->unsignedTinyInteger('pin_failed')->default(0);
            $t->timestamp('pin_locked_until')->nullable();
            $t->string('courier_key', 160)->nullable();     // kunci data kurir (sync collection "couriers") milik akun ini
        });

        Schema::table('outlets', function (Blueprint $t) {
            $t->string('code', 4)->nullable();              // awalan nomor nota, contoh BKS
            $t->string('address', 300)->nullable();
            $t->string('phone', 20)->nullable();
            $t->timestamp('deactivated_at')->nullable();
            // null = cucian dikerjakan di outlet ini; terisi = dikirim ke outlet tersebut.
            $t->foreignId('process_outlet_id')->nullable()->constrained('outlets')->nullOnDelete();
            $t->unique(['business_id', 'code']);
        });

        Schema::table('businesses', function (Blueprint $t) {
            $t->boolean('allow_debt')->default(true);       // boleh serah terima sebelum lunas
        });

        // HP milik outlet yang dipakai bergantian: pegawai memilih nama lalu mengetik PIN.
        Schema::create('shared_devices', function (Blueprint $t) {
            $t->id();
            $t->foreignId('business_id')->constrained()->restrictOnDelete();
            $t->foreignId('outlet_id')->constrained()->restrictOnDelete();
            $t->string('device_uuid', 64);
            $t->string('label', 120);
            $t->string('secret');                            // hash; nilai asli hanya ada di HP itu
            $t->foreignId('bound_by')->constrained('users')->restrictOnDelete();
            $t->timestamp('last_seen_at')->nullable();
            $t->timestamp('revoked_at')->nullable();
            $t->timestamps();
            $t->index(['device_uuid', 'revoked_at']);
        });
    }

    public function down(): void {
        Schema::dropIfExists('shared_devices');
        Schema::table('businesses', fn (Blueprint $t) => $t->dropColumn('allow_debt'));
        Schema::table('outlets', function (Blueprint $t) {
            $t->dropUnique(['business_id', 'code']);
            $t->dropConstrainedForeignId('process_outlet_id');
            $t->dropColumn(['code', 'address', 'phone', 'deactivated_at']);
        });
        Schema::table('users', function (Blueprint $t) {
            $t->dropUnique(['phone']);
            $t->dropColumn(['phone', 'pin', 'pin_failed', 'pin_locked_until', 'courier_key']);
        });
    }
};
