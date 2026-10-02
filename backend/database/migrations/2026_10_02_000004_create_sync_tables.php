<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/** Offline-first sync between the Android app (local storage) and the central server. */
return new class extends Migration {
    public function up(): void {
        Schema::create('sync_records', function (Blueprint $t) {
            $t->id();
            $t->foreignId('business_id')->constrained()->restrictOnDelete();
            $t->foreignId('outlet_id')->nullable()->constrained()->restrictOnDelete();
            $t->string('collection', 40);
            $t->string('record_key', 160);
            $t->longText('data')->nullable(); // JSON, null when deleted
            $t->boolean('deleted')->default(false);
            $t->unsignedBigInteger('rev'); // per-business change sequence, used as pull cursor
            $t->foreignId('updated_by')->nullable()->constrained('users')->restrictOnDelete();
            $t->string('device_uuid', 64)->nullable();
            $t->timestamps();
            $t->unique(['business_id', 'collection', 'record_key']);
            $t->index(['business_id', 'rev']);
            $t->index(['business_id', 'collection', 'outlet_id']);
        });
        Schema::create('sync_ops', function (Blueprint $t) {
            $t->id();
            $t->foreignId('business_id')->constrained()->restrictOnDelete();
            $t->string('op_id', 64);
            $t->json('result');
            $t->timestamp('created_at');
            $t->unique(['business_id', 'op_id']);
        });
        Schema::create('sync_conflicts', function (Blueprint $t) {
            $t->id();
            $t->foreignId('business_id')->constrained()->restrictOnDelete();
            $t->string('collection', 40);
            $t->string('record_key', 160);
            $t->longText('losing_data')->nullable();
            $t->foreignId('user_id')->nullable()->constrained()->restrictOnDelete();
            $t->string('device_uuid', 64)->nullable();
            $t->timestamp('created_at');
            $t->index(['business_id', 'created_at']);
        });
        Schema::table('cashier_devices', function (Blueprint $t) {
            $t->string('device_uuid', 64)->nullable()->after('label');
            $t->foreignId('user_id')->nullable()->after('device_uuid')->constrained()->restrictOnDelete();
            $t->timestamp('last_seen_at')->nullable();
            $t->unique(['outlet_id', 'device_uuid']);
        });
    }

    public function down(): void {
        Schema::table('cashier_devices', function (Blueprint $t) {
            $t->dropUnique(['outlet_id', 'device_uuid']);
            $t->dropConstrainedForeignId('user_id');
            $t->dropColumn(['device_uuid', 'last_seen_at']);
        });
        Schema::dropIfExists('sync_conflicts');
        Schema::dropIfExists('sync_ops');
        Schema::dropIfExists('sync_records');
    }
};
