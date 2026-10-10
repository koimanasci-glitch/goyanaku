<?php
namespace Tests\WhatsApp;

use App\Models\{Business, User};
use App\Support\AiBilling;
use App\WhatsApp\{AutoMessages, Chatbot, ChatkuHttpGateway, Devices, Inbound, Intent, Media, QrisWatch, Replies};
use App\WhatsApp\Chatku\Client;
use App\WhatsApp\Contracts\ChatkuGateway;
use App\WhatsApp\Jobs\{AiReply, ForwardAiTopup, SendReply};
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\{Crypt, DB, Http, Mail, Queue, Storage, URL};
use Illuminate\Support\Str;
use Tests\Support\FakeChatkuExtras;
use Tests\TestCase;

/** Integrasi GOYANA ↔ CHATKU (keputusan Paduka 10 Okt 2026): adapter API Mitra, chatbot per cabang, media, pesan otomatis, AI, blast, QRIS. */
class ChatkuIntegrationTest extends TestCase {
    use RefreshDatabase;
    private FakeChatkuExtras $gw;

    protected function setUp(): void {
        parent::setUp();
        config(['whatsapp.enabled' => true, 'whatsapp.queue_connection' => null,
            'whatsapp.chatku' => ['base_url' => 'https://chatku.test/api/partner/v1', 'api_key' => 'ckp_test', 'webhook_secret' => 'rahasia', 'timeout' => 5, 'tenant_prefix' => 'biz-', 'marketing_tenant' => 'goyana-pusat']]);
        $this->gw = new FakeChatkuExtras;
        $this->app->instance(ChatkuGateway::class, $this->gw);
        Storage::fake('local');
        Queue::fake();
    }

    private function owner(string $package = 'Gold'): User {
        $b = Business::create(['name' => 'Laundry Bersih', 'trial_ends_at' => now()->addMonth()]);
        $b->outlets()->create(['name' => 'Pusat']);
        $b->subscriptions()->create(['package' => $package, 'starts_at' => now()->subDay(), 'ends_at' => now()->addMonth(), 'source' => 'manual', 'reference' => (string) Str::uuid()]);
        $u = new User(['name' => 'Owner', 'email' => Str::uuid().'@example.test', 'password' => 'Password123456']); $u->business_id = $b->id; $u->save();
        return $u;
    }

    private function device(User $u, array $extra = []): object {
        $d = app(Devices::class)->save($u, ['id' => (string) Str::uuid(), 'name' => 'Pusat', 'phone' => '081200000001', 'outlet_id' => $u->business->outlets()->first()->id], true);
        DB::table('wa_devices')->where('id', $d->id)->update($extra + ['remote_id' => '77', 'status' => 'connected', 'reply_status' => true, 'reply_services' => true]);
        return DB::table('wa_devices')->where('id', $d->id)->first();
    }

    private function msg(string $text, array $extra = []): array {
        return $extra + ['id' => (string) Str::uuid(), 'device' => '77', 'from' => '6281234567890', 'text' => $text, 'occurred_at' => now()->toIso8601String(), 'from_me' => false, 'group' => false];
    }

    private function order(object $d, string $key, string $status, array $extra = []): void {
        DB::table('order_index')->insert($extra + ['business_id' => $d->business_id, 'outlet_id' => $d->outlet_id, 'record_key' => $key, 'customer' => 'budi santoso',
            'customer_key' => 'phone:6281234567890', 'status' => $status, 'total' => 50000, 'paid' => 20000, 'ordered_at' => now(), 'created_at' => now(), 'updated_at' => now()]);
    }

    private function lastBody(): string { return Crypt::decryptString(DB::table('wa_outbox')->orderByDesc('id')->value('body')); }

    private function signed(array $payload, ?int $ts = null, string $secret = 'rahasia'): Request {
        $raw = json_encode($payload); $ts ??= time();
        return Request::create('/x', 'POST', [], [], [], ['HTTP_X_CHATKU_TIMESTAMP' => (string) $ts, 'HTTP_X_CHATKU_SIGNATURE' => hash_hmac('sha256', $ts.'.'.$raw, $secret), 'CONTENT_TYPE' => 'application/json'], $raw);
    }

    // ------------------------------------------------------------------ adapter API Mitra

    public function test_adapter_provisions_tenant_then_device_and_maps_status(): void {
        $u = $this->owner(); $d = app(Devices::class)->save($u, ['id' => (string) Str::uuid(), 'name' => 'Pusat', 'phone' => '081200000001', 'outlet_id' => $u->business->outlets()->first()->id], true);
        Http::fake([
            'chatku.test/api/partner/v1/tenants/*/devices' => Http::response(['data' => ['id' => 12, 'status' => 'pending']], 201),
            'chatku.test/api/partner/v1/tenants/*' => Http::response(['data' => ['ref' => 'biz-'.$u->business_id]]),
            'chatku.test/api/partner/v1/devices/12' => Http::response(['data' => ['id' => 12, 'status' => 'qr', 'phone' => null, 'phone_match' => null]]),
            'chatku.test/api/partner/v1/devices/12/messages' => Http::response(['data' => ['message_id' => 991, 'status' => 'queued', 'replayed' => false]], 202),
        ]);
        $g = new ChatkuHttpGateway(new Client(config('whatsapp.chatku')), config('whatsapp.chatku'));
        $this->assertSame('12', $g->provision('goyana-wa:'.$d->id, '6281200000001', 'Pusat'));
        Http::assertSent(fn ($r) => $r->method() === 'PUT' && str_ends_with($r->url(), '/tenants/biz-'.$u->business_id) && $r['name'] === 'Laundry Bersih' && $r->hasHeader('Authorization', 'Bearer ckp_test'));
        Http::assertSent(fn ($r) => $r->method() === 'POST' && str_ends_with($r->url(), '/devices') && $r['key'] === 'goyana-wa:'.$d->id);
        $this->assertSame('pairing', $g->status('12')['status']);
        $this->assertSame('991', $g->send('12', '6281234567890', 'Halo', 'goyana-reply:5'));
        Http::assertSent(fn ($r) => str_ends_with($r->url(), '/messages') && $r->hasHeader('Idempotency-Key', 'goyana-reply:5'));
        foreach (['connected' => 'connected', 'connecting' => 'pairing', 'logged_out' => 'disconnected', 'disconnected' => 'disconnected'] as $in => $out) $this->assertSame($out, ChatkuHttpGateway::mapStatus($in));
    }

    public function test_adapter_errors_become_clear_http_errors_without_secrets(): void {
        Http::fake(['*' => Http::response(['error' => ['code' => 'device_offline', 'message' => 'Perangkat WhatsApp belum tersambung.']], 409)]);
        $g = new ChatkuHttpGateway(new Client(config('whatsapp.chatku')), config('whatsapp.chatku'));
        try { $g->pairing('12', 'qr'); $this->fail('harus gagal'); }
        catch (\Symfony\Component\HttpKernel\Exception\HttpException $e) { $this->assertSame(409, $e->getStatusCode()); $this->assertStringNotContainsString('ckp_test', $e->getMessage()); }
    }

    public function test_webhook_signature_window_and_normalization(): void {
        $g = new ChatkuHttpGateway(new Client(config('whatsapp.chatku')), config('whatsapp.chatku'));
        $p = ['id' => 'evt_1', 'event' => 'message.received', 'created_at' => now()->toIso8601String(), 'tenant' => 'biz-1', 'device' => ['id' => 77, 'key' => 'k', 'phone' => '62'],
            'data' => ['message_id' => 'WA1', 'from' => '6281234567890', 'name' => 'Budi', 'type' => 'text', 'text' => 'status', 'is_group' => false, 'received_at' => now()->toIso8601String()]];
        $e = $g->verifyInbound($this->signed($p));
        $this->assertSame(['message', 'WA1', '77', 'status', false], [$e['type'], $e['id'], $e['device'], $e['text'], $e['from_me']]);
        $p['event'] = 'message.from_me'; $p['data'] = ['message_id' => 'WA2', 'to' => '6281234567890', 'self' => false, 'text' => 'oke kak', 'sent_at' => now()->toIso8601String()];
        $this->assertTrue($g->verifyInbound($this->signed($p))['from_me']);
        $p['event'] = 'device.status'; $p['data'] = ['status' => 'connected', 'phone_match' => true];
        $this->assertSame('device.status', $g->verifyInbound($this->signed($p))['type']);
        foreach ([$this->signed($p, null, 'salah'), $this->signed($p, time() - 900)] as $bad) {
            try { $g->verifyInbound($bad); $this->fail('harus ditolak'); } catch (\Symfony\Component\HttpKernel\Exception\HttpException $ex) { $this->assertSame(401, $ex->getStatusCode()); }
        }
    }

    public function test_webhook_routes_device_status_and_disconnects_wrong_number(): void {
        $u = $this->owner(); $d = $this->device($u);
        $this->postJson('/api/whatsapp/chatku/events', ['type' => 'device.status', 'device' => '77', 'data' => ['status' => 'connected', 'phone_match' => false]], ['X-Test-Signature' => 'sah'])->assertOk();
        $this->assertDatabaseHas('wa_devices', ['id' => $d->id, 'status' => 'disconnected']);
        $this->assertNotNull(DB::table('wa_devices')->where('id', $d->id)->value('status_note'));
        $this->assertCount(1, $this->gw->called('disconnect'));
    }

    public function test_stale_empty_and_group_events_are_accepted_without_reply(): void {
        $u = $this->owner(); $this->device($u);
        foreach ([$this->msg('status', ['occurred_at' => now()->subHour()->toIso8601String()]), $this->msg(''), $this->msg('status', ['group' => true])] as $e) {
            $this->postJson('/api/whatsapp/chatku/events', $e, ['X-Test-Signature' => 'sah'])->assertOk();
        }
        $this->assertSame(0, DB::table('wa_outbox')->count());
    }

    // ------------------------------------------------------------------ maksud & balasan

    public function test_intent_separates_price_status_bill_hours(): void {
        $this->assertSame('price', Intent::of('harga cucian kiloan berapa ya kak'));
        $this->assertSame('status', Intent::of('cucian saya sudah jadi belum?'));
        $this->assertSame('bill', Intent::of('sisa tagihan saya berapa'));
        $this->assertSame('hours', Intent::of('jam buka sampai jam berapa'));
        $this->assertSame('pickup', Intent::of('bisa antar jemput?'));
        $this->assertSame('status', Intent::of('BKS-261008-1-0133'));
        $this->assertNull(Intent::of('berapa'));
        $this->assertNull(Intent::of('halo kak'));
    }

    public function test_status_reply_is_friendly_with_bill_and_code_plus_last_digits(): void {
        $u = $this->owner(); $d = $this->device($u);
        $this->order($d, 'BKS-261008-1-0133', 'siap', ['delivery' => false]);
        $r = app(Replies::class)->status($d, '6281234567890', 'cek status');
        $this->assertStringContainsString('Halo Kak Budi', $r);
        $this->assertStringContainsString('sisa *Rp30.000*', $r);
        $this->assertStringContainsString('Silakan diambil', $r);
        // nomor lain (keluarga) + kode nota + 4 angka terakhir nomor pemesan
        $this->assertStringContainsString('Siap diambil', app(Replies::class)->status($d, '6289999999999', 'BKS-261008-1-0133 7890'));
        $this->assertStringContainsString('belum ditemukan', app(Replies::class)->status($d, '6289999999999', 'BKS-261008-1-0133 1111'));
        $this->assertStringContainsString('belum ditemukan', app(Replies::class)->status($d, '6289999999999', 'BKS-261008-1-0133'));
    }

    public function test_bill_lists_multiple_orders_with_total_due(): void {
        $u = $this->owner(); $d = $this->device($u);
        $this->order($d, 'BKS-261008-1-0001', 'cuci'); $this->order($d, 'BKS-261008-1-0002', 'siap', ['paid' => 50000]);
        $r = app(Replies::class)->status($d, '6281234567890', 'sisa tagihan saya', 'bill');
        $this->assertStringContainsString('Total belum dibayar: *Rp30.000*', $r);
        $this->assertStringContainsString('lunas', $r);
    }

    public function test_nota_link_is_signed_and_shows_only_that_order(): void {
        $u = $this->owner(); $d = $this->device($u); $this->order($d, 'BKS-261008-1-0133', 'proses');
        $o = DB::table('order_index')->first();
        $this->get(\App\WhatsApp\Nota::url($o))->assertOk()->assertSee('BKS-261008-1-0133')->assertSee('Rp30.000')->assertDontSee('6281234567890');
        $this->get('/wa/nota?b='.$o->business_id.'&k='.$o->record_key)->assertForbidden();
    }

    // ------------------------------------------------------------------ balasan cepat, media, ambil alih

    public function test_quick_reply_with_media_is_sent_as_media(): void {
        $u = $this->owner(); $d = $this->device($u);
        $m = Media::store($u->business_id, $d->outlet_id, UploadedFile::fake()->image('harga.png', 2400, 1800), 'Daftar harga');
        DB::table('wa_quick_replies')->insert(['id' => (string) Str::uuid(), 'business_id' => $u->business_id, 'outlet_id' => $d->outlet_id, 'name' => 'Promo',
            'keys' => 'promo, diskon', 'mode' => 'contains', 'reply' => 'Promo Oktober Kak!', 'media_id' => $m->id, 'enabled' => true, 'created_at' => now(), 'updated_at' => now()]);
        app(Inbound::class)->receive($this->msg('ada diskon ga kak?'));
        $o = DB::table('wa_outbox')->first();
        $this->assertSame(['quick', $m->id], [$o->feature, $o->media_id]);
        (new SendReply($o->id))->handle(app(Devices::class), $this->gw);
        $send = $this->gw->called('sendMedia')[0];
        $this->assertSame('Promo Oktober Kak!', $send[2]);
        $this->assertStringStartsWith('goyana-media-'.$m->id, $send[3]['key']);
        $this->get($send[3]['url'])->assertOk()->assertHeader('Content-Type', 'image/jpeg');
        // kata harus utuh: "promosi" tidak memicu "promo"
        $this->assertNull(Chatbot::quickMatch($d, 'promosikan dong'));
    }

    public function test_quick_reply_needs_silver_and_toggle(): void {
        $u = $this->owner('Silver'); $d = $this->device($u);
        DB::table('wa_quick_replies')->insert(['id' => (string) Str::uuid(), 'business_id' => $u->business_id, 'outlet_id' => $d->outlet_id, 'name' => 'Hi',
            'keys' => 'halo', 'mode' => 'exact', 'reply' => 'Halo Kak', 'enabled' => true, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('wa_bot_settings')->insert(['business_id' => $u->business_id, 'outlet_id' => $d->outlet_id, 'quick_enabled' => false, 'created_at' => now(), 'updated_at' => now()]);
        app(Inbound::class)->receive($this->msg('halo'));
        $this->assertSame(0, DB::table('wa_outbox')->count());
        DB::table('wa_bot_settings')->update(['quick_enabled' => true]);
        config(['whatsapp.quick_packages' => ['Gold']]);
        app(Inbound::class)->receive($this->msg('halo'));
        $this->assertSame(0, DB::table('wa_outbox')->count());
        config(['whatsapp.quick_packages' => ['Silver']]);
        app(Inbound::class)->receive($this->msg('halo'));
        $this->assertSame('Halo Kak', $this->lastBody());
    }

    public function test_owner_reply_pauses_bot_and_hash_commands_control_it(): void {
        $u = $this->owner(); $d = $this->device($u); $this->order($d, 'BKS-261008-1-0133', 'cuci');
        app(Inbound::class)->receive($this->msg('oke kak saya cek dulu', ['from_me' => true]));
        app(Inbound::class)->receive($this->msg('status'));
        $this->assertSame(0, DB::table('wa_outbox')->count());
        app(Inbound::class)->receive($this->msg('#bot', ['from_me' => true]));
        app(Inbound::class)->receive($this->msg('status'));
        $this->assertSame(1, DB::table('wa_outbox')->count());
        // chat diri sendiri: "#stop" = semua kontak diam; "#bot" = semua lanjut
        app(Inbound::class)->receive($this->msg('#stop', ['from_me' => true, 'self' => true, 'from' => '6281200000001']));
        app(Inbound::class)->receive($this->msg('status', ['from' => '6281111111111']));
        $this->assertSame(1, DB::table('wa_outbox')->count());
        app(Inbound::class)->receive($this->msg('#bot', ['from_me' => true, 'self' => true, 'from' => '6281200000001']));
        app(Inbound::class)->receive($this->msg('status'));
        $this->assertSame(2, DB::table('wa_outbox')->count());
    }

    public function test_stop_promo_is_recorded_and_confirmed(): void {
        $u = $this->owner('Platinum'); $d = $this->device($u);
        app(Inbound::class)->receive($this->msg('STOP'));
        $this->assertTrue(Chatbot::optedOut($u->business_id, '6281234567890'));
        $this->assertStringContainsString('tidak akan menerima promo', $this->lastBody());
        app(Inbound::class)->receive($this->msg('mulai'));
        $this->assertFalse(Chatbot::optedOut($u->business_id, '6281234567890'));
    }

    public function test_media_limit_compression_copy_and_delete_removes_file(): void {
        $u = $this->owner(); $outlet = $u->business->outlets()->first(); $other = $u->business->outlets()->create(['name' => 'Cabang']);
        $res = $this->actingAs($u)->post('/api/whatsapp/chatbot/'.$outlet->id.'/media', ['name' => 'Foto', 'file' => UploadedFile::fake()->image('a.png', 3000, 2000)], ['Accept' => 'application/json'])->assertCreated();
        $m = DB::table('wa_media')->where('id', $res->json('id'))->first();
        $this->assertSame('image/jpeg', $m->mime);
        $this->assertLessThanOrEqual(300 * 1024, $m->bytes);
        [$w] = getimagesizefromstring(Storage::disk('local')->get($m->path));
        $this->assertLessThanOrEqual(1600, $w);
        $pdf = UploadedFile::fake()->createWithContent('harga.pdf', "%PDF-1.4\n".str_repeat('x', 1000));
        $this->actingAs($u)->post('/api/whatsapp/chatbot/'.$outlet->id.'/media', ['name' => 'PDF', 'file' => $pdf], ['Accept' => 'application/json'])->assertCreated();
        $this->actingAs($u)->post('/api/whatsapp/chatbot/'.$outlet->id.'/media', ['name' => 'Exe', 'file' => UploadedFile::fake()->createWithContent('x.pdf', 'MZ'.str_repeat('a', 50))], ['Accept' => 'application/json'])->assertStatus(422);
        for ($i = 0; $i < 8; $i++) Media::store($u->business_id, $outlet->id, UploadedFile::fake()->image("b$i.jpg", 50, 50), "F$i");
        $this->actingAs($u)->post('/api/whatsapp/chatbot/'.$outlet->id.'/media', ['name' => 'Ke-11', 'file' => UploadedFile::fake()->image('c.jpg', 50, 50)], ['Accept' => 'application/json'])->assertStatus(422);
        $copy = $this->actingAs($u)->postJson('/api/whatsapp/media/'.$m->id.'/copy', ['outlet_id' => $other->id])->assertCreated()->json();
        $this->assertSame($other->id, $copy['outlet_id']);
        $this->actingAs($u)->deleteJson('/api/whatsapp/media/'.$m->id)->assertNoContent();
        Storage::disk('local')->assertMissing($m->path);
        Storage::disk('local')->assertExists(DB::table('wa_media')->where('id', $copy['id'])->value('path'));
        // usaha lain tidak bisa menyentuh media ini
        $x = $this->owner();
        $this->actingAs($x)->deleteJson('/api/whatsapp/media/'.$copy['id'])->assertNotFound();
        $this->get('/wa/media/'.$copy['id'].'?v=1')->assertForbidden();
    }

    public function test_settings_api_checks_version_and_package(): void {
        $u = $this->owner('Silver'); $outlet = $u->business->outlets()->first();
        $this->actingAs($u)->getJson('/api/whatsapp/chatbot/'.$outlet->id)->assertOk()->assertJsonPath('features.ai', false)->assertJsonPath('settings.version', 0);
        $this->actingAs($u)->putJson('/api/whatsapp/chatbot/'.$outlet->id, ['version' => 0, 'ai_enabled' => true])->assertForbidden();
        $this->actingAs($u)->putJson('/api/whatsapp/chatbot/'.$outlet->id, ['version' => 0, 'takeover_minutes' => 15, 'knowledge' => 'Antar gratis 3 km'])->assertOk()->assertJsonPath('settings.version', 1);
        $this->actingAs($u)->putJson('/api/whatsapp/chatbot/'.$outlet->id, ['version' => 0, 'takeover_minutes' => 20])->assertStatus(409);
        $id = (string) Str::uuid();
        $this->actingAs($u)->postJson('/api/whatsapp/chatbot/'.$outlet->id.'/replies', ['id' => $id, 'name' => 'Jam', 'keys' => 'jam buka', 'mode' => 'contains', 'reply' => '08.00–20.00'])->assertCreated();
        $this->actingAs($u)->postJson('/api/whatsapp/chatbot/'.$outlet->id.'/replies', ['id' => $id, 'name' => 'Jam', 'keys' => 'jam buka', 'mode' => 'contains', 'reply' => '07.00–21.00'])->assertOk();
        $this->assertSame('07.00–21.00', DB::table('wa_quick_replies')->value('reply'));
        $this->actingAs($this->owner())->getJson('/api/whatsapp/chatbot/'.$outlet->id)->assertNotFound();
    }

    // ------------------------------------------------------------------ pesan otomatis

    public function test_auto_messages_ready_and_late_once_and_respect_quiet_hours(): void {
        $u = $this->owner(); $d = $this->device($u);
        DB::table('wa_bot_settings')->insert(['business_id' => $u->business_id, 'outlet_id' => $d->outlet_id, 'auto_ready' => true, 'auto_late' => true, 'auto_nota' => true,
            'late_days' => 3, 'quiet_from' => '00:00', 'quiet_until' => '00:00', 'created_at' => now(), 'updated_at' => now()]);
        $this->order($d, 'BKS-1', 'siap', ['ready_at' => now()->subHour(), 'ordered_at' => now()->subDays(2), 'delivery' => true]);
        $this->order($d, 'BKS-2', 'siap', ['ready_at' => now()->subDays(4), 'ordered_at' => now()->subDays(5)]);
        $this->order($d, 'BKS-3', 'antrian', ['ordered_at' => now()->subMinutes(5)]);
        $this->assertSame(3, app(AutoMessages::class)->run());
        $this->assertSame(0, app(AutoMessages::class)->run());
        $bodies = DB::table('wa_outbox')->pluck('body')->map(fn ($b) => Crypt::decryptString($b))->implode("\n---\n");
        $this->assertStringContainsString('diantar kurir', $bodies);
        $this->assertStringContainsString('belum diambil', $bodies);
        $this->assertStringContainsString('/wa/nota?', $bodies);
        // jam tenang sepanjang hari → tidak ada kiriman baru
        DB::table('wa_bot_settings')->update(['quiet_from' => '00:00', 'quiet_until' => '23:59']);
        $this->order($d, 'BKS-4', 'antrian', ['ordered_at' => now()]);
        $this->assertSame(0, app(AutoMessages::class)->run());
    }

    public function test_auto_messages_need_gold(): void {
        $u = $this->owner('Silver'); $d = $this->device($u);
        DB::table('wa_bot_settings')->insert(['business_id' => $u->business_id, 'outlet_id' => $d->outlet_id, 'auto_ready' => true, 'quiet_from' => '00:00', 'quiet_until' => '00:00', 'created_at' => now(), 'updated_at' => now()]);
        $this->order($d, 'BKS-1', 'siap', ['ready_at' => now()]);
        $this->assertSame(0, app(AutoMessages::class)->run());
    }

    // ------------------------------------------------------------------ AI lewat CHATKU

    private function aiSetup(int $balance = 10000): array {
        $u = $this->owner(); $d = $this->device($u);
        Business::whereKey($u->business_id)->update(['ai_balance' => $balance]);
        DB::table('wa_bot_settings')->insert(['business_id' => $u->business_id, 'outlet_id' => $d->outlet_id, 'ai_enabled' => true, 'knowledge' => 'Antar gratis 3 km', 'created_at' => now(), 'updated_at' => now()]);
        app(Inbound::class)->receive($this->msg('kak bisa cuci karpet ga?'));
        Queue::assertPushed(AiReply::class);
        $job = Queue::pushed(AiReply::class)->first();
        return [$u, $d, $job];
    }

    public function test_ai_reply_charges_laundry_balance_and_sends_answer(): void {
        [$u, $d, $job] = $this->aiSetup();
        $job->handle(app(Devices::class), app(Replies::class), $this->gw);
        $payload = $this->gw->called('ai')[0][1];
        $this->assertSame('kak bisa cuci karpet ga?', $payload['question']);
        $this->assertStringContainsString('Antar gratis 3 km', $payload['knowledge']);
        $this->assertSame('Halo Kak, bisa.', $this->lastBody());
        $this->assertSame(9880, (int) Business::find($u->business_id)->ai_balance);
        $this->assertDatabaseHas('ai_ledger', ['business_id' => $u->business_id, 'type' => 'usage', 'amount' => -120]);
        $job->handle(app(Devices::class), app(Replies::class), $this->gw); // ulang: tidak dobel
        $this->assertSame(1, DB::table('wa_outbox')->count());
        $this->assertSame(9880, (int) Business::find($u->business_id)->ai_balance);
    }

    public function test_ai_invented_price_is_never_sent(): void {
        [, , $job] = $this->aiSetup();
        $this->gw->aiAnswer = ['answer' => 'Cuci karpet Rp99.000 kak', 'cost' => 100, 'unverified_prices' => ['Rp99.000']];
        $job->handle(app(Devices::class), app(Replies::class), $this->gw);
        $this->assertStringNotContainsString('99.000', $this->lastBody());
        $this->assertStringContainsString('admin kami cek', $this->lastBody());
    }

    public function test_ai_without_balance_hands_over_to_admin(): void {
        [, , $job] = $this->aiSetup(0);
        $job->handle(app(Devices::class), app(Replies::class), $this->gw);
        $this->assertCount(0, $this->gw->called('ai'));
        $this->assertStringContainsString('teruskan ke admin', $this->lastBody());
    }

    public function test_ai_topup_is_forwarded_to_chatku(): void {
        $u = $this->owner();
        AiBilling::topUp($u->business, 50000, 'TRF-1', null);
        Queue::assertPushed(ForwardAiTopup::class, fn ($j) => $j->amount === 50000 && $j->reference === 'TRF-1');
        Queue::pushed(ForwardAiTopup::class)->first()->handle($this->gw);
        $this->assertSame([$u->business_id, 50000, ForwardAiTopup::reference('TRF-1')], $this->gw->called('aiTopup')[0]);
        $this->assertLessThanOrEqual(120, strlen(ForwardAiTopup::reference(str_repeat('x', 120))));
    }

    // ------------------------------------------------------------------ blast

    public function test_blast_platinum_only_skips_opted_out_and_tracks_status(): void {
        $u = $this->owner('Platinum'); $d = $this->device($u);
        foreach ([['budi', '081234567890'], ['sari', '081277777777'], ['tanpa', ''], ['budi2', '0812-3456-7890']] as $i => [$n, $p]) {
            DB::table('sync_records')->insert(['business_id' => $u->business_id, 'collection' => 'customers', 'record_key' => 'c'.$i, 'data' => json_encode(['name' => $n, 'phone' => $p]), 'rev' => $i + 1, 'created_at' => now(), 'updated_at' => now()]);
        }
        DB::table('wa_optouts')->insert(['business_id' => $u->business_id, 'contact' => Chatbot::contact('biz'.$u->business_id, '6281277777777'), 'kind' => 'promo', 'created_at' => now()]);
        $res = $this->actingAs($u)->postJson('/api/whatsapp/blasts', ['device_id' => $d->id, 'name' => 'Promo', 'body' => 'Halo {nama}, diskon 20%!', 'audience' => 'all'])->assertCreated();
        $payload = $this->gw->called('blast')[0][1];
        $this->assertCount(1, $payload['recipients']);
        $this->assertStringContainsString('Halo Budi, diskon 20%!', $payload['recipients'][0]['text']);
        $this->assertStringContainsString('Balas STOP', $payload['recipients'][0]['text']);
        $this->postJson('/api/whatsapp/chatku/events', ['type' => 'blast.message', 'device' => '77', 'data' => ['blast_ref' => $payload['ref'], 'to' => '6281234567890',
            'ref' => $payload['recipients'][0]['ref'], 'status' => 'sent']], ['X-Test-Signature' => 'sah'])->assertOk();
        $this->assertDatabaseHas('wa_blasts', ['id' => $res->json('id'), 'sent' => 1]);
        $this->assertSame('0812••••7890', DB::table('wa_blast_recipients')->value('masked'));
        $g = $this->owner('Gold'); $gd = $this->device($g, ['remote_id' => '78']);
        $this->actingAs($g)->postJson('/api/whatsapp/blasts', ['device_id' => $gd->id, 'name' => 'Promo', 'body' => 'x', 'audience' => 'all'])->assertForbidden();
    }

    // ------------------------------------------------------------------ QRIS

    public function test_qris_change_notifies_owner(): void {
        Mail::fake();
        $u = $this->owner(); $u->forceFill(['role' => 'owner'])->save();
        $qris = fn ($name) => '00020101021126610014COM.GO-JEK.WWW01189360091434506469550210G4506469550303UMI51440014ID.CO.QRIS.WWW0215ID10200211817450303UMI5204581253033605802ID59'
            .sprintf('%02d', strlen($name)).$name.'6007JAKARTA61051234062070703A016304ABCD';
        DB::table('sync_records')->insert(['business_id' => $u->business_id, 'collection' => 'settings', 'record_key' => 'goyana-qris-text', 'data' => json_encode($qris('LAUNDRY BERSIH')), 'rev' => 1, 'created_at' => now(), 'updated_at' => now()]);
        $this->assertSame(0, app(QrisWatch::class)->run());
        $this->assertSame(['name' => 'LAUNDRY BERSIH', 'city' => 'JAKARTA', 'nmid' => 'ID1020021181745'], QrisWatch::parse(QrisWatch::emv(json_encode($qris('LAUNDRY BERSIH')))));
        DB::table('sync_records')->update(['data' => json_encode($qris('ORANG LAIN'))]);
        $this->assertSame(1, app(QrisWatch::class)->run());
        $this->assertDatabaseHas('audit_events', ['business_id' => $u->business_id, 'action' => 'qris.changed']);
        $this->assertStringContainsString('ORANG LAIN', DB::table('outbound_messages')->where('kind', 'qris_changed')->value('body'));
        $this->assertSame(0, app(QrisWatch::class)->run());
    }

    public function test_review_fixes_self_chat_stop_while_paused_zero_takeover_and_guess_limit(): void {
        $g = new ChatkuHttpGateway(new Client(config('whatsapp.chatku')), config('whatsapp.chatku'));
        $e = $g->verifyInbound($this->signed(['id' => 'e', 'event' => 'message.from_me', 'device' => ['id' => 77, 'phone' => '6281200000001'],
            'data' => ['message_id' => 'W', 'to' => null, 'self' => true, 'text' => '#stop', 'sent_at' => now()->toIso8601String()]]));
        $this->assertSame('6281200000001', $e['from']);
        $u = $this->owner('Platinum'); $d = $this->device($u);
        app(Inbound::class)->receive($e);
        $this->assertTrue(Chatbot::paused($d, Chatbot::contact($d->id, '6281234567890')));
        app(Inbound::class)->receive($this->msg('STOP'));
        $this->assertTrue(Chatbot::optedOut($u->business_id, '6281234567890'));
        $this->assertSame(0, DB::table('wa_outbox')->count());
        app(Inbound::class)->receive($this->msg('#bot', ['from_me' => true, 'self' => true, 'from' => '6281200000001']));
        DB::table('wa_bot_settings')->insert(['business_id' => $u->business_id, 'outlet_id' => $d->outlet_id, 'takeover_minutes' => 0, 'created_at' => now(), 'updated_at' => now()]);
        app(Inbound::class)->receive($this->msg('baik kak', ['from_me' => true]));
        $this->assertFalse(Chatbot::paused($d, Chatbot::contact($d->id, '6281234567890')));
        // tebak 4 angka: maks. 5 percobaan per kode per hari, jawaban tanpa tagihan
        $this->order($d, 'BKS-261008-1-0133', 'cuci');
        for ($i = 0; $i < 5; $i++) app(Replies::class)->status($d, '6289999999999', 'BKS-261008-1-0133 '.(1000 + $i));
        $this->assertStringContainsString('belum ditemukan', app(Replies::class)->status($d, '6289999999999', 'BKS-261008-1-0133 7890'));
        \Illuminate\Support\Facades\RateLimiter::clear('wa-code4:'.$d->business_id.':BKS-261008-1-0133');
        $r = app(Replies::class)->status($d, '6289999999999', 'BKS-261008-1-0133 7890');
        $this->assertStringContainsString('dicuci', $r); $this->assertStringNotContainsString('Rp', $r); $this->assertStringNotContainsString('Budi', $r);
        // pesan sangat panjang tidak 422
        $this->postJson('/api/whatsapp/chatku/events', $this->msg(str_repeat('a ', 3000)), ['X-Test-Signature' => 'sah'])->assertOk();
    }

    // ------------------------------------------------------------------ hapus perangkat

    public function test_removing_device_deletes_it_at_chatku(): void {
        $u = $this->owner(); $d = $this->device($u);
        $this->actingAs($u)->deleteJson('/api/whatsapp/devices/'.$d->id)->assertNoContent();
        $this->assertSame(['77'], $this->gw->called('remove')[0]);
    }
}
