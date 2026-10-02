<?php
namespace Tests\Feature;

use App\Models\{Business, User};
use App\Support\QuickReply;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class QuickReplyTest extends TestCase {
    use RefreshDatabase;

    private Business $b;

    private function rec(string $c, string $key, array $data): void {
        static $rev = 0;
        DB::table('sync_records')->insert(['business_id' => $this->b->id, 'collection' => $c, 'record_key' => $key, 'data' => json_encode($data), 'rev' => ++$rev, 'created_at' => now(), 'updated_at' => now()]);
    }
    private function order(string $id, string $name, string $st, int $total, int $paid, string $created): void {
        $this->rec('orders', $id, ['card' => ['dataset' => ['st' => $st, 'paid177' => (string) $paid, 'created177' => $created], 'fields' => [['Reguler'], [$id], [$name]], 'total' => $total],
            'detail' => ['id' => $id, 'name' => $name, 'items' => [['n' => 'Cuci Baju', 'unit' => 'kg', 'qty' => 3]], 'due' => '2026-10-05T10:00:00Z']]);
    }

    protected function setUp(): void {
        parent::setUp();
        $this->b = Business::create(['name' => 'Laundry Wangi', 'trial_ends_at' => now()->addMonth()]);
        $this->rec('customers', 'sari', ['name' => 'Sari Dewi', 'phone' => '0812-0000-0002 · Jakarta']);
        $this->rec('customers', 'budi', ['name' => 'Budi', 'phone' => '081200000001']);
        $this->order('GY-1', 'Sari Dewi', 'siap', 31500, 0, '2026-10-02T10:00:00Z');
        $this->order('GY-2', 'Sari Dewi', 'proses', 20000, 20000, '2026-10-03T10:00:00Z');
        $this->order('GY-3', 'Sari Dewi', 'diambil', 10000, 10000, '2026-09-01T10:00:00Z');
        $this->order('GY-4', 'Budi', 'antrian', 99000, 0, '2026-10-03T10:00:00Z');
        $this->rec('services', 'cuci baju', ['name' => 'Cuci Baju', 'unit' => 'kg', 'prices' => ['Reguler' => 7000, 'Express' => 10500, 'Kilat' => 0], 'enabled' => ['Reguler' => true, 'Express' => true, 'Kilat' => false]]);
        $this->rec('outlet_profiles', 'srv-1', ['name' => 'Laundry Wangi Pusat', 'address' => 'Jl. Melati 5, Bekasi', 'phone' => '0219999']);
    }

    public function test_status_and_bill_only_show_the_senders_own_active_orders(): void {
        $r = QuickReply::answer($this->b, '+62 812-0000-0002', 'Mas baju saya sudah jadi belum?');
        $this->assertSame(['status', 'Sari Dewi'], [$r['intent'], $r['customer']]);
        $this->assertStringContainsString('GY-1', $r['reply']);
        $this->assertStringContainsString('Siap diambil', $r['reply']);
        $this->assertStringContainsString('GY-2', $r['reply']);
        $this->assertStringNotContainsString('GY-3', $r['reply'], 'finished orders are not listed');
        $this->assertStringNotContainsString('GY-4', $r['reply'], 'never another customer\'s order');
        $bill = QuickReply::answer($this->b, '6281200000002', 'total yang harus dibayar berapa?');
        $this->assertStringContainsString('sisa Rp31.500', $bill['reply']);
        $this->assertStringContainsString('lunas', $bill['reply']);
        $this->assertStringContainsString('Total belum dibayar: *Rp31.500*', $bill['reply']);
    }

    public function test_general_questions_and_unknown_numbers(): void {
        $price = QuickReply::answer($this->b, '0899', 'harga kiloan berapa ya');
        $this->assertSame('price', $price['intent']);
        $this->assertStringContainsString('Cuci Baju: Reguler Rp7.000 · Express Rp10.500 /kg', $price['reply']);
        $this->assertStringNotContainsString('Kilat', $price['reply'], 'disabled durations are hidden');
        $this->assertStringContainsString('Jl. Melati 5', QuickReply::answer($this->b, '0899', 'alamatnya dimana kak')['reply']);
        $unknown = QuickReply::answer($this->b, '089911112222', 'cucian saya sudah selesai?');
        $this->assertNull($unknown['customer']);
        $this->assertStringContainsString('belum terdaftar', $unknown['reply']);
        $this->assertStringNotContainsString('GY-', $unknown['reply']);
        $this->assertNull(QuickReply::answer($this->b, '6281200000002', 'mau tanya kerja sama')['reply'], 'no match goes to a human / AI');
    }

    public function test_admin_simulator(): void {
        $admin = new User(['name' => 'Admin', 'email' => 'a@x.test', 'password' => 'PasswordAman123']); $admin->is_platform_admin = true; $admin->save();
        $this->actingAsAdmin($admin)->post('/admin/businesses/'.$this->b->id.'/quick-reply-test', ['from' => '6281200000002', 'text' => 'sudah jadi?'])
            ->assertRedirect()->assertSessionHas('qr', fn ($r) => $r['customer'] === 'Sari Dewi');
        $this->get('/admin/businesses/'.$this->b->id)->assertSee('Uji Balasan Cepat WhatsApp');
    }
}
