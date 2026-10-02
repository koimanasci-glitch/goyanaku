<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
return new class extends Migration {
    public function up(): void {
        Schema::create('businesses', function (Blueprint $t) {
            $t->id(); $t->string('name'); $t->timestamp('trial_ends_at'); $t->timestamps();
        });
        Schema::create('users', function (Blueprint $t) {
            $t->id(); $t->foreignId('business_id')->nullable()->constrained()->restrictOnDelete();
            $t->string('name'); $t->string('email')->unique(); $t->string('password');
            $t->boolean('is_platform_admin')->default(false);
            $t->timestamp('email_verified_at')->nullable(); $t->rememberToken(); $t->timestamps();
        });
        Schema::create('outlets', function (Blueprint $t) {
            $t->id(); $t->foreignId('business_id')->constrained()->restrictOnDelete();
            $t->string('name'); $t->timestamps();
        });
        Schema::create('package_grants', function (Blueprint $t) {
            $t->id(); $t->foreignId('business_id')->constrained()->restrictOnDelete();
            $t->foreignId('granted_by')->constrained('users')->restrictOnDelete();
            $t->string('package'); $t->string('reason', 500);
            $t->timestamp('starts_at'); $t->timestamp('ends_at'); $t->timestamp('revoked_at')->nullable(); $t->timestamps();
            $t->index(['business_id', 'ends_at']);
        });
        Schema::create('cashier_devices', function (Blueprint $t) {
            $t->id(); $t->foreignId('outlet_id')->constrained()->restrictOnDelete();
            $t->string('label'); $t->unsignedTinyInteger('slot')->nullable(); $t->timestamp('revoked_at')->nullable(); $t->timestamps();
            $t->unique(['outlet_id', 'slot']);
        });
        Schema::create('audit_events', function (Blueprint $t) {
            $t->id(); $t->foreignId('actor_id')->constrained('users')->restrictOnDelete();
            $t->foreignId('business_id')->constrained()->restrictOnDelete();
            $t->string('action'); $t->json('details'); $t->timestamp('created_at');
        });
    }
    public function down(): void {
        foreach (['audit_events', 'cashier_devices', 'package_grants', 'outlets', 'users', 'businesses'] as $table) Schema::dropIfExists($table);
    }
};
