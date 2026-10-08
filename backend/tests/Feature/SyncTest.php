<?php
namespace Tests\Feature;

use App\Models\{Business, User};
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\TestCase;

class SyncTest extends TestCase {
    use RefreshDatabase;

    private function owner(bool $expired = false): User {
        $business = Business::create(['name' => 'Laundry', 'trial_ends_at' => $expired ? now()->subDay() : now()->addMonth()]);
        $business->outlets()->create(['name' => 'Pusat']);
        $business->outlets()->create(['name' => 'Cabang']);
        $user = new User(['name' => 'Owner', 'email' => uniqid().'@example.test', 'password' => 'PasswordAman123']);
        $user->business()->associate($business); $user->save();
        return $user->fresh();
    }

    private function staff(User $owner, string $role, int $outletIndex = 0): User {
        $u = new User(['name' => ucfirst($role), 'email' => $role.uniqid().'@example.test', 'password' => 'PasswordAman123']);
        $u->business_id = $owner->business_id; $u->role = $role;
        $u->outlet_id = $owner->business->outlets()->orderBy('id')->get()[$outletIndex]->id; $u->save();
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

    private function pull(string $token, int $cursor = 0) {
        $this->app['auth']->forgetGuards();
        return $this->withToken($token)->getJson('/api/sync/pull?cursor='.$cursor);
    }

    private function outletKey(User $owner, int $i): string { return 'srv-'.$owner->business->outlets()->orderBy('id')->get()[$i]->id; }

    public function test_order_pushed_by_one_phone_is_pulled_by_another(): void {
        $owner = $this->owner(); $t = $this->token($owner);
        $order = ['card' => ['total' => 17000, 'dataset' => ['st' => 'antrian']], 'detail' => ['paid' => 0]];
        $r = $this->push($t, [['collection' => 'orders', 'key' => 'GY-0001', 'outlet' => $this->outletKey($owner, 0), 'data' => $order]])->assertOk();
        $this->assertSame('applied', $r->json('results.0.status'));
        $pull = $this->pull($this->token($owner))->assertOk();
        $this->assertSame('GY-0001', $pull->json('records.0.key'));
        $this->assertSame(17000, $pull->json('records.0.data.card.total'));
        $this->assertSame($this->outletKey($owner, 0), $pull->json('records.0.outlet'));
        $this->assertSame(0, count($this->pull($t, $pull->json('cursor'))->json('records')));
    }

    public function test_retrying_the_same_op_is_idempotent(): void {
        $owner = $this->owner(); $t = $this->token($owner);
        $change = ['op_id' => 'op-12345678', 'collection' => 'customers', 'key' => 'phone:628123', 'data' => ['name' => 'Budi']];
        $this->app['auth']->forgetGuards();
        $a = $this->withToken($t)->postJson('/api/sync/push', ['device_id' => 'device-1234', 'changes' => [$change]])->json('results.0');
        $this->app['auth']->forgetGuards();
        $b = $this->withToken($t)->postJson('/api/sync/push', ['device_id' => 'device-1234', 'changes' => [$change]])->json('results.0');
        $this->assertSame($a, $b);
        $this->assertDatabaseCount('sync_records', 1);
    }

    public function test_stale_edit_becomes_conflict_and_is_kept_not_lost(): void {
        $owner = $this->owner(); $t = $this->token($owner);
        $rev = $this->push($t, [['collection' => 'customers', 'key' => 'c1', 'data' => ['name' => 'Asli']]])->json('results.0.rev');
        $this->push($t, [['collection' => 'customers', 'key' => 'c1', 'data' => ['name' => 'HP A'], 'base_rev' => $rev]], 'device-a-123')
            ->assertJsonPath('results.0.status', 'applied');
        $r = $this->push($t, [['collection' => 'customers', 'key' => 'c1', 'data' => ['name' => 'HP B'], 'base_rev' => $rev]], 'device-b-123');
        $r->assertJsonPath('results.0.status', 'conflict')->assertJsonPath('results.0.record.data.name', 'HP A');
        $this->assertDatabaseHas('sync_conflicts', ['record_key' => 'c1', 'device_uuid' => 'device-b-123']);
    }

    public function test_delete_is_synced_as_tombstone(): void {
        $owner = $this->owner(); $t = $this->token($owner);
        $rev = $this->push($t, [['collection' => 'services', 'key' => 'cuci kering', 'data' => ['p' => 7000]]])->json('results.0.rev');
        $this->push($t, [['collection' => 'services', 'key' => 'cuci kering', 'deleted' => true, 'base_rev' => $rev]])->assertJsonPath('results.0.status', 'applied');
        $rec = collect($this->pull($t)->json('records'))->firstWhere('key', 'cuci kering');
        $this->assertTrue($rec['deleted']); $this->assertNull($rec['data']);
    }

    public function test_kasir_is_limited_to_own_outlet_and_permissions(): void {
        $owner = $this->owner(); $kasir = $this->staff($owner, 'kasir', 0); $t = $this->token($kasir);
        // Kasir writes an order: always stored under the kasir's outlet, whatever the phone sends.
        $this->push($t, [['collection' => 'orders', 'key' => 'K-1', 'outlet' => $this->outletKey($owner, 1), 'data' => ['x' => 1]]])
            ->assertJsonPath('results.0.status', 'applied');
        $this->assertDatabaseHas('sync_records', ['record_key' => 'K-1', 'outlet_id' => $kasir->outlet_id]);
        // Kasir may not change prices.
        $this->push($t, [['collection' => 'services', 'key' => 's', 'data' => ['p' => 1]]])->assertJsonPath('results.0.status', 'rejected');
        // Kasir does not see the other outlet's orders.
        $this->push($this->token($owner), [['collection' => 'orders', 'key' => 'B-1', 'outlet' => $this->outletKey($owner, 1), 'data' => ['x' => 2]]]);
        $keys = collect($this->pull($t)->json('records'))->pluck('key');
        $this->assertTrue($keys->contains('K-1')); $this->assertFalse($keys->contains('B-1'));
        // And cannot overwrite it.
        $this->push($t, [['collection' => 'orders', 'key' => 'B-1', 'data' => ['x' => 3], 'base_rev' => 2]])->assertJsonPath('results.0.status', 'rejected');
    }

    public function test_kurir_cannot_read_cash_or_take_cashier_slot(): void {
        $owner = $this->owner(); $kurir = $this->staff($owner, 'kurir');
        $kurir->courier_key = 'kur-1'; $kurir->save();
        $order = ['card' => ['total' => 10000, 'dataset' => ['st' => 'diantar', 'antar' => '1', 'courier181' => 'kur-1']], 'detail' => ['paid' => 10000]];
        $rev = $this->push($this->token($owner), [
            ['collection' => 'kas', 'key' => 'k', 'outlet' => $this->outletKey($owner, 0), 'data' => ['start' => 1]],
            ['collection' => 'orders', 'key' => 'O', 'outlet' => $this->outletKey($owner, 0), 'data' => $order],
        ])->json('results.1.rev');
        $t = $this->token($kurir);
        $this->assertFalse(collect($this->pull($t)->json('records'))->pluck('collection')->contains('kas'));
        // Kurir menyelesaikan pengantaran tugasnya dari HP sendiri: tersimpan, dan HP itu tidak memakai slot kasir.
        $order['card']['dataset']['st'] = 'diambil';
        $this->push($t, [['collection' => 'orders', 'key' => 'O', 'data' => $order, 'base_rev' => $rev]], 'kurir-device-1')->assertJsonPath('results.0.status', 'applied');
        $this->assertDatabaseMissing('cashier_devices', ['device_uuid' => 'kurir-device-1']);
    }

    public function test_third_cashier_phone_in_an_outlet_is_rejected(): void {
        $owner = $this->owner(); $t = $this->token($owner); $o = $this->outletKey($owner, 0);
        foreach (['phone-0001', 'phone-0002'] as $i => $d) {
            $this->push($t, [['collection' => 'orders', 'key' => 'O'.$i, 'outlet' => $o, 'data' => ['i' => $i]]], $d)->assertJsonPath('results.0.status', 'applied');
        }
        $this->push($t, [['collection' => 'orders', 'key' => 'O3', 'outlet' => $o, 'data' => ['i' => 3]]], 'phone-0003')
            ->assertJsonPath('results.0.status', 'rejected')->assertJsonPath('results.0.message', 'Maksimal 2 perangkat kasir per outlet.');
        // Non-transaction data still syncs from that phone.
        $this->push($t, [['collection' => 'customers', 'key' => 'c', 'data' => ['n' => 1]]], 'phone-0003')->assertJsonPath('results.0.status', 'applied');
        // Owner revokes a phone; the new phone can then take the slot, the revoked one cannot write.
        $device = $owner->business->outlets()->orderBy('id')->first()->devices()->where('device_uuid', 'phone-0001')->first();
        $this->actingAs($owner)->post('/outlets/'.$device->outlet_id.'/devices/'.$device->id.'/revoke');
        $this->push($t, [['collection' => 'orders', 'key' => 'O4', 'outlet' => $o, 'data' => ['i' => 4]]], 'phone-0003')->assertJsonPath('results.0.status', 'applied');
        $this->push($t, [['collection' => 'orders', 'key' => 'O5', 'outlet' => $o, 'data' => ['i' => 5]]], 'phone-0001')->assertJsonPath('results.0.status', 'rejected');
        $this->assertDatabaseHas('audit_events', ['action' => 'device.rejected']);
    }

    public function test_dashboard_slot_is_claimed_by_first_phone(): void {
        $owner = $this->owner(); $outlet = $owner->business->outlets()->orderBy('id')->first();
        $this->actingAs($owner)->post('/outlets/'.$outlet->id.'/devices', ['label' => 'Kasir depan']);
        $this->push($this->token($owner), [['collection' => 'orders', 'key' => 'O', 'outlet' => 'srv-'.$outlet->id, 'data' => ['i' => 1]]], 'phone-front');
        $this->assertDatabaseHas('cashier_devices', ['label' => 'Kasir depan', 'device_uuid' => 'phone-front']);
        $this->assertSame(1, $outlet->devices()->count());
    }

    public function test_read_only_business_can_pull_but_not_push(): void {
        $owner = $this->owner(); $t = $this->token($owner);
        $this->push($t, [['collection' => 'customers', 'key' => 'c', 'data' => ['n' => 1]]]);
        $owner->business->update(['trial_ends_at' => now()->subDay()]);
        $this->push($t, [['collection' => 'customers', 'key' => 'd', 'data' => ['n' => 2]]])
            ->assertJsonPath('results.0.status', 'rejected')->assertJsonPath('results.0.message', 'Paket sudah berakhir. Data hanya bisa dilihat.');
        $this->pull($t)->assertOk()->assertJsonPath('read_only', true)->assertJsonCount(1, 'records');
    }

    public function test_businesses_never_see_each_other(): void {
        $a = $this->owner(); $b = $this->owner();
        $this->push($this->token($a), [['collection' => 'customers', 'key' => 'rahasia', 'data' => ['n' => 'A']]]);
        $this->assertCount(0, $this->pull($this->token($b))->json('records'));
        // Same key in another business is a separate record.
        $this->push($this->token($b), [['collection' => 'customers', 'key' => 'rahasia', 'data' => ['n' => 'B']]])->assertJsonPath('results.0.status', 'applied');
        $this->assertDatabaseCount('sync_records', 2);
    }

    public function test_unknown_collection_and_oversized_data_are_rejected(): void {
        $owner = $this->owner(); $t = $this->token($owner);
        $this->push($t, [['collection' => 'users', 'key' => 'x', 'data' => ['is_platform_admin' => true]]])->assertJsonPath('results.0.status', 'rejected');
        $this->push($t, [['collection' => 'settings', 'key' => 'big', 'data' => str_repeat('a', 500000)]])->assertJsonPath('results.0.message', 'Data terlalu besar.');
        $this->app['auth']->forgetGuards();
        $this->flushHeaders()->getJson('/api/sync/pull')->assertUnauthorized();
    }

    public function test_owner_dashboard_shows_synced_sales(): void {
        $owner = $this->owner(); $t = $this->token($owner);
        $now = now()->toIso8601String();
        $this->push($t, [
            ['collection' => 'orders', 'key' => 'A', 'outlet' => $this->outletKey($owner, 0), 'data' => ['card' => ['total' => 17000, 'paid' => true, 'dataset' => ['st' => 'antrian', 'created177' => $now]]]],
            ['collection' => 'orders', 'key' => 'B', 'outlet' => $this->outletKey($owner, 1), 'data' => ['card' => ['total' => 8000, 'paid' => false, 'dataset' => ['st' => 'siap', 'created177' => $now]]]],
            ['collection' => 'orders', 'key' => 'C', 'outlet' => $this->outletKey($owner, 1), 'data' => ['card' => ['total' => 99000, 'dataset' => ['st' => 'batal', 'created177' => $now]]]],
        ]);
        $this->actingAs($owner)->get('/dashboard')->assertOk()->assertSee('Rp25.000')->assertSee('2 pesanan')->assertSee('1 belum lunas')->assertSee('HP terpasang');
    }

    public function test_business_settings_set_by_owner_reach_staff_phones_but_staff_cannot_change_them(): void {
        $owner = $this->owner(); $kasir = $this->staff($owner, 'kasir', 0);
        $shared = json_encode(['discounts' => [['id' => 1, 'name' => 'Diskon 10%']], 'tpl' => ['cashier' => ['tg' => ['3' => false]]]]);
        $rev = $this->push($this->token($owner), [
            ['collection' => 'settings', 'key' => 'goyana-pure-shared', 'data' => $shared],
            ['collection' => 'settings', 'key' => 'goyana-perfumes178', 'data' => '[["Lavender","rgb(1, 2, 3)"]]'],
        ])->assertJsonPath('results.0.status', 'applied')->json('results.0.rev');
        $t = $this->token($kasir);
        $seen = collect($this->pull($t)->json('records'))->where('collection', 'settings')->keyBy('key');
        $this->assertSame($shared, $seen['goyana-pure-shared']['data']);
        $this->assertArrayHasKey('goyana-perfumes178', $seen->all());
        $this->push($t, [['collection' => 'settings', 'key' => 'goyana-pure-shared', 'data' => '{"discounts":[]}', 'base_rev' => $rev]])
            ->assertJsonPath('results.0.status', 'rejected');
        $this->assertSame($shared, json_decode(\Illuminate\Support\Facades\DB::table('sync_records')->where('record_key', 'goyana-pure-shared')->value('data')));
    }
}
