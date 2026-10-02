<?php
namespace Tests\Feature;
use App\Models\{Business, User};
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;
class ApiSessionTest extends TestCase {
    use RefreshDatabase;
    private function user(string $name, bool $admin = false): User {
        $b = $admin ? null : Business::create(['name' => $name, 'trial_ends_at' => now()->addMonth()]);
        $b?->outlets()->create(['name' => $name.' Pusat']);
        $u = new User(['name' => $name, 'email' => $name.'@example.test', 'password' => 'PasswordAman123']);
        $u->business_id = $b?->id; $u->is_platform_admin = $admin; $u->save(); return $u;
    }
    public function test_api_requires_token_and_ignores_client_tenant_selection(): void {
        $a = $this->user('a'); $b = $this->user('b');
        $this->getJson('/api/me')->assertUnauthorized();
        $response = $this->postJson('/api/session', ['email' => $a->email, 'password' => 'PasswordAman123'])->assertOk();
        $token = $response->json('token');
        $this->assertNotSame($token, $a->tokens()->sole()->token);
        $this->withToken($token)->getJson('/api/me?business_id='.$b->business_id)->assertOk()->assertJsonPath('business.id', $a->business_id)->assertJsonMissing(['name' => 'b Pusat']);
    }
    public function test_platform_admin_cannot_get_laundry_api_token(): void {
        $u = $this->user('admin', true);
        $this->postJson('/api/session', ['email' => $u->email, 'password' => 'PasswordAman123'])->assertUnprocessable();
        $this->assertDatabaseCount('personal_access_tokens', 0);
    }
    public function test_token_expiry_ability_and_logout_revoke_access(): void {
        $u = $this->user('owner');
        $expired = $u->createToken('old', ['business:read'], now()->subMinute())->plainTextToken;
        $this->withToken($expired)->getJson('/api/me')->assertUnauthorized();
        $wrong = $u->createToken('wrong', ['different'], now()->addDay())->plainTextToken;
        $this->withToken($wrong)->getJson('/api/me')->assertForbidden();
        $this->app['auth']->forgetGuards();
        $token = $u->createToken('owner', ['business:read'], now()->addDay())->plainTextToken;
        $this->withToken($token)->deleteJson('/api/session')->assertNoContent();
        // Clear the cached auth guard between independent requests in the same test.
        $this->app['auth']->forgetGuards();
        $this->withToken($token)->getJson('/api/me')->assertUnauthorized();
    }
    public function test_pwa_manifest_is_only_linked_for_platform_administrator(): void {
        $owner = $this->user('owner');
        $this->actingAs($owner)->get('/dashboard')->assertOk()->assertDontSee('rel="manifest"', false);
        $this->actingAs($this->user('admin', true))->get('/admin')->assertOk()->assertSee('admin.webmanifest')->assertSee('admin-sw.js');
    }
}
