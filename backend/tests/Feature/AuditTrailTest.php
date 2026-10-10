<?php
namespace Tests\Feature;

use App\Models\{Business, User};
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

/** Riwayat aktivitas tersimpan di server per cabang, tidak bisa diubah/dihapus (10 Oktober 2026). */
class AuditTrailTest extends TestCase {
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

    private function staff(string $role, int $i, string $name): User {
        $u = new User(['name' => $name, 'email' => $role.uniqid().'@example.test', 'password' => 'PasswordAman123']);
        $u->business_id = $this->owner->business_id; $u->role = $role;
        $u->outlet_id = $this->owner->business->outlets()->orderBy('id')->get()[$i]->id; $u->save();
        return $u->fresh();
    }

    private function token(User $u): string {
        $this->app['auth']->forgetGuards();
        return $this->postJson('/api/session', ['email' => $u->email, 'password' => 'PasswordAman123'])->json('token');
    }

    private function push(string $token, array $changes) {
        $this->app['auth']->forgetGuards();
        return $this->withToken($token)->postJson('/api/sync/push', ['device_id' => 'device-aaaa-1111', 'changes' => array_map(
            fn ($c) => $c + ['op_id' => (string) Str::uuid()], $changes)]);
    }

    private function audits(string $token): array {
        $this->app['auth']->forgetGuards();
        $r = $this->withToken($token)->getJson('/api/sync/pull?cursor=0')->assertOk()->json('records');
        return array_values(array_filter($r, fn ($x) => $x['collection'] === 'audit'));
    }

    private function key(int $i): string { return 'srv-'.$this->owner->business->outlets()->orderBy('id')->get()[$i]->id; }

    public function test_owner_sees_every_branch_history_stamped_with_the_real_account(): void {
        $kasir = $this->token($this->staff('kasir', 1, 'Rina'));
        // HP mengaku "by: Owner", server mencap nama akun yang sebenarnya.
        $this->push($kasir, [['collection' => 'audit', 'key' => 'a-1', 'outlet' => $this->key(1),
            'data' => ['id' => 'a-1', 'ic' => '✕', 't' => 'Batal pesanan', 's' => 'GY-9 · Rp45.000', 'at' => '2026-10-10T03:00:00Z', 'by' => 'Owner']]])
            ->assertJsonPath('results.0.status', 'applied');
        $owner = $this->token($this->owner);
        $this->push($owner, [['collection' => 'audit', 'key' => 'a-2', 'outlet' => $this->key(0), 'data' => ['id' => 'a-2', 't' => 'Ubah harga', 's' => 'Cuci', 'at' => '2026-10-10T04:00:00Z']]]);

        $all = $this->audits($owner);
        $this->assertSame(['a-1', 'a-2'], array_column($all, 'key'));
        $this->assertSame(['Rina', 'kasir', $this->key(1)], [$all[0]['data']['by'], $all[0]['data']['role'], $all[0]['outlet']]);

        // Kepala cabang Bekasi hanya melihat riwayat Bekasi; kasir tidak menerima riwayat.
        $kepala = $this->token($this->staff('manager', 1, 'Dodi'));
        $this->assertSame(['a-1'], array_column($this->audits($kepala), 'key'));
        $this->assertSame([], $this->audits($kasir));
    }

    public function test_history_cannot_be_changed_or_deleted_even_by_the_owner(): void {
        $owner = $this->token($this->owner);
        $entry = ['id' => 'a-1', 't' => 'Tarik uang', 's' => 'Rp500.000', 'at' => '2026-10-10T03:00:00Z'];
        $this->push($owner, [['collection' => 'audit', 'key' => 'a-1', 'outlet' => $this->key(1), 'data' => $entry]]);
        $rev = (int) DB::table('sync_records')->where('record_key', 'a-1')->value('rev');
        $this->push($owner, [['collection' => 'audit', 'key' => 'a-1', 'outlet' => $this->key(1), 'base_rev' => $rev, 'data' => ['s' => 'Rp5.000'] + $entry]])
            ->assertJsonPath('results.0.status', 'rejected')->assertJsonPath('results.0.message', 'Riwayat aktivitas tidak bisa diubah.');
        $this->push($owner, [['collection' => 'audit', 'key' => 'a-1', 'outlet' => $this->key(1), 'base_rev' => $rev, 'deleted' => true]])
            ->assertJsonPath('results.0.status', 'rejected')->assertJsonPath('results.0.message', 'Riwayat aktivitas tidak bisa dihapus.');
        // Kiriman ulang yang sama (HP mengirim lagi) diterima tanpa mengubah apa pun.
        $this->push($owner, [['collection' => 'audit', 'key' => 'a-1', 'outlet' => $this->key(1), 'base_rev' => $rev, 'data' => $entry]])
            ->assertJsonPath('results.0.status', 'applied');
        $this->assertSame('Rp500.000', json_decode(DB::table('sync_records')->where('record_key', 'a-1')->value('data'), true)['s']);
    }
}
