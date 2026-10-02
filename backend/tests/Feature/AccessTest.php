<?php
namespace Tests\Feature;

use App\Models\{Business, User};
use App\Support\Totp;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AccessTest extends TestCase {
    use RefreshDatabase;

    private function owner(string $name = 'Laundry Satu', bool $expired = false): User {
        $business = Business::create(['name' => $name, 'trial_ends_at' => $expired ? now()->subDay() : now()->addMonthsNoOverflow(2)]);
        $business->outlets()->create(['name' => $name.' Pusat']);
        $user = new User(['name' => 'Pemilik', 'email' => uniqid().'@example.test', 'password' => 'PasswordAman123']);
        $user->business()->associate($business); $user->save();
        return $user->fresh();
    }

    private function admin(): User {
        $user = new User(['name' => 'Admin', 'email' => uniqid().'@example.test', 'password' => 'PasswordAman123']);
        $user->is_platform_admin = true; $user->save(); return $user;
    }

    private function staff(User $owner, string $role = 'kasir'): User {
        $this->actingAs($owner)->post('/team', [
            'name' => 'Pegawai '.$role, 'email' => $role.uniqid().'@example.test', 'role' => $role,
            'outlet_id' => $owner->business->outlets()->first()->id, 'password' => 'PasswordAman123',
        ])->assertRedirect();
        return User::where('role', $role)->latest('id')->first();
    }

    // ---------- packages & subscriptions ----------

    public function test_trial_is_basic_with_one_branch_then_read_only(): void {
        $owner = $this->owner();
        $access = $owner->business->currentAccess();
        $this->assertSame(['Basic', 'trial', false, 1, 2], [$access['package'], $access['source'], $access['read_only'], $access['branches'], $access['outlet_limit']]);
        $expired = $this->owner('Lama', true)->business->currentAccess();
        $this->assertTrue($expired['read_only']);
        $this->assertNull($expired['package']);
    }

    public function test_basic_allows_one_pusat_plus_one_branch(): void {
        $owner = $this->owner();
        $this->actingAs($owner)->post('/outlets', ['name' => 'Cabang 1'])->assertRedirect()->assertSessionHasNoErrors();
        $this->post('/outlets', ['name' => 'Cabang 2'])->assertSessionHasErrors('name');
        $this->assertSame(2, $owner->business->outlets()->count());
    }

    public function test_admin_records_payment_which_unlocks_expired_business_and_renews(): void {
        $owner = $this->owner('Bayar', true); $business = $owner->business; $admin = $this->admin();
        $url = '/admin/businesses/'.$business->id.'/subscriptions';
        $this->actingAsAdmin($admin)->post($url, ['package' => 'Silver', 'months' => 1, 'amount' => 65000, 'reference' => 'TRF-001'])->assertRedirect();
        $access = $business->currentAccess();
        $this->assertSame(['Silver', 'subscription', false, 3], [$access['package'], $access['source'], $access['read_only'], $access['outlet_limit']]);
        $firstEnd = $access['ends_at'];
        $this->post($url, ['package' => 'Silver', 'months' => 1, 'amount' => 65000, 'reference' => 'TRF-001'])->assertSessionHasErrors('reference');
        $this->post($url, ['package' => 'Silver', 'months' => 2, 'amount' => 130000, 'reference' => 'TRF-002'])->assertRedirect();
        $this->assertTrue($business->subscriptions()->latest('id')->first()->starts_at->equalTo($firstEnd));
        $this->assertDatabaseHas('audit_events', ['action' => 'subscription.recorded', 'actor_id' => $admin->id]);
        foreach ($business->subscriptions as $s) {
            $this->post($url.'/'.$s->id.'/cancel', ['reason' => 'Salah input'])->assertRedirect();
        }
        $this->assertTrue($business->currentAccess()['read_only']);
    }

    public function test_highest_active_package_wins_and_owner_cannot_record_payments(): void {
        $owner = $this->owner(); $business = $owner->business; $admin = $this->admin();
        $business->subscriptions()->create(['package' => 'Basic', 'starts_at' => now(), 'ends_at' => now()->addMonth(), 'source' => 'manual', 'reference' => 'A']);
        $business->grants()->create(['package' => 'Gold', 'reason' => 'Beta', 'starts_at' => now(), 'ends_at' => now()->addWeek(), 'granted_by' => $admin->id]);
        $this->assertSame('Gold', $business->currentAccess()['package']);
        $this->actingAs($owner)->post('/admin/businesses/'.$business->id.'/subscriptions', ['package' => 'Platinum', 'months' => 12, 'amount' => 0, 'reference' => 'X'])->assertForbidden();
    }

    // ---------- team & roles ----------

    public function test_owner_creates_kasir_who_cannot_use_owner_functions(): void {
        $owner = $this->owner(); $kasir = $this->staff($owner);
        $this->assertSame('kasir', $kasir->role);
        $this->assertTrue($kasir->hasPermission('orders.create'));
        $this->assertFalse($kasir->hasPermission('reports.view'));
        $this->assertFalse($kasir->hasPermission('prices.edit'));
        $this->post('/logout');
        $this->actingAs($kasir)->get('/dashboard')->assertOk()->assertSee('Kasir')->assertDontSee('Akun tim');
        $outlet = $owner->business->outlets()->first();
        $this->post('/outlets/'.$outlet->id.'/devices', ['label' => 'HP kasir'])->assertForbidden();
        $this->post('/team', ['name' => 'X', 'email' => 'x@example.test', 'role' => 'kasir', 'outlet_id' => $outlet->id, 'password' => 'PasswordAman123'])->assertForbidden();
        $this->post('/outlets', ['name' => 'Cabang'])->assertForbidden();
        $this->post('/team', ['name' => 'Y', 'email' => 'y@example.test', 'role' => 'owner', 'outlet_id' => $outlet->id, 'password' => 'PasswordAman123'])->assertForbidden();
    }

    public function test_owner_cannot_create_another_owner_or_assign_foreign_outlet(): void {
        $owner = $this->owner(); $other = $this->owner('Lain');
        $this->actingAs($owner)->post('/team', ['name' => 'Y', 'email' => 'y@example.test', 'role' => 'owner',
            'outlet_id' => $owner->business->outlets()->first()->id, 'password' => 'PasswordAman123'])->assertSessionHasErrors('role');
        $this->post('/team', ['name' => 'Z', 'email' => 'z@example.test', 'role' => 'kasir',
            'outlet_id' => $other->business->outlets()->first()->id, 'password' => 'PasswordAman123'])->assertSessionHasErrors('outlet_id');
        $this->assertDatabaseCount('users', 2);
    }

    public function test_staff_api_token_follows_role_and_assigned_outlet(): void {
        $owner = $this->owner();
        $this->actingAs($owner)->post('/outlets', ['name' => 'Cabang Rahasia']);
        $kurir = $this->staff($owner, 'kurir');
        $this->post('/logout');
        $token = $this->postJson('/api/session', ['email' => $kurir->email, 'password' => 'PasswordAman123'])->assertOk()->json('token');
        $this->assertSame(['business:read', 'courier.tasks'], $kurir->tokens()->sole()->abilities);
        $this->withToken($token)->getJson('/api/me')->assertOk()
            ->assertJsonPath('user.role', 'kurir')->assertJsonCount(1, 'outlets')->assertJsonMissing(['name' => 'Cabang Rahasia']);
    }

    public function test_deactivated_staff_lose_web_and_api_access_but_history_stays(): void {
        $owner = $this->owner(); $kasir = $this->staff($owner);
        $token = $kasir->createToken('android', ['business:read'], now()->addDay())->plainTextToken;
        $this->actingAs($owner)->post('/team/'.$kasir->id.'/deactivate')->assertRedirect();
        $this->assertDatabaseHas('users', ['id' => $kasir->id]);
        $this->assertSame(0, $kasir->tokens()->count());
        $this->post('/logout');
        $this->app['auth']->forgetGuards();
        $this->withToken($token)->getJson('/api/me')->assertUnauthorized();
        $this->postJson('/api/session', ['email' => $kasir->email, 'password' => 'PasswordAman123'])->assertUnprocessable();
        $this->post('/login', ['email' => $kasir->email, 'password' => 'PasswordAman123'])->assertSessionHasErrors('email');
        $this->assertGuest();
        $this->assertDatabaseHas('audit_events', ['action' => 'team.deactivated']);
    }

    public function test_owner_cannot_manage_staff_of_another_business(): void {
        $a = $this->owner('A'); $b = $this->owner('B'); $kasirB = $this->staff($b);
        $this->post('/logout');
        $this->actingAs($a)->post('/team/'.$kasirB->id.'/deactivate')->assertNotFound();
        $this->post('/team/'.$kasirB->id.'/password', ['password' => 'PasswordBaru1234'])->assertNotFound();
        $this->assertNull($kasirB->fresh()->deactivated_at);
    }

    public function test_read_only_business_cannot_add_staff_or_branches(): void {
        $owner = $this->owner('Habis', true);
        $outlet = $owner->business->outlets()->first();
        $this->actingAs($owner)->post('/team', ['name' => 'X', 'email' => 'x@example.test', 'role' => 'kasir', 'outlet_id' => $outlet->id, 'password' => 'PasswordAman123'])->assertForbidden();
        $this->post('/outlets', ['name' => 'Cabang'])->assertForbidden();
        $this->get('/dashboard')->assertOk()->assertSee('Mode baca saja');
    }

    public function test_password_reset_by_owner_signs_staff_out_of_phones(): void {
        $owner = $this->owner(); $kasir = $this->staff($owner);
        $kasir->createToken('android', ['business:read'], now()->addDay());
        $this->actingAs($owner)->post('/team/'.$kasir->id.'/password', ['password' => 'PasswordBaru1234'])->assertRedirect();
        $this->assertSame(0, $kasir->tokens()->count());
        $this->post('/logout');
        $this->postJson('/api/session', ['email' => $kasir->email, 'password' => 'PasswordBaru1234'])->assertOk();
    }

    // ---------- admin OTP ----------

    public function test_admin_must_set_up_and_pass_otp_before_admin_pages(): void {
        $admin = $this->admin();
        $this->post('/login', ['email' => $admin->email, 'password' => 'PasswordAman123'])->assertRedirect('/admin');
        $this->get('/admin')->assertRedirect('/admin/mfa/setup');
        $this->get('/admin/mfa/setup')->assertOk()->assertSee('Aktifkan OTP admin');
        $secret = session('mfa_pending_secret');
        $this->post('/admin/mfa/setup', ['code' => '000000'])->assertSessionHasErrors('code');
        $this->post('/admin/mfa/setup', ['code' => Totp::code($secret, intdiv(time(), 30))])->assertRedirect('/admin');
        $this->get('/admin')->assertOk();
        $this->assertNotNull($admin->fresh()->mfa_confirmed_at);
        $this->assertNotSame($secret, $admin->fresh()->getRawOriginal('mfa_secret'), 'secret is stored encrypted');

        // New login: password alone is not enough, and a used code cannot be replayed.
        $this->post('/logout');
        $this->post('/login', ['email' => $admin->email, 'password' => 'PasswordAman123']);
        $this->get('/admin')->assertRedirect('/admin/mfa');
        $this->post('/admin/mfa', ['code' => Totp::code($secret, intdiv(time(), 30))])->assertSessionHasErrors('code');
        $this->post('/admin/mfa', ['code' => Totp::code($secret, intdiv(time(), 30) + 1)])->assertRedirect('/admin');
        $this->get('/admin')->assertOk();
    }

    public function test_totp_matches_rfc_6238_reference_vector(): void {
        // RFC 6238 SHA1 seed "12345678901234567890" in base32, T=59s → 94287082 (last 6 digits).
        $this->assertSame('287082', Totp::code('GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ', intdiv(59, 30)));
        $this->assertSame(1, Totp::verify('GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ', '287082', 59));
    }

    public function test_email_verification_is_enforced_when_enabled(): void {
        config(['goyana.require_email_verification' => true]);
        $this->post('/register', ['name' => 'Baru', 'business_name' => 'Laundry Baru', 'email' => 'baru@example.test',
            'password' => 'PasswordAman123', 'password_confirmation' => 'PasswordAman123']);
        $this->get('/dashboard')->assertRedirect('/email/verify');
        $user = User::where('email', 'baru@example.test')->first();
        $user->markEmailAsVerified();
        $this->actingAs($user->fresh())->get('/dashboard')->assertOk();
    }
}
