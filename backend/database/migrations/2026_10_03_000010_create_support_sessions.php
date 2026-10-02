<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
/** Mode Bantuan (§46): owner mengizinkan CS/admin mengubah pengaturan dari server selama 30 menit. */
return new class extends Migration {
    public function up(): void {
        Schema::create('support_sessions', function (Blueprint $t) {
            $t->id();
            $t->foreignId('business_id')->constrained()->restrictOnDelete();
            $t->foreignId('granted_by')->constrained('users')->restrictOnDelete();
            $t->timestamp('expires_at');
            $t->timestamp('revoked_at')->nullable();
            $t->timestamp('created_at');
            $t->index(['business_id', 'expires_at']);
        });
    }
    public function down(): void { Schema::dropIfExists('support_sessions'); }
};
