<?php
namespace Tests\Feature;

use App\Models\{Business, CashierDevice, User};
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class AdminPanelTest extends TestCase {
    use RefreshDatabase;

    private function business(string $name, bool $expired = false, string $email = null): Business {
        $b = Business::create(['name' => $name, 'trial_ends_at' => $expired ? now()->subDay() : now()->addMonthsNoOverflow(2)]);
        $b->outlets()->create(['name' => $name.' Pusat']);
        $u = new User(['name' => 'Pemilik '.$name, 'email' => $email ?? uniqid().'@example.test', 'password' => 'PasswordAman123']);
        $u->business()->associate($b); $u->save();
        return $b;
    }

    private function admin(): User {
        $u = new User(['name' => 'Admin Pusat', 'email' => uniqid().'@example.test', 'password' => 'PasswordAman123']);
        $u->is_platform_admin = true; $u->save(); return $u;
    }

    public function test_overview_counts_and_filters_businesses(): void {
        $trial = $this->business('Laundry Trial', false, 'trial@cuci.test');
        $expired = $this->business('Laundry Lama', true);
        $paid = $this->business('Laundry Bayar', true);
        $paid->subscriptions()->create(['package' => 'Silver', 'starts_at' => now()->subDay(), 'ends_at' => now()->addDays(5), 'source' => 'manual', 'reference' => 'T1', 'amount' => 65000]);
        $admin = $this->admin();
        $this->actingAsAdmin($admin)->get('/admin')->assertOk()
            ->assertSeeInOrder(['Total usaha', '3', 'Berbayar', '1', 'Beta', '0', 'Trial', '1', 'Baca saja', '1'])
            ->assertSee('Rp65.000')->assertSee('Berakhir dalam 7 hari');
        $this->get('/admin?status=expired')->assertSee('Laundry Lama')->assertDontSee('Laundry Trial')->assertDontSee('Laundry Bayar');
        $this->get('/admin?status=paid')->assertSee('Laundry Bayar')->assertDontSee('Laundry Lama');
        $this->get('/admin?q=trial@cuci')->assertSee('Laundry Trial')->assertDontSee('Laundry Lama');
        $this->get('/admin?q='.$expired->id)->assertSee('Laundry Lama');
    }

    public function test_business_detail_and_admin_revokes_lost_phone(): void {
        $b = $this->business('Laundry HP'); $admin = $this->admin();
        $outlet = $b->outlets()->first();
        $device = $outlet->devices()->create(['label' => 'HP Kasir A', 'slot' => 1]);
        $device->device_uuid = 'abcdef1234567890'; $device->last_seen_at = now(); $device->save();
        DB::table('sync_records')->insert(['business_id' => $b->id, 'outlet_id' => $outlet->id, 'collection' => 'orders', 'record_key' => 'INV-1', 'data' => '{}', 'rev' => 1, 'created_at' => now(), 'updated_at' => now()]);
        $this->actingAsAdmin($admin)->get('/admin/businesses/'.$b->id)->assertOk()
            ->assertSee('Pemilik Laundry HP')->assertSee('HP Kasir A')->assertSee('ID abcdef12')->assertSee('orders')->assertSee('Aktivitas terakhir');
        $url = '/admin/businesses/'.$b->id.'/devices/'.$device->id.'/revoke';
        $this->post($url, [])->assertSessionHasErrors('reason');
        $this->post($url, ['reason' => 'HP hilang'])->assertRedirect();
        $device->refresh();
        $this->assertNotNull($device->revoked_at); $this->assertNull($device->slot);
        $this->assertDatabaseHas('audit_events', ['business_id' => $b->id, 'actor_id' => $admin->id, 'action' => 'device.revoked_by_admin']);
        // A device from another business cannot be revoked through this business.
        $other = $this->business('Lain'); $foreign = $other->outlets()->first()->devices()->create(['label' => 'X', 'slot' => 1]);
        $this->post('/admin/businesses/'.$b->id.'/devices/'.$foreign->id.'/revoke', ['reason' => 'x'])->assertNotFound();
        $this->assertNull($foreign->fresh()->revoked_at);
    }

    public function test_audit_page_filters_and_system_page_reports_checks(): void {
        $b = $this->business('Laundry Audit'); $admin = $this->admin();
        $this->actingAsAdmin($admin)->post('/admin/businesses/'.$b->id.'/grants', ['package' => 'Gold', 'reason' => 'Beta tester', 'ends_at' => now('Asia/Jakarta')->addDays(10)->format('Y-m-d\TH:i')])->assertRedirect();
        DB::table('audit_events')->insert(['actor_id' => $b->users()->first()->id, 'business_id' => $b->id, 'action' => 'device.paired', 'details' => '{}', 'created_at' => now()]);
        $this->get('/admin/audit')->assertOk()->assertSee('package.granted')->assertSee('device.paired');
        $this->get('/admin/audit?action=package.')->assertSee('Beta tester')->assertDontSee('<span class="badge">device.paired</span>', false);
        $this->get('/admin/audit?admin=1')->assertSee('package.granted')->assertDontSee('<span class="badge">device.paired</span>', false);
        $this->get('/admin/system')->assertOk()->assertSee('Database')->assertSee('Migrasi database')->assertSee('Semua migrasi sudah dijalankan')->assertSee('Ruang disk');
    }

    public function test_admin_pages_are_closed_to_laundry_owners(): void {
        $b = $this->business('Laundry Biasa'); $owner = $b->users()->first();
        foreach (['/admin', '/admin/audit', '/admin/system', '/admin/businesses/'.$b->id] as $url) {
            $this->actingAs($owner)->get($url)->assertForbidden();
        }
        $device = $b->outlets()->first()->devices()->create(['label' => 'HP', 'slot' => 1]);
        $this->post('/admin/businesses/'.$b->id.'/devices/'.$device->id.'/revoke', ['reason' => 'x'])->assertForbidden();
    }
}
