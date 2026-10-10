<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/** Zona waktu per cabang (keputusan Paduka 10 Oktober 2026): WIB, WITA, atau WIT. Cabang lama = WIB. */
return new class extends Migration {
    public function up(): void {
        Schema::table('outlets', function (Blueprint $t) {
            $t->string('timezone', 40)->default('Asia/Jakarta')->after('phone');
        });
    }

    public function down(): void {
        Schema::table('outlets', fn (Blueprint $t) => $t->dropColumn('timezone'));
    }
};
