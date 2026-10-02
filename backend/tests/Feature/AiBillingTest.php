<?php
namespace Tests\Feature;

use App\Models\{Business, User};
use App\Support\{AiBilling, Settings};
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\{DB, Http};
use Illuminate\Validation\ValidationException;
use Tests\TestCase;

class AiBillingTest extends TestCase {
    use RefreshDatabase;

    private Business $b; private User $admin;

    protected function setUp(): void {
        parent::setUp();
        config(['mail.default' => 'array']);
        $this->b = Business::create(['name' => 'Laundry AI', 'trial_ends_at' => now()->addMonth()]);
        $owner = new User(['name' => 'Owner', 'email' => 'o@x.test', 'password' => 'PasswordAman123']); $owner->business()->associate($this->b); $owner->save();
        $this->admin = new User(['name' => 'Admin', 'email' => 'a@x.test', 'password' => 'PasswordAman123']); $this->admin->is_platform_admin = true; $this->admin->save();
    }

    public function test_rupiah_price_uses_rate_cushion_and_margin_and_rounds_up(): void {
        DB::table('fx_rates')->insert(['currency' => 'USD', 'day' => now()->toDateString(), 'rate' => 16000, 'source' => 't', 'created_at' => now()]);
        // $0.01 × 16.000 × 1,02 × 1,25 = 204
        $this->assertSame(204, AiBilling::toRupiah(0.01));
        $this->assertSame(1, AiBilling::toRupiah(0.0000001), 'never free');
        Settings::put(['ai_margin_percent' => 50], null);
        $this->assertSame(245, AiBilling::toRupiah(0.01)); // 244,8 → 245
    }

    public function test_topup_minimum_charge_idempotent_and_never_negative(): void {
        DB::table('fx_rates')->insert(['currency' => 'USD', 'day' => now()->toDateString(), 'rate' => 16000, 'source' => 't', 'created_at' => now()]);
        try { AiBilling::topUp($this->b, 20000, 'TRF-1', $this->admin->id); $this->fail('below minimum accepted'); } catch (ValidationException) {}
        $this->assertSame(50000, AiBilling::topUp($this->b, 50000, 'TRF-1', $this->admin->id));
        try { AiBilling::topUp($this->b, 50000, 'TRF-1', $this->admin->id); $this->fail('duplicate reference accepted'); } catch (ValidationException) {}

        $this->assertSame(204, AiBilling::charge($this->b, 0.01, 'm/x', 'req-1'));
        $this->assertSame(204, AiBilling::charge($this->b, 0.01, 'm/x', 'req-1'), 'retry of the same request is not charged twice');
        $this->assertSame(49796, $this->b->fresh()->ai_balance);
        $this->assertNull(AiBilling::charge($this->b, 10.0, 'm/x', 'req-big'), 'too expensive request is refused');
        $this->assertSame(49796, $this->b->fresh()->ai_balance);
        $this->assertSame([50000, -204], DB::table('ai_ledger')->orderBy('id')->pluck('amount')->map(fn ($v) => (int) $v)->all());
    }

    public function test_daily_rate_and_model_prices_update_safely(): void {
        Http::fake(['open.er-api.com/*' => Http::sequence()->push(['rates' => ['IDR' => 16200.5]])->push(['rates' => ['IDR' => 16100]])->push(['rates' => ['IDR' => 3]]),
            'openrouter.ai/*' => Http::sequence()
                ->push(['data' => [['id' => 'vendor/murah', 'name' => 'Murah', 'pricing' => ['prompt' => '0.0000001', 'completion' => '0.0000004']], ['id' => 'vendor/lain', 'name' => 'Lain', 'pricing' => ['prompt' => '0.000001', 'completion' => '0.000002']]]])
                ->push(['data' => [['id' => 'vendor/murah', 'name' => 'Murah', 'pricing' => ['prompt' => '0.0000002', 'completion' => '0.0000004']]]])]);
        $this->artisan('goyana:fx-update')->assertExitCode(0);
        $this->artisan('goyana:fx-update')->assertExitCode(0);
        $this->assertSame(16200.5, AiBilling::fxRate(), 'same day keeps the higher rate');
        $this->artisan('goyana:fx-update')->assertExitCode(1);
        $this->assertSame(16200.5, AiBilling::fxRate(), 'nonsense rate is ignored');

        $this->artisan('goyana:ai-prices')->assertExitCode(0);
        $this->assertEquals(0.1, (float) DB::table('ai_models')->where('id', 'vendor/murah')->value('prompt_usd_per_mtok'));
        Settings::put(['ai_model_primary' => 'vendor/murah', 'ai_model_fallback' => 'vendor/lain'], null);
        $this->artisan('goyana:ai-prices')->assertExitCode(0);
        $this->assertEquals(0.2, (float) DB::table('ai_models')->where('id', 'vendor/murah')->value('prompt_usd_per_mtok'));
        $this->assertFalse((bool) DB::table('ai_models')->where('id', 'vendor/lain')->value('available'));
        $mails = app('mailer')->getSymfonyTransport()->messages()->all();
        $body = collect($mails)->map(fn ($m) => $m->getOriginalMessage()->getTextBody())->implode("\n");
        $this->assertStringContainsString('vendor/murah naik harga', $body);
        $this->assertStringContainsString('vendor/lain tidak tersedia lagi', $body);

        // Pre-check before calling the AI uses the latest price.
        AiBilling::topUp($this->b, 50000, 'T', $this->admin->id);
        $this->assertTrue(AiBilling::canAfford($this->b, 'vendor/murah', 2000, 500));
        $this->assertFalse(AiBilling::canAfford($this->b, 'vendor/lain', 10, 10), 'unavailable model cannot be used');
    }

    public function test_admin_records_topup_and_picks_models(): void {
        DB::table('ai_models')->insert(['id' => 'vendor/murah', 'name' => 'Murah', 'prompt_usd_per_mtok' => 0.1, 'completion_usd_per_mtok' => 0.4, 'available' => true, 'updated_at' => now()]);
        $this->actingAsAdmin($this->admin)->post('/admin/businesses/'.$this->b->id.'/ai-topup', ['amount' => 100000, 'reference' => 'QRIS-9'])->assertRedirect()->assertSessionHasNoErrors();
        $this->assertSame(100000, $this->b->fresh()->ai_balance);
        $this->get('/admin/businesses/'.$this->b->id)->assertSee('Saldo AI · Rp100.000')->assertSee('QRIS-9');
        $base = ['ai_margin_percent' => 25, 'ai_min_topup' => 50000, 'fx_cushion_percent' => 2, 'ai_daily_budget_usd' => 5, 'bot_pause_minutes' => 15];
        $this->post('/admin/settings', $base + ['ai_model_primary' => 'vendor/tidak-ada'])->assertSessionHasErrors('ai_model_primary');
        $this->post('/admin/settings', $base + ['ai_model_primary' => 'vendor/murah'])->assertSessionHasNoErrors();
        $this->assertSame('vendor/murah', Settings::get('ai_model_primary'));
        $this->get('/admin/settings')->assertSee('vendor/murah');
    }
}
