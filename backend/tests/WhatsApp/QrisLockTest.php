<?php
namespace Tests\WhatsApp;

use App\Models\{Business, User};
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\{DB, Mail};
use Illuminate\Support\Str;
use Tests\TestCase;

/** Kunci QRIS (keputusan Paduka 10 Okt 2026): hanya pemilik setelah konfirmasi password / kode email. */
class QrisLockTest extends TestCase {
    use RefreshDatabase;

    private function owner(): User {
        $b = Business::create(['name' => 'Laundry', 'trial_ends_at' => now()->addMonth()]);
        $b->outlets()->create(['name' => 'Pusat']);
        $u = new User(['name' => 'Owner', 'email' => uniqid().'@example.test', 'password' => 'PasswordAman123']);
        $u->business()->associate($b); $u->save();
        return $u->fresh();
    }

    private function token(User $u): string {
        $this->app['auth']->forgetGuards();
        return $this->postJson('/api/session', ['email' => $u->email, 'password' => 'PasswordAman123'])->json('token');
    }

    private function push(string $token, string $key, string $data, int $base = 0): array {
        $this->app['auth']->forgetGuards();
        return $this->withToken($token)->postJson('/api/sync/push', ['device_id' => 'device-aaaa-1111', 'changes' => [
            ['op_id' => (string) Str::uuid(), 'collection' => 'settings', 'key' => $key, 'data' => $data, 'base_rev' => $base]]])->json('results.0');
    }

    public function test_owner_must_confirm_password_before_changing_qris(): void {
        $u = $this->owner(); $t = $this->token($u);
        $this->assertSame('rejected', $this->push($t, 'goyana-qris-text', '000201ORANGLAIN')['status']);
        // pengaturan lain tidak terkunci
        $this->assertSame('applied', $this->push($t, 'goyana-durations199', '{"a":1}')['status']);
        $this->app['auth']->forgetGuards();
        $this->withToken($t)->postJson('/api/qris/unlock', ['password' => 'salah'])->assertStatus(422);
        $this->withToken($t)->postJson('/api/qris/unlock', ['password' => 'PasswordAman123'])->assertOk()->assertJsonPath('minutes', 10);
        $r = $this->push($t, 'goyana-qris-text', '000201PUNYASAYA');
        $this->assertSame('applied', $r['status']);
        $this->assertDatabaseHas('audit_events', ['business_id' => $u->business_id, 'action' => 'qris.unlock']);
        // setelah 10 menit terkunci lagi; kiriman isi yang sama tetap diterima
        $this->travel(11)->minutes();
        $this->assertSame('rejected', $this->push($t, 'goyana-qris-text', '000201LAIN', $r['rev'])['status']);
        $this->assertSame('applied', $this->push($t, 'goyana-qris-text', '000201PUNYASAYA', $r['rev'])['status']);
    }

    public function test_staff_can_never_change_qris_and_email_code_works(): void {
        Mail::fake();
        $u = $this->owner();
        $k = new User(['name' => 'Kasir', 'email' => 'k'.uniqid().'@example.test', 'password' => 'PasswordAman123']);
        $k->business_id = $u->business_id; $k->role = 'kepala_cabang'; $k->outlet_id = $u->business->outlets()->value('id'); $k->save();
        $kt = $this->token($k->fresh());
        $this->app['auth']->forgetGuards();
        $this->withToken($kt)->postJson('/api/qris/unlock', ['password' => 'PasswordAman123'])->assertForbidden();
        $this->assertSame('rejected', $this->push($kt, 'goyana-qris-image', 'data:image/png;base64,AAAA')['status']);

        $t = $this->token($u);
        $this->app['auth']->forgetGuards();
        $this->withToken($t)->postJson('/api/qris/code')->assertOk();
        $this->assertStringNotContainsString('Kode konfirmasi ganti QRIS:', (string) DB::table('outbound_messages')->where('kind', 'qris_code')->value('body'));
        $this->withToken($t)->postJson('/api/qris/unlock', ['code' => '000000'])->assertStatus(422);
    }
}
