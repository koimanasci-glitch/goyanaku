<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        // Paid packages. Separate from beta grants so billing history stays auditable.
        Schema::create('subscriptions', function (Blueprint $t) {
            $t->id();
            $t->foreignId('business_id')->constrained()->restrictOnDelete();
            $t->string('package');
            $t->timestamp('starts_at');
            $t->timestamp('ends_at');
            $t->string('source', 30); // manual | google_play | gateway
            $t->string('reference', 120)->nullable();
            $t->unsignedBigInteger('amount')->nullable(); // rupiah
            $t->foreignId('recorded_by')->nullable()->constrained('users')->restrictOnDelete();
            $t->timestamp('cancelled_at')->nullable();
            $t->timestamps();
            $t->index(['business_id', 'ends_at']);
            $t->unique(['source', 'reference']);
        });

        Schema::table('users', function (Blueprint $t) {
            $t->string('role', 20)->default('owner')->after('business_id');
            $t->foreignId('outlet_id')->nullable()->after('role')->constrained()->restrictOnDelete();
            $t->timestamp('deactivated_at')->nullable();
            $t->text('mfa_secret')->nullable();
            $t->timestamp('mfa_confirmed_at')->nullable();
            $t->unsignedBigInteger('mfa_last_step')->nullable();
        });

        Schema::table('audit_events', function (Blueprint $t) {
            $t->index(['business_id', 'created_at']);
        });
    }

    public function down(): void {
        Schema::table('audit_events', fn (Blueprint $t) => $t->dropIndex(['business_id', 'created_at']));
        Schema::table('users', function (Blueprint $t) {
            $t->dropConstrainedForeignId('outlet_id');
            $t->dropColumn(['role', 'deactivated_at', 'mfa_secret', 'mfa_confirmed_at', 'mfa_last_step']);
        });
        Schema::dropIfExists('subscriptions');
    }
};
