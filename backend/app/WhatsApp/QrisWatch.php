<?php
namespace App\WhatsApp;

use Illuminate\Support\Facades\{DB, Mail};

/**
 * Pengaman QRIS (keputusan Paduka 10 Okt 2026). QRIS tetap tersimpan di sinkronisasi setelan; server memantau perubahannya:
 * bila isi QRIS berubah, pemilik langsung diberi tahu (email + catatan audit) lengkap dengan nama merchant & NMID baru,
 * supaya penggantian QRIS diam-diam (uang pelanggan masuk ke rekening orang lain) cepat ketahuan.
 * Penguncian penuh di server (hanya owner + PIN) membutuhkan perubahan SyncController — dicatat di GOYANA-CATATAN-PADUKA.md.
 */
final class QrisWatch {
    public const KEYS = ['goyana-qris-text', 'goyana-qris-image'];

    /** @return array{name:string,city:string,nmid:string} */
    public static function parse(string $emv): array {
        $out = ['name' => '', 'city' => '', 'nmid' => ''];
        $tlv = self::tlv($emv);
        $out['name'] = trim($tlv['59'] ?? ''); $out['city'] = trim($tlv['60'] ?? '');
        foreach ($tlv as $tag => $value) {
            if ((int) $tag < 26 || (int) $tag > 51) continue;
            foreach (self::tlv($value) as $v) if (preg_match('/^ID\d{10,}$/', $v)) { $out['nmid'] = $v; break 2; }
        }
        return $out;
    }

    private static function tlv(string $s): array {
        $out = []; $i = 0; $n = strlen($s);
        while ($i + 4 <= $n) {
            $tag = substr($s, $i, 2); $len = substr($s, $i + 2, 2);
            if (!ctype_digit($tag) || !ctype_digit($len)) break;
            $out[$tag] = substr($s, $i + 4, (int) $len); $i += 4 + (int) $len;
        }
        return $out;
    }

    /** Teks EMV QRIS dari data setelan yang tersinkron (bentuk data ditentukan aplikasi). */
    public static function emv(?string $raw): string {
        if ($raw === null) return '';
        $s = str_replace(['\\/', '\\u0000'], ['/', ''], $raw);
        return preg_match('/000201[0-9A-Za-z .,\-\/:*&@#\']{20,}?6304[0-9A-Fa-f]{4}/', $s, $m) ? $m[0] : '';
    }

    public function run(): int {
        $changed = 0;
        $rows = DB::table('sync_records')->where('collection', 'settings')->whereIn('record_key', self::KEYS)
            ->orderBy('business_id')->get(['business_id', 'record_key', 'data', 'deleted'])->groupBy('business_id');
        foreach ($rows as $businessId => $recs) {
            $text = $recs->firstWhere('record_key', 'goyana-qris-text');
            $image = $recs->firstWhere('record_key', 'goyana-qris-image');
            $hash = hash('sha256', ($text && !$text->deleted ? $text->data : '').'|'.($image && !$image->deleted ? hash('sha256', (string) $image->data) : ''));
            $emv = $text && !$text->deleted ? self::emv((string) $text->data) : '';
            $info = $emv !== '' ? self::parse($emv) : ['name' => '', 'city' => '', 'nmid' => ''];
            $old = DB::table('wa_qris_watch')->where('business_id', $businessId)->first();
            if (!$old) {
                DB::table('wa_qris_watch')->insert(['business_id' => $businessId, 'hash' => $hash, 'merchant' => $info['name'] ?: null, 'nmid' => $info['nmid'] ?: null, 'checked_at' => now()]);
                continue;
            }
            if (hash_equals((string) $old->hash, $hash)) { DB::table('wa_qris_watch')->where('business_id', $businessId)->update(['checked_at' => now()]); continue; }
            DB::table('wa_qris_watch')->where('business_id', $businessId)->update(['hash' => $hash, 'merchant' => $info['name'] ?: null, 'nmid' => $info['nmid'] ?: null, 'changed_at' => now(), 'checked_at' => now()]);
            $this->notify((int) $businessId, $old, $info, $emv === '' && !($image && !$image->deleted));
            $changed++;
        }
        return $changed;
    }

    private function notify(int $businessId, object $old, array $new, bool $removed): void {
        $owner = DB::table('users')->where(['business_id' => $businessId, 'role' => 'owner'])->whereNull('deactivated_at')->orderBy('id')->first();
        $tz = \App\Models\Outlet::zoneOf(null, $businessId);
        $when = now()->timezone($tz)->format('d M Y H:i').' '.\App\Models\Outlet::labelOf($tz);
        $was = trim(($old->merchant ?? '—').($old->nmid ? ' · '.$old->nmid : ''));
        $now = $removed ? 'QRIS dihapus' : trim(($new['name'] ?: 'nama merchant tidak terbaca').($new['nmid'] ? ' · '.$new['nmid'] : ''));
        $body = "QRIS usaha Anda berubah pada $when.\n\nSebelumnya: $was\nSekarang: $now\n\n"
            ."Bila bukan Anda yang mengganti, segera buka aplikasi GOYANA → Pengaturan → QRIS, pasang lagi QRIS yang benar, dan ganti PIN admin/password.";
        if ($owner) DB::table('audit_events')->insert(['actor_id' => $owner->id, 'business_id' => $businessId, 'action' => 'qris.changed',
            'details' => json_encode(['before' => $was, 'after' => $now], JSON_UNESCAPED_UNICODE), 'created_at' => now()]);
        if (!$owner?->email) return;
        $key = 'qris-changed:'.$businessId.':'.now()->format('YmdHi');
        try {
            DB::table('outbound_messages')->insert(['business_id' => $businessId, 'kind' => 'qris_changed', 'dedupe_key' => $key, 'channel' => 'email',
                'recipient' => $owner->email, 'subject' => 'Peringatan: QRIS usaha berubah', 'body' => $body, 'status' => 'sent', 'created_at' => now()]);
            Mail::raw($body, fn ($m) => $m->to($owner->email)->subject('Peringatan: QRIS usaha berubah'));
        } catch (\Throwable $e) {
            DB::table('outbound_messages')->where('dedupe_key', $key)->update(['status' => 'failed', 'error' => mb_substr($e->getMessage(), 0, 300)]);
        }
    }
}
