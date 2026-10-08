<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
return new class extends Migration {
    public function up(): void {
        Schema::create('wa_devices', function (Blueprint $t) {
            $t->uuid('id')->primary(); $t->foreignId('business_id')->constrained()->restrictOnDelete();
            $t->foreignId('outlet_id')->constrained()->restrictOnDelete(); $t->string('name', 80); $t->string('phone', 15);
            $t->string('remote_id')->nullable()->unique(); $t->string('status', 20)->default('disconnected');
            $t->boolean('reply_status')->default(false); $t->boolean('reply_services')->default(false);
            $t->unsignedInteger('version')->default(1); $t->timestamp('status_checked_at')->nullable(); $t->timestamps();
            $t->unique(['business_id', 'phone']); $t->index(['business_id', 'outlet_id']);
        });
        Schema::create('wa_slot_grants', function (Blueprint $t) {
            $t->id(); $t->foreignId('business_id')->constrained()->restrictOnDelete();
            $t->string('payment_reference')->unique(); $t->unsignedInteger('slots');
            $t->timestamp('starts_at'); $t->timestamp('ends_at'); $t->timestamp('revoked_at')->nullable(); $t->timestamps();
        });
        Schema::create('wa_templates', function (Blueprint $t) {
            $t->id(); $t->string('key', 80)->unique(); $t->string('purpose', 40); $t->string('name', 100);
            $t->text('body'); $t->boolean('active')->default(false); $t->boolean('ai_draft')->default(false);
            $t->unsignedInteger('version')->default(1); $t->foreignId('reviewed_by')->nullable()->constrained('users'); $t->timestamps();
        });
        Schema::create('wa_template_revisions', function (Blueprint $t) {
            $t->id(); $t->foreignId('template_id')->constrained('wa_templates'); $t->unsignedInteger('version');
            $t->foreignId('actor_id')->constrained('users'); $t->text('body'); $t->boolean('active'); $t->timestamps();
            $t->unique(['template_id', 'version']);
        });
        Schema::create('wa_events', function (Blueprint $t) {
            $t->id(); $t->uuid('device_id'); $t->string('provider_id', 160); $t->string('state', 20);
            $t->timestamps(); $t->unique(['device_id', 'provider_id']);
        });
        Schema::create('wa_outbox', function (Blueprint $t) {
            $t->id(); $t->foreignId('event_id')->unique()->constrained('wa_events'); $t->uuid('device_id');
            $t->unsignedInteger('device_version'); $t->string('feature', 30); $t->text('recipient'); $t->text('body'); // encrypted by application
            $t->string('state', 20)->default('pending'); $t->string('provider_receipt')->nullable();
            $t->unsignedInteger('attempts')->default(0); $t->timestamp('lease_until')->nullable(); $t->timestamps();
        });
        Schema::create('wa_unknown_topics', function (Blueprint $t) {
            $t->id(); $t->date('day'); $t->string('topic', 40); $t->unsignedInteger('count')->default(0);
            $t->unique(['day', 'topic']); // no raw message, phone, name, tenant ID, or order data
        });
        if (Schema::hasTable('order_index')) Schema::table('order_index', fn (Blueprint $t) => $t->index(['business_id', 'outlet_id', 'customer_key'], 'wa_order_customer_lookup'));
    }
    public function down(): void {
        if (Schema::hasTable('order_index')) Schema::table('order_index', fn (Blueprint $t) => $t->dropIndex('wa_order_customer_lookup'));
        foreach (['wa_unknown_topics','wa_outbox','wa_events','wa_template_revisions','wa_templates','wa_slot_grants','wa_devices'] as $table) Schema::dropIfExists($table);
    }
};
