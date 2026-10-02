<?php
namespace Tests\Feature;

use App\Models\{Business, User};
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class AssistTest extends TestCase {
    use RefreshDatabase;

    public function test_owner_allows_assist_admin_changes_price_phone_receives_it_and_can_undo(): void {
        $b = Business::create(['name' => 'Laundry Bantu', 'trial_ends_at' => now()->addMonth()]);
        $b->outlets()->create(['name' => 'Pusat']);
        $owner = new User(['name' => 'Owner', 'email' => 'o@x.test', 'password' => 'PasswordAman123']); $owner->business()->associate($b); $owner->save();
        $admin = new User(['name' => 'Admin', 'email' => 'a@x.test', 'password' => 'PasswordAman123']); $admin->is_platform_admin = true; $admin->save();
        $svc = ['key' => 'cuci baju', 'name' => 'Cuci Baju', 'unit' => 'kg', 'prices' => ['Reguler' => 7000, 'Express' => 10500], 'enabled' => ['Reguler' => true, 'Express' => true]];
        DB::table('sync_records')->insert(['business_id' => $b->id, 'collection' => 'services', 'record_key' => 'cuci baju', 'data' => json_encode($svc), 'rev' => 5, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('sync_records')->insert(['business_id' => $b->id, 'collection' => 'orders', 'record_key' => 'GY-1', 'data' => '{}', 'rev' => 6, 'created_at' => now(), 'updated_at' => now()]);
        $form = ['key' => 'cuci baju', 'prices' => ['Reguler' => 8000, 'Express' => 10500], 'enabled' => ['Reguler' => 1, 'Express' => 1]];

        // Without the owner's permission: view only.
        $this->actingAsAdmin($admin)->get('/admin/businesses/'.$b->id.'/assist')->assertOk()->assertSee('Tidak aktif');
        $this->post('/admin/businesses/'.$b->id.'/assist/service', $form)->assertForbidden();

        $this->actingAs($owner)->get('/support')->assertSee('Izinkan Bantuan 30 menit');
        $this->post('/support-assist')->assertRedirect();
        $this->get('/support')->assertSee('Hentikan sekarang');

        $this->actingAsAdmin($admin)->post('/admin/businesses/'.$b->id.'/assist/service', $form)->assertRedirect()->assertSessionHasNoErrors();
        $rec = DB::table('sync_records')->where(['business_id' => $b->id, 'record_key' => 'cuci baju'])->first();
        $this->assertSame(7, (int) $rec->rev, 'new rev above every existing record so phones pull it');
        $this->assertSame(8000, json_decode($rec->data, true)['prices']['Reguler']);

        // The owner's phone downloads the change through the normal sync API.
        $this->app['auth']->forgetGuards();
        $token = $this->postJson('/api/session', ['email' => 'o@x.test', 'password' => 'PasswordAman123'])->json('token');
        $this->app['auth']->forgetGuards();
        $pull = $this->withToken($token)->getJson('/api/sync/pull?cursor=6')->assertOk()->json('records');
        $this->assertSame('cuci baju', $pull[0]['key']);
        $this->assertSame(8000, $pull[0]['data']['prices']['Reguler']);

        $event = DB::table('audit_events')->where('action', 'assist.changed')->value('id');
        $this->app['auth']->forgetGuards(); $this->flushHeaders();
        $this->actingAsAdmin($admin)->post('/admin/businesses/'.$b->id.'/assist/revert/'.$event)->assertRedirect();
        $this->assertSame(7000, json_decode(DB::table('sync_records')->where('record_key', 'cuci baju')->value('data'), true)['prices']['Reguler']);

        // Only settings: orders cannot be touched, and stopping ends access immediately.
        $this->actingAs($owner)->post('/support-assist/stop')->assertRedirect();
        $this->actingAsAdmin($admin)->post('/admin/businesses/'.$b->id.'/assist/service', $form)->assertForbidden();
    }
}
