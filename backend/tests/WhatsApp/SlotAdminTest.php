<?php
namespace Tests\WhatsApp;

use App\Models\{Business, User};
use App\WhatsApp\Devices;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

/** Slot WhatsApp tambahan Rp30.000/nomor/bulan dicatat administrator (selama Google Play belum tersambung). */
class SlotAdminTest extends TestCase {
    use RefreshDatabase;

    public function test_admin_records_paid_slot_extends_and_revokes(): void {
        $b = Business::create(['name' => 'Laundry Slot', 'trial_ends_at' => now()->addMonth()]);
        $b->outlets()->create(['name' => 'Pusat']);
        $b->subscriptions()->create(['package' => 'Silver', 'starts_at' => now()->subDay(), 'ends_at' => now()->addMonth(), 'source' => 'manual', 'reference' => (string) Str::uuid()]);
        $owner = new User(['name' => 'O', 'email' => 'slot@cuci.test', 'password' => 'PasswordAman123']); $owner->business()->associate($b); $owner->save();
        $admin = new User(['name' => 'Admin', 'email' => uniqid().'@example.test', 'password' => 'PasswordAman123']); $admin->is_platform_admin = true; $admin->save();
        $this->assertSame(1, app(Devices::class)->entitlement($b)['limit']);

        $this->actingAsAdmin($admin)->get('/admin/whatsapp/slots')->assertOk()->assertSee('Rp30.000 per nomor per bulan');
        $this->post('/admin/whatsapp/slots', ['client' => 'slot@cuci.test', 'slots' => 1, 'months' => 2, 'paid' => 60000, 'reference' => 'TRF-001'])
            ->assertSessionHas('status', 'Slot WhatsApp ditambahkan untuk Laundry Slot.');
        $this->assertSame(2, app(Devices::class)->entitlement($b->fresh())['limit']);
        $this->post('/admin/whatsapp/slots', ['client' => (string) $b->id, 'slots' => 1, 'months' => 1, 'paid' => 10000, 'reference' => 'TRF-002'])
            ->assertSessionHas('status', fn ($s) => str_contains($s, 'seharusnya Rp30.000'));
        $first = DB::table('wa_slot_grants')->where('payment_reference', 'TRF-001')->first();
        $second = DB::table('wa_slot_grants')->where('payment_reference', 'TRF-002')->first();
        $this->assertSame(2, app(Devices::class)->entitlement($b->fresh())['limit'], 'perpanjangan tidak menambah nomor');
        $this->assertEquals(\Carbon\Carbon::parse($first->ends_at)->addMonthNoOverflow()->toDateString(), \Carbon\Carbon::parse($second->ends_at)->toDateString());
        $this->post('/admin/whatsapp/slots', ['client' => (string) $b->id, 'slots' => 1, 'months' => 1, 'paid' => 30000, 'reference' => 'TRF-001'])->assertSessionHasErrors('reference');
        $this->post('/admin/whatsapp/slots/'.$first->id.'/revoke')->assertSessionHas('status');
        $this->assertDatabaseHas('audit_events', ['business_id' => $b->id, 'action' => 'wa.slot_revoked']);
        $this->assertDatabaseHas('audit_events', ['business_id' => $b->id, 'action' => 'wa.slot_granted']);
    }
}
