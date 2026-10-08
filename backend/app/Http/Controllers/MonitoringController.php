<?php
namespace App\Http\Controllers;

use App\Support\Monitoring;
use Carbon\CarbonImmutable;
use Illuminate\Http\Request;

/**
 * Halaman Monitoring di web: laporan lengkap semua cabang untuk owner; admin outlet hanya outletnya sendiri.
 * Angkanya sama dengan GET /api/monitoring yang dipakai aplikasi (App\Support\Monitoring).
 */
class MonitoringController {
    public function __invoke(Request $request) {
        $user = $request->user(); $business = $user->business;
        abort_if($user->is_platform_admin || !$business, 403);
        abort_unless($user->role === 'owner' || $user->hasPermission('reports.view'), 403, 'Laporan hanya untuk owner.');
        $data = $request->validate(['outlet_id' => 'nullable|integer', 'from' => 'nullable|date_format:Y-m-d', 'to' => 'nullable|date_format:Y-m-d|after_or_equal:from']);
        $outlets = $business->outlets()->orderBy('id')->get();
        $outletId = $user->role === 'owner' ? ($data['outlet_id'] ?? null) : $user->outlet_id;
        if ($outletId !== null) abort_unless($outlets->contains('id', (int) $outletId), 404);
        $today = CarbonImmutable::now(Monitoring::TZ);
        $from = CarbonImmutable::parse($data['from'] ?? $today->toDateString(), Monitoring::TZ)->startOfDay();
        $to = CarbonImmutable::parse($data['to'] ?? ($data['from'] ?? $today->toDateString()), Monitoring::TZ)->endOfDay();
        if ($from->diffInDays($to) > 366) $to = $from->addDays(366)->endOfDay();
        return view('monitoring', [
            'business' => $business, 'outlets' => $outlets, 'owner' => $user->role === 'owner', 'outletId' => $outletId === null ? null : (int) $outletId,
            'from' => $from, 'to' => $to, 'report' => (new Monitoring($business))->report($outletId === null ? null : (int) $outletId, $from, $to),
            'stageNames' => ['jemput' => 'Jemput', 'antrian' => 'Antrian', 'cuci' => 'Cuci', 'kering' => 'Kering', 'setrika' => 'Setrika', 'packing' => 'Packing',
                'selesaiproses' => 'Selesai Proses', 'siap' => 'Siap Ambil', 'telat' => 'Siap Ambil (lewat waktu)', 'diantar' => 'Diantar'],
        ]);
    }
}
