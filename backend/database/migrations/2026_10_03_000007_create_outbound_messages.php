<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
/** Pesan otomatis ke klien (§42B, hemat). Satu baris per pesan; dedupe_key menjamin tiap pesan hanya sekali. */
return new class extends Migration {
    public function up(): void {
        Schema::create('outbound_messages', function (Blueprint $t) {
            $t->id();
            $t->foreignId('business_id')->constrained()->restrictOnDelete();
            $t->string('kind', 30); // welcome | expiry_reminder | expired | payment
            $t->string('dedupe_key', 120)->unique();
            $t->string('channel', 12); // email | whatsapp (setelah CHATKU)
            $t->string('recipient', 254);
            $t->string('subject', 200);
            $t->text('body');
            $t->string('status', 12); // sent | failed
            $t->string('error', 300)->nullable();
            $t->timestamp('created_at');
            $t->index(['business_id', 'id']);
        });
    }
    public function down(): void { Schema::dropIfExists('outbound_messages'); }
};
