<?php
namespace Tests\Feature;

use App\Models\{Business, User};
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

/** Stok per cabang dan kiriman bahan antar cabang (keputusan Paduka 10 Oktober 2026). */
class StockSyncTest extends TestCase {
    use RefreshDatabase;

    private User $owner;

    protected function setUp(): void {
        parent::setUp();
        $business = Business::create(['name' => 'Laundry', 'trial_ends_at' => now()->addMonth()]);
        $business->outlets()->create(['name' => 'Pusat']);
        $business->outlets()->create(['name' => 'Bekasi']);
        $business->outlets()->create(['name' => 'Depok']);
        $user = new User(['name' => 'Owner', 'email' => uniqid().'@example.test', 'password' => 'PasswordAman123']);
        $user->business()->associate($business); $user->save();
        $this->owner = $user->fresh();
    }

    private function staff(string $role, int $outletIndex): User {
        $u = new User(['name' => ucfirst($role), 'email' => $role.uniqid().'@example.test', 'password' => 'PasswordAman123']);
        $u->business_id = $this->owner->business_id; $u->role = $role;
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

    private function pull(string $token): array {
        $this->app['auth']->forgetGuards();
        return $this->withToken($token)->getJson('/api/sync/pull?cursor=0')->assertOk()->json('records');
    }

    private function key(int $i): string { return 'srv-'.$this->owner->business->outlets()->orderBy('id')->get()[$i]->id; }

    private function led(string $id, int $outlet, string $type, float $qty, string $item = 'deterjen'): array {
        return ['collection' => 'stock_ledger', 'key' => $id, 'outlet' => $this->key($outlet),
            'data' => ['id' => $id, 'itemId' => $item, 'outletId' => $this->key($outlet), 'type' => $type, 'qty' => $qty, 'at' => '2026-10-10T07:00:00Z']];
    }

    private function balance(array $records, int $outlet, string $item = 'deterjen'): float {
        return array_sum(array_map(fn ($r) => (float) $r['data']['qty'], array_filter($records,
            fn ($r) => $r['collection'] === 'stock_ledger' && !$r['deleted'] && $r['data']['itemId'] === $item && $r['data']['outletId'] === $this->key($outlet))));
    }

    public function test_stock_is_kept_per_outlet_and_staff_only_see_their_own(): void {
        $owner = $this->token($this->owner);
        $this->push($owner, [$this->led('m1', 0, 'Stok Awal', 20), $this->led('m2', 1, 'Stok Awal', 3)])
            ->assertJsonPath('results.0.status', 'applied')->assertJsonPath('results.1.status', 'applied');
        $this->assertSame([$this->owner->business->outlets()->orderBy('id')->value('id')],
            DB::table('sync_records')->where('record_key', 'm1')->pluck('outlet_id')->all());

        $all = $this->pull($owner);
        $this->assertSame(20.0, $this->balance($all, 0));
        $this->assertSame(3.0, $this->balance($all, 1));

        // Kasir Bekasi hanya menerima catatan Bekasi.
        $kasir = $this->token($this->staff('kasir', 1));
        $mine = $this->pull($kasir);
        $this->assertSame(['m2'], array_values(array_map(fn ($r) => $r['key'], array_filter($mine, fn ($r) => $r['collection'] === 'stock_ledger'))));

        // Kasir mencatat pemakaian: masuk ke cabangnya walau HP mengirim outlet lain.
        $wrong = $this->led('m3', 0, 'Pemakaian', -1);
        $this->push($kasir, [$wrong])->assertJsonPath('results.0.status', 'applied');
        $row = DB::table('sync_records')->where('record_key', 'm3')->first();
        $this->assertSame($this->staff('kasir', 1)->outlet_id, (int) $row->outlet_id);
        $this->assertSame($this->key(1), json_decode($row->data, true)['outletId']);

        // Kasir tidak boleh menambah stok, mengubah, atau menghapus catatan yang sudah ada.
        $this->push($kasir, [$this->led('m4', 1, 'Stok Masuk', 50)])
            ->assertJsonPath('results.0.status', 'rejected')->assertJsonPath('results.0.message', 'Akun ini hanya bisa mencatat pemakaian bahan dan menerima kiriman.');
        $rev = (int) DB::table('sync_records')->where('record_key', 'm2')->value('rev');
        $edit = $this->led('m2', 1, 'Stok Awal', 30); $edit['base_rev'] = $rev;
        $this->push($kasir, [$edit])->assertJsonPath('results.0.status', 'rejected');
        $this->push($kasir, [['collection' => 'stock_ledger', 'key' => 'm2', 'outlet' => $this->key(1), 'deleted' => true, 'base_rev' => $rev]])
            ->assertJsonPath('results.0.status', 'rejected')->assertJsonPath('results.0.message', 'Catatan stok hanya bisa dihapus owner.');

        // Kepala cabang boleh stok masuk, tapi hanya di cabangnya.
        $kepala = $this->token($this->staff('manager', 1));
        $this->push($kepala, [$this->led('m5', 1, 'Stok Masuk', 5)])->assertJsonPath('results.0.status', 'applied');
        $this->assertSame(7.0, $this->balance($this->pull($owner), 1));
    }

    public function test_transfer_is_sent_by_origin_and_received_once_by_destination(): void {
        $owner = $this->token($this->owner);
        $this->push($owner, [$this->led('m1', 0, 'Stok Awal', 20)]);
        $t = ['id' => 'tr-1', 'itemId' => 'deterjen', 'from' => $this->key(0), 'to' => $this->key(1), 'qty' => 10, 'status' => 'sent', 'sentAt' => '2026-10-10T07:00:00Z'];
        $this->push($owner, [
            ['collection' => 'stock_transfers', 'key' => 'tr-1', 'data' => $t],
            $this->led('m2', 0, 'Transfer Keluar', -10) + [],
        ])->assertJsonPath('results.0.status', 'applied')->assertJsonPath('results.1.status', 'applied');

        // Cabang lain (Depok) tidak melihat kiriman Pusat → Bekasi; Bekasi melihatnya.
        $depok = $this->token($this->staff('kasir', 2));
        $this->assertEmpty(array_filter($this->pull($depok), fn ($r) => $r['collection'] === 'stock_transfers'));
        $kasirBekasi = $this->staff('kasir', 1);
        $bekasi = $this->token($kasirBekasi);
        $this->assertCount(1, array_filter($this->pull($bekasi), fn ($r) => $r['collection'] === 'stock_transfers'));

        // Depok tidak bisa menerima; Bekasi tidak bisa menerima lebih dari yang dikirim.
        $rev = (int) DB::table('sync_records')->where('record_key', 'tr-1')->value('rev');
        $got = fn (float $q) => ['collection' => 'stock_transfers', 'key' => 'tr-1', 'base_rev' => $rev,
            'data' => ['status' => 'received', 'receivedQty' => $q, 'receivedAt' => '2026-10-10T09:00:00Z'] + $t];
        $this->push($depok, [$got(10)])->assertJsonPath('results.0.status', 'rejected')->assertJsonPath('results.0.message', 'Hanya cabang tujuan yang bisa menerima kiriman ini.');
        $this->push($bekasi, [$got(12)])->assertJsonPath('results.0.status', 'rejected')->assertJsonPath('results.0.message', 'Jumlah diterima tidak boleh melebihi jumlah dikirim.');

        // Bekasi menerima 8 (selisih 2) dan mencatat stok masuk di cabangnya.
        $this->push($bekasi, [$got(8), $this->led('m3', 1, 'Transfer Masuk', 8)])
            ->assertJsonPath('results.0.status', 'applied')->assertJsonPath('results.1.status', 'applied');
        $all = $this->pull($owner);
        $this->assertSame(10.0, $this->balance($all, 0));
        $this->assertSame(8.0, $this->balance($all, 1));

        // Sudah diterima: tidak bisa diterima lagi atau diubah jumlahnya.
        $rev2 = (int) DB::table('sync_records')->where('record_key', 'tr-1')->value('rev');
        $again = $got(10); $again['base_rev'] = $rev2;
        $this->push($bekasi, [$again])->assertJsonPath('results.0.status', 'rejected')->assertJsonPath('results.0.message', 'Kiriman ini sudah diterima.');

        // Kasir tidak bisa membuat kiriman; kepala cabang hanya dari cabangnya sendiri.
        $t2 = ['id' => 'tr-2', 'from' => $this->key(1), 'to' => $this->key(0)] + $t;
        $this->push($bekasi, [['collection' => 'stock_transfers', 'key' => 'tr-2', 'data' => $t2]])
            ->assertJsonPath('results.0.status', 'rejected')->assertJsonPath('results.0.message', 'Hanya kepala cabang atau owner yang bisa mengirim bahan.');
        $kepala = $this->token($this->staff('manager', 1));
        $this->push($kepala, [['collection' => 'stock_transfers', 'key' => 'tr-3', 'data' => ['id' => 'tr-3'] + $t]])
            ->assertJsonPath('results.0.status', 'rejected')->assertJsonPath('results.0.message', 'Kiriman hanya bisa dibuat dari cabang Anda sendiri.');
        $this->push($kepala, [['collection' => 'stock_transfers', 'key' => 'tr-2', 'data' => $t2]])->assertJsonPath('results.0.status', 'applied');
    }

    public function test_suppliers_and_purchases_need_silver(): void {
        $owner = $this->token($this->owner);
        $sup = ['collection' => 'stock_suppliers', 'key' => 's1', 'data' => ['id' => 's1', 'name' => 'Toko A']];
        $this->push($owner, [$sup, ['collection' => 'stock_purchases', 'key' => 'p1', 'data' => ['id' => 'p1']]])
            ->assertJsonPath('results.0.message', 'Supplier & belanja bahan membutuhkan paket Silver.')
            ->assertJsonPath('results.1.message', 'Supplier & belanja bahan membutuhkan paket Silver.');
        $this->owner->business->grants()->create(['package' => 'Silver', 'reason' => 'Uji', 'starts_at' => now()->subMinute(), 'ends_at' => now()->addWeek(), 'granted_by' => $this->owner->id]);
        $this->push($owner, [$sup])->assertJsonPath('results.0.status', 'applied');
        $this->assertTrue($this->owner->business->fresh()->allows('suppliers'));
        $this->assertFalse($this->owner->business->fresh()->allows('loyalty'));
    }

    public function test_old_business_wide_ledger_rows_are_moved_to_their_outlet(): void {
        $b = $this->owner->business;
        $ids = $b->outlets()->orderBy('id')->pluck('id');
        foreach ([['a', 'srv-'.$ids[1]], ['b', 'default']] as [$k, $o]) {
            DB::table('sync_records')->insert(['business_id' => $b->id, 'collection' => 'stock_ledger', 'record_key' => $k, 'outlet_id' => null,
                'data' => json_encode(['id' => $k, 'itemId' => 'x', 'outletId' => $o, 'qty' => 1]), 'deleted' => false, 'rev' => 1, 'created_at' => now(), 'updated_at' => now()]);
        }
        (require database_path('migrations/2026_10_10_000017_scope_stock_ledger_to_outlets.php'))->up();
        $this->assertSame([(int) $ids[1], (int) $ids[0]], DB::table('sync_records')->whereIn('record_key', ['a', 'b'])->orderBy('record_key')->pluck('outlet_id')->map(fn ($v) => (int) $v)->all());
    }
}
