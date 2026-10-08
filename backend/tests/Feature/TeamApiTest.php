<?php
namespace Tests\Feature;

use App\Models\{Business, User};
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

/** Login nomor HP + PIN, Kelola Pegawai, Kelola Cabang, dan HP outlet (keputusan pengguna 8 Oktober 2026). */
class TeamApiTest extends TestCase {
    use RefreshDatabase;

    private User $owner;
    private string $ownerToken;

    protected function setUp(): void {
        parent::setUp();
        $this->owner = $this->makeOwner('Laundry Bekasi');
        $this->ownerToken = $this->passwordToken($this->owner);
    }

    private function makeOwner(string $name, bool $expired = false): User {
        $business = Business::create(['name' => $name, 'trial_ends_at' => $expired ? now()->subDay() : now()->addMonth()]);
        $business->outlets()->create(['name' => $name.' — Pusat']);
        $user = new User(['name' => 'Owner', 'email' => uniqid().'@example.test', 'password' => 'PasswordAman123']);
        $user->business()->associate($business); $user->save();
        return $user->fresh();
    }

    private function passwordToken(User $u): string {
        $this->app['auth']->forgetGuards();
        return $this->postJson('/api/session', ['email' => $u->email, 'password' => 'PasswordAman123'])->json('token');
    }

    private function api(string $method, string $uri, array $data = [], ?string $token = null) {
        $this->app['auth']->forgetGuards(); $this->flushHeaders();
        if ($token !== '') $this->withToken($token ?? $this->ownerToken);
        return $this->json($method, '/api'.$uri, $data);
    }

    private function pusat(): int { return (int) $this->owner->business->outlets()->orderBy('id')->value('id'); }

    private function member(array $data = []): array {
        return $this->api('POST', '/team', $data + ['name' => 'Siti', 'role' => 'kasir', 'outlet_id' => $this->pusat(), 'phone' => '0812-3456-7890', 'pin' => '482915'])
            ->assertCreated()->json('member');
    }

    private function pinLogin(string $phone, string $pin, string $device = 'hp-siti-0001') {
        return $this->api('POST', '/session/pin', ['phone' => $phone, 'pin' => $pin, 'device_id' => $device], '');
    }

    // ---------- login PIN ----------

    public function test_owner_creates_staff_who_logs_in_with_phone_and_pin(): void {
        $member = $this->member();
        $this->assertSame(['6281234567890', true, 'kasir', $this->pusat()], [$member['phone'], $member['has_pin'], $member['role'], $member['outlet_id']]);
        $this->assertNull(User::find($member['id'])->email);
        $token = $this->pinLogin('081234567890', '482915')->assertOk()->json('token');
        $me = $this->api('GET', '/me', [], $token)->assertOk();
        $me->assertJsonPath('user.role', 'kasir')->assertJsonPath('user.login', 'pin')->assertJsonPath('user.outlet_id', $this->pusat())
            ->assertJsonCount(1, 'outlets')->assertJsonPath('access.cashier_device_limit', 2);
        $this->assertNotEmpty($me->json('note.prefix'));
        // PIN tidak pernah ikut terkirim.
        $this->assertStringNotContainsString('482915', $me->getContent());
        $this->assertNotSame('482915', User::find($member['id'])->pin);
    }

    public function test_wrong_pin_locks_the_account_until_owner_resets_it(): void {
        $member = $this->member();
        foreach (range(1, 5) as $i) $this->pinLogin('081234567890', '111222')->assertStatus(422);
        $this->pinLogin('081234567890', '482915')->assertStatus(422)->assertJsonValidationErrors('pin');
        $this->assertNotNull(User::find($member['id'])->pin_locked_until);
        $this->assertDatabaseHas('audit_events', ['action' => 'pin.locked']);
        $this->api('POST', '/team/'.$member['id'].'/pin', ['pin' => '739104'])->assertNoContent();
        $this->pinLogin('081234567890', '739104')->assertOk();
    }

    public function test_weak_pin_duplicate_phone_and_missing_login_are_rejected(): void {
        foreach (['123456', '111111', '654321'] as $weak) {
            $this->api('POST', '/team', ['name' => 'A', 'role' => 'kasir', 'outlet_id' => $this->pusat(), 'phone' => '081111111111', 'pin' => $weak])->assertStatus(422)->assertJsonValidationErrors('pin');
        }
        $this->member();
        $this->api('POST', '/team', ['name' => 'B', 'role' => 'kurir', 'outlet_id' => $this->pusat(), 'phone' => '6281234567890', 'pin' => '482915'])->assertStatus(422)->assertJsonValidationErrors('phone');
        $this->api('POST', '/team', ['name' => 'C', 'role' => 'kasir', 'outlet_id' => $this->pusat()])->assertStatus(422)->assertJsonValidationErrors('phone');
        $this->api('POST', '/team', ['name' => 'D', 'role' => 'owner', 'outlet_id' => $this->pusat(), 'phone' => '081222222222', 'pin' => '482915'])->assertStatus(422)->assertJsonValidationErrors('role');
    }

    public function test_one_staff_account_is_active_on_one_phone(): void {
        $this->member();
        $first = $this->pinLogin('081234567890', '482915', 'hp-lama-0001')->json('token');
        $second = $this->pinLogin('081234567890', '482915', 'hp-baru-0002')->json('token');
        $this->api('GET', '/me', [], $first)->assertUnauthorized();
        $this->api('GET', '/me', [], $second)->assertOk();
        // Owner boleh masuk di beberapa perangkat.
        $again = $this->passwordToken($this->owner);
        $this->api('GET', '/me', [], $this->ownerToken)->assertOk();
        $this->api('GET', '/me', [], $again)->assertOk();
    }

    public function test_owner_cannot_use_pin_login_and_staff_cannot_manage_team(): void {
        $this->owner->forceFill(['phone' => '6281999999999', 'pin' => '482915'])->save();
        $this->pinLogin('081999999999', '482915')->assertStatus(422);
        $this->member();
        $kasir = $this->pinLogin('081234567890', '482915')->json('token');
        $this->api('GET', '/team', [], $kasir)->assertForbidden();
        $this->api('POST', '/outlets', ['name' => 'Cabang Gelap'], $kasir)->assertForbidden();
        $this->api('PATCH', '/business', ['allow_debt' => false], $kasir)->assertForbidden();
        $this->api('GET', '/team', [], '')->assertUnauthorized();
    }

    public function test_staff_changes_own_pin(): void {
        $this->member();
        $token = $this->pinLogin('081234567890', '482915')->json('token');
        $this->api('POST', '/me/pin', ['current_pin' => '000111', 'pin' => '739104'], $token)->assertStatus(422);
        $this->api('POST', '/me/pin', ['current_pin' => '482915', 'pin' => '739104'], $token)->assertNoContent();
        $this->api('GET', '/me', [], $token)->assertOk();
        $this->pinLogin('081234567890', '482915')->assertStatus(422);
        $this->pinLogin('081234567890', '739104')->assertOk();
    }

    // ---------- penempatan ----------

    public function test_moving_outlet_applies_without_relogin_and_role_change_ends_the_session(): void {
        $cabang = $this->api('POST', '/outlets', ['name' => 'Cabang Depok', 'code' => 'dpk'])->assertCreated()->json('outlet');
        $member = $this->member();
        $token = $this->pinLogin('081234567890', '482915')->json('token');
        $this->api('PATCH', '/team/'.$member['id'], ['outlet_id' => $cabang['id']])->assertOk()->assertJsonPath('member.outlet_id', $cabang['id']);
        $this->api('GET', '/me', [], $token)->assertOk()->assertJsonPath('user.outlet_id', $cabang['id'])->assertJsonPath('note.prefix', 'DPK')->assertJsonPath('outlets.0.id', $cabang['id']);
        $this->api('PATCH', '/team/'.$member['id'], ['role' => 'produksi'])->assertOk();
        $this->api('GET', '/me', [], $token)->assertUnauthorized();
        $this->assertDatabaseHas('audit_events', ['action' => 'team.updated']);
    }

    public function test_deactivated_staff_loses_access_but_history_stays(): void {
        $member = $this->member();
        $token = $this->pinLogin('081234567890', '482915')->json('token');
        $this->api('POST', '/team/'.$member['id'].'/deactivate')->assertOk()->assertJsonPath('member.active', false);
        $this->api('GET', '/me', [], $token)->assertUnauthorized();
        $this->pinLogin('081234567890', '482915')->assertStatus(422);
        $this->assertDatabaseHas('users', ['id' => $member['id']]);
        $this->api('POST', '/team/'.$member['id'].'/activate')->assertOk()->assertJsonPath('member.active', true);
        $this->pinLogin('081234567890', '482915')->assertOk();
    }

    public function test_owner_only_manages_own_business(): void {
        $member = $this->member();
        $other = $this->makeOwner('Laundry Lain'); $otherToken = $this->passwordToken($other);
        $this->api('PATCH', '/team/'.$member['id'], ['role' => 'kurir'], $otherToken)->assertNotFound();
        $this->api('POST', '/team/'.$member['id'].'/pin', ['pin' => '739104'], $otherToken)->assertNotFound();
        $this->api('PATCH', '/outlets/'.$this->pusat(), ['name' => 'Diambil alih'], $otherToken)->assertNotFound();
        $this->api('POST', '/team', ['name' => 'X', 'role' => 'kasir', 'outlet_id' => $this->pusat(), 'phone' => '081333333333', 'pin' => '482915'], $otherToken)->assertStatus(422);
        $this->assertCount(0, $this->api('GET', '/team', [], $otherToken)->json('team'));
    }

    public function test_admin_outlet_remains_a_role_but_cannot_manage_team(): void {
        $roles = collect($this->api('GET', '/team')->json('roles'))->pluck('key')->all();
        $this->assertEqualsCanonicalizing(['kasir', 'produksi', 'kurir', 'manager'], $roles);
        $this->member(['role' => 'manager']);
        $token = $this->pinLogin('081234567890', '482915')->json('token');
        $this->api('GET', '/me', [], $token)->assertJsonPath('user.role_label', 'Admin Outlet');
        $this->api('GET', '/team', [], $token)->assertForbidden();
    }

    // ---------- kurir ----------

    public function test_courier_account_always_has_courier_data_with_exactly_one_outlet(): void {
        $cabang = $this->api('POST', '/outlets', ['name' => 'Cabang Depok'])->json('outlet');
        $member = $this->member(['role' => 'kurir', 'name' => 'Budi']);
        $key = $member['courier_key'];
        $read = fn () => json_decode(DB::table('sync_records')->where('collection', 'couriers')->where('record_key', $key)->value('data'), true);
        $this->assertSame(['Budi', ['srv-'.$this->pusat()], true, $member['id']], [$read()['name'], $read()['outlets'], $read()['active'], $read()['userId']]);
        $this->api('PATCH', '/team/'.$member['id'], ['outlet_id' => $cabang['id']])->assertOk();
        $this->assertSame(['srv-'.$cabang['id']], $read()['outlets']);
        $this->api('POST', '/team/'.$member['id'].'/deactivate');
        $this->assertFalse($read()['active']);
    }

    public function test_owner_links_an_old_courier_with_many_outlets_to_one_account_and_outlet(): void {
        $this->app['auth']->forgetGuards();
        $this->withToken($this->ownerToken)->postJson('/api/sync/push', ['device_id' => 'hp-owner-0001', 'changes' => [
            ['op_id' => (string) Str::uuid(), 'collection' => 'couriers', 'key' => 'kur-lama', 'data' => ['id' => 'kur-lama', 'name' => 'Pak Lama', 'phone' => '0813', 'outlets' => [], 'active' => true]],
        ]])->assertJsonPath('results.0.status', 'applied');
        $member = $this->member(['role' => 'kurir', 'name' => 'Pak Lama', 'courier_key' => 'kur-lama']);
        $this->assertSame('kur-lama', $member['courier_key']);
        $data = json_decode(DB::table('sync_records')->where('collection', 'couriers')->where('record_key', 'kur-lama')->value('data'), true);
        $this->assertSame(['srv-'.$this->pusat()], $data['outlets']);
        // Data kurir yang sama tidak bisa disambungkan ke dua akun.
        $this->api('POST', '/team', ['name' => 'Lain', 'role' => 'kurir', 'outlet_id' => $this->pusat(), 'phone' => '081444444444', 'pin' => '482915', 'courier_key' => 'kur-lama'])
            ->assertStatus(422)->assertJsonValidationErrors('courier_key');
    }

    // ---------- HP outlet bergantian ----------

    public function test_shared_outlet_phone_lists_names_and_logs_in_with_pin(): void {
        $cabang = $this->api('POST', '/outlets', ['name' => 'Cabang Depok'])->json('outlet');
        $siti = $this->member();
        $this->member(['name' => 'Andi', 'role' => 'produksi', 'phone' => '081555555555', 'pin' => '905713']);
        $jauh = $this->member(['name' => 'Jauh', 'phone' => '081666666666', 'pin' => '317420', 'outlet_id' => $cabang['id']]);
        $bind = $this->api('POST', '/devices/shared', ['device_id' => 'hp-outlet-0001', 'outlet_id' => $this->pusat(), 'label' => 'HP meja depan'])->assertCreated();
        $secret = $bind->json('device_secret');
        $roster = $this->api('POST', '/devices/roster', ['device_id' => 'hp-outlet-0001', 'device_secret' => $secret], '')->assertOk();
        $this->assertSame(['Andi', 'Siti'], collect($roster->json('staff'))->pluck('name')->all());
        $this->assertStringNotContainsString('6281', $roster->getContent());
        $login = fn (int $id, string $pin, ?string $s = null) => $this->api('POST', '/session/pin', ['user_id' => $id, 'pin' => $pin, 'device_id' => 'hp-outlet-0001', 'device_secret' => $s ?? $secret], '');
        $token = $login($siti['id'], '482915')->assertOk()->json('token');
        $this->api('GET', '/me', [], $token)->assertJsonPath('user.name', 'Siti');
        $login($jauh['id'], '317420')->assertStatus(422);               // pegawai outlet lain
        $login($siti['id'], '482915', 'kunci-palsu')->assertStatus(422); // HP tidak diikat
        $this->api('DELETE', '/devices/shared/'.$bind->json('id'))->assertNoContent();
        $this->api('POST', '/devices/roster', ['device_id' => 'hp-outlet-0001', 'device_secret' => $secret], '')->assertStatus(422);
        $login($siti['id'], '482915')->assertStatus(422);
    }

    // ---------- cabang ----------

    public function test_branch_limit_code_and_processing_location(): void {
        $pusat = $this->api('GET', '/outlets')->assertOk()->json('outlets.0');
        $this->assertSame([2, 'PUS'], [$this->api('GET', '/outlets')->json('limit'), $pusat['code']]);
        $cabang = $this->api('POST', '/outlets', ['name' => 'Cabang Bekasi', 'code' => 'bks', 'address' => 'Jl. Raya 1', 'phone' => '0218888888'])->assertCreated()->json('outlet');
        $this->assertSame(['BKS', 'Jl. Raya 1', true], [$cabang['code'], $cabang['address'], $cabang['active']]);
        // Basic/Trial: 1 pusat + 1 cabang (batas di repo tidak diubah).
        $this->api('POST', '/outlets', ['name' => 'Cabang Ketiga'])->assertStatus(422)->assertJsonValidationErrors('name');
        $this->api('PATCH', '/outlets/'.$cabang['id'], ['code' => 'PUS'])->assertStatus(422)->assertJsonValidationErrors('code');
        // Cabang hanya titik terima; cucian dikerjakan di pusat.
        $this->api('PATCH', '/outlets/'.$cabang['id'], ['process_outlet_id' => $pusat['id']])->assertOk()->assertJsonPath('outlet.process_outlet_id', $pusat['id']);
        $this->api('PATCH', '/outlets/'.$pusat['id'], ['process_outlet_id' => $cabang['id']])->assertStatus(422);
        $this->api('PATCH', '/outlets/'.$cabang['id'], ['process_outlet_id' => null])->assertOk()->assertJsonPath('outlet.process_outlet_id', null);
    }

    public function test_deactivated_branch_takes_no_new_data_and_frees_the_limit(): void {
        $cabang = $this->api('POST', '/outlets', ['name' => 'Cabang Bekasi'])->json('outlet');
        $member = $this->member(['outlet_id' => $cabang['id']]);
        $this->api('POST', '/outlets/'.$this->pusat().'/deactivate')->assertStatus(422);
        $this->api('POST', '/outlets/'.$cabang['id'].'/deactivate')->assertStatus(422); // masih ada pegawai aktif
        $this->api('POST', '/team/'.$member['id'].'/deactivate');
        $this->api('POST', '/outlets/'.$cabang['id'].'/deactivate')->assertOk()->assertJsonPath('outlet.active', false);
        $this->app['auth']->forgetGuards();
        $this->withToken($this->ownerToken)->postJson('/api/sync/push', ['device_id' => 'hp-owner-0001', 'changes' => [
            ['op_id' => (string) Str::uuid(), 'collection' => 'orders', 'key' => 'O1', 'outlet' => 'srv-'.$cabang['id'], 'data' => ['x' => 1]],
        ]])->assertJsonPath('results.0.status', 'rejected')->assertJsonPath('results.0.message', 'Cabang ini sudah dinonaktifkan owner.');
        $this->api('POST', '/outlets', ['name' => 'Cabang Baru'])->assertCreated();
        $this->api('POST', '/outlets/'.$cabang['id'].'/activate')->assertStatus(422); // batas paket penuh
    }

    // ---------- HP kasir per paket ----------

    public function test_cashier_phone_limit_follows_the_package(): void {
        $business = $this->owner->business;
        DB::table('subscriptions')->insert(['business_id' => $business->id, 'package' => 'Silver', 'starts_at' => now()->subDay(), 'ends_at' => now()->addMonth(),
            'source' => 'manual', 'reference' => 'TRF-1', 'created_at' => now(), 'updated_at' => now()]);
        $this->api('GET', '/me')->assertJsonPath('access.cashier_device_limit', 3);
        foreach (['hp-kasir-0001' => 1, 'hp-kasir-0002' => 2, 'hp-kasir-0003' => 3] as $device => $slot) {
            $this->api('POST', '/devices/claim', ['device_id' => $device, 'outlet_id' => $this->pusat()])->assertOk()->assertJsonPath('slot', $slot)->assertJsonPath('note.device', (string) $slot);
        }
        $this->api('POST', '/devices/claim', ['device_id' => 'hp-kasir-0004', 'outlet_id' => $this->pusat()])->assertStatus(422)
            ->assertJsonPath('errors.device_id.0', 'Maksimal 3 perangkat kasir per outlet.');
        $this->api('GET', '/me?device_id=hp-kasir-0002')->assertOk(); // owner: tanpa outlet tetap, awalan nota mengikuti outlet aktif di HP
        $this->assertCount(3, $this->api('GET', '/devices')->json('cashier'));
        $this->assertSame([2, 3, 4, 5], array_map(fn ($p) => config("goyana.packages.$p.cashier_devices"), ['Basic', 'Silver', 'Gold', 'Platinum']));
    }

    public function test_kurir_note_code_and_no_cashier_slot(): void {
        $member = $this->member(['role' => 'kurir']);
        $token = $this->pinLogin('081234567890', '482915', 'hp-kurir-0001')->json('token');
        $this->api('GET', '/me?device_id=hp-kurir-0001', [], $token)->assertJsonPath('note.device', 'K'.$member['id']);
        $this->api('POST', '/devices/claim', ['device_id' => 'hp-kurir-0001'], $token)->assertForbidden();
    }

    // ---------- setelan ----------

    public function test_owner_sets_whether_debt_is_allowed(): void {
        $this->api('GET', '/me')->assertJsonPath('business.allow_debt', true);
        $this->api('PATCH', '/business', ['allow_debt' => false])->assertOk()->assertJsonPath('business.allow_debt', false);
        $this->api('GET', '/me')->assertJsonPath('business.allow_debt', false);
    }

    public function test_expired_business_cannot_add_staff_or_branches(): void {
        $expired = $this->makeOwner('Habis', true); $token = $this->passwordToken($expired);
        $outlet = (int) $expired->business->outlets()->value('id');
        $this->api('POST', '/team', ['name' => 'A', 'role' => 'kasir', 'outlet_id' => $outlet, 'phone' => '081777777777', 'pin' => '482915'], $token)->assertForbidden();
        $this->api('POST', '/outlets', ['name' => 'Cabang'], $token)->assertForbidden();
    }

    // ---------- dashboard web ----------

    public function test_web_dashboard_creates_staff_with_phone_and_pin(): void {
        $this->actingAs($this->owner)->post('/team', ['name' => 'Rina', 'role' => 'kasir', 'outlet_id' => $this->pusat(), 'phone' => '081888888888', 'pin' => '482915'])
            ->assertRedirect()->assertSessionHasNoErrors();
        $rina = User::where('phone', '6281888888888')->firstOrFail();
        $this->get('/dashboard')->assertOk()->assertSee('+6281888888888')->assertSee('Ganti PIN');
        $this->post('/team/'.$rina->id.'/pin', ['pin' => '739104'])->assertRedirect()->assertSessionHasNoErrors();
        $this->app['auth']->forgetGuards();
        $this->pinLogin('081888888888', '739104')->assertOk();
    }
}
