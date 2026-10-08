<?php
namespace App\Http\Controllers;
use Illuminate\Http\Request;
class DashboardController {
    public function __invoke(Request $request) {
        if ($request->user()->is_platform_admin) return redirect()->route('admin.index');
        $business = $request->user()->business;
        abort_unless($business, 403);
        $user = $request->user();
        if (!$user->isOwner()) {
            return view('staff', ['user' => $user, 'business' => $business, 'outlet' => $user->outlet]);
        }
        return view('dashboard', ['business' => $business, 'access' => $business->currentAccess(),
            'outlets' => $business->outlets()->with('devices')->get(),
            'team' => $business->users()->where('role', '!=', 'owner')->with('outlet')->orderBy('name')->get(),
            'roles' => collect(config('goyana.roles'))->except('owner'),
            'summary' => $this->summary($business),
            'alerts' => (new \App\Support\Monitoring($business))->alerts(),
            'shared' => \App\Models\SharedDevice::where('business_id', $business->id)->whereNull('revoked_at')->orderBy('outlet_id')->get()->groupBy('outlet_id')]);
    }

    /** Omzet & order counts from orders synced by the phones (Asia/Jakarta days). */
    private function summary($business): array {
        $tz = 'Asia/Jakarta'; $today = now($tz)->startOfDay(); $month = now($tz)->startOfMonth();
        $outlets = $business->outlets()->pluck('name', 'id');
        $rows = \Illuminate\Support\Facades\DB::table('sync_records')->where('business_id', $business->id)
            ->where('collection', 'orders')->where('deleted', false)->get(['outlet_id', 'data', 'updated_at']);
        $empty = fn () => ['today_orders' => 0, 'today_total' => 0, 'month_orders' => 0, 'month_total' => 0, 'unpaid' => 0];
        $total = $empty(); $per = [];
        foreach ($rows as $r) {
            $d = json_decode($r->data, true) ?: []; $card = $d['card'] ?? [];
            $status = $card['dataset']['st'] ?? '';
            if ($status === 'batal') continue;
            $created = \Carbon\CarbonImmutable::parse($card['dataset']['created177'] ?? $r->updated_at)->timezone($tz);
            $amount = (int) ($card['total'] ?? 0);
            $o = (int) $r->outlet_id; $per[$o] ??= $empty();
            foreach ([&$total, &$per[$o]] as &$bucket) {
                if ($created >= $month) { $bucket['month_orders']++; $bucket['month_total'] += $amount; }
                if ($created >= $today) { $bucket['today_orders']++; $bucket['today_total'] += $amount; }
                if (empty($card['paid'])) $bucket['unpaid']++;
            }
            unset($bucket);
        }
        $devices = \App\Models\CashierDevice::whereIn('outlet_id', $outlets->keys())->whereNotNull('device_uuid')
            ->whereNull('revoked_at')->max('last_seen_at');
        return ['total' => $total, 'per_outlet' => collect($per)->mapWithKeys(fn ($v, $k) => [$outlets[$k] ?? 'Outlet' => $v])->all(),
            'last_sync' => $devices ? \Carbon\CarbonImmutable::parse($devices)->timezone($tz) : null, 'synced' => $rows->count()];
    }
}
