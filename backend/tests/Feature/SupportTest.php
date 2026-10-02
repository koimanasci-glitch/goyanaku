<?php
namespace Tests\Feature;

use App\Models\{Business, Ticket, User};
use App\Support\Settings;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SupportTest extends TestCase {
    use RefreshDatabase;

    private function owner(string $name = 'Laundry CS'): User {
        $b = Business::create(['name' => $name, 'trial_ends_at' => now()->addMonth()]);
        $b->outlets()->create(['name' => 'Pusat']);
        $u = new User(['name' => 'Owner '.$name, 'email' => uniqid().'@example.test', 'password' => 'PasswordAman123']);
        $u->business()->associate($b); $u->save(); return $u->fresh();
    }
    private function admin(): User {
        $u = new User(['name' => 'Admin CS', 'email' => uniqid().'@example.test', 'password' => 'PasswordAman123']);
        $u->is_platform_admin = true; $u->save(); return $u;
    }

    public function test_ticket_flow_between_laundry_and_admin_with_internal_notes(): void {
        $owner = $this->owner(); $admin = $this->admin();
        $this->actingAs($owner)->post('/support', ['subject' => 'Printer mati', 'category' => 'printer', 'body' => 'Tidak bisa cetak nota'])->assertRedirect();
        $ticket = Ticket::firstOrFail();
        $this->assertSame([$owner->business_id, 'open'], [$ticket->business_id, $ticket->status]);

        $this->actingAsAdmin($admin)->get('/admin/tickets')->assertOk()->assertSee('Printer mati')->assertSee('Menunggu CS');
        $this->post('/admin/tickets/'.$ticket->id.'/reply', ['body' => 'Cek kabel dulu (internal)', 'internal' => 1])->assertRedirect();
        $this->assertSame('open', $ticket->fresh()->status, 'internal note does not answer the ticket');
        $this->post('/admin/tickets/'.$ticket->id.'/reply', ['body' => 'Coba nyalakan Bluetooth lalu sambung ulang'])->assertRedirect();
        $this->assertSame('answered', $ticket->fresh()->status);

        $this->actingAs($owner)->get('/support/'.$ticket->id)->assertOk()->assertSee('Coba nyalakan Bluetooth')->assertDontSee('Cek kabel dulu');
        $this->post('/support/'.$ticket->id, ['body' => 'Sudah bisa, terima kasih'])->assertRedirect();
        $this->assertSame('open', $ticket->fresh()->status);

        $this->actingAsAdmin($admin)->post('/admin/tickets/'.$ticket->id.'/reply', ['body' => 'Siap', 'close' => 1]);
        $this->assertSame('closed', $ticket->fresh()->status);
        $this->assertNotNull($ticket->fresh()->closed_at);
    }

    public function test_tickets_are_private_per_business_and_staff(): void {
        $a = $this->owner('A'); $b = $this->owner('B');
        $this->actingAs($a)->post('/support', ['subject' => 'Rahasia A', 'category' => 'lainnya', 'body' => 'x']);
        $ticket = Ticket::firstOrFail();
        $this->actingAs($b)->get('/support/'.$ticket->id)->assertNotFound();
        $this->post('/support/'.$ticket->id, ['body' => 'nyusup'])->assertNotFound();
        $this->get('/support')->assertDontSee('Rahasia A');
        $this->get('/admin/tickets')->assertForbidden();
    }

    public function test_admin_changes_platform_settings_with_history(): void {
        $admin = $this->admin();
        $this->assertSame(25, Settings::get('ai_margin_percent'));
        $this->actingAsAdmin($admin)->get('/admin/settings')->assertOk()->assertSee('Saldo AI klien');
        $base = ['ai_margin_percent' => 30, 'ai_min_topup' => 50000, 'fx_cushion_percent' => 2, 'ai_daily_budget_usd' => 5, 'bot_pause_minutes' => 15, 'msg_welcome' => 1];
        $this->post('/admin/settings', $base + ['cs_whatsapp' => '0812'])->assertSessionHasErrors('cs_whatsapp');
        $this->post('/admin/settings', $base + ['cs_whatsapp' => '6281234567890'])->assertRedirect()->assertSessionHasNoErrors();
        $this->assertSame(30, Settings::get('ai_margin_percent'));
        $this->assertFalse(Settings::get('msg_expired'));
        $this->assertSame('6281234567890', Settings::get('cs_whatsapp'));
        $this->assertDatabaseHas('platform_audit', ['actor_id' => $admin->id, 'action' => 'settings.updated']);
        $this->get('/admin/settings')->assertSee('Riwayat perubahan');
        $owner = $this->owner();
        $this->actingAs($owner)->post('/admin/settings', $base)->assertForbidden();
        $this->get('/support')->assertSee('wa.me/6281234567890');
    }
}
