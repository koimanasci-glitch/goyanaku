<?php
namespace App\Support;

use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;

/**
 * WA blast divisi marketing: digilir, sedikit demi sedikit (keputusan pengguna 8 Oktober 2026).
 *
 * Yang dijaga mesin ini:
 * - jatah harian per nomor pengirim naik bertahap (pemanasan), dengan batas atas;
 * - jeda acak antar pesan, hanya pada jam dan hari kerja WIB;
 * - satu calon paling banyak satu pembuka dan satu tindak lanjut per kampanye, dan tidak dikirimi kampanye baru terlalu cepat;
 * - balasan "STOP" atau sejenisnya menghentikan semua kiriman ke nomor itu selamanya;
 * - gagal berturut-turut menghentikan nomor pengirim; tanpa balasan sama sekali menurunkan jatahnya.
 * Sasaran hanya pemilik laundry (client dan calon client). Pelanggan milik laundry tidak pernah menjadi sasaran.
 */
final class Blast {
    public const TZ = 'Asia/Jakarta';
    public const STATUSES = ['baru' => 'Baru', 'dihubungi' => 'Sudah dihubungi', 'membalas' => 'Membalas', 'tertarik' => 'Tertarik', 'daftar' => 'Sudah daftar', 'menolak' => 'Menolak'];
    private const STOP = '/\b(stop|berhenti|unsubscribe|unsub|jangan\s+(kirim|hubungi|wa|chat)|tidak\s+usah\s+(kirim|hubungi))\b/iu';

    // ---------- jatah ----------

    /** Jatah harian nomor pengirim ini hari ini. */
    public static function quota(object $sender, ?CarbonImmutable $now = null): int {
        $now = ($now ?? CarbonImmutable::now())->utc(); $s = Settings::all(); // waktu disimpan dalam UTC
        $weeks = max(0, intdiv((int) CarbonImmutable::parse($sender->started_at)->diffInDays($now), 7));
        $quota = min((int) $s['blast_max_per_day'], (int) $s['blast_start_per_day'] + (int) $s['blast_step_per_week'] * $weeks);
        // Tiga hari terakhir sudah mengirim cukup banyak tetapi tidak ada satu pun balasan: tanda pesannya tidak diinginkan.
        $since = $now->subDays(3);
        $sent = DB::table('campaign_messages')->where('sender_id', $sender->id)->where('status', 'sent')->where('sent_at', '>=', $since)->count();
        if ($sent >= 30 && !DB::table('prospect_events')->where('kind', 'balas')->where('created_at', '>=', $since)->exists()) $quota = intdiv($quota, 2);
        return max(0, $quota);
    }

    public static function sentToday(int $senderId, ?CarbonImmutable $now = null): int {
        $start = ($now ?? CarbonImmutable::now())->setTimezone(self::TZ)->startOfDay()->utc();
        return DB::table('campaign_messages')->where('sender_id', $senderId)->where('status', 'sent')->where('sent_at', '>=', $start)->count();
    }

    /** Sekarang jam kirim? */
    public static function open(?CarbonImmutable $now = null): bool {
        $local = ($now ?? CarbonImmutable::now())->setTimezone(self::TZ); $s = Settings::all();
        if ($local->isSunday() && !$s['blast_sunday']) return false;
        return $local->hour >= (int) $s['blast_hour_start'] && $local->hour < (int) $s['blast_hour_end'];
    }

    // ---------- antrean ----------

    /**
     * Mengisi antrean kampanye dari sasarannya. Mengembalikan [antre, dilewati].
     * Dilewati: sudah minta berhenti, baru saja dihubungi kampanye lain, tanpa nomor, atau sudah ada di kampanye ini.
     */
    public static function enqueue(object $campaign): array {
        $variants = array_values(array_filter((array) json_decode((string) $campaign->variants, true), fn ($v) => trim((string) $v) !== ''));
        if (!$variants) return [0, 0];
        $filters = (array) json_decode((string) $campaign->filters, true);
        $recent = now()->subDays((int) Settings::get('blast_recontact_days'));
        $queued = 0; $skipped = 0; $n = 0;
        foreach (self::audience((string) $campaign->audience, $filters) as $contact) {
            $phone = $contact['phone'];
            $blocked = $phone === '' || DB::table('marketing_optouts')->where('phone', $phone)->exists()
                || DB::table('campaign_messages')->where('phone', $phone)->where('campaign_id', '!=', $campaign->id)->whereIn('status', ['sent', 'manual', 'queued'])
                    ->where(fn ($q) => $q->where('sent_at', '>=', $recent)->orWhere('status', 'queued'))->exists()
                || DB::table('campaign_messages')->where('campaign_id', $campaign->id)->where('phone', $phone)->where('kind', 'opener')->exists();
            if ($blocked) { $skipped++; continue; }
            DB::table('campaign_messages')->insert(['campaign_id' => $campaign->id, 'prospect_id' => $contact['prospect_id'], 'business_id' => $contact['business_id'],
                'phone' => $phone, 'name' => mb_substr($contact['business'], 0, 160), 'body' => self::fill($variants[$n++ % count($variants)], $contact),
                'kind' => 'opener', 'status' => 'queued', 'created_at' => now()]);
            $queued++;
        }
        return [$queued, $skipped];
    }

    /**
     * Sasaran kampanye: [{phone, business, owner, city, prospect_id, business_id}].
     * - prospects: calon client menurut status dan kota, kecuali yang minta tidak dihubungi atau sudah daftar.
     * - clients: pemilik laundry yang sudah terdaftar, menurut status paket. Hanya nama usaha, nama dan nomor pemilik yang dipakai.
     */
    public static function audience(string $audience, array $filters): array {
        if ($audience === 'clients') {
            $out = [];
            $query = \App\Models\Business::withAccessStatus(in_array($filters['access'] ?? null, ['paid', 'beta', 'trial', 'expired'], true) ? $filters['access'] : null);
            foreach ($query->with(['users' => fn ($u) => $u->where('role', 'owner'), 'outlets'])->orderBy('id')->get() as $b) {
                $owner = $b->users->first();
                $phone = User::normalizePhone($owner?->phone ?: ($b->outlets->first()?->phone ?? ''));
                if (!preg_match('/^62\d{8,13}$/', $phone)) continue;
                $out[] = ['phone' => $phone, 'business' => $b->name, 'owner' => (string) ($owner?->name ?? ''), 'city' => '', 'prospect_id' => null, 'business_id' => $b->id];
            }
            return $out;
        }
        $statuses = array_values(array_intersect((array) ($filters['statuses'] ?? ['baru']), array_keys(self::STATUSES)));
        $rows = DB::table('prospects')->where('do_not_contact', false)->whereNull('business_id')->whereNotIn('status', ['daftar', 'menolak'])
            ->when($statuses, fn ($q) => $q->whereIn('status', $statuses))
            ->when(trim((string) ($filters['city'] ?? '')) !== '', fn ($q) => $q->where('city', trim((string) $filters['city'])))
            ->orderByRaw('last_contacted_at is not null')->orderBy('id')->get(); // yang belum pernah dihubungi didahulukan
        return $rows->map(fn ($p) => ['phone' => $p->phone, 'business' => $p->name, 'owner' => (string) $p->owner_name, 'city' => (string) $p->city,
            'prospect_id' => $p->id, 'business_id' => null])->all();
    }

    public static function fill(string $template, array $contact): string {
        $name = trim($contact['owner']) !== '' ? $contact['owner'] : $contact['business'];
        return trim(strtr($template, ['{nama}' => $name, '{usaha}' => $contact['business'], '{kota}' => $contact['city']]));
    }

    // ---------- pengiriman ----------

    /**
     * Dipanggil penjadwal tiap menit: tiap nomor pengirim mengirim paling banyak satu pesan bila gilirannya tiba.
     * Mengembalikan ringkasan untuk log: sent, failed, skipped, dan alasan bila tidak mengirim.
     */
    public static function tick(?CarbonImmutable $now = null): array {
        $now = ($now ?? CarbonImmutable::now())->utc();
        $out = ['sent' => 0, 'failed' => 0, 'skipped' => 0, 'idle' => null];
        if (!WhatsApp::connected()) return ['idle' => 'Gateway WhatsApp belum tersambung'] + $out;
        if (!self::open($now)) return ['idle' => 'Di luar jam kirim'] + $out;
        $s = Settings::all();
        // Hanya nomor yang sudah dipasangkan di Chatku yang mendapat giliran.
        foreach (DB::table('marketing_senders')->where('active', true)->whereNull('paused_at')->whereNotNull('remote_id')->orderBy('id')->get() as $sender) {
            if ($sender->next_at && CarbonImmutable::parse($sender->next_at)->gt($now)) continue;
            if (self::sentToday($sender->id, $now) >= self::quota($sender, $now)) continue;
            $message = self::next($now, $out);
            if (!$message) break;
            try {
                WhatsApp::send($sender, $message->phone, $message->body, 'goyana-blast:'.$message->id);
            } catch (\RuntimeException $e) {
                DB::table('campaign_messages')->where('id', $message->id)->update(['status' => 'failed', 'error' => mb_substr($e->getMessage(), 0, 300), 'sender_id' => $sender->id]);
                $streak = (int) $sender->fail_streak + 1; $stop = $streak >= (int) $s['blast_fail_stop'];
                DB::table('marketing_senders')->where('id', $sender->id)->update(['fail_streak' => $streak, 'updated_at' => now(),
                    'paused_at' => $stop ? now() : null, 'pause_reason' => $stop ? $streak.' pesan gagal berturut-turut: '.mb_substr($e->getMessage(), 0, 120) : null]);
                if ($stop) AdminNotify::send('Blast dihentikan', 'Nomor pengirim '.$sender->label.' dihentikan otomatis: '.$streak.' pesan gagal berturut-turut. Periksa nomor dan gateway di /admin/marketing/senders.');
                $out['failed']++;
                continue;
            }
            self::delivered($message, $sender->id, $now, 'sent');
            $gap = random_int(min((int) $s['blast_gap_min'], (int) $s['blast_gap_max']) * 60, max((int) $s['blast_gap_min'], (int) $s['blast_gap_max']) * 60);
            DB::table('marketing_senders')->where('id', $sender->id)->update(['fail_streak' => 0, 'next_at' => $now->addSeconds($gap), 'updated_at' => now()]);
            $out['sent']++;
        }
        self::finishCampaigns();
        return $out;
    }

    /** Pesan berikutnya yang boleh dikirim: pembuka lebih dulu, lalu tindak lanjut yang sudah waktunya. */
    private static function next(CarbonImmutable $now, array &$out): ?object {
        while (true) {
            $message = DB::table('campaign_messages')->join('campaigns', 'campaigns.id', '=', 'campaign_messages.campaign_id')
                ->where('campaigns.status', 'running')->where('campaign_messages.status', 'queued')
                ->where(fn ($q) => $q->whereNull('not_before')->orWhere('not_before', '<=', $now))
                ->orderByRaw("campaign_messages.kind = 'followup'")->orderBy('campaign_messages.id')->first(['campaign_messages.*']);
            if (!$message) return null;
            $why = self::blocked($message);
            if ($why === null) return $message;
            DB::table('campaign_messages')->where('id', $message->id)->update(['status' => 'skipped', 'error' => $why]);
            $out['skipped']++;
        }
    }

    /** Alasan pesan ini tidak boleh lagi dikirim, atau null bila boleh. */
    private static function blocked(object $message): ?string {
        if (DB::table('marketing_optouts')->where('phone', $message->phone)->exists()) return 'Minta tidak dihubungi';
        if (!$message->prospect_id) return null;
        $p = DB::table('prospects')->where('id', $message->prospect_id)->first();
        if (!$p) return 'Kontak dihapus';
        if ($p->do_not_contact || $p->status === 'menolak') return 'Minta tidak dihubungi';
        if ($p->business_id || $p->status === 'daftar') return 'Sudah mendaftar';
        // Tindak lanjut hanya untuk yang belum merespons sama sekali.
        if ($message->kind === 'followup' && $p->status !== 'dihubungi') return 'Sudah merespons';
        return null;
    }

    /** Catat pesan terkirim (oleh mesin atau manual oleh marketing) dan jadwalkan tindak lanjutnya. */
    public static function delivered(object $message, ?int $senderId, ?CarbonImmutable $now = null, string $status = 'manual', ?int $userId = null): void {
        $now = ($now ?? CarbonImmutable::now())->utc();
        DB::table('campaign_messages')->where('id', $message->id)->update(['status' => $status, 'sent_at' => $now, 'sender_id' => $senderId, 'error' => null]);
        if ($message->prospect_id) {
            DB::table('prospects')->where('id', $message->prospect_id)->where('status', 'baru')->update(['status' => 'dihubungi']);
            DB::table('prospects')->where('id', $message->prospect_id)->update(['last_contacted_at' => $now, 'updated_at' => now()]);
            DB::table('prospect_events')->insert(['prospect_id' => $message->prospect_id, 'kind' => 'kirim', 'user_id' => $userId,
                'detail' => ($message->kind === 'followup' ? 'Tindak lanjut' : 'Pesan pembuka').($status === 'manual' ? ' (manual)' : ''), 'created_at' => $now]);
        }
        if ($message->kind !== 'opener') return;
        $campaign = DB::table('campaigns')->where('id', $message->campaign_id)->first();
        $followups = array_values(array_filter((array) json_decode((string) ($campaign->followups ?? '[]'), true), fn ($v) => trim((string) $v) !== ''));
        if (!$followups || DB::table('campaign_messages')->where('campaign_id', $message->campaign_id)->where('phone', $message->phone)->where('kind', 'followup')->exists()) return;
        $p = $message->prospect_id ? DB::table('prospects')->where('id', $message->prospect_id)->first() : null;
        $contact = ['business' => $message->name, 'owner' => (string) ($p->owner_name ?? ''), 'city' => (string) ($p->city ?? '')];
        DB::table('campaign_messages')->insert(['campaign_id' => $message->campaign_id, 'prospect_id' => $message->prospect_id, 'business_id' => $message->business_id,
            'phone' => $message->phone, 'name' => $message->name, 'body' => self::fill($followups[$message->id % count($followups)], $contact), 'kind' => 'followup',
            'status' => 'queued', 'not_before' => $now->addDays((int) Settings::get('blast_followup_days')), 'created_at' => now()]);
    }

    private static function finishCampaigns(): void {
        foreach (DB::table('campaigns')->where('status', 'running')->pluck('id') as $id) {
            if (!DB::table('campaign_messages')->where('campaign_id', $id)->where('status', 'queued')->exists()) {
                DB::table('campaigns')->where('id', $id)->update(['status' => 'done', 'updated_at' => now()]);
            }
        }
    }

    // ---------- balasan ----------

    /** Balasan masuk dari gateway. "STOP" dan sejenisnya: nomor itu tidak pernah dikirimi lagi. */
    public static function inbound(string $phone, string $text): string {
        $phone = User::normalizePhone($phone);
        if ($phone === '') return 'ignored';
        $stop = (bool) preg_match(self::STOP, $text);
        $p = DB::table('prospects')->where('phone', $phone)->first();
        if ($stop) {
            self::optOut($phone, 'Balasan: '.mb_substr(trim($text), 0, 120));
            return 'stopped';
        }
        if (!$p) return 'ignored';
        DB::table('prospects')->where('id', $p->id)->update(['replies' => (int) $p->replies + 1, 'updated_at' => now(),
            'status' => in_array($p->status, ['baru', 'dihubungi'], true) ? 'membalas' : $p->status]);
        DB::table('prospect_events')->insert(['prospect_id' => $p->id, 'kind' => 'balas', 'detail' => mb_substr(trim($text), 0, 500), 'created_at' => now()]);
        // Sudah membalas: tindak lanjut otomatis dibatalkan, percakapan dilanjutkan orang marketing.
        DB::table('campaign_messages')->where('phone', $phone)->where('status', 'queued')->where('kind', 'followup')->update(['status' => 'skipped', 'error' => 'Sudah merespons']);
        return 'recorded';
    }

    public static function optOut(string $phone, string $reason, ?int $userId = null): void {
        DB::table('marketing_optouts')->updateOrInsert(['phone' => $phone], ['reason' => mb_substr($reason, 0, 200), 'created_at' => now()]);
        DB::table('campaign_messages')->where('phone', $phone)->where('status', 'queued')->update(['status' => 'skipped', 'error' => 'Minta tidak dihubungi']);
        $p = DB::table('prospects')->where('phone', $phone)->first();
        if (!$p) return;
        DB::table('prospects')->where('id', $p->id)->update(['do_not_contact' => true, 'status' => 'menolak', 'updated_at' => now()]);
        DB::table('prospect_events')->insert(['prospect_id' => $p->id, 'kind' => 'stop', 'detail' => mb_substr($reason, 0, 500), 'user_id' => $userId, 'created_at' => now()]);
    }

    /** Calon yang nomornya sekarang terdaftar sebagai pemilik atau outlet client ditandai "Sudah daftar". */
    public static function markRegistered(): int {
        $n = 0;
        foreach (DB::table('prospects')->whereNull('business_id')->get(['id', 'phone']) as $p) {
            $businessId = User::where('phone', $p->phone)->whereNotNull('business_id')->value('business_id')
                ?? DB::table('outlets')->where('phone', $p->phone)->value('business_id');
            if (!$businessId) continue;
            DB::table('prospects')->where('id', $p->id)->update(['business_id' => $businessId, 'status' => 'daftar', 'updated_at' => now()]);
            DB::table('prospect_events')->insert(['prospect_id' => $p->id, 'kind' => 'status', 'detail' => 'Mendaftar sebagai client', 'created_at' => now()]);
            DB::table('campaign_messages')->where('phone', $p->phone)->where('status', 'queued')->update(['status' => 'skipped', 'error' => 'Sudah mendaftar']);
            $n++;
        }
        return $n;
    }
}
