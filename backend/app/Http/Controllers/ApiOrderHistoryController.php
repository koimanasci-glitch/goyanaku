<?php
namespace App\Http\Controllers;

use App\Models\User;
use App\Support\Monitoring;
use Carbon\CarbonImmutable;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Riwayat Transaksi (keputusan Paduka 10 Oktober 2026, pengganti jatah koreksi):
 * - GET /orders/{key}/history: kejadian satu nota (dibuat, dibayar, diubah, dikembalikan, dibatalkan, tahap), dengan nama akun.
 *   Kasir/kepala cabang hanya nota cabangnya; pegawai dan kurir tidak bisa (mereka tidak melihat harga).
 * - GET /corrections: perubahan setelah diproses/dibayar, pengembalian uang, dan batal setelah bayar, per kasir; owner semua cabang,
 *   kepala cabang hanya cabangnya.
 */
class ApiOrderHistoryController {
    private function user(Request $request): User {
        $user = $request->user();
        abort_if($user->is_platform_admin || !$user->business_id, 403);
        abort_unless($user->tokenCan('business:read'), 403);
        return $user;
    }

    private function present($events): array {
        $names = DB::table('users')->whereIn('id', $events->pluck('user_id')->filter()->unique())->pluck('name', 'id');
        $outlets = DB::table('outlets')->whereIn('id', $events->pluck('outlet_id')->unique())->pluck('name', 'id');
        return $events->map(fn ($e) => [
            'key' => $e->record_key, 'kind' => $e->kind, 'item' => $e->item_index, 'from' => $e->from_status, 'to' => $e->to_status,
            'details' => $e->details ? json_decode($e->details, true) : null,
            'by' => $names[$e->user_id] ?? 'Akun dihapus', 'role' => $e->role, 'outlet' => 'srv-'.$e->outlet_id, 'outlet_name' => $outlets[$e->outlet_id] ?? '',
            'at' => CarbonImmutable::parse($e->created_at)->toIso8601String(),
        ])->values()->all();
    }

    public function history(Request $request, string $key) {
        $user = $this->user($request);
        abort_unless($user->orderMode() === 'full', 403, 'Riwayat transaksi hanya untuk kasir, kepala cabang, dan owner.');
        $index = DB::table('order_index')->where('business_id', $user->business_id)->where('record_key', $key)->first();
        abort_unless($index, 404, 'Nota ini belum tersimpan di server.');
        if ($user->role !== 'owner') abort_unless((int) $index->outlet_id === (int) $user->outlet_id, 403, 'Nota milik cabang lain.');
        $events = DB::table('order_events')->where('business_id', $user->business_id)->where('record_key', $key)->orderBy('id')->get();
        return response()->json(['key' => $key, 'events' => $this->present($events)]);
    }

    public function corrections(Request $request) {
        $user = $this->user($request);
        abort_unless($user->role === 'owner' || $user->hasPermission('reports.view'), 403, 'Laporan koreksi hanya untuk owner dan kepala cabang.');
        $data = $request->validate(['outlet_id' => 'nullable|integer', 'from' => 'nullable|date_format:Y-m-d', 'to' => 'nullable|date_format:Y-m-d|after_or_equal:from']);
        $outletId = $user->role === 'owner' ? ($data['outlet_id'] ?? null) : $user->outlet_id;
        if ($outletId !== null) abort_unless($user->business->outlets()->whereKey($outletId)->exists(), 404);
        $today = CarbonImmutable::now(Monitoring::TZ);
        $from = CarbonImmutable::parse($data['from'] ?? $today->startOfMonth()->toDateString(), Monitoring::TZ)->startOfDay();
        $to = CarbonImmutable::parse($data['to'] ?? $today->toDateString(), Monitoring::TZ)->endOfDay();
        if ($from->diffInDays($to) > 366) throw ValidationException::withMessages(['to' => 'Rentang tanggal paling lama satu tahun.']);
        $events = DB::table('order_events')->where('business_id', $user->business_id)
            ->when($outletId !== null, fn ($q) => $q->where('outlet_id', $outletId))
            ->whereBetween('created_at', [$from->utc(), $to->utc()])
            ->whereIn('kind', ['ubah', 'kembali', 'batal'])->orderByDesc('id')->limit(2000)->get()
            ->filter(fn ($e) => match ($e->kind) {
                'ubah' => (bool) (json_decode((string) $e->details, true)['flag'] ?? false),
                'batal' => (int) (json_decode((string) $e->details, true)['paid'] ?? 0) > 0,
                default => true,
            })->values();
        $list = $this->present($events);
        $people = collect($list)->groupBy('by')->map(fn ($g, $name) => ['name' => $name, 'count' => $g->count(),
            'lowered' => $g->filter(fn ($e) => $e['kind'] === 'ubah' && ($e['details']['after']['total'] ?? 0) < ($e['details']['before']['total'] ?? 0))->count(),
            'refund' => (int) $g->where('kind', 'kembali')->sum(fn ($e) => (int) ($e['details']['amount'] ?? 0))])
            ->sortByDesc('count')->values()->all();
        return response()->json(['from' => $from->toDateString(), 'to' => $to->toDateString(), 'people' => $people, 'events' => $list]);
    }
}
