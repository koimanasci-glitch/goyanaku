<?php
namespace Tests\Feature;

use App\Models\{Business, User};
use App\Support\Settings;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class LifecycleTest extends TestCase {
    use RefreshDatabase;

    private function subjects(): array {
        return array_map(fn ($m) => $m->getOriginalMessage()->getSubject(), app('mailer')->getSymfonyTransport()->messages()->all());
    }
    private function business(string $name, $trialEnds, $createdAt = null): Business {
        $b = Business::create(['name' => $name, 'trial_ends_at' => $trialEnds]);
        if ($createdAt) { $b->created_at = $createdAt; $b->save(); }
        $u = new User(['name' => 'Owner '.$name, 'email' => strtolower(str_replace(' ', '', $name)).'@x.test', 'password' => 'PasswordAman123']);
        $u->business()->associate($b); $u->save();
        return $b;
    }

    public function test_each_message_is_sent_once_and_respects_settings(): void {
        config(['mail.default' => 'array']);
        $this->business('Baru', now()->addMonths(2));
        $this->business('Hampir Habis', now()->addDays(2), now()->subMonths(2));
        $this->business('Sudah Habis', now()->subDay(), now()->subMonths(2));
        $this->business('Lama Habis', now()->subMonth(), now()->subMonths(3));
        $paid = $this->business('Bayar', now()->subDay(), now()->subMonths(2));
        $paid->subscriptions()->create(['package' => 'Gold', 'starts_at' => now(), 'ends_at' => now()->addMonth(), 'source' => 'manual', 'reference' => 'TRF-7', 'amount' => 100000]);

        $this->artisan('goyana:lifecycle')->assertExitCode(0);
        $subjects = $this->subjects();
        sort($subjects);
        $this->assertSame(['Paket berakhir — data Anda aman', 'Pembayaran paket Gold diterima', 'Selamat datang di GOYANA', 'Trial berakhir '.now('Asia/Jakarta')->addDays(2)->format('d M')], $subjects);
        $this->assertSame('hampirhabis@x.test', DB::table('outbound_messages')->where('kind', 'expiry_reminder')->value('recipient'));

        $this->artisan('goyana:lifecycle');
        $this->assertCount(4, $this->subjects(), 'second run sends nothing again');

        Settings::put(['msg_welcome' => false], null);
        $this->business('Baru Dua', now()->addMonths(2));
        $this->artisan('goyana:lifecycle');
        $this->assertCount(4, $this->subjects(), 'welcome switched off by admin');
    }
}
