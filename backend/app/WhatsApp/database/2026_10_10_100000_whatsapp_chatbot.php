<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Chatbot per cabang di server (keputusan Paduka 10 Okt 2026): balasan cepat, AI/knowledge, media (maks. 10),
 * pemilik ambil alih, pesan otomatis (nota/siap/telat ambil), blast laundry + berhenti promo.
 * Nomor pelanggan disimpan terenkripsi atau sebagai hash; isi chat hanya ringkas, terenkripsi, dan dihapus otomatis.
 */
return new class extends Migration {
    public function up(): void {
        // Antrean database untuk worker WA (Docker: layanan "worker"); dibuat hanya bila belum ada.
        if (!Schema::hasTable('jobs')) Schema::create('jobs', function (Blueprint $t) {
            $t->id(); $t->string('queue')->index(); $t->longText('payload'); $t->unsignedTinyInteger('attempts');
            $t->unsignedInteger('reserved_at')->nullable(); $t->unsignedInteger('available_at'); $t->unsignedInteger('created_at');
        });
        if (!Schema::hasTable('failed_jobs')) Schema::create('failed_jobs', function (Blueprint $t) {
            $t->id(); $t->string('uuid')->unique(); $t->text('connection'); $t->text('queue'); $t->longText('payload'); $t->longText('exception'); $t->timestamp('failed_at')->useCurrent();
        });
        Schema::create('wa_bot_settings', function (Blueprint $t) {
            $t->id(); $t->foreignId('business_id')->constrained()->restrictOnDelete(); $t->foreignId('outlet_id')->constrained()->restrictOnDelete();
            $t->boolean('quick_enabled')->default(true);
            $t->boolean('ai_enabled')->default(false); $t->string('ai_name', 60)->default('Asisten Laundry');
            $t->text('ai_instructions')->nullable(); $t->text('knowledge')->nullable();
            $t->boolean('ai_prices')->default(true); $t->boolean('ai_status')->default(true);
            $t->unsignedSmallInteger('takeover_minutes')->default(30);
            $t->boolean('auto_nota')->default(false); $t->boolean('auto_ready')->default(false); $t->boolean('auto_late')->default(false);
            $t->unsignedTinyInteger('late_days')->default(3);
            $t->string('quiet_from', 5)->default('21:00'); $t->string('quiet_until', 5)->default('07:00');
            $t->unsignedInteger('version')->default(1); $t->timestamps();
            $t->unique(['business_id', 'outlet_id']);
        });
        Schema::create('wa_media', function (Blueprint $t) {
            $t->uuid('id')->primary(); $t->foreignId('business_id')->constrained()->restrictOnDelete(); $t->foreignId('outlet_id')->constrained()->restrictOnDelete();
            $t->string('name', 80); $t->string('kind', 10); $t->string('mime', 40); $t->string('path', 200);
            $t->unsignedInteger('bytes'); $t->string('sha256', 64); $t->unsignedInteger('version')->default(1); $t->timestamps();
            $t->index(['business_id', 'outlet_id']);
        });
        Schema::create('wa_quick_replies', function (Blueprint $t) {
            $t->uuid('id')->primary(); $t->foreignId('business_id')->constrained()->restrictOnDelete(); $t->foreignId('outlet_id')->constrained()->restrictOnDelete();
            $t->string('name', 80); $t->string('keys', 500); $t->string('mode', 10)->default('contains'); $t->text('reply')->nullable();
            $t->uuid('media_id')->nullable(); $t->boolean('enabled')->default(true); $t->unsignedSmallInteger('position')->default(0);
            $t->timestamps(); $t->index(['business_id', 'outlet_id']);
        });
        Schema::create('wa_takeovers', function (Blueprint $t) {
            $t->uuid('device_id'); $t->string('contact', 64); $t->timestamp('until')->nullable(); $t->boolean('manual')->default(false);
            $t->primary(['device_id', 'contact']);
        });
        Schema::create('wa_chat_log', function (Blueprint $t) {
            $t->id(); $t->uuid('device_id'); $t->string('contact', 64); $t->string('from', 10); $t->text('text'); $t->timestamp('created_at');
            $t->index(['device_id', 'contact', 'id']); $t->index('created_at');
        });
        Schema::create('wa_auto_sent', function (Blueprint $t) {
            $t->id(); $t->foreignId('business_id')->constrained()->restrictOnDelete(); $t->string('record_key', 160); $t->string('kind', 10);
            $t->string('state', 12)->default('queued'); $t->timestamp('created_at');
            $t->unique(['business_id', 'record_key', 'kind']);
        });
        Schema::create('wa_optouts', function (Blueprint $t) {
            $t->id(); $t->foreignId('business_id')->constrained()->restrictOnDelete(); $t->string('contact', 64); $t->string('kind', 10)->default('promo');
            $t->timestamp('created_at'); $t->unique(['business_id', 'contact', 'kind']);
        });
        Schema::create('wa_blasts', function (Blueprint $t) {
            $t->uuid('id')->primary(); $t->foreignId('business_id')->constrained()->restrictOnDelete(); $t->foreignId('outlet_id')->constrained()->restrictOnDelete();
            $t->uuid('device_id'); $t->string('name', 80); $t->text('body'); $t->uuid('media_id')->nullable();
            $t->string('status', 16)->default('queued'); $t->string('reason', 200)->nullable();
            $t->unsignedInteger('total')->default(0); $t->unsignedInteger('sent')->default(0); $t->unsignedInteger('failed')->default(0); $t->unsignedInteger('skipped')->default(0);
            $t->timestamp('schedule_at')->nullable(); $t->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete(); $t->timestamps();
            $t->index(['business_id', 'created_at']);
        });
        Schema::create('wa_blast_recipients', function (Blueprint $t) {
            $t->id(); $t->uuid('blast_id'); $t->string('contact', 64); $t->string('masked', 20); $t->string('name', 80)->nullable();
            $t->string('status', 12)->default('queued'); $t->string('error', 120)->nullable(); $t->timestamp('updated_at')->nullable();
            $t->unique(['blast_id', 'contact']);
        });
        Schema::table('wa_outbox', function (Blueprint $t) { $t->uuid('media_id')->nullable(); $t->string('delivery', 12)->nullable(); });
        Schema::table('wa_devices', function (Blueprint $t) { $t->string('status_note', 120)->nullable(); });
        Schema::create('wa_qris_watch', function (Blueprint $t) {
            $t->foreignId('business_id')->primary()->constrained()->restrictOnDelete(); $t->string('hash', 64)->nullable();
            $t->string('merchant', 120)->nullable(); $t->string('nmid', 40)->nullable(); $t->timestamp('changed_at')->nullable(); $t->timestamp('checked_at')->nullable();
        });
    }
    public function down(): void {
        Schema::table('wa_devices', fn (Blueprint $t) => $t->dropColumn('status_note'));
        Schema::table('wa_outbox', fn (Blueprint $t) => $t->dropColumn(['media_id', 'delivery']));
        foreach (['wa_qris_watch', 'wa_blast_recipients', 'wa_blasts', 'wa_optouts', 'wa_auto_sent', 'wa_chat_log', 'wa_takeovers', 'wa_quick_replies', 'wa_media', 'wa_bot_settings'] as $table) Schema::dropIfExists($table);
    }
};
