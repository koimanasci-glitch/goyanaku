<?php
namespace Tests\Feature;

use App\Models\{Business, User};
use Illuminate\Auth\Notifications\ResetPassword;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Notification;
use Tests\TestCase;

class PasswordResetTest extends TestCase {
    use RefreshDatabase;

    public function test_owner_resets_password_by_email_and_phone_sessions_end(): void {
        Notification::fake();
        $b = Business::create(['name' => 'L', 'trial_ends_at' => now()->addMonth()]);
        $u = new User(['name' => 'Owner', 'email' => 'owner@x.test', 'password' => 'PasswordLama123']); $u->business()->associate($b); $u->save();
        $u->createToken('hp');
        $this->post('/forgot-password', ['email' => 'tidakada@x.test'])->assertSessionHas('status');
        $this->post('/forgot-password', ['email' => ' OWNER@x.test '])->assertSessionHas('status');
        $token = null;
        Notification::assertSentTo($u, ResetPassword::class, function ($n) use (&$token) { $token = $n->token; return true; });
        $this->get('/reset-password/'.$token.'?email=owner@x.test')->assertOk()->assertSee('Buat password baru');
        $this->post('/reset-password', ['token' => 'salah', 'email' => 'owner@x.test', 'password' => 'PasswordBaru123', 'password_confirmation' => 'PasswordBaru123'])->assertSessionHasErrors('email');
        $this->post('/reset-password', ['token' => $token, 'email' => 'owner@x.test', 'password' => 'PasswordBaru123', 'password_confirmation' => 'PasswordBaru123'])->assertRedirect('/login');
        $this->assertSame(0, $u->tokens()->count());
        $this->post('/login', ['email' => 'owner@x.test', 'password' => 'PasswordBaru123'])->assertRedirect();
        $this->assertAuthenticatedAs($u->fresh());
    }

    public function test_platform_admin_cannot_reset_by_email(): void {
        Notification::fake();
        $a = new User(['name' => 'Admin', 'email' => 'admin@x.test', 'password' => 'PasswordLama123']); $a->is_platform_admin = true; $a->save();
        $this->post('/forgot-password', ['email' => 'admin@x.test'])->assertSessionHas('status');
        Notification::assertNothingSent();
    }
}
