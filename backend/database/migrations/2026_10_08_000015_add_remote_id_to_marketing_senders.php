<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/** Nomor pengirim marketing memakai jalur Chatku yang sama dengan perangkat WA client: remote_id = sesi nomor itu di Chatku. */
return new class extends Migration {
    public function up(): void {
        Schema::table('marketing_senders', fn (Blueprint $t) => $t->string('remote_id')->nullable()->unique());
    }

    public function down(): void {
        Schema::table('marketing_senders', function (Blueprint $t) { $t->dropUnique(['remote_id']); $t->dropColumn('remote_id'); });
    }
};
