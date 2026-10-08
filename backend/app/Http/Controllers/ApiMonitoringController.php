<?php
namespace App\Http\Controllers;

use App\Models\User;
use App\Support\{Monitoring, Team};
use Carbon\CarbonImmutable;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Monitoring dan alur uang kurir.
 * - Laporan lengkap semua cabang: hanya owner. Admin outlet melihat outletnya sendiri.
 * - Kasir, pegawai, kurir: ringkasan milik sendiri saja.
 * - Tunai yang diterima kurir "dipegang kurir" sampai disetor ke kasir outletnya dan dikonfirmasi.
 */
class ApiMonitoringController {
    private function user(Request $request): User {
        $user = $request->user();
        abort_if($user->is_platform_admin || !$user->business_id, 403);
        abort_unless($user->tokenCan('business:read'), 403);
        return $user;
    }

    public function report(Request $request) {
        $user = $this->user($request);
        abort_unless($user->role === 'owner' || $user->hasPermission('reports.view'), 403, 'Laporan hanya untuk owner.');
        $data = $request->validate(['outlet_id' => 'nullable|integer', 'from' => 'nullable|date_format:Y-m-d', 'to' => 'nullable|date_format:Y-m-d|after_or_equal:from']);
        $outletId = $user->role === 'owner' ? ($data['outlet_id'] ?? null) : $user->outlet_id; // admin outlet selalu outletnya sendiri
        if ($outletId !== null) abort_unless($user->business->outlets()->whereKey($outletId)->exists(), 404);
        $today = CarbonImmutable::now(Monitoring::TZ);
        $from = CarbonImmutable::parse($data['from'] ?? $today->toDateString(), Monitoring::TZ)->startOfDay();
        $to = CarbonImmutable::parse($data['to'] ?? ($data['from'] ?? $today->toDateString()), Monitoring::TZ)->endOfDay();
        if ($from->diffInDays($to) > 366) throw ValidationException::withMessages(['to' => 'Rentang tanggal paling lama satu tahun.']);
        return response()->json((new Monitoring($user->business))->report($outletId === null ? null : (int) $outletId, $from, $to));
    }

    public function alerts(Request $request) {
        $user = $this->user($request);
        abort_unless($user->role === 'owner' || $user->hasPermission('reports.view'), 403, 'Peringatan hanya untuk owner.');
        return response()->json(['alerts' => (new Monitoring($user->business))->alerts($user->role === 'owner' ? null : $user->outlet_id)]);
    }

    /** Ringkasan milik sendiri (kasir, pegawai, kurir). */
    public function own(Request $request) {
        $user = $this->user($request);
        return response()->json((new Monitoring($user->business))->own($user));
    }

    // ---------- tunai kurir ----------

    /** Kurir: uang yang sedang dia pegang dan riwayatnya. */
    public function courierOwn(Request $request) {
        $user = $this->user($request);
        abort_unless($user->orderMode() === 'courier', 403);
        $cash = (new Monitoring($user->business))->courierCash([$user->outlet_id], $user->id)[0] ?? null;
        $history = DB::table('courier_ledger')->where('business_id', $user->business_id)->where('courier_id', $user->id)->orderByDesc('id')->limit(50)->get()
            ->map(fn ($r) => ['type' => $r->type, 'amount' => (int) $r->amount, 'expected' => $r->expected === null ? null : (int) $r->expected,
                'note_no' => $r->record_key, 'at' => CarbonImmutable::parse($r->created_at, 'UTC')->toIso8601String()])->all();
        return response()->json(['held' => (int) ($cash['held'] ?? 0), 'since' => $cash['since'] ?? null, 'notes' => (int) ($cash['notes'] ?? 0), 'history' => $history]);
    }

    /** Kasir/admin outlet (outletnya) atau owner: tunai yang dipegang tiap kurir. */
    public function courierCash(Request $request) {
        $user = $this->user($request);
        abort_unless($user->hasPermission('cash.manage'), 403);
        $outlets = $user->role === 'owner' ? $user->business->outlets()->pluck('id')->all() : [$user->outlet_id];
        return response()->json(['couriers' => (new Monitoring($user->business))->courierCash($outlets)]);
    }

    /** Kasir menerima setoran kurir: seluruh saldo kurir diselesaikan, selisihnya tercatat atas nama kurir itu. */
    public function deposit(Request $request, User $courier) {
        $user = $this->user($request);
        abort_unless($user->hasPermission('cash.manage'), 403);
        abort_unless($courier->business_id === $user->business_id && $courier->orderMode() === 'courier', 404);
        abort_unless($user->role === 'owner' || $user->outlet_id === $courier->outlet_id, 403, 'Kurir setor ke kasir outletnya sendiri.');
        abort_if($user->business->currentAccess()['read_only'], 403, 'Paket sudah berakhir.');
        $data = $request->validate(['amount' => 'required|integer|min:0|max:1000000000', 'note' => 'nullable|string|max:300']);
        $entry = DB::transaction(function () use ($user, $courier, $data) {
            User::whereKey($courier->id)->lockForUpdate()->first();
            $held = (new Monitoring($user->business))->courierCash([$courier->outlet_id], $courier->id)[0]['held'] ?? 0;
            if ($held <= 0) throw ValidationException::withMessages(['amount' => 'Kurir ini tidak sedang memegang tunai.']);
            if ((int) $data['amount'] !== $held && trim((string) ($data['note'] ?? '')) === '') {
                throw ValidationException::withMessages(['note' => 'Jumlah berbeda dari catatan (Rp'.number_format($held, 0, ',', '.').'). Isi keterangan selisihnya.']);
            }
            DB::table('courier_ledger')->insert(['business_id' => $user->business_id, 'outlet_id' => $courier->outlet_id, 'courier_id' => $courier->id,
                'type' => 'deposit', 'amount' => (int) $data['amount'], 'expected' => $held, 'confirmed_by' => $user->id, 'note' => $data['note'] ?? null, 'created_at' => now()]);
            Team::audit($user, 'courier.deposit', ['courier_id' => $courier->id, 'expected' => $held, 'received' => (int) $data['amount']]);
            return ['expected' => $held, 'received' => (int) $data['amount'], 'difference' => (int) $data['amount'] - $held];
        });
        return response()->json(['deposit' => $entry + ['courier_id' => $courier->id, 'outlet_id' => $courier->outlet_id]], 201);
    }
}
