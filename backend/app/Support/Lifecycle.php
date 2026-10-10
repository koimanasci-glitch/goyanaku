<?php
namespace App\Support;
use App\Models\{Business, Subscription};
use Illuminate\Support\Facades\{DB, Mail};
/**
 * Pesan otomatis hemat ke owner laundry (GOYANA-SISTEM-PUSAT.md §42B): selamat datang, pengingat 3 hari
 * sebelum paket habis, info baca-saja, dan bukti bayar. Masing-masing hanya sekali (dedupe_key).
 * Saat ini lewat email; WhatsApp ditambahkan setelah CHATKU tersambung (§41).
 */
class Lifecycle {
    public static function run(): array {
        $s = Settings::all(); $sent = ['welcome' => 0, 'expiry_reminder' => 0, 'expired' => 0, 'payment' => 0];
        if ($s['msg_welcome']) {
            foreach (Business::where('created_at', '>=', now()->subDays(3))->get() as $b) $sent['welcome'] += self::send($b, 'welcome', 'welcome:'.$b->id, ...self::welcome($b, $s));
        }
        if ($s['msg_expiry_reminder'] || $s['msg_expired']) {
            foreach (Business::where('created_at', '<=', now())->cursor() as $b) {
                $a = $b->currentAccess();
                if (!$a['ends_at']) continue;
                $end = \Carbon\CarbonImmutable::parse($a['ends_at']);
                $day = $end->timezone('Asia/Jakarta')->toDateString();
                if (!$a['read_only'] && $s['msg_expiry_reminder'] && $end->lessThanOrEqualTo(now()->addDays(3))) {
                    $sent['expiry_reminder'] += self::send($b, 'expiry_reminder', "expiry:{$b->id}:$day", ...self::reminder($b, $a, $end));
                }
                if ($a['read_only'] && $s['msg_expired'] && $end->greaterThanOrEqualTo(now()->subDays(3))) {
                    $sent['expired'] += self::send($b, 'expired', "expired:{$b->id}:$day", ...self::expired($b));
                }
            }
        }
        if ($s['msg_payment']) {
            foreach (Subscription::with('business')->whereNull('cancelled_at')->where('created_at', '>=', now()->subDays(3))->get() as $sub) {
                $sent['payment'] += self::send($sub->business, 'payment', 'payment:sub:'.$sub->id, 'Pembayaran paket '.$sub->package.' diterima',
                    "Terima kasih, pembayaran paket {$sub->package} sebesar Rp".number_format((int) $sub->amount, 0, ',', '.')." sudah kami terima.\n"
                    .'Masa aktif: '.$sub->starts_at->timezone('Asia/Jakarta')->format('d M Y').' – '.$sub->ends_at->timezone('Asia/Jakarta')->format('d M Y').".\nReferensi: {$sub->reference}");
            }
            foreach (DB::table('ai_ledger')->where('type', 'topup')->where('created_at', '>=', now()->subDays(3))->get() as $l) {
                $b = Business::find($l->business_id);
                $sent['payment'] += self::send($b, 'payment', 'payment:ai:'.$l->id, 'Top-up saldo AI diterima',
                    'Top-up saldo AI Rp'.number_format($l->amount, 0, ',', '.').' sudah masuk. Saldo sekarang Rp'.number_format($l->balance_after, 0, ',', '.').".\nReferensi: {$l->reference}");
            }
        }
        return $sent;
    }

    private static function owner(Business $b) { return $b->users()->where('role', 'owner')->whereNull('deactivated_at')->orderBy('id')->first(); }

    private static function footer(): string {
        $cs = Settings::get('cs_whatsapp');
        return "\n\n— GOYANA\nBantuan: ".url('/support').($cs ? "\nWhatsApp CS: https://wa.me/$cs" : '');
    }

    private static function welcome(Business $b, array $s): array {
        return ['Selamat datang di GOYANA', "Halo, {$b->name} sudah terdaftar dan langsung aktif trial paket Basic sampai ".$b->trial_ends_at->timezone('Asia/Jakarta')->format('d M Y').".\n\n"
            ."Panduan singkat (cukup sekali):\n1. Atur layanan & harga di menu Pengaturan.\n2. Buat transaksi pertama dari tombol Tambah di Beranda.\n3. Sambungkan printer Bluetooth (opsional) di Pengaturan > Printer.\n4. Tambah kasir & cabang dari dashboard web: ".url('/dashboard').'.'];
    }
    private static function reminder(Business $b, array $a, $end): array {
        $what = $a['source'] === 'trial' ? 'Trial' : 'Paket '.$a['package'];
        // Jam berakhir ditulis dalam zona waktu outlet pusat (WIB / WITA / WIT).
        $tz = \App\Models\Outlet::zoneOf(null, (int) $b->id);
        return [$what.' berakhir '.$end->timezone($tz)->format('d M'), "$what {$b->name} berakhir ".$end->timezone($tz)->format('d M Y H:i').' '.\App\Models\Outlet::labelOf($tz).".\n"
            ."Setelah itu data tetap aman dan bisa dilihat, tetapi transaksi baru terkunci sampai paket aktif lagi.\nPilih paket dari aplikasi: Pengaturan > Paket."];
    }
    private static function expired(Business $b): array {
        return ['Paket berakhir — data Anda aman', "Paket {$b->name} sudah berakhir. Semua data tetap tersimpan dan bisa dilihat (mode baca saja).\n"
            ."Aktifkan paket kapan saja untuk kembali mencatat transaksi: Pengaturan > Paket."];
    }

    private static function send(?Business $b, string $kind, string $key, string $subject, string $body): int {
        if (!$b || DB::table('outbound_messages')->where('dedupe_key', $key)->exists()) return 0;
        $owner = self::owner($b);
        if (!$owner) return 0;
        $body .= self::footer();
        try {
            // Reserve the key first so two overlapping runs never send twice.
            $id = DB::table('outbound_messages')->insertGetId(['business_id' => $b->id, 'kind' => $kind, 'dedupe_key' => $key, 'channel' => 'email',
                'recipient' => $owner->email, 'subject' => $subject, 'body' => $body, 'status' => 'sent', 'created_at' => now()]);
        } catch (\Illuminate\Database\UniqueConstraintViolationException) { return 0; }
        try { Mail::raw($body, fn ($m) => $m->to($owner->email)->subject($subject)); }
        catch (\Throwable $e) { DB::table('outbound_messages')->where('id', $id)->update(['status' => 'failed', 'error' => mb_substr($e->getMessage(), 0, 300)]); return 0; }
        return 1;
    }
}
