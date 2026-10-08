<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/** Masuk dengan Google: id akun Google pemilik (kolom "sub" pada tanda masuk Google). */
return new class extends Migration {
    public function up(): void {
        Schema::table('users', function (Blueprint $table) {
            $table->string('google_id', 64)->nullable()->unique();
        });
    }

    public function down(): void {
        Schema::table('users', function (Blueprint $table) {
            $table->dropUnique(['google_id']);
            $table->dropColumn('google_id');
        });
    }
};
