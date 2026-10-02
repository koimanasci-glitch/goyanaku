<?php
namespace App\Http\Controllers;
use App\Models\Business;
use App\Models\PackageGrant;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
class AdminController {
    public function index() { return view('admin', ['businesses' => Business::latest('id')->paginate(20)]); }
    public function show(Business $business) {
        return view('business', ['business' => $business, 'access' => $business->currentAccess(), 'grants' => $business->grants()->latest('id')->get()]);
    }
    public function grant(Request $request, Business $business) {
        $data = $request->validate([
            'package' => ['required', Rule::in(['Basic', 'Silver', 'Gold', 'Platinum'])],
            'reason' => 'required|string|max:500',
            'ends_at' => 'required|date|after:now|before:'.now()->addYear()->toIso8601String(),
        ]);
        // Browser datetime-local is shown in Jakarta; parse it explicitly in that timezone.
        $endsAt = \Carbon\CarbonImmutable::parse($data['ends_at'], 'Asia/Jakarta')->utc();
        abort_unless($endsAt->isFuture() && $endsAt->lessThan(now()->addYear()), 422);
        DB::transaction(function () use ($request, $business, $data, $endsAt) {
            Business::whereKey($business->id)->lockForUpdate()->firstOrFail();
            $grant = $business->grants()->create([
                'package' => $data['package'], 'reason' => $data['reason'], 'starts_at' => now(),
                'ends_at' => $endsAt, 'granted_by' => $request->user()->id,
            ]);
            DB::table('audit_events')->insert(['actor_id' => $request->user()->id, 'business_id' => $business->id,
                'action' => 'package.granted', 'details' => json_encode(['grant_id' => $grant->id, 'package' => $grant->package, 'reason' => $grant->reason, 'ends_at' => $endsAt->toIso8601String()]), 'created_at' => now()]);
        });
        return back()->with('status', 'Paket sementara diberikan. Tidak membuat tagihan atau saldo AI.');
    }
    public function revoke(Request $request, Business $business, PackageGrant $grant) {
        abort_unless($grant->business_id === $business->id, 404);
        DB::transaction(function () use ($request, $business, $grant) {
            Business::whereKey($business->id)->lockForUpdate()->firstOrFail();
            $locked = PackageGrant::whereKey($grant->id)->lockForUpdate()->firstOrFail();
            if ($locked->revoked_at) return;
            $locked->revoked_at = now(); $locked->save();
            DB::table('audit_events')->insert(['actor_id' => $request->user()->id, 'business_id' => $business->id,
                'action' => 'package.revoked', 'details' => json_encode(['grant_id' => $grant->id]), 'created_at' => now()]);
        });
        return back()->with('status', 'Paket sementara dicabut.');
    }
}
