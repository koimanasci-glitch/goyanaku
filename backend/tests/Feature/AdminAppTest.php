<?php
namespace Tests\Feature;

use App\Models\{Business, User};
use App\Support\{Blast, ServerStats, Settings};
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/** Aplikasi administrator: Beranda, divisi, monitor VPS, CRM marketing, dan WA blast yang digilir (keputusan pengguna 8 Oktober 2026). */
class AdminAppTest extends TestCase {
    use RefreshDatabase;

    private function admin(?string $division = null, string $name = 'Admin'): User {
        $u = new User(['name' => $name, 'email' => uniqid().'@example.test', 'password' => 'PasswordAman123']);
        $u->is_platform_admin = true; $u->admin_division = $division; $u->save(); return $u->fresh();
    }

    private function client(string $name, ?string $phone = null, bool $expired = false): Business {
        $b = Business::create(['name' => $name, 'trial_ends_at' => $expired ? now()->subDay() : now()->addMonth()]);
        $b->outlets()->create(['name' => $name.' Pusat']);
        $u = new User(['name' => 'Pemilik '.$name, 'email' => uniqid().'@example.test', 'password' => 'PasswordAman123', 'phone' => $phone]);
        $u->business()->associate($b); $u->save();
        return $b;
    }

    private function prospect(string $name, string $phone, array $extra = []): int {
        return DB::table('prospects')->insertGetId($extra + ['name' => $name, 'phone' => $phone, 'source' => 'manual', 'status' => 'baru', 'created_at' => now(), 'updated_at' => now()]);
    }

    private function gateway(int $status = 200): void {
        config(['goyana.whatsapp.driver' => 'http', 'goyana.whatsapp.url' => 'https://wa.example/send', 'goyana.whatsapp.token' => 'rahasia']);
        Http::fake(['wa.example/*' => Http::response(['ok' => true], $status)]);
    }

    /** Senin 12 Oktober 2026, 10.00 WIB. */
    private function workTime(): CarbonImmutable { return CarbonImmutable::parse('2026-10-12 10:00', 'Asia/Jakarta'); }

    private function sender(string $phone = '6281100000001', ?CarbonImmutable $started = null): int {
        return DB::table('marketing_senders')->insertGetId(['label' => 'Marketing 1', 'phone' => $phone, 'active' => true, 'started_at' => ($started ?? $this->workTime())->utc(), 'created_at' => now(), 'updated_at' => now()]);
    }

    private function campaign(array $data = []): int {
        $this->post('/admin/marketing/campaigns', $data + ['name' => 'Perkenalan', 'audience' => 'prospects', 'statuses' => ['baru'], 'variants' => ['Halo {nama}, info untuk {usaha}?', 'Hai {nama} dari {usaha}']])->assertRedirect();
        return (int) DB::table('campaigns')->max('id');
    }

    // ---------- Beranda dan divisi ----------

    public function test_home_shows_totals_menu_and_recent_clients_in_the_goyana_theme(): void {
        $this->client('Laundry Bersih Jaya'); $this->client('Laundry Lama', null, true);
        $this->actingAsAdmin($this->admin())->get('/admin')->assertOk()
            ->assertSeeInOrder(['Total Client', '2', 'Total Outlet', '2', 'Paket Aktif', '0', 'Client Trial', '1'])
            ->assertSee('Tambah Client')->assertSee('Monitor VPS')->assertSee('Client Terbaru')->assertSee('Laundry Bersih Jaya')->assertSee('Baca saja')
            ->assertSee('Poppins')->assertSee('/icons/mark.svg')->assertSee('Management Client', false)->assertSee('Beranda');
        $this->get('/admin/features')->assertOk()->assertSee('Audit')->assertSee('Pengguna');
        $this->get('/admin/packages')->assertOk()->assertSee('Platinum')->assertSee('Rp350.000');
        $this->get('/admin/reports')->assertOk()->assertSee('Laporan SaaS')->assertSee('Client per paket');
    }

    public function test_each_division_opens_only_its_own_areas(): void {
        $b = $this->client('Laundry Uji');
        $open = ['marketing' => ['/admin', '/admin/features', '/admin/marketing', '/admin/marketing/clients', '/admin/marketing/campaigns', '/admin/reports'],
            'cs' => ['/admin', '/admin/clients', '/admin/businesses/'.$b->id, '/admin/tickets', '/admin/faqs'],
            'teknis' => ['/admin', '/admin/clients', '/admin/system', '/admin/settings', '/admin/audit']];
        $closed = ['marketing' => ['/admin/clients', '/admin/businesses/'.$b->id, '/admin/system', '/admin/settings', '/admin/audit', '/admin/admins', '/admin/tickets', '/admin/clients/new'],
            'cs' => ['/admin/marketing', '/admin/system', '/admin/settings', '/admin/admins', '/admin/reports', '/admin/clients/new'],
            'teknis' => ['/admin/marketing', '/admin/tickets', '/admin/admins', '/admin/reports', '/admin/clients/new']];
        foreach ($open as $division => $urls) {
            $this->actingAsAdmin($this->admin($division));
            foreach ($urls as $url) $this->get($url)->assertOk();
            foreach ($closed[$division] as $url) $this->get($url)->assertForbidden();
        }
        // Marketing tidak bisa mengubah paket; CS boleh memberi paket sementara tetapi tidak membuat langganan.
        $grant = ['package' => 'Gold', 'reason' => 'Uji', 'ends_at' => now('Asia/Jakarta')->addDays(5)->format('Y-m-d\TH:i')];
        $this->actingAsAdmin($this->admin('marketing'))->post('/admin/businesses/'.$b->id.'/grants', $grant)->assertForbidden();
        $this->actingAsAdmin($this->admin('cs'))->post('/admin/businesses/'.$b->id.'/grants', $grant)->assertRedirect();
        $this->post('/admin/businesses/'.$b->id.'/subscriptions', [])->assertForbidden();
        // Beranda marketing tidak menautkan data client dan tidak menampilkan server.
        $this->actingAsAdmin($this->admin('marketing'))->get('/admin')->assertDontSee('/admin/businesses/'.$b->id)->assertDontSee('Monitor VPS ›');
        // Administrator lama tanpa divisi adalah pemilik: semua terbuka.
        $this->actingAsAdmin($this->admin())->get('/admin/admins')->assertOk();
    }

    public function test_owner_manages_division_accounts_and_cannot_lose_the_last_owner(): void {
        $owner = $this->admin();
        $this->actingAsAdmin($owner)->post('/admin/admins', ['name' => 'Rina Marketing', 'email' => 'Rina@Goyana.test', 'password' => 'PasswordAman123', 'division' => 'marketing'])->assertRedirect()->assertSessionHasNoErrors();
        $rina = User::where('email', 'rina@goyana.test')->firstOrFail();
        $this->assertSame([true, 'marketing'], [(bool) $rina->is_platform_admin, $rina->adminDivision()]);
        $this->get('/admin/admins')->assertSee('Rina Marketing')->assertSee('OTP belum dipasang');
        $this->post('/admin/admins/'.$rina->id, ['division' => 'cs'])->assertSessionHasNoErrors();
        $this->assertSame('cs', $rina->fresh()->adminDivision());
        $this->post('/admin/admins/'.$rina->id.'/toggle')->assertSessionHasNoErrors();
        $this->assertNotNull($rina->fresh()->deactivated_at);
        // Pemilik terakhir tidak bisa diturunkan atau menonaktifkan dirinya.
        $this->post('/admin/admins/'.$owner->id, ['division' => 'marketing'])->assertSessionHasErrors('division');
        $this->post('/admin/admins/'.$owner->id.'/toggle')->assertSessionHasErrors('admin');
        $this->assertDatabaseHas('platform_audit', ['actor_id' => $owner->id, 'action' => 'admin.created']);
        // Akun laundry tidak bisa dijadikan sasaran rute ini.
        $laundry = $this->client('Laundry X')->users()->first();
        $this->post('/admin/admins/'.$laundry->id, ['division' => 'cs'])->assertNotFound();
    }

    public function test_admin_adds_a_client_with_owner_account_on_trial(): void {
        $this->actingAsAdmin($this->admin())->post('/admin/clients', ['business_name' => 'Star Clean', 'name' => 'Bu Star', 'email' => 'Star@Clean.test', 'phone' => '0812-0000-1111', 'password' => 'PasswordAman123'])
            ->assertRedirect()->assertSessionHasNoErrors();
        $owner = User::where('email', 'star@clean.test')->firstOrFail();
        $this->assertSame(['owner', '6281200001111', 'Star Clean'], [$owner->role, $owner->phone, $owner->business->name]);
        $this->assertSame(['Basic', 'trial'], [$owner->business->currentAccess()['package'], $owner->business->currentAccess()['source']]);
        $this->assertSame(1, $owner->business->outlets()->count());
        $this->post('/admin/clients', ['business_name' => 'Lain', 'name' => 'X', 'email' => 'lain@clean.test', 'phone' => '081200001111', 'password' => 'PasswordAman123'])->assertSessionHasErrors('phone');
    }

    // ---------- monitor VPS ----------

    public function test_vps_monitor_shows_ram_cpu_disk_and_history(): void {
        $s = ServerStats::now();
        $this->assertGreaterThan(0, $s['ram_total']); $this->assertGreaterThan(0, $s['disk_total']); $this->assertGreaterThanOrEqual(1, $s['cpu_cores']);
        $this->assertSame(['ok', 'warn', 'fail'], [ServerStats::state(50), ServerStats::state(85), ServerStats::state(95)]);
        ServerStats::record(); ServerStats::record();
        $this->assertCount(2, ServerStats::history());
        $this->artisan('goyana:health');
        $this->assertSame(3, DB::table('server_metrics')->count());
        $this->actingAsAdmin($this->admin('teknis'))->get('/admin/system')->assertOk()->assertSee('Monitor VPS')->assertSee('RAM')->assertSee('CPU')->assertSee('Disk')
            ->assertSee('24 jam terakhir')->assertSee('<polyline', false)->assertSee('Server menyala');
    }

    // ---------- CRM marketing ----------

    public function test_prospects_are_added_imported_deduplicated_and_never_include_existing_clients(): void {
        $this->client('Laundry Sudah Client', '6281299990000');
        $this->actingAsAdmin($marketing = $this->admin('marketing'));
        $this->post('/admin/marketing/prospects', ['name' => 'Laundry Kencana', 'phone' => '0812-1111-2222', 'city' => 'Bekasi'])->assertSessionHas('status', 'Calon client ditambahkan.');
        $this->post('/admin/marketing/prospects', ['name' => 'Kembar', 'phone' => '6281211112222'])->assertSessionHas('status', 'Nomor itu sudah ada di daftar.');
        $this->post('/admin/marketing/prospects', ['name' => 'Client', 'phone' => '081299990000'])->assertSessionHas('status', 'Nomor itu sudah terdaftar sebagai client.');
        $csv = "Nama Usaha;Nomor;Pemilik;Kota\nLaundry Express;0813 3333 4444;Pak Eko;Bekasi\nLaundry Kencana;081211112222;;\nSalah;123;;\nStar Wash;+62 814-5555-6666;;Depok\nSudah;081299990000;;\n";
        $this->post('/admin/marketing/prospects/import', ['file' => UploadedFile::fake()->createWithContent('calon.csv', $csv), 'source' => 'pameran'])
            ->assertSessionHas('status', '2 calon ditambahkan · 1 sudah ada · 1 sudah client · 1 nomor tidak valid.');
        $this->assertSame(['6281211112222', '6281333334444', '6281455556666'], DB::table('prospects')->orderBy('phone')->pluck('phone')->all());
        $this->assertSame(['Pak Eko', 'Bekasi', 'pameran'], array_values((array) DB::table('prospects')->where('phone', '6281333334444')->first(['owner_name', 'city', 'source'])));
        $this->get('/admin/marketing?city=Bekasi')->assertOk()->assertSee('Laundry Kencana')->assertSee('Laundry Express')->assertDontSee('Star Wash');
        // Marketing melihat client hanya sebagai usaha, pemilik, nomor, paket.
        $this->get('/admin/marketing/clients')->assertOk()->assertSee('Laundry Sudah Client')->assertSee('+6281299990000');
        // Calon yang kemudian mendaftar ditandai otomatis.
        $this->client('Star Wash', '6281455556666');
        $this->assertSame(1, Blast::markRegistered());
        $this->assertSame('daftar', DB::table('prospects')->where('phone', '6281455556666')->value('status'));
        $this->assertDatabaseHas('platform_audit', ['actor_id' => $marketing->id, 'action' => 'marketing.import']);
    }

    public function test_campaign_queue_rotates_wording_and_skips_people_who_must_not_be_contacted(): void {
        $this->prospect('Laundry A', '6281200000001', ['owner_name' => 'Bu Ani', 'city' => 'Bekasi']);
        $this->prospect('Laundry B', '6281200000002', ['city' => 'Bekasi']);
        $this->prospect('Laundry C', '6281200000003', ['city' => 'Depok']);
        $this->prospect('Laundry Stop', '6281200000004', ['city' => 'Bekasi', 'do_not_contact' => true, 'status' => 'menolak']);
        $this->prospect('Laundry Tertarik', '6281200000005', ['city' => 'Bekasi', 'status' => 'tertarik']);
        $this->actingAsAdmin($this->admin('marketing'));
        $id = $this->campaign(['city' => 'Bekasi']);
        $rows = DB::table('campaign_messages')->where('campaign_id', $id)->orderBy('id')->get();
        $this->assertSame(['6281200000001', '6281200000002'], $rows->pluck('phone')->all());
        $this->assertSame(['Halo Bu Ani, info untuk Laundry A?', 'Hai Laundry B dari Laundry B'], $rows->pluck('body')->all());
        $this->assertSame('draft', DB::table('campaigns')->where('id', $id)->value('status'));
        // Kampanye kedua tidak mengantre ulang orang yang masih menunggu di kampanye pertama.
        $second = $this->campaign(['name' => 'Kedua']);
        $this->assertSame(['6281200000003'], DB::table('campaign_messages')->where('campaign_id', $second)->pluck('phone')->all());
        // Sasaran client: pemilik yang punya nomor saja.
        $this->client('Laundry Client', '6281277770000'); $this->client('Tanpa Nomor');
        $third = $this->campaign(['name' => 'Upgrade', 'audience' => 'clients', 'access' => 'trial', 'variants' => ['Halo {nama}, trial {usaha} segera habis.']]);
        $this->assertSame(['Halo Pemilik Laundry Client, trial Laundry Client segera habis.'], DB::table('campaign_messages')->where('campaign_id', $third)->pluck('body')->all());
        $this->get('/admin/marketing/campaigns/'.$id)->assertOk()->assertSee('Mulai kampanye')->assertSee('Gateway WhatsApp belum tersambung')->assertSee('wa.me/6281200000001', false);
    }

    public function test_blast_sends_one_at_a_time_within_quota_hours_and_random_gap(): void {
        $this->gateway();
        foreach (range(1, 30) as $i) $this->prospect('Laundry '.$i, '62812000001'.str_pad((string) $i, 2, '0', STR_PAD_LEFT));
        $this->actingAsAdmin($this->admin('marketing'));
        $id = $this->campaign(); $sender = $this->sender(); $now = $this->workTime();
        // Draf: tidak ada yang terkirim sebelum kampanye dimulai.
        $this->assertSame(0, Blast::tick($now)['sent']);
        $this->post('/admin/marketing/campaigns/'.$id.'/status', ['status' => 'running'])->assertRedirect();
        $this->assertSame(1, Blast::tick($now)['sent']);
        Http::assertSent(fn ($r) => $r['from'] === '6281100000001' && $r['to'] === '6281200000101' && $r->hasHeader('Authorization', 'Bearer rahasia'));
        // Jeda acak 2–6 menit: semenit kemudian belum boleh, tujuh menit kemudian boleh.
        $next = CarbonImmutable::parse(DB::table('marketing_senders')->where('id', $sender)->value('next_at'));
        $this->assertTrue($next->gte($now->addMinutes(2)) && $next->lte($now->addMinutes(6)));
        $this->assertSame(0, Blast::tick($now->addMinute())['sent']);
        $this->assertSame(1, Blast::tick($now->addMinutes(7))['sent']);
        // Di luar jam kirim dan hari Minggu: diam.
        $this->assertSame('Di luar jam kirim', Blast::tick($now->setTime(20, 0))['idle']);
        $this->assertSame('Di luar jam kirim', Blast::tick(CarbonImmutable::parse('2026-10-11 10:00', 'Asia/Jakarta'))['idle']);
        // Jatah hari pertama 20: sesudah itu berhenti sampai besok, walau antrean masih ada.
        for ($i = 0; $i < 40; $i++) Blast::tick($now->addMinutes(10 + $i * 7));
        $this->assertSame(20, Blast::sentToday($sender, $now));
        $this->assertSame(10, DB::table('campaign_messages')->where('status', 'queued')->count());
        $this->assertSame('dihubungi', DB::table('prospects')->where('phone', '6281200000101')->value('status'));
        // Pemanasan: minggu ketiga jatahnya 40, dan tidak pernah lewat batas atas 80.
        $this->assertSame([20, 40, 80], [Blast::quota((object) ['id' => 0, 'started_at' => $now], $now), Blast::quota((object) ['id' => 0, 'started_at' => $now->subDays(15)], $now),
            Blast::quota((object) ['id' => 0, 'started_at' => $now->subDays(400)], $now)]);
    }

    public function test_stop_reply_ends_all_contact_and_a_reply_cancels_the_follow_up(): void {
        $this->gateway(); config(['goyana.whatsapp.webhook_token' => 'token-webhook']);
        $a = $this->prospect('Laundry A', '6281200000001'); $b = $this->prospect('Laundry B', '6281200000002'); $c = $this->prospect('Laundry C', '6281200000003');
        $this->actingAsAdmin($this->admin('marketing'));
        $id = $this->campaign(['followups' => ['Halo lagi {nama}, masih berminat?']]);
        $this->post('/admin/marketing/campaigns/'.$id.'/status', ['status' => 'running']);
        $this->sender(); $now = $this->workTime();
        foreach ([0, 7, 14] as $m) Blast::tick($now->addMinutes($m));
        $this->assertSame(3, DB::table('campaign_messages')->where('kind', 'followup')->where('status', 'queued')->count());
        // Tindak lanjut baru boleh dikirim 5 hari kemudian.
        $this->assertSame(0, Blast::tick($now->addDays(2))['sent']);
        // A membalas STOP, B membalas biasa, C diam.
        $this->flushHeaders();
        $this->postJson('/api/marketing/inbound', ['from' => '081200000001', 'text' => 'Stop ya, jangan kirim lagi'])->assertForbidden();
        $this->withToken('token-webhook')->postJson('/api/marketing/inbound', ['from' => '081200000001', 'text' => 'Stop ya, jangan kirim lagi'])->assertJsonPath('result', 'stopped');
        $this->withToken('token-webhook')->postJson('/api/marketing/inbound', ['from' => '6281200000002', 'text' => 'Boleh, berapa harganya?'])->assertJsonPath('result', 'recorded');
        $this->assertSame([1, 'menolak'], [(int) DB::table('prospects')->where('id', $a)->value('do_not_contact'), DB::table('prospects')->where('id', $a)->value('status')]);
        $this->assertSame(['membalas', 1], [DB::table('prospects')->where('id', $b)->value('status'), (int) DB::table('prospects')->where('id', $b)->value('replies')]);
        $this->assertDatabaseHas('marketing_optouts', ['phone' => '6281200000001']);
        // Hari keenam: hanya C yang menerima tindak lanjut.
        $later = $now->addDays(7);
        foreach ([0, 7, 14] as $m) Blast::tick($later->addMinutes($m));
        $this->assertSame(['6281200000003'], DB::table('campaign_messages')->where('kind', 'followup')->where('status', 'sent')->pluck('phone')->all());
        $this->assertSame('done', DB::table('campaigns')->where('id', $id)->value('status'));
        // Yang pernah STOP tidak bisa dimasukkan lagi dan tidak ikut kampanye berikutnya.
        $this->actingAsAdmin($this->admin('marketing'));
        DB::table('prospects')->where('id', $a)->delete();
        $this->post('/admin/marketing/prospects', ['name' => 'Laundry A lagi', 'phone' => '081200000001'])->assertSessionHas('status', 'Nomor itu pernah meminta tidak dihubungi.');
        $this->assertSame(0, DB::table('prospects')->where('phone', '6281200000001')->count());
    }

    public function test_repeated_failures_pause_the_sender_and_manual_sending_still_respects_opt_outs(): void {
        $this->gateway(500);
        foreach (range(1, 8) as $i) $this->prospect('Laundry '.$i, '628120000000'.$i);
        $this->actingAsAdmin($this->admin('marketing'));
        $id = $this->campaign(); $this->post('/admin/marketing/campaigns/'.$id.'/status', ['status' => 'running']);
        $sender = $this->sender(); $now = $this->workTime();
        for ($i = 0; $i < 8; $i++) Blast::tick($now->addMinutes($i));
        $row = DB::table('marketing_senders')->where('id', $sender)->first();
        $this->assertNotNull($row->paused_at); $this->assertStringContainsString('5 pesan gagal berturut-turut', $row->pause_reason);
        $this->assertSame([5, 3], [DB::table('campaign_messages')->where('status', 'failed')->count(), DB::table('campaign_messages')->where('status', 'queued')->count()]);
        $this->get('/admin/marketing/campaigns')->assertOk()->assertSee('Dihentikan otomatis')->assertSee('Jalankan lagi');
        // Kirim manual: ditandai terkirim, calon berubah status; yang minta berhenti ditolak.
        $queued = DB::table('campaign_messages')->where('status', 'queued')->orderBy('id')->get();
        $this->post('/admin/marketing/messages/'.$queued[0]->id.'/sent')->assertSessionHasNoErrors();
        $this->assertSame('manual', DB::table('campaign_messages')->where('id', $queued[0]->id)->value('status'));
        Blast::optOut($queued[1]->phone, 'uji');
        $this->assertSame('skipped', DB::table('campaign_messages')->where('id', $queued[1]->id)->value('status'));
        // Nomor CS pusat tidak boleh dipakai untuk blast.
        Settings::put(['cs_whatsapp' => '6281100000009'], null);
        $this->post('/admin/marketing/senders', ['label' => 'CS', 'phone' => '081100000009'])->assertSessionHasErrors('phone');
        $this->post('/admin/marketing/senders', ['label' => 'Marketing 2', 'phone' => '081100000002'])->assertSessionHasNoErrors();
        $this->post('/admin/marketing/rules', ['blast_start_per_day' => 10, 'blast_step_per_week' => 5, 'blast_max_per_day' => 40, 'blast_gap_min' => 3, 'blast_gap_max' => 9,
            'blast_hour_start' => 9, 'blast_hour_end' => 16, 'blast_followup_days' => 7, 'blast_recontact_days' => 45, 'blast_fail_stop' => 4])->assertSessionHasNoErrors();
        $this->assertSame([10, 40, 16, false], [Settings::get('blast_start_per_day'), Settings::get('blast_max_per_day'), Settings::get('blast_hour_end'), Settings::get('blast_sunday')]);
        $this->post('/admin/marketing/rules', ['blast_start_per_day' => 90, 'blast_step_per_week' => 5, 'blast_max_per_day' => 40, 'blast_gap_min' => 3, 'blast_gap_max' => 9,
            'blast_hour_start' => 9, 'blast_hour_end' => 16, 'blast_followup_days' => 7, 'blast_recontact_days' => 45, 'blast_fail_stop' => 4])->assertSessionHasErrors('blast_max_per_day');
    }

    public function test_without_a_gateway_nothing_is_sent_automatically(): void {
        $this->prospect('Laundry A', '6281200000001');
        $this->actingAsAdmin($this->admin('marketing'));
        $id = $this->campaign(); $this->post('/admin/marketing/campaigns/'.$id.'/status', ['status' => 'running']); $this->sender();
        $this->assertSame('Gateway WhatsApp belum tersambung', Blast::tick($this->workTime())['idle']);
        $this->artisan('goyana:blast')->expectsOutput('Gateway WhatsApp belum tersambung')->assertExitCode(0);
        $this->assertSame(1, DB::table('campaign_messages')->where('status', 'queued')->count());
    }
}
