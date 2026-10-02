<?php
namespace Tests\Feature;
use App\Models\{Business, User};
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;
class FoundationTest extends TestCase {
    use RefreshDatabase;
    private function owner(string $name = 'Laundry Satu'): User {
        $business = Business::create(['name' => $name, 'trial_ends_at' => now()->addMonthsNoOverflow(2)]);
        $business->outlets()->create(['name' => $name.' Pusat']);
        $user = new User(['name' => 'Pemilik', 'email' => uniqid().'@example.test', 'password' => 'PasswordAman123']);
        $user->business()->associate($business); $user->save();
        return $user;
    }
    private function admin(): User {
        $user = new User(['name' => 'Admin', 'email' => uniqid().'@example.test', 'password' => 'PasswordAman123']);
        $user->is_platform_admin = true; $user->save(); return $user;
    }
    public function test_registration_creates_owner_business_outlet_and_trial_without_privilege_escalation(): void {
        $this->post('/register', [
            'name' => 'Susilo', 'business_name' => 'Cikarang Laundry', 'email' => 'SUSILO@example.test',
            'password' => 'PasswordAman123', 'password_confirmation' => 'PasswordAman123',
            'is_platform_admin' => true, 'business_id' => 999,
        ])->assertRedirect('/dashboard');
        $user = User::sole(); $this->assertAuthenticatedAs($user);
        $this->assertFalse($user->is_platform_admin);
        $this->assertSame('susilo@example.test', $user->email);
        $this->assertTrue(Hash::check('PasswordAman123', $user->password));
        $this->assertDatabaseCount('businesses', 1); $this->assertDatabaseCount('outlets', 1);
        $this->assertTrue($user->business->trial_ends_at->isFuture());
        $this->get('/admin')->assertForbidden();
    }
    public function test_duplicate_registration_does_not_create_extra_business(): void {
        $owner = $this->owner();
        $this->post('/register', ['name' => 'Other', 'business_name' => 'Other', 'email' => $owner->email,
            'password' => 'PasswordAman123', 'password_confirmation' => 'PasswordAman123'])->assertSessionHasErrors('email');
        $this->assertDatabaseCount('businesses', 1);
    }
    public function test_owner_sees_only_own_business_and_cannot_enter_platform_admin(): void {
        $a = $this->owner('Usaha A'); $this->owner('Usaha Rahasia B');
        $this->actingAs($a)->get('/dashboard')->assertOk()->assertSee('Usaha A')->assertDontSee('Usaha Rahasia B');
        $this->get('/admin')->assertForbidden();
        $this->post('/admin/businesses/'.$a->business_id.'/grants', ['package' => 'Platinum'])->assertForbidden();
    }
    public function test_guests_cannot_access_dashboards(): void {
        $this->get('/dashboard')->assertRedirect('/login');
        $this->get('/admin')->assertRedirect('/login');
    }
    public function test_login_normalizes_email_and_logout_ends_session(): void {
        $owner = $this->owner();
        $this->post('/login', ['email' => strtoupper($owner->email), 'password' => 'PasswordAman123'])->assertRedirect('/dashboard');
        $this->assertAuthenticatedAs($owner);
        $this->post('/logout')->assertRedirect('/login'); $this->assertGuest();
    }
    public function test_failed_login_is_generic_and_rate_limited(): void {
        for ($i = 0; $i < 5; $i++) $this->post('/login', ['email' => 'unknown@example.test', 'password' => 'Wrong'])->assertSessionHasErrors(['email' => 'Email atau password tidak sesuai.']);
        $this->post('/login', ['email' => 'unknown@example.test', 'password' => 'Wrong'])->assertStatus(429);
    }
    public function test_admin_can_list_businesses_and_grant_then_revoke_temporary_package(): void {
        $owner = $this->owner(); $admin = $this->admin(); $business = $owner->business;
        $this->actingAs($admin)->get('/admin')->assertOk()->assertSee($business->name);
        $this->get('/admin/businesses/'.$business->id)->assertOk();
        $this->post('/admin/businesses/'.$business->id.'/grants', [
            'package' => 'Platinum', 'reason' => 'Beta teman', 'ends_at' => now()->addDay()->timezone('Asia/Jakarta')->format('Y-m-d\TH:i'),
        ])->assertRedirect();
        $this->assertSame('Platinum', $business->currentAccess()['package']);
        $grant = $business->grants()->sole();
        $this->assertDatabaseHas('audit_events', ['actor_id' => $admin->id, 'action' => 'package.granted']);
        $this->post('/admin/businesses/'.$business->id.'/grants/'.$grant->id.'/revoke')->assertRedirect();
        $this->assertSame('trial', $business->currentAccess()['source']);
        $this->assertDatabaseHas('audit_events', ['action' => 'package.revoked']);
        $this->post('/admin/businesses/'.$business->id.'/grants/'.$grant->id.'/revoke')->assertRedirect();
        $this->assertDatabaseCount('audit_events', 2);
    }
    public function test_expired_grant_does_not_keep_access_and_data_is_retained(): void {
        $owner = $this->owner(); $business = $owner->business;
        $business->trial_ends_at = now()->subDay(); $business->save();
        $business->grants()->create(['package' => 'Platinum', 'reason' => 'Expired', 'starts_at' => now()->subDays(2), 'ends_at' => now()->subDay(), 'granted_by' => $this->admin()->id]);
        $this->assertTrue($business->currentAccess()['read_only']);
        $this->actingAs($owner)->get('/dashboard')->assertOk()->assertSee('Mode baca saja');
        $this->post('/outlets/'.$business->outlets()->sole()->id.'/devices', ['label' => 'Device'])->assertForbidden();
        $this->assertDatabaseCount('businesses', 1); $this->assertDatabaseCount('users', 2);
    }
    public function test_invalid_or_past_grants_are_rejected(): void {
        $owner = $this->owner(); $this->actingAs($this->admin());
        $url = '/admin/businesses/'.$owner->business_id.'/grants';
        $this->post($url, ['package' => 'Unlimited', 'reason' => 'Test', 'ends_at' => now()->addDay()->toIso8601String()])->assertSessionHasErrors('package');
        $this->post($url, ['package' => 'Platinum', 'reason' => 'Test', 'ends_at' => now()->subDay()->toIso8601String()])->assertSessionHasErrors('ends_at');
        $this->assertDatabaseCount('package_grants', 0);
    }
    public function test_cross_business_grant_revocation_is_rejected(): void {
        $a = $this->owner(); $b = $this->owner(); $admin = $this->admin();
        $grant = $b->business->grants()->create(['package' => 'Gold', 'reason' => 'Beta', 'starts_at' => now(), 'ends_at' => now()->addDay(), 'granted_by' => $admin->id]);
        $this->actingAs($admin)->post('/admin/businesses/'.$a->business_id.'/grants/'.$grant->id.'/revoke')->assertNotFound();
        $this->assertNull($grant->fresh()->revoked_at);
    }
    public function test_cashier_device_limit_and_slot_reuse_are_enforced(): void {
        $owner = $this->owner(); $outlet = $owner->business->outlets()->sole(); $url = '/outlets/'.$outlet->id.'/devices';
        $this->actingAs($owner)->post($url, ['label' => 'A'])->assertRedirect();
        $this->post($url, ['label' => 'B'])->assertRedirect();
        $this->post($url, ['label' => 'C'])->assertSessionHasErrors('label');
        $this->assertDatabaseCount('cashier_devices', 2);
        $device = $outlet->devices()->first();
        $this->post($url.'/'.$device->id.'/revoke')->assertRedirect();
        $this->post($url, ['label' => 'Replacement'])->assertRedirect();
        $this->assertSame(2, $outlet->devices()->whereNull('revoked_at')->count());
        $this->assertNull($device->fresh()->slot);
    }
    public function test_owner_cannot_register_or_revoke_another_business_device(): void {
        $a = $this->owner(); $b = $this->owner(); $outlet = $b->business->outlets()->sole();
        $device = $outlet->devices()->create(['label' => 'Private', 'slot' => 1]);
        $this->actingAs($a)->post('/outlets/'.$outlet->id.'/devices', ['label' => 'Attack'])->assertForbidden();
        $this->post('/outlets/'.$outlet->id.'/devices/'.$device->id.'/revoke')->assertForbidden();
        $this->assertNull($device->fresh()->revoked_at);
    }
}
