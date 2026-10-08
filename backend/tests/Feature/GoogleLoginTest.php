<?php
namespace Tests\Feature;

use App\Models\{Business, User};
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/** Masuk dan daftar dengan Google, sesi pemilik yang awet, dan akun dengan semua menu terbuka (keputusan pengguna 8 Oktober 2026). */
class GoogleLoginTest extends TestCase {
    use RefreshDatabase;

    protected function setUp(): void {
        parent::setUp();
        config(['goyana.google.client_ids' => ['client-goyana.apps.googleusercontent.com']]);
    }

    private array $claims = []; private int $googleStatus = 200;

    /** Jawaban Google berikutnya untuk pemeriksaan tanda masuk. */
    private function google(array $claims = [], int $status = 200): void {
        $this->claims = $claims; $this->googleStatus = $status;
        Http::fake(['oauth2.googleapis.com/*' => fn () => Http::response($this->claims + ['aud' => 'client-goyana.apps.googleusercontent.com', 'iss' => 'https://accounts.google.com',
            'exp' => (string) (time() + 600), 'sub' => '1122334455', 'email' => 'Pemilik@Gmail.com', 'email_verified' => 'true', 'name' => 'Pak Pemilik'], $this->googleStatus)]);
    }

    private function signIn(array $extra = []) {
        $this->app['auth']->forgetGuards(); $this->flushHeaders();
        return $this->postJson('/api/session/google', $extra + ['id_token' => 'tanda-dari-google', 'device_id' => 'hp-owner-0001']);
    }

    private function me(string $token) {
        $this->app['auth']->forgetGuards(); $this->flushHeaders();
        return $this->withToken($token)->getJson('/api/me?device_id=hp-owner-0001');
    }

    public function test_new_google_account_gets_a_business_on_trial_and_signs_in_again_without_duplicates(): void {
        $this->google();
        $first = $this->signIn(['business_name' => 'Laundry Bersih'])->assertCreated()->assertJsonPath('created', true);
        $me = $this->me($first->json('token'))->assertOk();
        $me->assertJsonPath('user.role', 'owner')->assertJsonPath('user.name', 'Pak Pemilik')->assertJsonPath('business.name', 'Laundry Bersih')
            ->assertJsonPath('access.package', 'Basic')->assertJsonPath('access.source', 'trial')->assertJsonPath('outlets.0.name', 'Laundry Bersih — Pusat');
        $user = User::where('email', 'pemilik@gmail.com')->firstOrFail();
        $this->assertSame(['1122334455', null], [$user->google_id, $user->password]);
        $this->assertNotNull($user->email_verified_at);
        // Masuk lagi (mis. di HP kedua): akun yang sama, tidak ada usaha baru.
        $this->signIn()->assertOk()->assertJsonPath('created', false);
        $this->assertSame([1, 1], [Business::count(), User::count()]);
        // Akun Google tidak bisa dipakai masuk dengan password kosong.
        $this->app['auth']->forgetGuards(); $this->flushHeaders();
        $this->postJson('/api/session', ['email' => 'pemilik@gmail.com', 'password' => ''])->assertStatus(422);
    }

    public function test_existing_owner_with_the_same_email_is_linked_not_duplicated(): void {
        $business = Business::create(['name' => 'Laundry Lama', 'trial_ends_at' => now()->addMonth()]); $business->outlets()->create(['name' => 'Pusat']);
        $owner = new User(['name' => 'Owner', 'email' => 'pemilik@gmail.com', 'password' => 'PasswordAman123']); $owner->business()->associate($business); $owner->save();
        $this->google();
        $token = $this->signIn()->assertOk()->assertJsonPath('created', false)->json('token');
        $this->me($token)->assertJsonPath('business.name', 'Laundry Lama');
        $this->assertSame('1122334455', $owner->fresh()->google_id);
        $this->assertSame(1, Business::count());
    }

    public function test_tokens_for_another_app_unverified_email_expired_or_rejected_by_google_are_refused(): void {
        foreach ([['aud' => 'aplikasi-lain.apps.googleusercontent.com'], ['email_verified' => 'false'], ['exp' => (string) (time() - 10)], ['iss' => 'https://palsu.example']] as $bad) {
            $this->google($bad);
            $this->signIn()->assertStatus(422)->assertJsonValidationErrors('id_token');
        }
        $this->google([], 400);
        $this->signIn()->assertStatus(422);
        $this->assertSame(0, User::count());
    }

    public function test_google_sign_in_is_off_until_the_server_has_a_client_id(): void {
        config(['goyana.google.client_ids' => []]);
        $this->google();
        $this->signIn()->assertStatus(503);
        $this->getJson('/api/session/options')->assertOk()->assertJsonPath('google.client_ids', []);
    }

    public function test_platform_admin_and_deactivated_accounts_cannot_use_google_in_the_cashier_app(): void {
        $admin = new User(['name' => 'Admin', 'email' => 'pemilik@gmail.com', 'password' => 'PasswordAman123']); $admin->is_platform_admin = true; $admin->save();
        $this->google();
        $this->signIn()->assertStatus(422);
        $admin->delete();
        $business = Business::create(['name' => 'Laundry', 'trial_ends_at' => now()->addMonth()]); $outlet = $business->outlets()->create(['name' => 'Pusat']);
        $kasir = new User(['name' => 'Kasir', 'email' => 'pemilik@gmail.com', 'password' => 'PasswordAman123']);
        $kasir->business_id = $business->id; $kasir->role = 'kasir'; $kasir->outlet_id = $outlet->id; $kasir->deactivated_at = now(); $kasir->save();
        $this->signIn()->assertStatus(422)->assertJsonPath('errors.id_token.0', 'Akun dinonaktifkan. Hubungi owner usaha.');
    }

    public function test_owner_stays_signed_in_and_the_session_is_extended_each_time_the_app_opens(): void {
        $this->google();
        $r = $this->signIn()->assertCreated();
        $this->assertTrue(now()->addDays(80)->lt($r->json('expires_at')));
        $token = $r->json('token');
        $this->travel(60)->days();
        $me = $this->me($token)->assertOk();
        $this->assertTrue(now()->addDays(80)->lt($me->json('session.expires_at')));
        // Enam puluh hari lagi masih masuk, karena tadi diperpanjang.
        $this->travel(60)->days();
        $this->me($token)->assertOk();
        // Tidak pernah dibuka lebih lama dari masa sesi: harus masuk lagi.
        $this->travel(120)->days();
        $this->me($token)->assertUnauthorized();
    }

    public function test_full_access_email_always_gets_the_top_package(): void {
        $this->google(['email' => 'koimanasci@gmail.com']);
        $token = $this->signIn()->assertCreated()->json('token');
        $this->me($token)->assertJsonPath('access.package', 'Basic');
        config(['goyana.full_access.emails' => ['koimanasci@gmail.com']]);
        $this->me($token)->assertJsonPath('access.package', 'Platinum')->assertJsonPath('access.read_only', false)->assertJsonPath('access.outlet_limit', 6)
            ->assertJsonPath('access.cashier_device_limit', 5);
        // Tetap terbuka walau masa trial sudah lewat; usaha lain tidak ikut.
        $this->travel(200)->days();
        $this->google(['email' => 'koimanasci@gmail.com']);
        $token = $this->signIn()->assertOk()->json('token');
        $this->me($token)->assertJsonPath('access.package', 'Platinum')->assertJsonPath('access.read_only', false);
        $this->google(['email' => 'orang.lain@gmail.com', 'sub' => '999']);
        $other = $this->signIn()->assertCreated()->json('token');
        $this->me($other)->assertJsonPath('access.package', 'Basic');
    }
}
