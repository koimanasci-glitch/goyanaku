<?php
namespace App\Http\Controllers;
use App\Models\Business;
use App\Models\PackageGrant;
use App\Models\Subscription;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
class AdminController {
    private function filtered(?string $status) { return Business::withAccessStatus($status); }

    public function index(Request $request) {
        $status = $request->query('status');
        $status = in_array($status, ['paid', 'beta', 'trial', 'expired'], true) ? $status : null;
        $term = trim((string) $request->query('q', ''));
        $list = $this->filtered($status);
        if ($term !== '') {
            $like = '%'.str_replace(['%', '_'], ['\%', '\_'], $term).'%';
            $list->where(fn ($q) => $q->where('name', 'like', $like)
                ->orWhereHas('users', fn ($u) => $u->where('email', 'like', $like)->orWhere('name', 'like', $like))
                ->when(ctype_digit($term), fn ($q) => $q->orWhere('id', (int) $term)));
        }
        $monthStart = now('Asia/Jakarta')->startOfMonth()->utc();
        $stats = [
            'total' => Business::count(),
            'paid' => $this->filtered('paid')->count(),
            'beta' => $this->filtered('beta')->count(),
            'trial' => $this->filtered('trial')->count(),
            'expired' => $this->filtered('expired')->count(),
            'new7' => Business::where('created_at', '>=', now()->subDays(7))->count(),
            'revenue' => (int) Subscription::whereNull('cancelled_at')->where('created_at', '>=', $monthStart)->sum('amount'),
            'devices' => \App\Models\CashierDevice::whereNull('revoked_at')->whereNotNull('device_uuid')->count(),
            'conflicts7' => DB::table('sync_conflicts')->where('created_at', '>=', now()->subDays(7))->count(),
        ];
        $endingTrials = $this->filtered('trial')->where('trial_ends_at', '<=', now()->addDays(7))->orderBy('trial_ends_at')->limit(10)->get();
        $endingPaid = Subscription::with('business')->whereNull('cancelled_at')->where('ends_at', '>', now())->where('ends_at', '<=', now()->addDays(7))->orderBy('ends_at')->limit(10)->get();
        $lastSync = DB::table('sync_records')->selectRaw('business_id, max(updated_at) as last')->groupBy('business_id')->pluck('last', 'business_id');
        return view('admin', ['businesses' => $list->with('users')->latest('id')->paginate(20)->withQueryString(), 'stats' => $stats,
            'status' => $status, 'term' => $term, 'endingTrials' => $endingTrials, 'endingPaid' => $endingPaid, 'lastSync' => $lastSync]);
    }

    public function show(Business $business) {
        $outlets = $business->outlets()->with(['devices' => fn ($d) => $d->orderByRaw('revoked_at is not null')->orderBy('slot')])->orderBy('id')->get();
        $sync = [
            'records' => DB::table('sync_records')->where('business_id', $business->id)->where('deleted', false)
                ->selectRaw('collection, count(*) as n, max(updated_at) as last')->groupBy('collection')->orderBy('collection')->get(),
            'last' => DB::table('sync_records')->where('business_id', $business->id)->max('updated_at'),
            'ops24' => DB::table('sync_ops')->where('business_id', $business->id)->where('created_at', '>=', now()->subDay())->count(),
            'conflicts' => DB::table('sync_conflicts')->where('business_id', $business->id)->latest('id')->limit(10)->get(['id', 'collection', 'record_key', 'device_uuid', 'created_at']),
        ];
        $audit = DB::table('audit_events')->leftJoin('users', 'users.id', '=', 'audit_events.actor_id')->where('audit_events.business_id', $business->id)
            ->orderByDesc('audit_events.id')->limit(30)->get(['audit_events.*', 'users.name as actor_name', 'users.is_platform_admin as actor_admin']);
        return view('business', ['business' => $business, 'access' => $business->currentAccess(), 'grants' => $business->grants()->latest('id')->get(),
            'subscriptions' => $business->subscriptions()->latest('id')->get(), 'packages' => config('goyana.packages'),
            'messages' => DB::table('outbound_messages')->where('business_id', $business->id)->orderByDesc('id')->limit(10)->get(),
            'aiLedger' => DB::table('ai_ledger')->where('business_id', $business->id)->orderByDesc('id')->limit(15)->get(),
            'users' => $business->users()->with('outlet')->orderByRaw("role <> 'owner'")->orderBy('id')->get(), 'outlets' => $outlets, 'sync' => $sync, 'audit' => $audit]);
    }

    /** Support action: free a cashier slot (lost/stolen phone) without the owner. Audited as the admin. */
    public function revokeDevice(Request $request, Business $business, \App\Models\CashierDevice $device) {
        abort_unless($device->outlet && $device->outlet->business_id === $business->id, 404);
        $data = $request->validate(['reason' => 'required|string|max:300']);
        DB::transaction(function () use ($request, $business, $device, $data) {
            $locked = \App\Models\CashierDevice::whereKey($device->id)->lockForUpdate()->firstOrFail();
            if ($locked->revoked_at) return;
            $locked->revoked_at = now(); $locked->slot = null; $locked->save();
            DB::table('audit_events')->insert(['actor_id' => $request->user()->id, 'business_id' => $business->id, 'action' => 'device.revoked_by_admin',
                'details' => json_encode(['device_id' => $locked->id, 'reason' => $data['reason']]), 'created_at' => now()]);
        });
        return back()->with('status', 'Akses perangkat dicabut oleh administrator.');
    }

    public function audit(Request $request) {
        $q = DB::table('audit_events')->leftJoin('users', 'users.id', '=', 'audit_events.actor_id')->leftJoin('businesses', 'businesses.id', '=', 'audit_events.business_id');
        $action = trim((string) $request->query('action', ''));
        if ($action !== '') $q->where('audit_events.action', 'like', str_replace(['%', '_'], ['\%', '\_'], $action).'%');
        if (ctype_digit((string) $request->query('business'))) $q->where('audit_events.business_id', (int) $request->query('business'));
        if ($request->boolean('admin')) $q->where('users.is_platform_admin', true);
        $events = $q->orderByDesc('audit_events.id')->select(['audit_events.*', 'users.name as actor_name', 'users.is_platform_admin as actor_admin', 'businesses.name as business_name'])
            ->paginate(50)->withQueryString();
        $actions = DB::table('audit_events')->distinct()->orderBy('action')->pluck('action');
        return view('admin-audit', ['events' => $events, 'actions' => $actions, 'action' => $action]);
    }

    public function system() {
        return view('admin-system', ['checks' => \App\Support\Health::checks(), 'info' => \App\Support\Health::info()]);
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

    public function aiTopUp(Request $request, Business $business) {
        $data = $request->validate(['amount' => 'required|integer|min:1|max:100000000', 'reference' => 'required|string|max:120']);
        $balance = \App\Support\AiBilling::topUp($business, (int) $data['amount'], $data['reference'], $request->user()->id);
        return back()->with('status', 'Top-up dicatat. Saldo AI sekarang Rp'.number_format($balance, 0, ',', '.').'.');
    }
}
