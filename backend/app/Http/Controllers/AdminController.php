<?php
namespace App\Http\Controllers;
use App\Models\Business;
use App\Models\PackageGrant;
use App\Models\Subscription;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
class AdminController {
    public function index() { return view('admin', ['businesses' => Business::latest('id')->paginate(20)]); }
    public function show(Business $business) {
        return view('business', ['business' => $business, 'access' => $business->currentAccess(), 'grants' => $business->grants()->latest('id')->get(),
            'subscriptions' => $business->subscriptions()->latest('id')->get(), 'packages' => config('goyana.packages')]);
    }
    public function grant(Request $request, Business $business) {
        $data = $request->validate([
            'package' => ['required', Rule::in(array_keys(config('goyana.packages')))],
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

    /**
     * Record a paid package confirmed outside the app (transfer/QRIS) until the payment
     * gateway / Play Billing webhook is live. Renewals continue from the current paid end date.
     */
    public function subscribe(Request $request, Business $business) {
        $data = $request->validate([
            'package' => ['required', Rule::in(array_keys(config('goyana.packages')))],
            'months' => 'required|integer|min:1|max:12',
            'amount' => 'required|integer|min:0|max:100000000',
            'reference' => 'required|string|max:120',
        ]);
        DB::transaction(function () use ($request, $business, $data) {
            Business::whereKey($business->id)->lockForUpdate()->firstOrFail();
            if (Subscription::where('source', 'manual')->where('reference', $data['reference'])->exists()) {
                throw \Illuminate\Validation\ValidationException::withMessages(['reference' => 'Referensi pembayaran ini sudah dicatat.']);
            }
            $paidUntil = $business->subscriptions()->whereNull('cancelled_at')->where('ends_at', '>', now())->max('ends_at');
            $start = $paidUntil ? \Carbon\CarbonImmutable::parse($paidUntil) : now()->toImmutable();
            $sub = $business->subscriptions()->create([
                'package' => $data['package'], 'starts_at' => $start, 'ends_at' => $start->addMonthsNoOverflow((int) $data['months']),
                'source' => 'manual', 'reference' => $data['reference'], 'amount' => (int) $data['amount'], 'recorded_by' => $request->user()->id,
            ]);
            DB::table('audit_events')->insert(['actor_id' => $request->user()->id, 'business_id' => $business->id, 'action' => 'subscription.recorded',
                'details' => json_encode(['subscription_id' => $sub->id, 'package' => $sub->package, 'months' => (int) $data['months'], 'amount' => $sub->amount, 'reference' => $sub->reference]), 'created_at' => now()]);
        });
        return back()->with('status', 'Pembayaran paket dicatat. Akses usaha aktif sesuai paket.');
    }

    public function cancelSubscription(Request $request, Business $business, Subscription $subscription) {
        abort_unless($subscription->business_id === $business->id, 404);
        $data = $request->validate(['reason' => 'required|string|max:500']);
        DB::transaction(function () use ($request, $business, $subscription, $data) {
            $locked = Subscription::whereKey($subscription->id)->lockForUpdate()->firstOrFail();
            if ($locked->cancelled_at) return;
            $locked->cancelled_at = now(); $locked->save();
            DB::table('audit_events')->insert(['actor_id' => $request->user()->id, 'business_id' => $business->id, 'action' => 'subscription.cancelled',
                'details' => json_encode(['subscription_id' => $locked->id, 'reason' => $data['reason']]), 'created_at' => now()]);
        });
        return back()->with('status', 'Catatan langganan dibatalkan.');
    }
}
