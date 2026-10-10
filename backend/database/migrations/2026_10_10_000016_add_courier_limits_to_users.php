<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Hak akses per kurir (keputusan pengguna 10 Oktober 2026). Kosong = semua boleh (bawaan kurir):
 * {"weigh": bool, "create": bool, "pay": bool}.
 */
return new class extends Migration {
    public function up(): void {
        Schema::table('users', fn (Blueprint $t) => $t->json('courier_limits')->nullable());
    }
    public function down(): void {
        Schema::table('users', fn (Blueprint $t) => $t->dropColumn('courier_limits'));
    }
};
