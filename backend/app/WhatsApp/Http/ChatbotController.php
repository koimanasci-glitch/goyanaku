<?php
namespace App\WhatsApp\Http;

use App\Models\{Business, Outlet};
use App\WhatsApp\{Blasts, Chatbot, Devices, Media, Nota};
use App\WhatsApp\Contracts\{ChatkuExtras, ChatkuGateway};
use Illuminate\Http\Request;
use Illuminate\Support\Facades\{DB, Storage};
use Illuminate\Support\Str;

/**
 * API aplikasi (owner) untuk Chatbot per cabang: pengaturan + Balasan Cepat + Media (maks. 10) + Blast + lanjutkan bot.
 * Semua data milik usaha pemanggil saja; gerbang paket ditegakkan di server (bukan hanya di aplikasi).
 */
final class ChatbotController {
    public function __construct(private Devices $devices) {}

    private function outlet(Request $r, int $outletId): array {
        $b = $this->devices->owner($r->user());
        $o = Outlet::where(['id' => $outletId, 'business_id' => $b->id])->first() ?? abort(404, 'Cabang tidak ditemukan.');
        return [$b, $o];
    }

    private function features(Business $b): array {
        return collect(['quick', 'ai', 'messages', 'blast'])->mapWithKeys(fn ($f) => [$f => Chatbot::allows($b, $f)])->all();
    }

    public function show(Request $r, int $outlet) {
        [$b, $o] = $this->outlet($r, $outlet);
        return response()->json([
            'outlet_id' => $o->id, 'settings' => Chatbot::settings($b->id, $o->id), 'features' => $this->features($b), 'ai_balance' => (int) $b->fresh()->ai_balance,
            'replies' => DB::table('wa_quick_replies')->where(['business_id' => $b->id, 'outlet_id' => $o->id])->orderBy('position')->orderBy('created_at')->get()->map(fn ($q) => $this->reply($q)),
            'media' => Media::list($b->id, $o->id), 'media_limit' => Media::limit(),
            'paused' => DB::table('wa_takeovers')->whereIn('device_id', DB::table('wa_devices')->where(['business_id' => $b->id, 'outlet_id' => $o->id])->select('id'))
                ->where(fn ($q) => $q->whereNull('until')->orWhere('until', '>', now()))->count(),
        ]);
    }

    private function reply(object $q): array {
        return ['id' => $q->id, 'name' => $q->name, 'keys' => $q->keys, 'mode' => $q->mode, 'reply' => (string) $q->reply, 'media_id' => $q->media_id,
            'enabled' => (bool) $q->enabled, 'position' => (int) $q->position];
    }

    public function save(Request $r, int $outlet) {
        [$b, $o] = $this->outlet($r, $outlet);
        $v = $r->validate([
            'version' => 'required|integer|min:0', 'quick_enabled' => 'boolean', 'ai_enabled' => 'boolean', 'ai_name' => 'nullable|string|max:60',
            'ai_instructions' => 'nullable|string|max:3000', 'knowledge' => 'nullable|string|max:20000', 'ai_prices' => 'boolean', 'ai_status' => 'boolean',
            'takeover_minutes' => 'integer|min:0|max:1440', 'auto_nota' => 'boolean', 'auto_ready' => 'boolean', 'auto_late' => 'boolean',
            'late_days' => 'integer|min:1|max:30', 'quiet_from' => 'date_format:H:i', 'quiet_until' => 'date_format:H:i',
        ]);
        abort_if(($v['ai_enabled'] ?? false) && !Chatbot::allows($b, 'ai'), 403, 'Chatbot AI membutuhkan paket Gold.');
        abort_if((($v['auto_nota'] ?? false) || ($v['auto_ready'] ?? false) || ($v['auto_late'] ?? false)) && !Chatbot::allows($b, 'messages'), 403, 'Pesan otomatis membutuhkan paket Gold.');
        return DB::transaction(function () use ($b, $o, $v) {
            Business::whereKey($b->id)->lockForUpdate()->firstOrFail();
            $cur = Chatbot::settings($b->id, $o->id);
            abort_unless((int) $v['version'] === $cur['version'], 409, 'Pengaturan sudah diubah dari HP lain. Muat ulang.');
            $row = array_intersect_key($v, Chatbot::DEFAULTS); unset($row['version']);
            foreach (['ai_name', 'ai_instructions', 'knowledge'] as $k) if (array_key_exists($k, $row)) $row[$k] = trim((string) $row[$k]);
            if (array_key_exists('ai_name', $row) && $row['ai_name'] === '') $row['ai_name'] = Chatbot::DEFAULTS['ai_name'];
            $row += ['version' => $cur['version'] + 1, 'updated_at' => now()];
            DB::table('wa_bot_settings')->updateOrInsert(['business_id' => $b->id, 'outlet_id' => $o->id], $cur['version'] === 0 ? $row + ['created_at' => now()] : $row);
            return response()->json(['settings' => Chatbot::settings($b->id, $o->id)]);
        });
    }

    public function saveReply(Request $r, int $outlet) {
        [$b, $o] = $this->outlet($r, $outlet);
        abort_unless(Chatbot::allows($b, 'quick'), 403, 'Balasan Cepat membutuhkan paket Silver.');
        $v = $r->validate(['id' => 'required|uuid', 'name' => 'required|string|max:80', 'keys' => 'required|string|max:500', 'mode' => 'required|in:contains,exact',
            'reply' => 'nullable|string|max:3900|required_without:media_id', 'media_id' => 'nullable|uuid', 'enabled' => 'boolean', 'position' => 'integer|min:0|max:999']);
        if (!empty($v['media_id'])) abort_unless(DB::table('wa_media')->where(['id' => $v['media_id'], 'business_id' => $b->id, 'outlet_id' => $o->id])->exists(), 422, 'Media tidak ada di cabang ini.');
        $old = DB::table('wa_quick_replies')->where('id', $v['id'])->first();
        abort_if($old && ((int) $old->business_id !== $b->id || (int) $old->outlet_id !== $o->id), 404);
        abort_if(!$old && DB::table('wa_quick_replies')->where(['business_id' => $b->id, 'outlet_id' => $o->id])->count() >= 100, 422, 'Maksimal 100 balasan per cabang.');
        $row = ['name' => trim($v['name']), 'keys' => trim($v['keys']), 'mode' => $v['mode'], 'reply' => trim((string) ($v['reply'] ?? '')), 'media_id' => $v['media_id'] ?? null,
            'enabled' => $v['enabled'] ?? true, 'position' => $v['position'] ?? ($old->position ?? 0), 'updated_at' => now()];
        $old ? DB::table('wa_quick_replies')->where('id', $old->id)->update($row)
            : DB::table('wa_quick_replies')->insert($row + ['id' => $v['id'], 'business_id' => $b->id, 'outlet_id' => $o->id, 'created_at' => now()]);
        return response()->json($this->reply(DB::table('wa_quick_replies')->where('id', $v['id'])->first()), $old ? 200 : 201);
    }

    public function deleteReply(Request $r, string $id) {
        $b = $this->devices->owner($r->user());
        abort_unless(Str::isUuid($id), 404);
        DB::table('wa_quick_replies')->where(['id' => $id, 'business_id' => $b->id])->delete();
        return response()->noContent();
    }

    // ---------------------------------------------------------------- media

    public function media(Request $r, int $outlet) {
        [$b, $o] = $this->outlet($r, $outlet);
        return response()->json(['media' => Media::list($b->id, $o->id), 'limit' => Media::limit()]);
    }

    public function upload(Request $r, int $outlet) {
        [$b, $o] = $this->outlet($r, $outlet);
        abort_unless(Chatbot::allows($b, 'quick'), 403, 'Media balasan membutuhkan paket Silver.');
        // Aplikasi mengirim JSON base64 (lapisan sinkron HP hanya JSON); multipart tetap diterima.
        if (!$r->hasFile('file') && $r->filled('data')) {
            $v = $r->validate(['name' => 'required|string|max:80', 'data' => 'required|string|max:'.(int) ceil(config('whatsapp.media.image_max_upload_kb', 8192) * 1024 * 4 / 3) + 8]);
            $raw = base64_decode(preg_replace('/^data:[^,]*,/', '', $v['data']), true);
            abort_if($raw === false || $raw === '', 422, 'Berkas tidak terbaca.');
            $tmp = tempnam(sys_get_temp_dir(), 'wam');
            file_put_contents($tmp, $raw);
            try {
                return response()->json(Media::present(Media::store($b->id, $o->id, new \Illuminate\Http\UploadedFile($tmp, 'media', null, null, true), $v['name'])), 201);
            } finally { @unlink($tmp); }
        }
        $v = $r->validate(['file' => 'required|file|max:'.(int) config('whatsapp.media.image_max_upload_kb', 8192), 'name' => 'required|string|max:80']);
        return response()->json(Media::present(Media::store($b->id, $o->id, $v['file'], $v['name'])), 201);
    }

    public function renameMedia(Request $r, string $id) {
        $b = $this->devices->owner($r->user());
        $v = $r->validate(['name' => 'required|string|max:80']);
        return response()->json(Media::present(Media::rename($b->id, $id, $v['name'])));
    }

    public function deleteMedia(Request $r, string $id) {
        Media::delete($this->devices->owner($r->user())->id, $id);
        return response()->noContent();
    }

    public function copyMedia(Request $r, string $id) {
        $b = $this->devices->owner($r->user());
        $v = $r->validate(['outlet_id' => 'required|integer']);
        return response()->json(Media::present(Media::copy($b->id, $id, (int) $v['outlet_id'])), 201);
    }

    /** Berkas media untuk CHATKU / pratinjau aplikasi: hanya lewat link bertanda tangan yang kedaluwarsa. */
    public function file(Request $r, string $id) {
        abort_unless(Str::isUuid($id), 404);
        $m = DB::table('wa_media')->where('id', $id)->first();
        abort_unless($m && (int) $r->query('v') === (int) $m->version && Storage::disk('local')->exists($m->path), 404);
        return response(Storage::disk('local')->get($m->path), 200, ['Content-Type' => $m->mime, 'Cache-Control' => 'private, max-age=600',
            'X-Content-Type-Options' => 'nosniff', 'Content-Disposition' => ($m->kind === 'pdf' ? 'inline; filename="'.Str::slug($m->name).'.pdf"' : 'inline')]);
    }

    public function nota(Request $r) {
        $n = Nota::view((int) $r->query('b'), (string) $r->query('k'));
        abort_unless($n, 404, 'Nota tidak ditemukan.');
        return response()->view('whatsapp::nota', ['n' => $n])->header('X-Robots-Tag', 'noindex')->header('Cache-Control', 'private, no-store');
    }

    /**
     * Uji jawaban Chatbot AI dari aplikasi (keputusan Paduka 10 Okt: popup AI dipotong dari saldo AI laundry).
     * Memakai bahan yang sama dengan bot sungguhan; harga di luar data tidak ditampilkan sebagai jawaban.
     */
    public function aiTest(Request $r, int $outlet, ChatkuGateway $gateway) {
        [$b, $o] = $this->outlet($r, $outlet);
        abort_unless(Chatbot::allows($b, 'ai'), 403, 'Chatbot AI membutuhkan paket Gold.');
        abort_unless($gateway instanceof ChatkuExtras, 503, 'Layanan AI belum tersambung ke server GOYANA.');
        $v = $r->validate(['question' => 'required|string|max:1000', 'phone' => 'nullable|string|max:40']);
        abort_if((int) $b->fresh()->ai_balance <= 0, 402, 'Saldo AI habis. Isi saldo minimal Rp50.000.');
        $from = null;
        if (!empty($v['phone'])) { try { $from = \App\WhatsApp\Phone::normalize($v['phone']); } catch (\InvalidArgumentException) {} }
        $d = (object) ['id' => 'test', 'business_id' => $b->id, 'outlet_id' => $o->id];
        $payload = \App\WhatsApp\Jobs\AiReply::payload($d, $b, Chatbot::settings($b->id, $o->id), $v['question'], [], $from, app(\App\WhatsApp\Replies::class));
        try {
            $res = $gateway->ai($b->id, $payload);
        } catch (\App\WhatsApp\Chatku\ChatkuException $e) {
            abort($e->codeName === 'saldo_habis' ? 402 : 503, $e->codeName === 'saldo_habis' ? 'Saldo AI habis. Isi saldo minimal Rp50.000.' : 'AI sedang sibuk, coba lagi sebentar.');
        }
        $cost = \App\Support\AiBilling::debitRupiah($b, (int) ($res['cost'] ?? 0), (string) ($res['model'] ?? 'chatku'), 'chatku-ai-test:'.Str::uuid());
        $unverified = array_values((array) ($res['unverified_prices'] ?? []));
        return response()->json([
            'answer' => $unverified ? 'Untuk harga pastinya, admin kami cek dulu ya Kak 🙏' : (string) ($res['answer'] ?? ''),
            'raw_answer' => (string) ($res['answer'] ?? ''), 'unverified_prices' => $unverified, 'handover' => (bool) ($res['handover'] ?? false),
            'media' => ($m = DB::table('wa_media')->where(['id' => $res['media_id'] ?? '', 'business_id' => $b->id])->first()) ? $m->name : null,
            'cost' => $cost, 'ai_balance' => (int) $b->fresh()->ai_balance,
        ]);
    }

    /** Lanjutkan bot untuk semua kontak yang sedang diambil alih di cabang ini. */
    public function resume(Request $r, int $outlet) {
        [$b, $o] = $this->outlet($r, $outlet);
        $n = DB::table('wa_takeovers')->whereIn('device_id', DB::table('wa_devices')->where(['business_id' => $b->id, 'outlet_id' => $o->id])->select('id'))->delete();
        return response()->json(['resumed' => $n]);
    }

    // ---------------------------------------------------------------- blast

    public function blasts(Request $r) {
        $b = $this->devices->owner($r->user());
        $q = DB::table('wa_blasts')->where('business_id', $b->id)->orderByDesc('created_at')->limit(50);
        if ($r->filled('outlet_id')) $q->where('outlet_id', (int) $r->query('outlet_id'));
        return response()->json(['blasts' => $q->get()->map(fn ($x) => Blasts::present($x)), 'allowed' => Chatbot::allows($b, 'blast')]);
    }

    public function audience(Request $r, Blasts $blasts) {
        $b = $this->devices->owner($r->user());
        $v = $r->validate(['outlet_id' => 'required|integer', 'audience' => 'in:outlet,all', 'days' => 'nullable|integer|min:1|max:730']);
        abort_unless(Outlet::where(['id' => $v['outlet_id'], 'business_id' => $b->id])->exists(), 404);
        return response()->json(['count' => count($blasts->audience($b->id, (int) $v['outlet_id'], $v['audience'] ?? 'outlet', $v['days'] ?? null)), 'max' => Blasts::MAX]);
    }

    public function createBlast(Request $r, Blasts $blasts) {
        $b = $this->devices->owner($r->user());
        $v = $r->validate(['device_id' => 'required|uuid', 'name' => 'required|string|max:80', 'body' => 'required|string|max:3500', 'media_id' => 'nullable|uuid',
            'audience' => 'in:outlet,all', 'days' => 'nullable|integer|min:1|max:730', 'schedule_at' => 'nullable|date|after:now',
            'send_from' => 'nullable|date_format:H:i', 'send_until' => 'nullable|date_format:H:i']);
        return response()->json(Blasts::present($blasts->create($r->user(), $b, $v)), 201);
    }

    public function blast(Request $r, string $id) {
        $b = $this->devices->owner($r->user());
        abort_unless(Str::isUuid($id), 404);
        $x = DB::table('wa_blasts')->where(['id' => $id, 'business_id' => $b->id])->first() ?? abort(404);
        return response()->json(Blasts::present($x, true));
    }

    public function cancelBlast(Request $r, string $id, Blasts $blasts) {
        abort_unless(Str::isUuid($id), 404);
        return response()->json(Blasts::present($blasts->cancel($this->devices->owner($r->user()), $id)));
    }
}
