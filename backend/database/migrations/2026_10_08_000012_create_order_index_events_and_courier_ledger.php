<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Pesanan tetap disinkronkan utuh (sync_records). Tabel di sini adalah catatan milik server
 * yang diisi setiap kali pesanan diterima, supaya monitoring owner tidak perlu membaca seluruh
 * isi pesanan dan supaya riwayat "siapa mengerjakan apa" tidak bisa diubah dari HP.
 */
return new class extends Migration {
    public function up(): void {
        Schema::create('order_index', function (Blueprint $t) {
            $t->id();
            $t->foreignId('business_id')->constrained()->restrictOnDelete();
            $t->foreignId('outlet_id')->constrained()->restrictOnDelete();
            $t->string('record_key', 160);
            $t->string('status', 20);
            $t->unsignedBigInteger('total')->default(0);
            $t->unsignedBigInteger('paid')->default(0);
            $t->unsignedBigInteger('discount')->default(0);
            $t->boolean('delivery')->default(false);          // pesanan diantar ke pelanggan
            $t->string('customer', 160)->nullable();
            $t->string('customer_key', 160)->nullable();      // sama dengan kunci sinkron pelanggan (phone:62… / name:…)
            $t->string('courier_key', 160)->nullable();       // kurir yang ditunjuk
            $t->foreignId('created_by')->nullable()->constrained('users')->restrictOnDelete();
            $t->string('created_role', 20)->nullable();
            // Kurir menimbang di lokasi: kasir memastikan timbangan saat memproses.
            $t->string('weigh_status', 12)->nullable();       // pending | confirmed
            $t->foreignId('weigh_by')->nullable()->constrained('users')->restrictOnDelete();
            $t->timestamp('ordered_at')->nullable();
            $t->timestamp('due_at')->nullable();
            $t->timestamp('ready_at')->nullable();            // saat menjadi Siap Ambil
            $t->boolean('deleted')->default(false);
            $t->timestamps();
            $t->unique(['business_id', 'record_key']);
            $t->index(['business_id', 'outlet_id', 'status']);
            $t->index(['business_id', 'ordered_at']);
        });

        Schema::create('order_events', function (Blueprint $t) {
            $t->id();
            $t->foreignId('business_id')->constrained()->restrictOnDelete();
            $t->foreignId('outlet_id')->constrained()->restrictOnDelete();
            $t->string('record_key', 160);
            $t->unsignedSmallInteger('item_index')->nullable(); // null = seluruh nota, angka = barang ke-n
            // maju | lompat | mundur | batal | timbang | bayar | buat
            $t->string('kind', 12);
            $t->string('from_status', 20)->nullable();
            $t->string('to_status', 20)->nullable();
            $t->json('details')->nullable();                    // tahap yang dilewati, berat sebelum/sesudah, alasan, nominal
            $t->foreignId('user_id')->nullable()->constrained()->restrictOnDelete();
            $t->string('role', 20)->nullable();
            $t->string('device_uuid', 64)->nullable();
            $t->timestamp('created_at');
            $t->index(['business_id', 'created_at']);
            $t->index(['business_id', 'record_key']);
            $t->index(['business_id', 'user_id', 'kind']);
        });

        // Tunai yang diterima kurir di lokasi dicatat "dipegang kurir" sampai disetor dan dikonfirmasi kasir.
        Schema::create('courier_ledger', function (Blueprint $t) {
            $t->id();
            $t->foreignId('business_id')->constrained()->restrictOnDelete();
            $t->foreignId('outlet_id')->constrained()->restrictOnDelete();
            $t->foreignId('courier_id')->constrained('users')->restrictOnDelete();
            $t->string('type', 10);                             // collect (+) | deposit (-)
            $t->bigInteger('amount');                           // collect: tunai diterima; deposit: tunai yang diterima kasir
            $t->bigInteger('expected')->nullable();             // deposit: saldo yang seharusnya disetor
            $t->string('record_key', 160)->nullable();          // collect: nomor nota
            $t->foreignId('confirmed_by')->nullable()->constrained('users')->restrictOnDelete();
            $t->string('note', 300)->nullable();
            $t->timestamp('created_at');
            $t->index(['business_id', 'courier_id', 'created_at']);
        });
    }

    public function down(): void {
        foreach (['courier_ledger', 'order_events', 'order_index'] as $table) Schema::dropIfExists($table);
    }
};
