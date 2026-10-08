<?php
namespace Tests\Feature;

use App\Models\{Business, User};
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

/** Aturan pesanan per peran yang ditegakkan server (keputusan pengguna 8 Oktober 2026). */
class OrderRulesTest extends TestCase {
    use RefreshDatabase;

    private User $owner;

    protected function setUp(): void {
        parent::setUp();
        $business = Business::create(['name' => 'Laundry', 'trial_ends_at' => now()->addMonth()]);
        $business->outlets()->create(['name' => 'Pusat']);
        $business->outlets()->create(['name' => 'Cabang']);
        $user = new User(['name' => 'Owner', 'email' => uniqid().'@example.test', 'password' => 'PasswordAman123']);
        $user->business()->associate($business); $user->save();
        $this->owner = $user->fresh();
        $all = ['Cuci', 'Kering', 'Setrika', 'Packing'];
        $this->push($this->token($this->owner), [
            ['collection' => 'services', 'key' => 'cuci setrika', 'data' => ['key' => 'cuci setrika', 'name' => 'Cuci Setrika', 'unit' => 'kg', 'prices' => ['Reguler' => 7000, 'Express' => 10500], 'proc' => $all]],
            ['collection' => 'services', 'key' => 'karpet', 'data' => ['key' => 'karpet', 'name' => 'Karpet', 'unit' => 'm', 'prices' => ['Reguler' => 15000], 'proc' => ['Cuci', 'Kering', 'Packing']]],
            ['collection' => 'couriers', 'key' => 'kur-1', 'data' => ['id' => 'kur-1', 'name' => 'Budi', 'phone' => '62811', 'outlets' => [$this->outletKey(0)], 'active' => true]],
            ['collection' => 'couriers', 'key' => 'kur-lama', 'data' => ['id' => 'kur-lama', 'name' => 'Lama', 'phone' => '62812', 'outlets' => [], 'active' => true]],
            ['collection' => 'customers', 'key' => 'phone:628123', 'data' => ['name' => 'Siti', 'phone' => '08123', 'address' => 'Jl. Melati 1', 'maps' => 'https://maps.example/x']],
        ]);
    }

    private function staff(string $role, int $outletIndex = 0, ?string $courierKey = null): User {
        $u = new User(['name' => ucfirst($role), 'email' => $role.uniqid().'@example.test', 'password' => 'PasswordAman123']);
        $u->business_id = $this->owner->business_id; $u->role = $role; $u->courier_key = $courierKey;
        $u->outlet_id = $this->owner->business->outlets()->orderBy('id')->get()[$outletIndex]->id; $u->save();
        return $u->fresh();
    }

    private function token(User $u): string {
        $this->app['auth']->forgetGuards();
        return $this->postJson('/api/session', ['email' => $u->email, 'password' => 'PasswordAman123'])->json('token');
    }

    private function push(string $token, array $changes, string $device = 'device-aaaa-1111') {
        $this->app['auth']->forgetGuards();
        return $this->withToken($token)->postJson('/api/sync/push', ['device_id' => $device, 'changes' => array_map(
            fn ($c) => $c + ['op_id' => (string) Str::uuid()], $changes)]);
    }

    private function pull(string $token) {
        $this->app['auth']->forgetGuards();
        return $this->withToken($token)->getJson('/api/sync/pull?cursor=0');
    }

    private function outletKey(int $i): string { return 'srv-'.$this->owner->business->outlets()->orderBy('id')->get()[$i]->id; }

    /** Pesanan seperti yang dikirim aplikasi. */
    private function order(string $id, array $items, string $st = 'antrian', array $dataset = [], array $detail = []): array {
        $sub = array_sum(array_map(fn ($i) => (int) round($i['qty'] * $i['price']), $items));
        $paid = $detail['paid'] ?? 0;
        return [
            'card' => ['dataset' => $dataset + ['st' => $st, 'created177' => now()->toIso8601String(), 'items' => json_encode($items), 'paid177' => (string) $paid, 'payments178' => '[]', 'method177' => 'Tunai'],
                'fields' => [['Reguler'], [$id], ['Siti'], [], [], []], 'total' => $sub, 'paid' => false],
            'detail' => $detail + ['id' => $id, 'name' => 'Siti', 'phone' => '08123', 'dur' => 'Reguler', 'items' => $items, 'discKey' => '0', 'ongkir' => 0, 'paid' => 0,
                'due' => now()->addDays(3)->toIso8601String(), 'hist' => [['st' => $st, 'at' => now()->toIso8601String(), 'by' => 'Kasir']]],
        ];
    }

    private function baju(float $qty = 2): array { return ['n' => 'Cuci Setrika', 'unit' => 'kg', 'price' => 7000, 'qty' => $qty]; }
    private function karpet(float $qty = 3): array { return ['n' => 'Karpet', 'unit' => 'm', 'price' => 15000, 'qty' => $qty]; }

    private function create(string $id, array $order, int $outlet = 0): int {
        return $this->push($this->token($this->owner), [['collection' => 'orders', 'key' => $id, 'outlet' => $this->outletKey($outlet), 'data' => $order]])
            ->assertJsonPath('results.0.status', 'applied')->json('results.0.rev');
    }

    private function stored(string $id): array {
        return json_decode(DB::table('sync_records')->where('collection', 'orders')->where('record_key', $id)->value('data'), true);
    }

    private function withStatus(array $order, string $st, string $by = 'Pegawai'): array {
        $order['card']['dataset']['st'] = $st;
        $order['detail']['hist'][] = ['st' => $st, 'at' => now()->toIso8601String(), 'by' => $by];
        return $order;
    }

    // ---------- pegawai ----------

    public function test_pegawai_advances_one_stage_but_cannot_change_price_or_payment(): void {
        $order = $this->order('GY-1', [$this->baju()], 'cuci'); $rev = $this->create('GY-1', $order);
        $t = $this->token($this->staff('produksi'));
        $tampered = $this->withStatus($order, 'kering');
        $tampered['card']['total'] = 1; $tampered['detail']['paid'] = 14000; $tampered['card']['dataset']['paid177'] = '14000';
        $tampered['detail']['items'][0]['price'] = 1; $tampered['detail']['discKey'] = 'p100';
        $r = $this->push($t, [['collection' => 'orders', 'key' => 'GY-1', 'data' => $tampered, 'base_rev' => $rev]], 'hp-pegawai-1');
        // Tahapnya diterima, sisanya diabaikan; HP diminta mengambil versi server.
        $r->assertJsonPath('results.0.status', 'conflict')->assertJsonPath('results.0.record.data.card.dataset.st', 'kering');
        $now = $this->stored('GY-1');
        $this->assertSame('kering', $now['card']['dataset']['st']);
        $this->assertSame(14000, $now['card']['total']);
        $this->assertSame(0, $now['detail']['paid']);
        $this->assertSame(7000, $now['detail']['items'][0]['price']);
        $this->assertSame('0', $now['detail']['discKey']);
        $this->assertDatabaseMissing('cashier_devices', ['device_uuid' => 'hp-pegawai-1']);
        $this->assertDatabaseHas('order_events', ['record_key' => 'GY-1', 'kind' => 'maju', 'from_status' => 'cuci', 'to_status' => 'kering', 'role' => 'produksi']);
    }

    public function test_pegawai_cannot_skip_stages_mark_ready_or_create_orders(): void {
        $order = $this->order('GY-2', [$this->baju()], 'cuci'); $rev = $this->create('GY-2', $order);
        $t = $this->token($this->staff('produksi'));
        $this->push($t, [['collection' => 'orders', 'key' => 'GY-2', 'data' => $this->withStatus($order, 'setrika'), 'base_rev' => $rev]])
            ->assertJsonPath('results.0.status', 'conflict')->assertJsonPath('results.0.message', 'Pegawai hanya bisa memajukan satu tahap.');
        $this->push($t, [['collection' => 'orders', 'key' => 'GY-2', 'data' => $this->withStatus($order, 'siap'), 'base_rev' => $rev]])
            ->assertJsonPath('results.0.status', 'conflict')->assertJsonPath('results.0.message', 'Hanya kasir atau owner yang menandai Siap Ambil.');
        $this->assertSame('cuci', $this->stored('GY-2')['card']['dataset']['st']);
        $this->push($t, [['collection' => 'orders', 'key' => 'GY-BARU', 'data' => $this->order('GY-BARU', [$this->baju()])]])->assertJsonPath('results.0.status', 'rejected');
        $this->push($t, [['collection' => 'orders', 'key' => 'GY-2', 'deleted' => true, 'base_rev' => $rev]])->assertJsonPath('results.0.status', 'rejected');
    }

    public function test_stages_follow_the_service_and_end_at_selesai_proses(): void {
        // Karpet: Cuci, Kering, Packing (tanpa Setrika).
        $order = $this->order('GY-3', [$this->karpet()], 'kering'); $rev = $this->create('GY-3', $order);
        $t = $this->token($this->staff('produksi'));
        $order = $this->withStatus($order, 'packing');
        $rev = $this->push($t, [['collection' => 'orders', 'key' => 'GY-3', 'data' => $order, 'base_rev' => $rev]])->assertJsonPath('results.0.status', 'applied')->json('results.0.rev');
        $order = $this->withStatus($order, 'selesaiproses');
        $rev = $this->push($t, [['collection' => 'orders', 'key' => 'GY-3', 'data' => $order, 'base_rev' => $rev]])->assertJsonPath('results.0.status', 'applied')->json('results.0.rev');
        $this->push($t, [['collection' => 'orders', 'key' => 'GY-3', 'data' => $this->withStatus($order, 'siap'), 'base_rev' => $rev]])->assertJsonPath('results.0.status', 'conflict');
        // Kasir yang menandai Siap Ambil.
        $this->push($this->token($this->staff('kasir')), [['collection' => 'orders', 'key' => 'GY-3', 'data' => $this->withStatus($order, 'siap', 'Kasir'), 'base_rev' => $rev]])
            ->assertJsonPath('results.0.status', 'applied');
        $this->assertNotNull(DB::table('order_index')->where('record_key', 'GY-3')->value('ready_at'));
    }

    public function test_pegawai_can_continue_an_order_sitting_on_a_stage_outside_its_service_flow(): void {
        // Aplikasi kasir selalu memulai proses di "cuci". Karpet di tahap "setrika" (di luar alurnya) tetap bisa dilanjutkan ke Packing.
        $order = $this->order('GY-8', [$this->karpet()], 'setrika'); $rev = $this->create('GY-8', $order);
        $t = $this->token($this->staff('produksi'));
        $this->push($t, [['collection' => 'orders', 'key' => 'GY-8', 'data' => $this->withStatus($order, 'selesaiproses'), 'base_rev' => $rev]])
            ->assertJsonPath('results.0.status', 'conflict')->assertJsonPath('results.0.message', 'Pegawai hanya bisa memajukan satu tahap.');
        $this->push($t, [['collection' => 'orders', 'key' => 'GY-8', 'data' => $this->withStatus($order, 'packing'), 'base_rev' => $rev]])
            ->assertJsonPath('results.0.status', 'applied');
        $this->assertSame('packing', $this->stored('GY-8')['card']['dataset']['st']);
    }

    public function test_kasir_may_skip_and_skipped_stages_are_recorded(): void {
        $order = $this->order('GY-4', [$this->baju()], 'cuci'); $rev = $this->create('GY-4', $order);
        $kasir = $this->staff('kasir');
        $this->push($this->token($kasir), [['collection' => 'orders', 'key' => 'GY-4', 'data' => $this->withStatus($order, 'diambil', 'Kasir'), 'base_rev' => $rev]])
            ->assertJsonPath('results.0.status', 'applied');
        $event = DB::table('order_events')->where('record_key', 'GY-4')->where('kind', 'lompat')->first();
        $this->assertSame($kasir->id, (int) $event->user_id);
        $this->assertSame(['kering', 'setrika', 'packing'], json_decode($event->details, true)['skipped']);
    }

    public function test_automatic_status_from_a_restricted_phone_is_ignored_without_bouncing(): void {
        $order = $this->order('GY-5', [$this->baju()], 'packing'); $rev = $this->create('GY-5', $order);
        $t = $this->token($this->staff('produksi'));
        $r = $this->push($t, [['collection' => 'orders', 'key' => 'GY-5', 'data' => $this->withStatus($order, 'siap', 'Otomatis'), 'base_rev' => $rev]]);
        $r->assertJsonPath('results.0.status', 'applied')->assertJsonPath('results.0.rev', $rev);
        $this->assertSame('packing', $this->stored('GY-5')['card']['dataset']['st']);
    }

    public function test_pegawai_does_not_receive_prices_payments_or_customer_phone(): void {
        $this->create('GY-6', $this->order('GY-6', [$this->baju()], 'cuci'));
        $records = collect($this->pull($this->token($this->staff('produksi')))->json('records'));
        $this->assertFalse($records->pluck('collection')->contains('customers'));
        $data = $records->firstWhere('key', 'GY-6')['data'];
        $this->assertArrayNotHasKey('total', $data['card']);
        $this->assertArrayNotHasKey('phone', $data['detail']);
        $this->assertArrayNotHasKey('price', $data['detail']['items'][0]);
        $this->assertSame('Cuci Setrika', $data['detail']['items'][0]['n']);
        $this->assertSame('cuci', $data['card']['dataset']['st']);
    }

    public function test_item_stage_is_stored_per_item(): void {
        $order = $this->order('GY-7', [$this->baju(), $this->karpet()], 'cuci'); $rev = $this->create('GY-7', $order);
        $order['detail']['items'][0]['st'] = 'cuci'; $order['detail']['items'][1]['st'] = 'setrika'; // karpet tidak punya tahap setrika
        $this->push($this->token($this->staff('produksi')), [['collection' => 'orders', 'key' => 'GY-7', 'data' => $order, 'base_rev' => $rev]]);
        $items = $this->stored('GY-7')['detail']['items'];
        $this->assertSame('cuci', $items[0]['st']);
        $this->assertArrayNotHasKey('st', $items[1]);
        $this->assertDatabaseHas('order_events', ['record_key' => 'GY-7', 'item_index' => 0, 'to_status' => 'cuci']);
    }

    // ---------- kurir ----------

    public function test_kurir_only_receives_own_tasks_with_customer_address(): void {
        $this->create('GY-A', $this->order('GY-A', [$this->baju()], 'jemput', ['courier181' => 'kur-1', 'antar' => '1']));
        $this->create('GY-B', $this->order('GY-B', [$this->baju()], 'antrian'));
        $records = collect($this->pull($this->token($this->staff('kurir', 0, 'kur-1')))->json('records'));
        $this->assertFalse($records->pluck('collection')->contains('customers'));
        $mine = $records->firstWhere('key', 'GY-A');
        $this->assertSame('Jl. Melati 1', $mine['data']['detail']['address']);
        $this->assertSame(14000, $mine['data']['card']['total']);
        $other = $records->firstWhere('key', 'GY-B');
        $this->assertTrue($other['deleted']); $this->assertNull($other['data']);
    }

    public function test_kurir_cannot_touch_tasks_of_others_or_change_price(): void {
        $order = $this->order('GY-C', [$this->baju()], 'diantar', ['courier181' => 'kur-1', 'antar' => '1']); $rev = $this->create('GY-C', $order);
        $other = $this->order('GY-D', [$this->baju()], 'diantar', ['courier181' => 'kur-9', 'antar' => '1']); $revD = $this->create('GY-D', $other);
        $t = $this->token($this->staff('kurir', 0, 'kur-1'));
        $this->push($t, [['collection' => 'orders', 'key' => 'GY-D', 'data' => $this->withStatus($other, 'diambil'), 'base_rev' => $revD]])
            ->assertJsonPath('results.0.status', 'rejected')->assertJsonPath('results.0.message', 'Tugas ini bukan milik Anda.');
        $cheap = $this->withStatus($order, 'diambil'); $cheap['card']['total'] = 100; $cheap['detail']['items'][0]['price'] = 50; $cheap['detail']['discKey'] = 'p50';
        $this->push($t, [['collection' => 'orders', 'key' => 'GY-C', 'data' => $cheap, 'base_rev' => $rev]])->assertJsonPath('results.0.status', 'conflict');
        $now = $this->stored('GY-C');
        $this->assertSame(['diambil', 14000, 7000, '0'], [$now['card']['dataset']['st'], $now['card']['total'], $now['detail']['items'][0]['price'], $now['detail']['discKey']]);
    }

    public function test_kurir_collects_cash_on_delivery_and_it_is_held_until_deposited(): void {
        $order = $this->order('GY-E', [$this->baju()], 'diantar', ['courier181' => 'kur-1', 'antar' => '1']); $rev = $this->create('GY-E', $order);
        $kurir = $this->staff('kurir', 0, 'kur-1'); $t = $this->token($kurir);
        $paid = $this->withStatus($order, 'diambil');
        $paid['detail']['paid'] = 14000; $paid['card']['dataset']['paid177'] = '14000'; $paid['card']['paid'] = true;
        $paid['card']['dataset']['payments178'] = json_encode([['m' => 'Tunai', 'a' => 14000, 'at' => now()->toIso8601String()]]);
        $this->push($t, [['collection' => 'orders', 'key' => 'GY-E', 'data' => $paid, 'base_rev' => $rev]])->assertJsonPath('results.0.status', 'applied');
        $this->assertSame(14000, $this->stored('GY-E')['detail']['paid']);
        $this->assertDatabaseHas('courier_ledger', ['courier_id' => $kurir->id, 'type' => 'collect', 'amount' => 14000, 'record_key' => 'GY-E']);
        $this->assertSame(14000, (int) DB::table('order_index')->where('record_key', 'GY-E')->value('paid'));
    }

    public function test_kurir_cannot_overpay_or_rewrite_payment_history(): void {
        $order = $this->order('GY-F', [$this->baju()], 'diantar', ['courier181' => 'kur-1', 'antar' => '1']); $rev = $this->create('GY-F', $order);
        $over = $order; $over['detail']['paid'] = 99000; $over['card']['dataset']['paid177'] = '99000';
        $this->push($this->token($this->staff('kurir', 0, 'kur-1')), [['collection' => 'orders', 'key' => 'GY-F', 'data' => $over, 'base_rev' => $rev]])
            ->assertJsonPath('results.0.status', 'conflict')->assertJsonPath('results.0.message', 'Pembayaran tidak sesuai tagihan pesanan.');
        $this->assertSame(0, $this->stored('GY-F')['detail']['paid']);
        $this->assertDatabaseCount('courier_ledger', 0);
    }

    public function test_kurir_creates_pickup_transaction_only_with_list_prices_and_kasir_confirms_weight(): void {
        $kurir = $this->staff('kurir', 0, 'kur-1'); $t = $this->token($kurir);
        $wrong = $this->order('GY-G', [['n' => 'Cuci Setrika', 'unit' => 'kg', 'price' => 1000, 'qty' => 3]], 'jemput');
        $this->push($t, [['collection' => 'orders', 'key' => 'GY-G', 'data' => $wrong]])->assertJsonPath('results.0.status', 'rejected')
            ->assertJsonPath('results.0.message', 'Harga "Cuci Setrika" tidak sesuai daftar harga.');
        $disc = $this->order('GY-G', [$this->baju(3)], 'jemput', [], ['discKey' => 'p10']);
        $this->push($t, [['collection' => 'orders', 'key' => 'GY-G', 'data' => $disc]])->assertJsonPath('results.0.message', 'Kurir tidak bisa memberi diskon.');
        $good = $this->order('GY-G', [$this->baju(3)], 'jemput');
        $r = $this->push($t, [['collection' => 'orders', 'key' => 'GY-G', 'data' => $good]], 'hp-kurir-1');
        // Tersimpan atas nama kurir pembuatnya, di outlet kurir, menunggu konfirmasi timbangan kasir.
        $r->assertJsonPath('results.0.record.data.card.dataset.courier181', 'kur-1');
        $index = DB::table('order_index')->where('record_key', 'GY-G')->first();
        $this->assertSame([$kurir->outlet_id, 'pending', $kurir->id], [(int) $index->outlet_id, $index->weigh_status, (int) $index->created_by]);
        $this->assertDatabaseMissing('cashier_devices', ['device_uuid' => 'hp-kurir-1']);

        $kasir = $this->staff('kasir');
        $fixed = $this->stored('GY-G'); $fixed['detail']['items'][0]['qty'] = 2.5; $fixed['card']['total'] = 17500;
        $fixed = $this->withStatus($fixed, 'antrian', 'Kasir');
        $rev = (int) DB::table('sync_records')->where('record_key', 'GY-G')->value('rev');
        $this->push($this->token($kasir), [['collection' => 'orders', 'key' => 'GY-G', 'data' => $fixed, 'base_rev' => $rev]])->assertJsonPath('results.0.status', 'applied');
        $this->assertSame('confirmed', DB::table('order_index')->where('record_key', 'GY-G')->value('weigh_status'));
        $weigh = json_decode(DB::table('order_events')->where('record_key', 'GY-G')->where('kind', 'timbang')->value('details'), true);
        $this->assertTrue($weigh['changed']); $this->assertSame($kurir->id, $weigh['courier_id']);
        $this->assertEquals(3, $weigh['before'][0]['qty']); $this->assertEquals(2.5, $weigh['after'][0]['qty']);
    }

    public function test_courier_without_single_outlet_cannot_be_assigned(): void {
        $order = $this->order('GY-H', [$this->baju()], 'jemput', ['antar' => '1']); $rev = $this->create('GY-H', $order);
        $kasir = $this->token($this->staff('kasir'));
        $order['card']['dataset']['courier181'] = 'kur-lama';
        $this->push($kasir, [['collection' => 'orders', 'key' => 'GY-H', 'data' => $order, 'base_rev' => $rev]])
            ->assertJsonPath('results.0.status', 'conflict')
            ->assertJsonPath('results.0.message', 'Lama belum punya outlet. Owner perlu memilih satu outlet di Management Kurir.');
        $this->assertArrayNotHasKey('courier181', $this->stored('GY-H')['card']['dataset']);
        $order['card']['dataset']['courier181'] = 'kur-1';
        $this->push($kasir, [['collection' => 'orders', 'key' => 'GY-H', 'data' => $order, 'base_rev' => $rev]])->assertJsonPath('results.0.status', 'applied');
        $this->assertSame('kur-1', DB::table('order_index')->where('record_key', 'GY-H')->value('courier_key'));
    }

    public function test_business_that_forbids_debt_blocks_unpaid_handover(): void {
        $order = $this->order('GY-I', [$this->baju()], 'siap'); $rev = $this->create('GY-I', $order);
        $kasir = $this->token($this->staff('kasir'));
        // Bawaan: hutang boleh (keputusan lama: pesanan belum bayar tetap boleh Diambil).
        $rev = $this->push($kasir, [['collection' => 'orders', 'key' => 'GY-I', 'data' => $this->withStatus($order, 'diambil', 'Kasir'), 'base_rev' => $rev]])
            ->assertJsonPath('results.0.status', 'applied')->json('results.0.rev');
        $this->owner->business->forceFill(['allow_debt' => false])->save();
        $order2 = $this->order('GY-J', [$this->baju()], 'siap'); $rev2 = $this->create('GY-J', $order2);
        $this->push($kasir, [['collection' => 'orders', 'key' => 'GY-J', 'data' => $this->withStatus($order2, 'diambil', 'Kasir'), 'base_rev' => $rev2]])
            ->assertJsonPath('results.0.status', 'conflict')->assertJsonPath('results.0.message', 'Pesanan belum lunas. Usaha ini tidak mengizinkan hutang.');
        $this->assertSame('siap', $this->stored('GY-J')['card']['dataset']['st']);
    }

    public function test_kurir_cannot_create_pickup_tasks_and_only_updates_own(): void {
        $kasir = $this->token($this->staff('kasir'));
        $task = ['id' => 'jp-1', 'name' => 'Siti', 'address' => 'Jl. Melati 1', 'status' => 'ditugaskan', 'courierId' => 'kur-1'];
        $rev = $this->push($kasir, [['collection' => 'pickups', 'key' => 'jp-1', 'data' => $task]])->assertJsonPath('results.0.status', 'applied')->json('results.0.rev');
        $revB = $this->push($kasir, [['collection' => 'pickups', 'key' => 'jp-2', 'data' => ['id' => 'jp-2', 'status' => 'ditugaskan', 'courierId' => 'kur-9']]])->json('results.0.rev');
        $t = $this->token($this->staff('kurir', 0, 'kur-1'));
        $this->push($t, [['collection' => 'pickups', 'key' => 'jp-3', 'data' => ['id' => 'jp-3', 'status' => 'baru']]])->assertJsonPath('results.0.status', 'rejected');
        $this->push($t, [['collection' => 'pickups', 'key' => 'jp-2', 'data' => ['id' => 'jp-2', 'status' => 'sampai'], 'base_rev' => $revB]])->assertJsonPath('results.0.status', 'rejected');
        $this->push($t, [['collection' => 'pickups', 'key' => 'jp-1', 'data' => ['status' => 'sampai', 'address' => 'diubah', 'courierId' => 'kur-9'] + $task, 'base_rev' => $rev]]);
        $now = json_decode(DB::table('sync_records')->where('collection', 'pickups')->where('record_key', 'jp-1')->value('data'), true);
        $this->assertSame(['sampai', 'Jl. Melati 1', 'kur-1'], [$now['status'], $now['address'], $now['courierId']]);
        $seen = collect($this->pull($t)->json('records'))->where('collection', 'pickups')->keyBy('key');
        $this->assertFalse($seen['jp-1']['deleted']); $this->assertTrue($seen['jp-2']['deleted']);
    }

    public function test_server_copy_returned_to_a_phone_is_limited_to_what_the_role_may_see(): void {
        $order = $this->order('GY-K', [$this->baju()], 'cuci'); $rev = $this->create('GY-K', $order);
        // Pegawai dengan data basi menerima versi server tanpa harga, pembayaran, dan nomor HP pelanggan.
        $r = $this->push($this->token($this->staff('produksi')), [['collection' => 'orders', 'key' => 'GY-K', 'data' => $this->withStatus($order, 'kering'), 'base_rev' => $rev + 5]]);
        $r->assertJsonPath('results.0.status', 'conflict');
        $record = $r->json('results.0.record');
        $this->assertArrayNotHasKey('total', $record['data']['card']);
        $this->assertArrayNotHasKey('phone', $record['data']['detail']);
        $this->assertStringNotContainsString('7000', json_encode($record));
        // Kurir tidak bisa memancing isi pesanan orang lain lewat kiriman basi.
        $r = $this->push($this->token($this->staff('kurir', 0, 'kur-1')), [['collection' => 'orders', 'key' => 'GY-K', 'data' => $this->withStatus($order, 'diambil'), 'base_rev' => $rev + 5]]);
        $r->assertJsonPath('results.0.status', 'conflict')->assertJsonPath('results.0.record.deleted', true)->assertJsonPath('results.0.record.data', null);
        $this->assertStringNotContainsString('Siti', $r->getContent());
    }
}
