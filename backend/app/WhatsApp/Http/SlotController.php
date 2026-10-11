<?php
namespace App\WhatsApp\Http;

use App\Models\{Business, User};
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Slot nomor WhatsApp tambahan (keputusan Paduka 10 Okt 2026: Rp30.000 per nomor per bulan). Selama pembayaran Google Play
 * belum tersambung, administrator mencatat pembayaran manual (transfer/QRIS) di sini — tercatat rapi dengan referensi & audit.
 */
final class SlotController {
    public const PRICE = 30000;

    public function index(Request $r) {
        $grants = DB::table('wa_slot_grants')->join('businesses', 'businesses.id', '=', 'wa_slot_grants.business_id')
            ->select('wa_slot_grants.*', 'businesses.name as business')->orderByDesc('wa_slot_grants.id')->paginate(30);
        return view('whatsapp::slots', ['grants' => $grants, 'price' => self::PRICE]);
    }

    public function store(Request $r) {
        $v = $r->validate(['client' => 'required|string|max:254', 'slots' => 'required|integer|min:1|max:10', 'months' => 'required|integer|min:1|max:12',
            'reference' => 'required|string|max:120|unique:wa_slot_grants,payment_reference', 'paid' => 'required|integer|min:0']);
        $b = ctype_digit($v['client']) ? Business::find((int) $v['client'])
            : Business::find(User::where('email', mb_strtolower(trim($v['client'])))->value('business_id'));
        if (!$b) return back()->withErrors(['client' => 'Client tidak ditemukan (isi ID usaha atau email pemilik).'])->withInput();
        $expected = self::PRICE * (int) $v['slots'] * (int) $v['months'];
        DB::transaction(function () use ($r, $b, $v, $expected) {
            Business::whereKey($b->id)->lockForUpdate()->firstOrFail();
            // Perpanjangan menyambung dari slot yang masih berjalan (tidak tumpang tindih → tidak dihitung dobel).
            $start = DB::table('wa_slot_grants')->where('business_id', $b->id)->where('slots', $v['slots'])->whereNull('revoked_at')->where('ends_at', '>', now())->max('ends_at');
            $starts = $start ? \Carbon\CarbonImmutable::parse($start) : now()->toImmutable();
            $id = DB::table('wa_slot_grants')->insertGetId(['business_id' => $b->id, 'payment_reference' => $v['reference'], 'slots' => $v['slots'],
                'starts_at' => $starts, 'ends_at' => $starts->addMonthsNoOverflow((int) $v['months']), 'created_at' => now(), 'updated_at' => now()]);
            DB::table('audit_events')->insert(['actor_id' => $r->user()->id, 'business_id' => $b->id, 'action' => 'wa.slot_granted',
                'details' => json_encode(['grant_id' => $id, 'slots' => (int) $v['slots'], 'months' => (int) $v['months'], 'paid' => (int) $v['paid'],
                    'expected' => $expected, 'reference' => $v['reference']]), 'created_at' => now()]);
        });
        $note = (int) $v['paid'] === $expected ? '' : ' Perhatian: dibayar Rp'.number_format((int) $v['paid'], 0, ',', '.').', seharusnya Rp'.number_format($expected, 0, ',', '.').'.';
        return back()->with('status', "Slot WhatsApp ditambahkan untuk {$b->name}.".$note);
    }

    public function revoke(Request $r, int $id) {
        $g = DB::table('wa_slot_grants')->where('id', $id)->first() ?? abort(404);
        if (!$g->revoked_at) {
            DB::table('wa_slot_grants')->where('id', $id)->update(['revoked_at' => now(), 'updated_at' => now()]);
            DB::table('audit_events')->insert(['actor_id' => $r->user()->id, 'business_id' => $g->business_id, 'action' => 'wa.slot_revoked',
                'details' => json_encode(['grant_id' => $id]), 'created_at' => now()]);
        }
        return back()->with('status', 'Slot dicabut. Nomor yang sudah tersambung tetap berjalan sampai dihapus; nomor terbaru kehilangan balasan otomatis.');
    }
}
