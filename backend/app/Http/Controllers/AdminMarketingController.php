<?php
namespace App\Http\Controllers;

use App\Models\{Business, User};
use App\Support\{Blast, Settings, WhatsApp};
use Carbon\CarbonImmutable;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

/**
 * Divisi marketing: CRM pemilik laundry (client dan calon client) dan WA blast yang digilir.
 * Marketing hanya melihat nama usaha, nama dan nomor pemilik, kota, dan paket. Transaksi dan pelanggan milik laundry tidak tampil di sini.
 */
class AdminMarketingController {
    public function index(Request $request) {
        $status = array_key_exists((string) $request->query('status'), Blast::STATUSES) ? (string) $request->query('status') : null;
        $term = trim((string) $request->query('q', '')); $city = trim((string) $request->query('city', ''));
        $list = DB::table('prospects')->when($status, fn ($q) => $q->where('status', $status))->when($city !== '', fn ($q) => $q->where('city', $city))
            ->when($term !== '', function ($q) use ($term) {
                $like = '%'.str_replace(['%', '_'], ['\%', '\_'], $term).'%';
                $q->where(fn ($w) => $w->where('name', 'like', $like)->orWhere('owner_name', 'like', $like)->orWhere('phone', 'like', $like));
            })->orderByDesc('id')->paginate(30)->withQueryString();
        return view('admin-marketing', ['prospects' => $list, 'status' => $status, 'term' => $term, 'city' => $city, 'statuses' => Blast::STATUSES,
            'counts' => DB::table('prospects')->selectRaw('status, count(*) as n')->groupBy('status')->pluck('n', 'status')->all(),
            'cities' => DB::table('prospects')->whereNotNull('city')->distinct()->orderBy('city')->limit(200)->pluck('city'),
            'connected' => WhatsApp::connected()]);
    }

    /** Client untuk marketing: usaha, pemilik, nomor, paket dan masa aktif saja. */
    public function clients(Request $request) {
        $status = in_array($request->query('status'), ['paid', 'beta', 'trial', 'expired'], true) ? $request->query('status') : null;
        $rows = Business::withAccessStatus($status)->with(['users' => fn ($u) => $u->where('role', 'owner'), 'outlets'])->latest('id')->paginate(30)->withQueryString();
        return view('admin-marketing-clients', ['clients' => $rows, 'status' => $status]);
    }

    public function store(Request $request) {
        $data = $request->validate(['name' => 'required|string|max:160', 'owner_name' => 'nullable|string|max:120', 'phone' => 'required|string|max:30',
            'city' => 'nullable|string|max:80', 'note' => 'nullable|string|max:1000']);
        $result = $this->add($data + ['source' => 'manual'], $request->user()->id);
        return back()->with('status', ['added' => 'Calon client ditambahkan.', 'duplicate' => 'Nomor itu sudah ada di daftar.', 'client' => 'Nomor itu sudah terdaftar sebagai client.',
            'invalid' => 'Nomor HP tidak valid.', 'optout' => 'Nomor itu pernah meminta tidak dihubungi.'][$result]);
    }

    /** Impor CSV: kolom nama usaha, nomor HP, lalu opsional nama pemilik dan kota. Baris judul dilewati otomatis. */
    public function import(Request $request) {
        $request->validate(['file' => 'required|file|max:2048|mimes:csv,txt', 'source' => 'nullable|string|max:40']);
        $handle = fopen($request->file('file')->getRealPath(), 'r');
        $first = (string) fgets($handle); rewind($handle);
        $delimiter = substr_count($first, ';') > substr_count($first, ',') ? ';' : ',';
        $tally = ['added' => 0, 'duplicate' => 0, 'client' => 0, 'invalid' => 0, 'optout' => 0]; $n = 0; $header = false;
        while (($row = fgetcsv($handle, 2000, $delimiter, '"', '\\')) !== false && $n < 5000) {
            $n++;
            $row = array_map(fn ($v) => trim((string) $v), $row);
            if (count($row) < 2 || $row[0] === '') { $tally['invalid']++; continue; }
            if (!$header && $n === 1 && strlen(preg_replace('/\D+/', '', $row[1])) < 6) { $header = true; $n--; continue; } // baris judul
            $tally[$this->add(['name' => mb_substr($row[0], 0, 160), 'phone' => $row[1], 'owner_name' => mb_substr($row[2] ?? '', 0, 120) ?: null,
                'city' => mb_substr($row[3] ?? '', 0, 80) ?: null, 'source' => trim((string) $request->input('source')) ?: 'impor'], $request->user()->id)]++;
        }
        fclose($handle);
        $this->log($request, 'marketing.import', $tally);
        return back()->with('status', $tally['added'].' calon ditambahkan · '.$tally['duplicate'].' sudah ada · '.$tally['client'].' sudah client · '.$tally['invalid'].' nomor tidak valid'
            .($tally['optout'] ? ' · '.$tally['optout'].' pernah minta tidak dihubungi' : '').'.');
    }

    private function add(array $data, int $userId): string {
        $phone = User::normalizePhone($data['phone']);
        if (!preg_match('/^62\d{8,13}$/', $phone)) return 'invalid';
        if (DB::table('prospects')->where('phone', $phone)->exists()) return 'duplicate';
        if (DB::table('marketing_optouts')->where('phone', $phone)->exists()) return 'optout';
        // Sudah client: tidak dimasukkan sebagai calon.
        if (User::where('phone', $phone)->whereNotNull('business_id')->exists() || DB::table('outlets')->where('phone', $phone)->exists()) return 'client';
        $id = DB::table('prospects')->insertGetId(['name' => $data['name'], 'owner_name' => $data['owner_name'] ?? null, 'phone' => $phone, 'city' => ($data['city'] ?? null) ?: null,
            'source' => $data['source'], 'note' => $data['note'] ?? null, 'created_by' => $userId, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('prospect_events')->insert(['prospect_id' => $id, 'kind' => 'dibuat', 'detail' => 'Sumber: '.$data['source'], 'user_id' => $userId, 'created_at' => now()]);
        return 'added';
    }

    public function show(int $prospect) {
        $p = DB::table('prospects')->where('id', $prospect)->first(); abort_unless($p, 404);
        return view('admin-prospect', ['p' => $p, 'statuses' => Blast::STATUSES,
            'events' => DB::table('prospect_events')->leftJoin('users', 'users.id', '=', 'prospect_events.user_id')->where('prospect_id', $p->id)
                ->orderByDesc('prospect_events.id')->limit(60)->get(['prospect_events.*', 'users.name as actor']),
            'pending' => DB::table('campaign_messages')->join('campaigns', 'campaigns.id', '=', 'campaign_messages.campaign_id')->where('prospect_id', $p->id)
                ->where('campaign_messages.status', 'queued')->orderBy('campaign_messages.id')->get(['campaign_messages.*', 'campaigns.name as campaign'])]);
    }

    public function update(Request $request, int $prospect) {
        $p = DB::table('prospects')->where('id', $prospect)->first(); abort_unless($p, 404);
        $data = $request->validate(['status' => ['required', Rule::in(array_keys(Blast::STATUSES))], 'note' => 'nullable|string|max:1000',
            'owner_name' => 'nullable|string|max:120', 'city' => 'nullable|string|max:80']);
        if ($data['status'] === 'menolak' && !$p->do_not_contact) {
            Blast::optOut($p->phone, 'Ditandai menolak oleh '.$request->user()->name, $request->user()->id);
        } elseif ($data['status'] !== $p->status) {
            DB::table('prospect_events')->insert(['prospect_id' => $p->id, 'kind' => 'status', 'user_id' => $request->user()->id,
                'detail' => Blast::STATUSES[$p->status].' → '.Blast::STATUSES[$data['status']], 'created_at' => now()]);
        }
        // Yang pernah meminta tidak dihubungi tetap tidak dihubungi walau statusnya diubah.
        DB::table('prospects')->where('id', $p->id)->update(['status' => $p->do_not_contact ? 'menolak' : $data['status'], 'note' => $data['note'] ?? null,
            'owner_name' => $data['owner_name'] ?? null, 'city' => ($data['city'] ?? null) ?: null, 'updated_at' => now()]);
        return back()->with('status', 'Kontak diperbarui.');
    }

    // ---------- kampanye ----------

    public function campaigns() {
        $rows = DB::table('campaigns')->orderByDesc('id')->limit(100)->get();
        $tally = DB::table('campaign_messages')->selectRaw('campaign_id, status, count(*) as n')->groupBy('campaign_id', 'status')->get()->groupBy('campaign_id')
            ->map(fn ($g) => $g->pluck('n', 'status')->all())->all();
        return view('admin-campaigns', ['campaigns' => $rows, 'tally' => $tally, 'statuses' => Blast::STATUSES, 'connected' => WhatsApp::connected(),
            'cities' => DB::table('prospects')->whereNotNull('city')->distinct()->orderBy('city')->limit(200)->pluck('city'),
            'senders' => DB::table('marketing_senders')->orderBy('id')->get()->map(fn ($s) => (array) $s + ['quota' => Blast::quota($s), 'today' => Blast::sentToday($s->id)]),
            'open' => Blast::open(), 'rules' => Settings::all()]);
    }

    public function storeCampaign(Request $request) {
        $data = $request->validate(['name' => 'required|string|max:120', 'audience' => ['required', Rule::in(['prospects', 'clients'])],
            'statuses' => 'nullable|array', 'statuses.*' => [Rule::in(array_keys(Blast::STATUSES))], 'city' => 'nullable|string|max:80',
            'access' => ['nullable', Rule::in(['paid', 'beta', 'trial', 'expired'])],
            'variants' => 'required|array|min:1|max:6', 'variants.*' => 'nullable|string|max:1000',
            'followups' => 'nullable|array|max:4', 'followups.*' => 'nullable|string|max:1000']);
        $clean = fn ($list) => array_values(array_filter(array_map(fn ($v) => trim((string) $v), (array) $list), fn ($v) => $v !== ''));
        $variants = $clean($data['variants']);
        if (!$variants) return back()->withErrors(['variants' => 'Isi paling sedikit satu kalimat pesan.'])->withInput();
        $filters = $data['audience'] === 'clients' ? ['access' => $data['access'] ?? null]
            : ['statuses' => $data['statuses'] ?? ['baru'], 'city' => trim((string) ($data['city'] ?? ''))];
        $id = DB::table('campaigns')->insertGetId(['name' => $data['name'], 'audience' => $data['audience'], 'filters' => json_encode($filters), 'variants' => json_encode($variants, JSON_UNESCAPED_UNICODE),
            'followups' => json_encode($clean($data['followups'] ?? []), JSON_UNESCAPED_UNICODE), 'status' => 'draft', 'created_by' => $request->user()->id, 'created_at' => now(), 'updated_at' => now()]);
        [$queued, $skipped] = Blast::enqueue(DB::table('campaigns')->where('id', $id)->first());
        $this->log($request, 'marketing.campaign_created', ['campaign_id' => $id, 'queued' => $queued, 'skipped' => $skipped]);
        return redirect()->route('admin.campaign', $id)->with('status', $queued.' pesan masuk antrean, '.$skipped.' dilewati. Kampanye masih draf: periksa dulu, lalu mulai.');
    }

    public function campaign(int $campaign) {
        $c = DB::table('campaigns')->where('id', $campaign)->first(); abort_unless($c, 404);
        return view('admin-campaign', ['c' => $c, 'connected' => WhatsApp::connected(),
            'tally' => DB::table('campaign_messages')->where('campaign_id', $c->id)->selectRaw('status, count(*) as n')->groupBy('status')->pluck('n', 'status')->all(),
            'messages' => DB::table('campaign_messages')->where('campaign_id', $c->id)->orderByRaw("status = 'queued' desc")->orderBy('id')->paginate(40)]);
    }

    public function campaignStatus(Request $request, int $campaign) {
        $c = DB::table('campaigns')->where('id', $campaign)->first(); abort_unless($c, 404);
        $data = $request->validate(['status' => ['required', Rule::in(['running', 'paused', 'done'])]]);
        DB::table('campaigns')->where('id', $c->id)->update(['status' => $data['status'], 'updated_at' => now()]);
        if ($data['status'] === 'done') DB::table('campaign_messages')->where('campaign_id', $c->id)->where('status', 'queued')->update(['status' => 'skipped', 'error' => 'Kampanye dihentikan']);
        $this->log($request, 'marketing.campaign_'.$data['status'], ['campaign_id' => $c->id]);
        return back()->with('status', ['running' => 'Kampanye berjalan. Pesan dikirim bergiliran sesuai jatah harian.', 'paused' => 'Kampanye dijeda.', 'done' => 'Kampanye dihentikan; sisa antrean dibatalkan.'][$data['status']]);
    }

    /** Kirim manual: marketing membuka WhatsApp sendiri untuk satu kontak, lalu menandainya terkirim. Tetap menghormati "jangan dihubungi". */
    public function markSent(Request $request, int $message) {
        $m = DB::table('campaign_messages')->where('id', $message)->where('status', 'queued')->first(); abort_unless($m, 404);
        if (DB::table('marketing_optouts')->where('phone', $m->phone)->exists()) {
            DB::table('campaign_messages')->where('id', $m->id)->update(['status' => 'skipped', 'error' => 'Minta tidak dihubungi']);
            return back()->withErrors(['message' => 'Kontak ini meminta tidak dihubungi.']);
        }
        Blast::delivered($m, null, CarbonImmutable::now(), 'manual', $request->user()->id);
        return back()->with('status', 'Ditandai terkirim manual.');
    }

    // ---------- nomor pengirim dan aturan ----------

    public function storeSender(Request $request) {
        $data = $request->validate(['label' => 'required|string|max:80', 'phone' => 'required|string|max:30']);
        $phone = User::normalizePhone($data['phone']);
        if (!preg_match('/^62\d{8,13}$/', $phone)) return back()->withErrors(['phone' => 'Nomor diawali 62 atau 08.']);
        if ($phone === (string) Settings::get('cs_whatsapp')) return back()->withErrors(['phone' => 'Nomor CS pusat tidak boleh dipakai untuk blast. Pakai nomor khusus marketing.']);
        if (DB::table('marketing_senders')->where('phone', $phone)->exists()) return back()->withErrors(['phone' => 'Nomor itu sudah terdaftar.']);
        DB::table('marketing_senders')->insert(['label' => $data['label'], 'phone' => $phone, 'active' => true, 'started_at' => now(), 'created_at' => now(), 'updated_at' => now()]);
        $this->log($request, 'marketing.sender_added', ['phone' => $phone]);
        return back()->with('status', 'Nomor pengirim ditambahkan. Jatah hariannya mulai dari '.Settings::get('blast_start_per_day').' pesan.');
    }

    public function toggleSender(Request $request, int $sender) {
        $s = DB::table('marketing_senders')->where('id', $sender)->first(); abort_unless($s, 404);
        $resume = $s->paused_at !== null;
        DB::table('marketing_senders')->where('id', $s->id)->update($resume
            ? ['paused_at' => null, 'pause_reason' => null, 'fail_streak' => 0, 'active' => true, 'updated_at' => now()]
            : ['active' => !$s->active, 'updated_at' => now()]);
        $this->log($request, 'marketing.sender_toggled', ['sender_id' => $s->id]);
        return back()->with('status', 'Nomor pengirim diperbarui.');
    }

    public function saveRules(Request $request) {
        $data = $request->validate([
            'blast_start_per_day' => 'required|integer|min:1|max:200', 'blast_step_per_week' => 'required|integer|min:0|max:100',
            'blast_max_per_day' => 'required|integer|min:1|max:300|gte:blast_start_per_day',
            'blast_gap_min' => 'required|integer|min:1|max:120', 'blast_gap_max' => 'required|integer|min:1|max:240|gte:blast_gap_min',
            'blast_hour_start' => 'required|integer|min:0|max:23', 'blast_hour_end' => 'required|integer|min:1|max:24|gt:blast_hour_start',
            'blast_followup_days' => 'required|integer|min:1|max:60', 'blast_recontact_days' => 'required|integer|min:1|max:365',
            'blast_fail_stop' => 'required|integer|min:2|max:50',
        ]);
        $data = array_map('intval', $data) + ['blast_sunday' => $request->boolean('blast_sunday')];
        Settings::put($data, $request->user()->id);
        $this->log($request, 'marketing.rules', $data);
        return back()->with('status', 'Aturan blast disimpan.');
    }

    /** Balasan masuk dari gateway WhatsApp (CHATKU). Dijaga token rahasia di .env server. */
    public function inbound(Request $request) {
        $token = (string) config('goyana.whatsapp.webhook_token');
        abort_unless($token !== '' && hash_equals($token, (string) $request->bearerToken()), 403);
        $data = $request->validate(['from' => 'required|string|max:30', 'text' => 'nullable|string|max:4000']);
        return response()->json(['result' => Blast::inbound($data['from'], (string) ($data['text'] ?? ''))]);
    }

    private function log(Request $request, string $action, array $details): void {
        DB::table('platform_audit')->insert(['actor_id' => $request->user()->id, 'action' => $action, 'details' => json_encode($details), 'created_at' => now()]);
    }
}
