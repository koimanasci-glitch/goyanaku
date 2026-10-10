<?php
namespace Tests\Feature;

use App\Models\{Business, Outlet, User};
use App\WhatsApp\Replies;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

/** Zona waktu per cabang (keputusan Paduka 10 Oktober 2026): WIB / WITA / WIT. */
class OutletTimezoneTest extends TestCase {
    use RefreshDatabase;

    private User $owner;
    private Business $business;

    protected function setUp(): void {
        parent::setUp();
        $this->business = Business::create(['name' => 'Laundry', 'trial_ends_at' => now()->addMonth()]);
        $this->business->outlets()->create(['name' => 'Pusat']);
        $this->business->outlets()->create(['name' => 'Bali']);
        $user = new User(['name' => 'Owner', 'email' => uniqid().'@example.test', 'password' => 'PasswordAman123']);
        $user->business()->associate($this->business); $user->save();
        $this->owner = $user->fresh();
    }

    private function token(): string {
        $this->app['auth']->forgetGuards();
        return $this->postJson('/api/session', ['email' => $this->owner->email, 'password' => 'PasswordAman123'])->json('token');
    }

    public function test_owner_sets_branch_timezone_from_api_and_app_profile(): void {
        [$pusat, $bali] = $this->business->outlets()->orderBy('id')->get()->all();
        $this->assertSame(['Asia/Jakarta', 'WIB'], [$pusat->tz(), $pusat->tzLabel()]);
        $t = $this->token();
        $this->withToken($t)->patchJson('/api/outlets/'.$bali->id, ['timezone' => 'Asia/Makassar'])->assertOk();
        $this->assertSame('WITA', $bali->fresh()->tzLabel());
        $this->withToken($t)->patchJson('/api/outlets/'.$bali->id, ['timezone' => 'Europe/London'])->assertStatus(422);
        // Profil outlet dari aplikasi membawa "tz".
        $this->app['auth']->forgetGuards();
        $this->withToken($t)->postJson('/api/sync/push', ['device_id' => 'device-aaaa-1111', 'changes' => [[
            'op_id' => (string) Str::uuid(), 'collection' => 'outlet_profiles', 'key' => 'srv-'.$pusat->id, 'data' => ['id' => 'srv-'.$pusat->id, 'name' => 'Pusat', 'tz' => 'WIT'],
        ]]])->assertJsonPath('results.0.status', 'applied');
        $this->assertSame('Asia/Jayapura', $pusat->fresh()->tz());
        $this->app['auth']->forgetGuards();
        $outlets = collect($this->withToken($t)->getJson('/api/me')->json('outlets'));
        $this->assertSame(['WIT', 'WITA'], $outlets->pluck('tz')->all());
    }

    public function test_whatsapp_due_time_uses_the_branch_timezone(): void {
        $bali = $this->business->outlets()->orderBy('id')->get()[1];
        $bali->timezone = 'Asia/Makassar'; $bali->save();
        DB::table('order_index')->insert(['business_id' => $this->business->id, 'outlet_id' => $bali->id, 'record_key' => 'BAL-261010-1-0001',
            'status' => 'cuci', 'total' => 21000, 'paid' => 0, 'customer' => 'Siti', 'customer_key' => 'phone:6281234567890',
            'ordered_at' => now(), 'due_at' => '2026-10-10 08:00:00', 'deleted' => false, 'created_at' => now(), 'updated_at' => now()]);
        $device = (object) ['business_id' => $this->business->id, 'outlet_id' => $bali->id];
        $reply = (new Replies())->status($device, '6281234567890', 'cek BAL-261010-1-0001');
        $this->assertStringContainsString('10/10/2026 16:00 WITA', $reply);
        $this->assertStringNotContainsString('WIB', $reply);
    }
}
