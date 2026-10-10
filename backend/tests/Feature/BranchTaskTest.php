<?php
namespace Tests\Feature;

use App\Models\{Business, User};
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

/** Kelola Cabang Ini: kas dari pemilik masuk ke laci kas satu HP kasir cabang, sekali saja (10 Oktober 2026). */
class BranchTaskTest extends TestCase {
    use RefreshDatabase;

    private User $owner;

    protected function setUp(): void {
        parent::setUp();
        $business = Business::create(['name' => 'Laundry', 'trial_ends_at' => now()->addMonth()]);
        $business->outlets()->create(['name' => 'Pusat']);
        $business->outlets()->create(['name' => 'Bekasi']);
        $user = new User(['name' => 'Owner', 'email' => uniqid().'@example.test', 'password' => 'PasswordAman123']);
        $user->business()->associate($business); $user->save();
        $this->owner = $user->fresh();
    }

    private function staff(string $role, int $i): User {
        $u = new User(['name' => ucfirst($role).$i, 'email' => $role.uniqid().'@example.test', 'password' => 'PasswordAman123']);
        $u->business_id = $this->owner->business_id; $u->role = $role;
        $u->outlet_id = $this->owner->business->outlets()->orderBy('id')->get()[$i]->id; $u->save();
        return $u->fresh();
    }

    private function token(User $u): string {
        $this->app['auth']->forgetGuards();
        return $this->postJson('/api/session', ['email' => $u->email, 'password' => 'PasswordAman123'])->json('token');
    }

    private function push(string $token, array $changes, string $device) {
        $this->app['auth']->forgetGuards();
        return $this->withToken($token)->postJson('/api/sync/push', ['device_id' => $device, 'changes' => array_map(
            fn ($c) => $c + ['op_id' => (string) Str::uuid()], $changes)]);
    }

    private function pull(string $token): array {
        $this->app['auth']->forgetGuards();
        return array_values(array_filter($this->withToken($token)->getJson('/api/sync/pull?cursor=0')->assertOk()->json('records'),
            fn ($r) => $r['collection'] === 'branch_tasks'));
    }

    private function key(int $i): string { return 'srv-'.$this->owner->business->outlets()->orderBy('id')->get()[$i]->id; }

    private function rev(string $key): int { return (int) DB::table('sync_records')->where('record_key', $key)->value('rev'); }

    public function test_cash_task_is_claimed_once_by_a_branch_cashier_phone(): void {
        $owner = $this->token($this->owner);
        $task = ['id' => 'bt-1', 'kind' => 'kas_out', 'amount' => 500000, 'note' => 'Tarik uang pemilik', 'o' => $this->key(1), 'at' => '2026-10-10T08:00:00Z'];
        $this->push($owner, [['collection' => 'branch_tasks', 'key' => 'bt-1', 'outlet' => $this->key(1), 'data' => $task + ['claimedBy' => 'x']]], 'owner-phone-1')
            ->assertJsonPath('results.0.status', 'applied');
        $stored = json_decode(DB::table('sync_records')->where('record_key', 'bt-1')->value('data'), true);
        $this->assertSame('Owner', $stored['by']);
        $this->assertArrayNotHasKey('claimedBy', $stored);

        // Kasir Bekasi melihatnya, pegawai Bekasi (tanpa laci) dan kasir Pusat tidak.
        $kasir = $this->token($this->staff('kasir', 1));
        $this->assertCount(1, $this->pull($kasir));
        $this->assertCount(0, $this->pull($this->token($this->staff('produksi', 1))));
        $this->assertCount(0, $this->pull($this->token($this->staff('kasir', 0))));

        // Kasir tidak bisa membuat atau mengubah isi; hanya mengambil dengan id HP-nya sendiri.
        $this->push($kasir, [['collection' => 'branch_tasks', 'key' => 'bt-2', 'outlet' => $this->key(1), 'data' => $task]], 'kasir-phone-1')
            ->assertJsonPath('results.0.message', 'Hanya pemilik atau kepala cabang yang bisa mencatat untuk cabang ini.');
        $claim = fn (string $dev, array $extra = []) => ['collection' => 'branch_tasks', 'key' => 'bt-1', 'outlet' => $this->key(1), 'base_rev' => $this->rev('bt-1'),
            'data' => array_merge($stored, ['claimedBy' => $dev, 'claimedAt' => '2026-10-10T08:01:00Z'], $extra)];
        $this->push($kasir, [$claim('kasir-phone-1', ['amount' => 5])], 'kasir-phone-1')
            ->assertJsonPath('results.0.message', 'Catatan cabang tidak bisa diubah. Batalkan lalu catat ulang.');
        $this->push($kasir, [$claim('phone-lain')], 'kasir-phone-1')->assertJsonPath('results.0.message', 'Catatan hanya bisa diambil oleh HP ini sendiri.');
        $this->push($kasir, [$claim('kasir-phone-1')], 'kasir-phone-1')->assertJsonPath('results.0.status', 'applied');

        // HP kasir kedua tidak bisa mengambil lagi; pemilik tidak bisa membatalkan yang sudah masuk laci.
        $kasir2 = $this->token($this->staff('kasir', 1));
        $this->push($kasir2, [$claim('kasir-phone-2')], 'kasir-phone-2')->assertJsonPath('results.0.message', 'Catatan ini sudah masuk ke laci kas HP lain.');
        $this->push($owner, [['collection' => 'branch_tasks', 'key' => 'bt-1', 'deleted' => true, 'base_rev' => $this->rev('bt-1')]], 'owner-phone-1')
            ->assertJsonPath('results.0.message', 'Sudah masuk ke laci kas cabang. Catat kebalikannya bila perlu dibatalkan.');
    }

    public function test_owner_can_cancel_unclaimed_and_opname_request_reaches_stock_staff(): void {
        $owner = $this->token($this->owner);
        $this->push($owner, [
            ['collection' => 'branch_tasks', 'key' => 'bt-9', 'outlet' => $this->key(1), 'data' => ['id' => 'bt-9', 'kind' => 'expense', 'amount' => 20000, 'o' => $this->key(1)]],
            ['collection' => 'branch_tasks', 'key' => 'bt-8', 'outlet' => $this->key(1), 'data' => ['id' => 'bt-8', 'kind' => 'opname', 'note' => 'Cek deterjen', 'o' => $this->key(1)]],
            ['collection' => 'branch_tasks', 'key' => 'bt-7', 'outlet' => $this->key(1), 'data' => ['id' => 'bt-7', 'kind' => 'kas_in', 'amount' => 0, 'o' => $this->key(1)]],
        ], 'owner-phone-1')->assertJsonPath('results.0.status', 'applied')->assertJsonPath('results.1.status', 'applied')
            ->assertJsonPath('results.2.message', 'Isi jumlah uang yang benar.');
        $this->assertSame(['bt-8'], array_column($this->pull($this->token($this->staff('produksi', 1))), 'key'));
        $this->push($owner, [['collection' => 'branch_tasks', 'key' => 'bt-9', 'deleted' => true, 'base_rev' => $this->rev('bt-9')]], 'owner-phone-1')
            ->assertJsonPath('results.0.status', 'applied');
    }
}
