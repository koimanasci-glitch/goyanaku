<?php
namespace Tests\Feature;

use App\Models\{Business, User};
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

/** Komplain & klaim + foto cucian (Tahap 2 fitur 9, 10 Oktober 2026). */
class ComplaintTest extends TestCase {
    use RefreshDatabase;

    private User $owner;

    protected function setUp(): void {
        parent::setUp();
        $business = Business::create(['name' => 'Laundry', 'trial_ends_at' => now()->addMonth()]);
        $business->outlets()->create(['name' => 'Pusat']);
        $user = new User(['name' => 'Owner', 'email' => uniqid().'@example.test', 'password' => 'PasswordAman123']);
        $user->business()->associate($business); $user->save();
        $this->owner = $user->fresh();
    }

    private function staff(string $role): User {
        $u = new User(['name' => 'Rina', 'email' => $role.uniqid().'@example.test', 'password' => 'PasswordAman123']);
        $u->business_id = $this->owner->business_id; $u->role = $role;
        $u->outlet_id = $this->owner->business->outlets()->value('id'); $u->save();
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

    private function rev(string $key): int { return (int) DB::table('sync_records')->where('record_key', $key)->value('rev'); }

    public function test_photos_are_kept_as_evidence(): void {
        $kasir = $this->token($this->staff('kasir'));
        $photo = ['order' => 'GY-1', 'slot' => 'in', 'img' => 'data:image/jpeg;base64,AAAA', 'at' => '2026-10-10T08:00:00Z'];
        $this->push($kasir, [['collection' => 'order_photos', 'key' => 'GY-1:in:a1', 'data' => $photo]])->assertJsonPath('results.0.status', 'applied');
        $this->assertSame('Rina', json_decode(DB::table('sync_records')->where('record_key', 'GY-1:in:a1')->value('data'), true)['by']);
        $this->push($kasir, [['collection' => 'order_photos', 'key' => 'GY-1:in:a1', 'base_rev' => $this->rev('GY-1:in:a1'), 'data' => ['img' => 'data:image/jpeg;base64,BBBB'] + $photo]])
            ->assertJsonPath('results.0.message', 'Foto cucian tidak bisa diubah.');
        $this->push($kasir, [['collection' => 'order_photos', 'key' => 'GY-1:in:a1', 'base_rev' => $this->rev('GY-1:in:a1'), 'deleted' => true]])
            ->assertJsonPath('results.0.message', 'Foto cucian hanya bisa dihapus pemilik.');
        $this->push($kasir, [['collection' => 'order_photos', 'key' => 'x', 'data' => ['order' => 'GY-1', 'slot' => 'in', 'img' => 'javascript:1']]])
            ->assertJsonPath('results.0.message', 'Foto cucian tidak lengkap.');
        $this->push($this->token($this->owner), [['collection' => 'order_photos', 'key' => 'GY-1:in:a1', 'base_rev' => $this->rev('GY-1:in:a1'), 'deleted' => true]])
            ->assertJsonPath('results.0.status', 'applied');
    }

    public function test_cashier_records_complaints_but_compensation_is_decided_by_owner(): void {
        $kasir = $this->token($this->staff('kasir'));
        $c = ['id' => 'k-1', 'order' => 'GY-1', 'customer' => 'Siti', 'type' => 'luntur', 'note' => 'Kemeja putih kena warna', 'status' => 'baru', 'at' => '2026-10-10T08:00:00Z'];
        $this->push($kasir, [['collection' => 'complaints', 'key' => 'k-1', 'data' => $c]])->assertJsonPath('results.0.status', 'applied');
        $paid = ['status' => 'selesai', 'result' => 'ganti', 'amount' => 50000] + $c;
        $this->push($kasir, [['collection' => 'complaints', 'key' => 'k-1', 'base_rev' => $this->rev('k-1'), 'data' => $paid]])
            ->assertJsonPath('results.0.message', 'Ganti rugi uang diputuskan pemilik atau kepala cabang.');
        $this->push($kasir, [['collection' => 'complaints', 'key' => 'k-1', 'base_rev' => $this->rev('k-1'), 'data' => ['status' => 'selesai'] + $c]])
            ->assertJsonPath('results.0.message', 'Pilih hasil penyelesaian komplain.');
        // Kasir boleh menyelesaikan dengan cuci ulang gratis; sesudah selesai tidak bisa diubah kasir.
        $redo = ['status' => 'selesai', 'result' => 'ulang'] + $c;
        $this->push($kasir, [['collection' => 'complaints', 'key' => 'k-1', 'base_rev' => $this->rev('k-1'), 'data' => $redo]])->assertJsonPath('results.0.status', 'applied');
        $stored = json_decode(DB::table('sync_records')->where('record_key', 'k-1')->value('data'), true);
        $this->assertSame(['Rina', 'Rina'], [$stored['by'], $stored['closedBy']]);
        $this->push($kasir, [['collection' => 'complaints', 'key' => 'k-1', 'base_rev' => $this->rev('k-1'), 'data' => ['status' => 'proses'] + $stored]])
            ->assertJsonPath('results.0.message', 'Komplain yang sudah selesai hanya bisa diubah pemilik atau kepala cabang.');
        // Pemilik memutuskan ganti rugi.
        $this->push($this->token($this->owner), [['collection' => 'complaints', 'key' => 'k-1', 'base_rev' => $this->rev('k-1'), 'data' => ['result' => 'ganti', 'amount' => 50000] + $stored]])
            ->assertJsonPath('results.0.status', 'applied');
        $this->push($kasir, [['collection' => 'complaints', 'key' => 'k-1', 'base_rev' => $this->rev('k-1'), 'deleted' => true]])
            ->assertJsonPath('results.0.message', 'Komplain hanya bisa dihapus pemilik.');
    }
}
