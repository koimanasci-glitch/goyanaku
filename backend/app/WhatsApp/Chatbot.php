<?php
namespace App\WhatsApp;

use App\Models\Business;
use Illuminate\Support\Facades\{Crypt, DB};

/**
 * Pengaturan chatbot per cabang di server (sebelumnya hanya di HP), gerbang paket, balasan cepat,
 * pemilik ambil alih (#stop / #bot), riwayat singkat untuk AI, dan berhenti promo.
 */
final class Chatbot {
    public const DEFAULTS = ['quick_enabled' => true, 'ai_enabled' => false, 'ai_name' => 'Asisten Laundry',
        'ai_instructions' => 'Jawab dengan ramah dan singkat, panggil pelanggan "Kak". Gunakan data aplikasi; jangan mengarang harga atau status.',
        'knowledge' => '', 'ai_prices' => true, 'ai_status' => true, 'takeover_minutes' => 30,
        'auto_nota' => false, 'auto_ready' => false, 'auto_late' => false, 'late_days' => 3, 'quiet_from' => '21:00', 'quiet_until' => '07:00', 'version' => 0];

    /** Paket aktif mendukung fitur? quick | ai | messages | blast | status | services */
    public static function allows(Business|int $business, string $feature): bool {
        $b = $business instanceof Business ? $business : Business::find($business);
        if (!$b) return false;
        $a = $b->currentAccess();
        return !$a['read_only'] && in_array($a['package'], (array) config('whatsapp.'.$feature.'_packages', []), true);
    }

    public static function settings(int $businessId, int $outletId): array {
        $row = DB::table('wa_bot_settings')->where(['business_id' => $businessId, 'outlet_id' => $outletId])->first();
        $s = self::DEFAULTS;
        if ($row) foreach ($s as $k => $_) $s[$k] = $row->{$k} ?? $s[$k];
        foreach (['quick_enabled', 'ai_enabled', 'ai_prices', 'ai_status', 'auto_nota', 'auto_ready', 'auto_late'] as $k) $s[$k] = (bool) $s[$k];
        foreach (['takeover_minutes', 'late_days', 'version'] as $k) $s[$k] = (int) $s[$k];
        $s['ai_instructions'] = (string) $s['ai_instructions']; $s['knowledge'] = (string) $s['knowledge'];
        return $s;
    }

    public static function contact(int|string $scope, string $phone): string {
        return hash_hmac('sha256', $scope.'|'.$phone, (string) config('app.key'));
    }

    public static function masked(string $phone): string {
        $p = Phone::normalize($phone); $local = '0'.substr($p, 2);
        return substr($local, 0, 4).str_repeat('•', max(0, strlen($local) - 8)).substr($local, -4);
    }

    // ---------------------------------------------------------------- balasan cepat

    /** Aturan aktif yang cocok (urut posisi). "exact" = pesan sama persis; "contains" = mengandung kata/frasa utuh. */
    public static function quickMatch(object $device, string $text): ?object {
        $t = mb_strtolower(trim(preg_replace('/\s+/u', ' ', $text)));
        if ($t === '') return null;
        $rules = DB::table('wa_quick_replies')->where(['business_id' => $device->business_id, 'outlet_id' => $device->outlet_id, 'enabled' => true])
            ->orderBy('position')->orderBy('created_at')->limit(200)->get();
        foreach ($rules as $r) {
            foreach (preg_split('/\s*,\s*/u', mb_strtolower((string) $r->keys)) as $k) {
                $k = trim($k);
                if ($k === '') continue;
                if ($r->mode === 'exact' ? $t === $k : (bool) preg_match('/(?<![\pL\pN])'.preg_quote($k, '/').'(?![\pL\pN])/u', $t)) return $r;
            }
        }
        return null;
    }

    // ---------------------------------------------------------------- pemilik ambil alih

    public static function paused(object $device, string $contact): bool {
        return DB::table('wa_takeovers')->where('device_id', $device->id)->whereIn('contact', [$contact, '*'])
            ->where(fn ($q) => $q->whereNull('until')->orWhere('until', '>', now()))->exists();
    }

    public static function pause(object $device, string $contact, ?int $minutes, bool $manual = false): void {
        $until = $minutes === null ? null : now()->addMinutes(max(1, $minutes));
        $old = DB::table('wa_takeovers')->where(['device_id' => $device->id, 'contact' => $contact])->first();
        // Jeda manual (#stop) tidak dipendekkan oleh balasan biasa pemilik.
        if ($old && $old->manual && !$manual && ($old->until === null || now()->lt($old->until))) return;
        DB::table('wa_takeovers')->updateOrInsert(['device_id' => $device->id, 'contact' => $contact], ['until' => $until, 'manual' => $manual]);
    }

    public static function resume(object $device, ?string $contact): void {
        $q = DB::table('wa_takeovers')->where('device_id', $device->id);
        if ($contact !== null) $q->where('contact', $contact);
        $q->delete();
    }

    /** Pesan pemilik dari HP: balasan biasa = bot diam N menit; "#stop"/"#bot" mengatur manual (juga dari chat diri sendiri + nomor). */
    public static function ownerMessage(object $device, string $to, string $text, bool $self): void {
        $cmd = mb_strtolower(trim($text));
        $settings = self::settings((int) $device->business_id, (int) $device->outlet_id);
        if ($self) {
            if (!preg_match('/^#(stop|bot)\b\s*([\d+\s-]*)$/u', $cmd, $m)) return;
            $target = null;
            if (trim($m[2]) !== '') { try { $target = self::contact($device->id, Phone::normalize($m[2])); } catch (\InvalidArgumentException) { return; } }
            $m[1] === 'stop' ? self::pause($device, $target ?? '*', null, true) : self::resume($device, $target);
            return;
        }
        try { $contact = self::contact($device->id, Phone::normalize($to)); } catch (\InvalidArgumentException) { return; }
        if ($cmd === '#bot') { self::resume($device, $contact); return; }
        if ($cmd === '#stop') { self::pause($device, $contact, null, true); return; }
        // 0 menit = pemilik membalas tidak menghentikan bot.
        if ($settings['takeover_minutes'] > 0) self::pause($device, $contact, $settings['takeover_minutes']);
        self::log($device, $contact, 'me', $text);
    }

    // ---------------------------------------------------------------- riwayat singkat (untuk AI)

    public static function log(object $device, string $contact, string $from, string $text): void {
        if (trim($text) === '') return;
        DB::table('wa_chat_log')->insert(['device_id' => $device->id, 'contact' => $contact, 'from' => $from,
            'text' => Crypt::encryptString(mb_substr($text, 0, 1000)), 'created_at' => now()]);
    }

    /** @return list<array{from:string,text:string}> paling lama → terbaru, tanpa pesan terakhir pelanggan yang sedang dijawab */
    public static function history(object $device, string $contact, int $limit = 8): array {
        return DB::table('wa_chat_log')->where(['device_id' => $device->id, 'contact' => $contact])
            ->where('created_at', '>', now()->subHours((int) config('whatsapp.chat_log_hours', 24)))
            ->orderByDesc('id')->limit($limit)->get()->reverse()->values()
            ->map(fn ($r) => ['from' => $r->from === 'customer' ? 'customer' : 'me', 'text' => self::decrypt($r->text)])
            ->filter(fn ($r) => $r['text'] !== '')->values()->all();
    }

    private static function decrypt(string $v): string { try { return Crypt::decryptString($v); } catch (\Throwable) { return ''; } }

    public static function prune(): int {
        $n = DB::table('wa_chat_log')->where('created_at', '<', now()->subHours((int) config('whatsapp.chat_log_hours', 24)))->delete();
        DB::table('wa_takeovers')->whereNotNull('until')->where('until', '<', now())->delete();
        return $n;
    }

    // ---------------------------------------------------------------- berhenti promo

    public const STOP = '/^(stop|berhenti|unsubscribe|jangan kirim promo|stop promo)$/u';
    public const START = '/^(mulai|start|subscribe|mau promo)$/u';

    public static function optedOut(int $businessId, string $phone): bool {
        return DB::table('wa_optouts')->where(['business_id' => $businessId, 'contact' => self::contact('biz'.$businessId, $phone), 'kind' => 'promo'])->exists();
    }

    /** @return string|null balasan konfirmasi bila pesan adalah STOP/MULAI */
    public static function optCommand(object $device, string $phone, string $text): ?string {
        $t = mb_strtolower(trim($text));
        $contact = self::contact('biz'.$device->business_id, $phone);
        if (preg_match(self::STOP, $t)) {
            DB::table('wa_optouts')->insertOrIgnore(['business_id' => $device->business_id, 'contact' => $contact, 'kind' => 'promo', 'created_at' => now()]);
            return 'Baik Kak, nomor ini tidak akan menerima promo lagi 🙏 Info pesanan tetap kami kirim. Balas MULAI bila ingin menerima promo kembali.';
        }
        if (preg_match(self::START, $t) && DB::table('wa_optouts')->where(['business_id' => $device->business_id, 'contact' => $contact])->delete()) {
            return 'Siap Kak, promo akan kami kirim lagi 😊';
        }
        return null;
    }
}
