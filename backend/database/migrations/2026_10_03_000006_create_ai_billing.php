<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
/** Saldo AI klien dalam Rupiah: top-up, potong per pemakaian dengan kurs & harga model harian (GOYANA-SISTEM-PUSAT.md §44). */
return new class extends Migration {
    public function up(): void {
        Schema::table('businesses', function (Blueprint $t) {
            $t->bigInteger('ai_balance')->default(0); // rupiah, never negative (enforced in AiBilling)
        });
        Schema::create('ai_ledger', function (Blueprint $t) {
            $t->id();
            $t->foreignId('business_id')->constrained()->restrictOnDelete();
            $t->string('type', 12); // topup | usage | adjust
            $t->bigInteger('amount'); // rupiah, + top-up / - usage
            $t->bigInteger('balance_after');
            $t->string('reference', 120)->nullable();
            $t->string('model', 120)->nullable();
            $t->decimal('cost_usd', 14, 8)->nullable();
            $t->decimal('fx_rate', 12, 2)->nullable();
            $t->json('meta')->nullable();
            $t->foreignId('actor_id')->nullable()->constrained('users')->restrictOnDelete();
            $t->timestamp('created_at');
            $t->index(['business_id', 'id']);
            $t->unique(['business_id', 'type', 'reference']);
        });
        Schema::create('fx_rates', function (Blueprint $t) {
            $t->id();
            $t->string('currency', 3);
            $t->date('day');
            $t->decimal('rate', 12, 2); // rupiah per 1 unit
            $t->string('source', 60);
            $t->timestamp('created_at');
            $t->unique(['currency', 'day']);
        });
        Schema::create('ai_models', function (Blueprint $t) {
            $t->string('id', 120)->primary(); // OpenRouter model id
            $t->string('name', 200);
            $t->decimal('prompt_usd_per_mtok', 12, 4);
            $t->decimal('completion_usd_per_mtok', 12, 4);
            $t->boolean('available')->default(true);
            $t->timestamp('updated_at');
        });
    }
    public function down(): void {
        Schema::dropIfExists('ai_models');
        Schema::dropIfExists('fx_rates');
        Schema::dropIfExists('ai_ledger');
        Schema::table('businesses', fn (Blueprint $t) => $t->dropColumn('ai_balance'));
    }
};
