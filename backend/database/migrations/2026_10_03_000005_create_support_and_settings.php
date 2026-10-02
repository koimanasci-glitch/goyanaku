<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
/** CS tickets (base for AI CS, GOYANA-SISTEM-PUSAT.md §42) and platform settings editable by the administrator. */
return new class extends Migration {
    public function up(): void {
        Schema::create('tickets', function (Blueprint $t) {
            $t->id();
            $t->foreignId('business_id')->nullable()->constrained()->restrictOnDelete();
            $t->foreignId('user_id')->nullable()->constrained()->restrictOnDelete();
            $t->string('subject', 160);
            $t->string('category', 30)->default('lainnya');
            $t->string('status', 20)->default('open'); // open | answered | closed
            $t->string('priority', 10)->default('normal'); // normal | high
            $t->string('source', 20)->default('web'); // web | app | wa | ai | admin
            $t->timestamp('last_activity_at');
            $t->timestamp('closed_at')->nullable();
            $t->timestamps();
            $t->index(['status', 'last_activity_at']);
            $t->index(['business_id', 'last_activity_at']);
        });
        Schema::create('ticket_messages', function (Blueprint $t) {
            $t->id();
            $t->foreignId('ticket_id')->constrained()->cascadeOnDelete();
            $t->foreignId('author_id')->nullable()->constrained('users')->restrictOnDelete();
            $t->string('author_type', 12); // customer | admin | ai | system
            $t->text('body');
            $t->boolean('internal')->default(false); // admin-only note
            $t->timestamp('created_at');
            $t->index(['ticket_id', 'id']);
        });
        Schema::create('platform_settings', function (Blueprint $t) {
            $t->string('key', 60)->primary();
            $t->json('value');
            $t->foreignId('updated_by')->nullable()->constrained('users')->restrictOnDelete();
            $t->timestamp('updated_at');
        });
        // Administrator actions that do not belong to one business (settings, etc.).
        Schema::create('platform_audit', function (Blueprint $t) {
            $t->id();
            $t->foreignId('actor_id')->constrained('users')->restrictOnDelete();
            $t->string('action', 60);
            $t->json('details');
            $t->timestamp('created_at');
        });
    }
    public function down(): void {
        Schema::dropIfExists('platform_audit');
        Schema::dropIfExists('platform_settings');
        Schema::dropIfExists('ticket_messages');
        Schema::dropIfExists('tickets');
    }
};
