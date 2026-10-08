<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Aplikasi administrator (keputusan pengguna 8 Oktober 2026):
 * - divisi akun administrator (pemilik, marketing, CS, teknis),
 * - catatan beban server untuk monitor VPS,
 * - CRM marketing: calon client, nomor pengirim, kampanye, antrean pesan, dan daftar "jangan dihubungi".
 * Pelanggan milik laundry client tidak pernah masuk ke tabel-tabel ini (SISTEM-PUSAT §264).
 */
return new class extends Migration {
    public function up(): void {
        Schema::table('users', function (Blueprint $t) {
            $t->string('admin_division', 20)->nullable(); // null pada administrator lama = pemilik
        });
        Schema::create('server_metrics', function (Blueprint $t) {
            $t->id();
            $t->unsignedBigInteger('ram_used'); $t->unsignedBigInteger('ram_total');
            $t->float('load1'); $t->unsignedSmallInteger('cpu_cores');
            $t->unsignedBigInteger('disk_used'); $t->unsignedBigInteger('disk_total');
            $t->timestamp('created_at')->index();
        });
        Schema::create('prospects', function (Blueprint $t) {
            $t->id();
            $t->string('name', 160);
            $t->string('owner_name', 120)->nullable();
            $t->string('phone', 20)->unique();
            $t->string('city', 80)->nullable()->index();
            $t->string('source', 40);                       // manual | impor | nama sumber lain
            $t->string('status', 16)->default('baru')->index(); // baru | dihubungi | membalas | tertarik | daftar | menolak
            $t->boolean('do_not_contact')->default(false);
            $t->text('note')->nullable();
            $t->foreignId('business_id')->nullable()->constrained()->nullOnDelete(); // terisi saat calon ini mendaftar
            $t->timestamp('last_contacted_at')->nullable();
            $t->unsignedInteger('replies')->default(0);
            $t->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $t->timestamps();
        });
        Schema::create('prospect_events', function (Blueprint $t) {
            $t->id();
            $t->foreignId('prospect_id')->constrained()->cascadeOnDelete();
            $t->string('kind', 16);                         // dibuat | status | kirim | balas | stop | catatan
            $t->string('detail', 500)->nullable();
            $t->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $t->timestamp('created_at')->index();
        });
        Schema::create('marketing_senders', function (Blueprint $t) {
            $t->id();
            $t->string('label', 80);
            $t->string('phone', 20)->unique();
            $t->boolean('active')->default(true);
            $t->timestamp('started_at');                    // awal pemanasan: jatah harian naik bertahap dari tanggal ini
            $t->timestamp('next_at')->nullable();           // jeda acak: paling cepat mengirim lagi pada waktu ini
            $t->unsignedSmallInteger('fail_streak')->default(0);
            $t->timestamp('paused_at')->nullable();
            $t->string('pause_reason', 200)->nullable();
            $t->timestamps();
        });
        Schema::create('campaigns', function (Blueprint $t) {
            $t->id();
            $t->string('name', 120);
            $t->string('audience', 12);                     // prospects | clients
            $t->json('filters');
            $t->json('variants');                           // beberapa variasi kalimat pembuka, dipakai bergiliran
            $t->json('followups')->nullable();              // variasi tindak lanjut; kosong = tanpa tindak lanjut
            $t->string('status', 12)->default('draft');     // draft | running | paused | done
            $t->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $t->timestamps();
        });
        Schema::create('campaign_messages', function (Blueprint $t) {
            $t->id();
            $t->foreignId('campaign_id')->constrained()->cascadeOnDelete();
            $t->foreignId('prospect_id')->nullable()->constrained()->nullOnDelete();
            $t->foreignId('business_id')->nullable()->constrained()->nullOnDelete();
            $t->string('phone', 20);
            $t->string('name', 160);
            $t->text('body');
            $t->string('kind', 10);                         // opener | followup
            $t->string('status', 10)->default('queued');    // queued | sent | manual | failed | skipped
            $t->foreignId('sender_id')->nullable()->constrained('marketing_senders')->nullOnDelete();
            $t->timestamp('not_before')->nullable();
            $t->timestamp('sent_at')->nullable();
            $t->string('error', 300)->nullable();
            $t->timestamp('created_at');
            $t->unique(['campaign_id', 'phone', 'kind']);
            $t->index(['status', 'not_before']);
            $t->index(['sender_id', 'sent_at']);
        });
        Schema::create('marketing_optouts', function (Blueprint $t) {
            $t->string('phone', 20)->primary();
            $t->string('reason', 200)->nullable();
            $t->timestamp('created_at');
        });
    }

    public function down(): void {
        foreach (['marketing_optouts', 'campaign_messages', 'campaigns', 'marketing_senders', 'prospect_events', 'prospects', 'server_metrics'] as $table) Schema::dropIfExists($table);
        Schema::table('users', fn (Blueprint $t) => $t->dropColumn('admin_division'));
    }
};
