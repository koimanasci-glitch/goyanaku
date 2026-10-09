<?php
namespace Tests\Feature;

use App\Models\{Business, User};
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

/** Monitoring owner antar cabang, peringatan otomatis, dan setoran tunai kurir. */
class MonitoringTest extends TestCase {
    use RefreshDatabase;

    private User $owner; private User $kasirA; private User $kasirB; private User $pegawai; private User $kurir; private User $manager;
    private array $tokens = [];

    protected function setUp(): void {
        parent::setUp();
        $business = Business::create(['name' => 'Laundry', 'trial_ends_at' => now()->addMonth()]);
        $business->outlets()->create(['name' => 'Pusat']);
        $business->outlets()->create(['name' => 'Cabang Bekasi']);
        $user = new User(['name' => 'Owner', 'email' => uniqid().'@example.test', 'password' => 'PasswordAman123']);
        $user->business()->associate($business); $user->save();
        $this->owner = $user->fresh();
        $this->kasirA = $this->staff('kasir', 0, 'Kasir A'); $this->kasirB = $this->staff('kasir', 1, 'Kasir B');
        $this->pegawai = $this->staff('produksi', 0, 'Andi'); $this->kurir = $this->staff('kurir', 0, 'Budi', 'kur-1');
        $this->manager = $this->staff('manager', 1, 'Kepala Bekasi');
        $this->push($this->owner, [
            ['collection' => 'services', 'key' => 'cuci setrika', 'data' => ['key' => 'cuci setrika', 'name' => 'Cuci Setrika', 'unit' => 'kg', 'prices' => ['Reguler' => 7000], 'proc' => ['Cuci', 'Kering', 'Setrika', 'Packing']]],
            ['collection' => 'couriers', 'key' => 'kur-1', 'data' => ['id' => 'kur-1', 'name' => 'Budi', 'outlets' => [$this->outletKey(0)], 'active' => true]],
        ]);
    }

    private function staff(string $role, int $outletIndex, string $name, ?string $courierKey = null): User {
        $u = new User(['name' => $name, 'email' => Str::slug($name).uniqid().'@example.test', 'password' => 'PasswordAman123']);
        $u->business_id = $this->owner->business_id; $u->role = $role; $u->courier_key = $courierKey;
        $u->outlet_id = $this->outletId($outletIndex); $u->save();
        return $u->fresh();
    }

    private function outletId(int $i): int { return (int) $this->owner->business->outlets()->orderBy('id')->get()[$i]->id; }
    private function outletKey(int $i): string { return 'srv-'.$this->outletId($i); }

    private function token(User $u): string {
        if (isset($this->tokens[$u->id])) return $this->tokens[$u->id];
        $this->app['auth']->forgetGuards(); $this->flushHeaders();
        return $this->tokens[$u->id] = $this->postJson('/api/session', ['email' => $u->email, 'password' => 'PasswordAman123'])->json('token');
    }

    private function api(User $as, string $method, string $uri, array $data = []) {
        $token = $this->token($as);
        $this->app['auth']->forgetGuards(); $this->flushHeaders();
        return $this->withToken($token)->json($method, '/api'.$uri, $data);
    }

    private function push(User $as, array $changes, string $device = 'device-aaaa-1111') {
        return $this->api($as, 'POST', '/sync/push', ['device_id' => $device, 'changes' => array_map(fn ($c) => $c + ['op_id' => (string) Str::uuid()], $changes)]);
    }

    private function order(string $id, float $kg, string $st, int $paid = 0, array $dataset = [], ?string $due = null): array {
        $items = [['n' => 'Cuci Setrika', 'unit' => 'kg', 'price' => 7000, 'qty' => $kg]]; $total = (int) round($kg * 7000);
        return [
            'card' => ['dataset' => $dataset + ['st' => $st, 'created177' => now()->toIso8601String(), 'items' => json_encode($items), 'paid177' => (string) $paid, 'method177' => 'Tunai',
                'payments178' => json_encode($paid ? [['m' => 'Tunai', 'a' => $paid, 'at' => now()->toIso8601String()]] : [])],
                'fields' => [['Reguler'], [$id], ['Siti'], [], [], []], 'total' => $total, 'paid' => $paid >= $total],
            'detail' => ['id' => $id, 'name' => 'Siti', 'phone' => '08123', 'dur' => 'Reguler', 'items' => $items, 'discKey' => '0', 'ongkir' => 0, 'paid' => $paid,
                'due' => $due ?? now()->addDays(3)->toIso8601String(), 'hist' => [['st' => $st, 'at' => now()->toIso8601String(), 'by' => 'Kasir']]],
        ];
    }

    private function move(User $as, string $id, string $st, ?callable $change = null): void {
        $row = DB::table('sync_records')->where('collection', 'orders')->where('record_key', $id)->first();
        $order = json_decode($row->data, true);
        $order['card']['dataset']['st'] = $st; $order['detail']['hist'][] = ['st' => $st, 'at' => now()->toIso8601String(), 'by' => $as->name];
        if ($change) $order = $change($order);
        $this->push($as, [['collection' => 'orders', 'key' => $id, 'data' => $order, 'base_rev' => (int) $row->rev]], 'hp-'.$as->id.'-0001')
            ->assertJsonPath('results.0.status', 'applied');
    }

    /** Satu hari kerja di dua cabang. */
    private function workday(): void {
        $this->push($this->kasirA, [['collection' => 'orders', 'key' => 'A-1', 'data' => $this->order('A-1', 2, 'antrian', 14000)]], 'hp-kasir-a-01')->assertJsonPath('results.0.status', 'applied');
        $this->move($this->pegawai, 'A-1', 'cuci'); $this->move($this->pegawai, 'A-1', 'kering');
        $this->move($this->kasirA, 'A-1', 'siap'); // melompati setrika dan packing
        $this->push($this->kasirB, [['collection' => 'orders', 'key' => 'B-1', 'data' => $this->order('B-1', 3, 'cuci', 0, [], now()->subHour()->toIso8601String())]], 'hp-kasir-b-01')
            ->assertJsonPath('results.0.status', 'applied');
        $this->push($this->kasirA, [['collection' => 'orders', 'key' => 'A-2', 'data' => $this->order('A-2', 2, 'diantar', 0, ['courier181' => 'kur-1', 'antar' => '1'])]], 'hp-kasir-a-01')
            ->assertJsonPath('results.0.status', 'applied');
        $this->move($this->kurir, 'A-2', 'diambil', function (array $o) {
            $o['detail']['paid'] = 14000; $o['card']['dataset']['paid177'] = '14000'; $o['card']['paid'] = true;
            $o['card']['dataset']['payments178'] = json_encode([['m' => 'Tunai', 'a' => 14000, 'at' => now()->toIso8601String()]]);
            return $o;
        });
    }

    public function test_owner_sees_every_branch_people_and_money(): void {
        $this->workday();
        $r = $this->api($this->owner, 'GET', '/monitoring')->assertOk();
        $r->assertJsonPath('scope', 'all')->assertJsonPath('totals.orders', 3)->assertJsonPath('totals.revenue', 49000)
            ->assertJsonPath('totals.cash_in', 28000)->assertJsonPath('totals.unpaid', 1)->assertJsonPath('totals.debt', 21000)
            ->assertJsonPath('totals.ready_uncollected', 1)->assertJsonPath('totals.late', 1)->assertJsonPath('money.courier_cash_total', 14000);
        $outlets = collect($r->json('outlets'))->keyBy('name');
        $this->assertSame([2, 28000, 1, 0], [$outlets['Pusat']['orders'], $outlets['Pusat']['revenue'], $outlets['Pusat']['ready_uncollected'], $outlets['Pusat']['late']]);
        $this->assertSame([1, 21000, 1, ['cuci' => 1]], [$outlets['Cabang Bekasi']['orders'], $outlets['Cabang Bekasi']['revenue'], $outlets['Cabang Bekasi']['late'], $outlets['Cabang Bekasi']['stages']]);
        $pegawai = collect($r->json('production'))->firstWhere('name', 'Andi');
        $this->assertSame([['cuci' => 1, 'kering' => 1], 2], [$pegawai['stages'], $pegawai['total']]);
        $kasir = collect($r->json('cashiers'))->firstWhere('name', 'Kasir A');
        $this->assertSame([2, 14000, 1, 1], [$kasir['created'], $kasir['received'], $kasir['skipped'], $kasir['marked_ready']]);
        $kurir = collect($r->json('couriers'))->firstWhere('name', 'Budi');
        $this->assertSame([1, 14000], [$kurir['deliveries'], $kurir['cash_collected']]);
        $this->assertSame('Budi', $r->json('money.courier_cash.0.courier'));
        $this->assertSame(['Tunai' => 28000], $r->json('money.cash_in_by_method'));
        $this->assertContains('late', collect($r->json('alerts'))->pluck('type')->all());
        // Saring satu cabang.
        $this->api($this->owner, 'GET', '/monitoring?outlet_id='.$this->outletId(1))->assertJsonPath('scope', 'outlet')->assertJsonPath('totals.orders', 1)->assertJsonCount(1, 'outlets');
        // Rentang tanggal lain: tidak ada transaksi, tetapi hutang dan cucian berjalan tetap terlihat.
        $past = now('Asia/Jakarta')->subDays(10)->toDateString();
        $this->api($this->owner, 'GET', '/monitoring?from='.$past.'&to='.$past)->assertJsonPath('totals.orders', 0)->assertJsonPath('totals.debt', 21000);
    }

    public function test_running_pickups_show_schedule_and_who_picks_up(): void {
        $pickup = function (string $id, array $dataset) {
            $o = $this->order($id, 0, 'jemput', 0, $dataset);
            $o['card']['dataset']['items'] = '[]'; $o['detail']['items'] = []; $o['card']['total'] = 0; $o['detail']['address'] = 'Jl. Mawar 1';
            return $o;
        };
        $this->push($this->kasirA, [
            ['collection' => 'orders', 'key' => 'J-1', 'data' => $pickup('J-1', ['courier181' => 'kur-1', 'jemput202' => '1', 'jemputDate' => '2026-10-10', 'jemputSlot' => 'pagi'])],
            ['collection' => 'orders', 'key' => 'J-2', 'data' => $pickup('J-2', ['jemput202' => '1', 'jemputSelf' => 'Kasir A', 'jemputDate' => '2026-10-09', 'jemputSlot' => 'asap'])],
        ], 'hp-kasir-a-01')->assertJsonPath('results.0.status', 'applied')->assertJsonPath('results.1.status', 'applied');
        $r = $this->api($this->owner, 'GET', '/monitoring')->assertOk();
        $rows = collect($r->json('pickups'))->keyBy('order');
        $this->assertSame(['Budi', false, '10 Oct · Pagi 08.00–11.00', 'Jl. Mawar 1'], [$rows['J-1']['courier'], $rows['J-1']['self'], $rows['J-1']['when'], $rows['J-1']['address']]);
        $this->assertSame(['Kasir A', true, 'Secepatnya'], [$rows['J-2']['courier'], $rows['J-2']['self'], $rows['J-2']['when']]);
        $this->app['auth']->forgetGuards(); $this->flushHeaders();
        $this->actingAs($this->owner)->get('/monitoring')->assertOk()->assertSee('Penjemputan berjalan')->assertSee('Dijemput sendiri: Kasir A');
        // Setelah dijemput (masuk Antrian) tidak lagi tampil.
        $this->move($this->kurir, 'J-1', 'antrian');
        $this->assertSame(['J-2'], collect($this->api($this->owner, 'GET', '/monitoring')->json('pickups'))->pluck('order')->all());
    }

    public function test_full_report_is_owner_only_and_admin_outlet_sees_own_branch(): void {
        $this->workday();
        foreach ([$this->kasirA, $this->pegawai, $this->kurir] as $staff) {
            $this->api($staff, 'GET', '/monitoring')->assertForbidden();
            $this->api($staff, 'GET', '/monitoring/alerts')->assertForbidden();
        }
        // Admin outlet meminta cabang lain tetap hanya mendapat cabangnya sendiri.
        $r = $this->api($this->manager, 'GET', '/monitoring?outlet_id='.$this->outletId(0))->assertOk();
        $r->assertJsonPath('scope', 'outlet')->assertJsonCount(1, 'outlets')->assertJsonPath('outlets.0.name', 'Cabang Bekasi')->assertJsonPath('totals.orders', 1);
        $this->assertSame([], $r->json('money.courier_cash'));
        // Usaha lain tidak melihat apa pun.
        $other = Business::create(['name' => 'Lain', 'trial_ends_at' => now()->addMonth()]); $other->outlets()->create(['name' => 'Pusat']);
        $stranger = new User(['name' => 'Lain', 'email' => uniqid().'@example.test', 'password' => 'PasswordAman123']); $stranger->business()->associate($other); $stranger->save();
        $this->api($stranger->fresh(), 'GET', '/monitoring')->assertOk()->assertJsonPath('totals.orders', 0)->assertJsonPath('money.courier_cash_total', 0);
        $this->api($stranger->fresh(), 'GET', '/monitoring?outlet_id='.$this->outletId(0))->assertNotFound();
    }

    public function test_web_monitoring_page_shows_the_same_report_and_follows_the_same_access(): void {
        $this->workday();
        $this->app['auth']->forgetGuards(); $this->flushHeaders();
        $this->actingAs($this->owner)->get('/monitoring')->assertOk()->assertSee('Rp49.000')->assertSee('Cabang Bekasi')->assertSee('Kasir A')->assertSee('Andi')->assertSee('Budi')
            ->assertSee('Tunai dipegang kurir');
        $this->get('/dashboard')->assertOk()->assertSee('Monitoring lengkap')->assertSee('Ubah data cabang');
        $this->get('/monitoring?outlet_id='.$this->outletId(1))->assertOk()->assertSee('Rp21.000')->assertDontSee('Rp49.000');
        // Admin outlet hanya cabangnya; kasir tidak boleh.
        $this->actingAs($this->manager)->get('/monitoring?outlet_id='.$this->outletId(0))->assertOk()->assertSee('Rp21.000')->assertDontSee('Kasir A');
        $this->actingAs($this->kasirA)->get('/monitoring')->assertForbidden();
    }

    public function test_owner_edits_branches_and_settings_from_the_web_dashboard(): void {
        $this->app['auth']->forgetGuards(); $this->flushHeaders();
        $cabang = $this->owner->business->outlets()->orderBy('id')->get()[1]; $pusat = $this->outletId(0);
        $this->actingAs($this->owner)->post('/outlets/'.$cabang->id, ['name' => 'Cabang Bekasi Timur', 'code' => 'bkt', 'address' => 'Jl. Baru 9', 'phone' => '0812-3456-7890', 'process_outlet_id' => $pusat])
            ->assertRedirect()->assertSessionHasNoErrors();
        $cabang->refresh();
        $this->assertSame(['Cabang Bekasi Timur', 'BKT', 'Jl. Baru 9', '6281234567890', $pusat], [$cabang->name, $cabang->code, $cabang->address, $cabang->phone, $cabang->process_outlet_id]);
        $this->post('/outlets/'.$cabang->id, ['name' => 'Cabang Bekasi Timur', 'process_outlet_id' => ''])->assertSessionHasNoErrors();
        $this->assertNull($cabang->fresh()->process_outlet_id);
        // Cabang yang masih punya pegawai aktif tidak bisa dinonaktifkan.
        $this->post('/outlets/'.$cabang->id.'/deactivate')->assertSessionHasErrors('outlet');
        $this->post('/business/settings', [])->assertRedirect();
        $this->assertFalse((bool) $this->owner->business->fresh()->allow_debt);
        $this->post('/business/settings', ['allow_debt' => '1']);
        $this->assertTrue((bool) $this->owner->business->fresh()->allow_debt);
        $this->actingAs($this->kasirA)->post('/outlets/'.$cabang->id, ['name' => 'Diganti'])->assertForbidden();
        $this->post('/business/settings', [])->assertForbidden();
    }

    public function test_staff_see_only_their_own_summary(): void {
        $this->workday();
        $this->api($this->kasirA, 'GET', '/me/summary')->assertOk()->assertJsonPath('orders_created', 2)->assertJsonPath('received_total', 14000)->assertJsonMissingPath('cash_held');
        $this->api($this->kasirB, 'GET', '/me/summary')->assertJsonPath('orders_created', 1)->assertJsonPath('received_total', 0);
        $this->api($this->pegawai, 'GET', '/me/summary')->assertJsonPath('total', 2)->assertJsonPath('stages_done.cuci', 1)->assertJsonMissingPath('received_total');
        $this->api($this->kurir, 'GET', '/me/summary')->assertJsonPath('cash_held', 14000)->assertJsonPath('done_today.deliveries', 1)->assertJsonPath('tasks.pickup', 0);
    }

    public function test_courier_cash_is_held_until_cashier_of_the_same_outlet_confirms_deposit(): void {
        $this->workday();
        $this->api($this->kurir, 'GET', '/courier/cash')->assertOk()->assertJsonPath('held', 14000)->assertJsonPath('notes', 1)->assertJsonPath('history.0.note_no', 'A-2');
        $this->api($this->kasirA, 'GET', '/courier-cash')->assertJsonPath('couriers.0.held', 14000);
        $this->api($this->kasirB, 'GET', '/courier-cash')->assertJsonCount(0, 'couriers');
        $url = '/courier-cash/'.$this->kurir->id.'/deposit';
        $this->api($this->kasirB, 'POST', $url, ['amount' => 14000])->assertForbidden();       // kasir outlet lain
        $this->api($this->pegawai, 'POST', $url, ['amount' => 14000])->assertForbidden();
        $this->api($this->kurir, 'POST', $url, ['amount' => 14000])->assertForbidden();         // kurir tidak mengonfirmasi setorannya sendiri
        $this->api($this->kasirA, 'POST', $url, ['amount' => 13000])->assertStatus(422)->assertJsonValidationErrors('note');
        $this->api($this->kasirA, 'POST', $url, ['amount' => 13000, 'note' => 'Kurang seribu, kembalian'])->assertCreated()
            ->assertJsonPath('deposit.expected', 14000)->assertJsonPath('deposit.difference', -1000);
        $this->api($this->kurir, 'GET', '/courier/cash')->assertJsonPath('held', 0)->assertJsonCount(2, 'history');
        $this->api($this->kasirA, 'POST', $url, ['amount' => 0])->assertStatus(422)->assertJsonValidationErrors('amount');
        $r = $this->api($this->owner, 'GET', '/monitoring')->assertJsonPath('money.courier_cash_total', 0)->assertJsonPath('money.deposits.0.difference', -1000)
            ->assertJsonPath('money.deposits.0.confirmed_by', 'Kasir A');
        $alert = collect($r->json('alerts'))->firstWhere('type', 'deposit_difference');
        $this->assertSame('Setoran Budi kurang Rp1.000.', $alert['text']);
        $this->assertDatabaseHas('audit_events', ['action' => 'courier.deposit']);
        // Kurir yang dipindah outlet tetap tercatat memegang uangnya.
        DB::table('courier_ledger')->insert(['business_id' => $this->owner->business_id, 'outlet_id' => $this->outletId(0), 'courier_id' => $this->kurir->id, 'type' => 'collect', 'amount' => 5000, 'record_key' => 'A-9', 'created_at' => now()]);
        $this->kurir->forceFill(['outlet_id' => $this->outletId(1)])->save();
        $this->api($this->kurir, 'GET', '/courier/cash')->assertJsonPath('held', 5000);
        $this->api($this->kasirA, 'POST', $url, ['amount' => 5000])->assertForbidden();
        $this->api($this->kasirB, 'POST', $url, ['amount' => 5000])->assertCreated()->assertJsonPath('deposit.difference', 0);
        $this->kurir->forceFill(['outlet_id' => $this->outletId(0)])->save();
    }

    public function test_alerts_for_stale_cash_uncollected_laundry_idle_phone_and_courier_without_outlet(): void {
        $this->workday();
        $this->push($this->owner, [['collection' => 'couriers', 'key' => 'kur-lama', 'data' => ['id' => 'kur-lama', 'name' => 'Lama', 'outlets' => [], 'active' => true]]]);
        $types = fn () => collect($this->api($this->owner, 'GET', '/monitoring/alerts')->assertOk()->json('alerts'))->pluck('type')->all();
        $this->assertEqualsCanonicalizing(['late', 'courier_without_outlet'], $types());
        $this->travel(26)->hours();
        $this->tokens = [];
        $this->assertContains('courier_cash', $types());
        $this->assertContains('device_stale', $types());
        $this->assertNotContains('uncollected', $types());
        $this->travel(8)->days();
        $this->tokens = [];
        $all = collect($this->api($this->owner, 'GET', '/monitoring/alerts')->json('alerts'));
        $this->assertSame('1 cucian siap ambil belum diambil lebih dari 7 hari.', $all->firstWhere('type', 'uncollected')['text']);
        $this->assertSame('Pusat', $all->firstWhere('type', 'uncollected')['outlet']);
        // Admin outlet hanya menerima peringatan cabangnya.
        $mine = collect($this->api($this->manager, 'GET', '/monitoring/alerts')->json('alerts'));
        $this->assertSame(['Cabang Bekasi'], $mine->pluck('outlet')->unique()->values()->all());
        $this->app['auth']->forgetGuards(); $this->flushHeaders();
        $this->actingAs($this->owner)->get('/dashboard')->assertOk()->assertSee('Perlu diperhatikan')->assertSee('belum punya outlet');
    }

    public function test_cash_closes_from_cashier_phones_reach_the_owner(): void {
        $kas = ['kasir' => 'Kasir A', 'start' => 0, 'sales' => [], 'ins' => [], 'outs' => [],
            'hist' => [['d' => now()->toIso8601String(), 'kasir' => 'Kasir A', 'omset' => 150000, 'diff' => -2000, 'setor' => 148000, 'note' => 'Kembalian kurang']]];
        $this->push($this->kasirA, [['collection' => 'kas', 'key' => $this->outletKey(0).'|Kasir A', 'data' => $kas]], 'hp-kasir-a-01')->assertJsonPath('results.0.status', 'applied');
        $r = $this->api($this->owner, 'GET', '/monitoring')->assertOk();
        $this->assertSame(['Kasir A', 148000, -2000, 'Kembalian kurang'], [$r->json('money.cash_closes.0.cashier'), $r->json('money.cash_closes.0.deposited'), $r->json('money.cash_closes.0.difference'), $r->json('money.cash_closes.0.note')]);
        $this->assertSame([], $this->api($this->manager, 'GET', '/monitoring')->json('money.cash_closes'));
    }

    public function test_old_orders_can_be_indexed_for_monitoring(): void {
        $this->workday();
        DB::table('order_events')->delete(); DB::table('order_index')->delete();
        $this->api($this->owner, 'GET', '/monitoring')->assertJsonPath('totals.orders', 0);
        $this->artisan('goyana:reindex-orders')->expectsOutput('3 pesanan lama dimasukkan ke indeks monitoring.')->assertExitCode(0);
        $this->api($this->owner, 'GET', '/monitoring')->assertJsonPath('totals.orders', 3)->assertJsonPath('totals.revenue', 49000)->assertJsonPath('totals.debt', 21000);
        $this->artisan('goyana:reindex-orders')->expectsOutput('0 pesanan lama dimasukkan ke indeks monitoring.');
    }
}
