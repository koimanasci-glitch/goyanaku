<?php
namespace App\Http\Controllers;

use App\Models\{Business, Outlet, Subscription, User};
use App\Support\ServerStats;
use Carbon\CarbonImmutable;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;

/** Aplikasi administrator: Beranda, daftar fitur, laporan, tambah client, dan akun administrator per divisi. */
class AdminHomeController {
    /** Menu aplikasi administrator: [rute, judul, ikon, warna, area]. Beranda menampilkan delapan yang pertama. */
    public const MENU = [
        ['admin.client.new', 'Tambah Client', 'user-plus', 'orange', 'billing'],
        ['admin.clients', 'Kelola Client', 'store', 'red', 'clients'],
        ['admin.packages', 'Paket & Langganan', 'box', 'amber', 'clients'],
        ['admin.admins', 'Pengguna', 'people', 'blue', 'admins'],
        ['admin.marketing', 'WhatsApp & CRM', 'chat', 'green', 'marketing'],
        ['admin.reports', 'Laporan SaaS', 'chart', 'violet', 'reports'],
        ['admin.system', 'Monitor VPS', 'server', 'gray', 'system'],
        ['admin.campaigns', 'Promosi & Notifikasi', 'megaphone', 'red', 'marketing'],
        ['admin.tickets', 'Tiket Bantuan', 'bell', 'blue', 'support'],
        ['admin.faqs', 'FAQ', 'help', 'green', 'support'],
        ['admin.wa.templates', 'Template WhatsApp', 'chat', 'orange', 'support'],
        ['admin.settings', 'Pengaturan Sistem', 'gear', 'gray', 'settings'],
        ['admin.audit', 'Audit', 'shield', 'violet', 'audit'],
    ];

    public function home(Request $request) {
        $month = now('Asia/Jakarta')->startOfMonth()->utc();
        $active = Business::withAccessStatus('paid')->count() + Business::withAccessStatus('beta')->count();
        $stats = [
            ['Total Client', Business::count(), Business::where('created_at', '>=', $month)->count(), 'people', 'admin.clients', []],
            ['Total Outlet', Outlet::count(), Outlet::where('created_at', '>=', $month)->count(), 'store', 'admin.clients', []],
            ['Paket Aktif', $active, Subscription::whereNull('cancelled_at')->where('created_at', '>=', $month)->distinct('business_id')->count('business_id'), 'crown', 'admin.clients', ['status' => 'paid']],
            ['Client Trial', Business::withAccessStatus('trial')->count(), Business::withAccessStatus('trial')->where('created_at', '>=', $month)->count(), 'hourglass', 'admin.clients', ['status' => 'trial']],
        ];
        $recent = $request->user()->adminCan('clients') || $request->user()->adminCan('marketing')
            ? Business::withCount('outlets')->latest('id')->limit(5)->get() : collect();
        return view('admin-home', ['stats' => $stats, 'recent' => $recent, 'menu' => array_slice(self::MENU, 0, 8),
            'server' => $request->user()->adminCan('system') ? ServerStats::now() : null]);
    }

    public function features() { return view('admin-features', ['menu' => self::MENU]); }

    /** Paket & Langganan: daftar paket dan client yang masa aktifnya segera habis. */
    public function packages() {
        $counts = [];
        foreach (Business::with('subscriptions', 'grants')->get() as $b) { $a = $b->currentAccess(); $k = $a['package'] ?? 'Berakhir'; $counts[$k] = ($counts[$k] ?? 0) + 1; }
        return view('admin-packages', ['packages' => config('goyana.packages'), 'counts' => $counts,
            'endingTrials' => Business::withAccessStatus('trial')->where('trial_ends_at', '<=', now()->addDays(7))->orderBy('trial_ends_at')->limit(30)->get(),
            'endingPaid' => Subscription::with('business')->whereNull('cancelled_at')->where('ends_at', '>', now())->where('ends_at', '<=', now()->addDays(7))->orderBy('ends_at')->limit(30)->get()]);
    }

    // ---------- tambah client ----------

    public function newClient() { return view('admin-client-new', ['packages' => array_keys(config('goyana.packages'))]); }

    /** Administrator mendaftarkan client: usaha + akun pemilik (email dan password awal), masa trial biasa. */
    public function storeClient(Request $request) {
        $request->merge(['email' => mb_strtolower(trim((string) $request->input('email')))]);
        $data = $request->validate([
            'business_name' => 'required|string|max:120', 'name' => 'required|string|max:120',
            'email' => 'required|email|max:254|unique:users,email', 'phone' => 'nullable|string|max:20',
            'password' => ['required', Password::min(12)->letters()->numbers()],
        ]);
        $phone = trim((string) ($data['phone'] ?? '')) === '' ? null : User::normalizePhone($data['phone']);
        if ($phone !== null && (!preg_match('/^62\d{8,13}$/', $phone) || User::where('phone', $phone)->exists())) {
            return back()->withErrors(['phone' => 'Nomor HP tidak valid atau sudah dipakai akun lain.'])->withInput($request->except('password'));
        }
        $business = DB::transaction(function () use ($data, $phone, $request) {
            $business = Business::create(['name' => $data['business_name'], 'trial_ends_at' => now()->addMonthsNoOverflow((int) config('goyana.trial.months'))]);
            $business->outlets()->create(['name' => $data['business_name'].' — Pusat']);
            $user = new User(['name' => $data['name'], 'email' => $data['email'], 'password' => $data['password'], 'phone' => $phone]);
            $user->business()->associate($business); $user->role = 'owner'; $user->email_verified_at = now(); $user->save();
            DB::table('audit_events')->insert(['actor_id' => $request->user()->id, 'business_id' => $business->id, 'action' => 'client.created_by_admin',
                'details' => json_encode(['owner_id' => $user->id]), 'created_at' => now()]);
            return $business;
        });
        return redirect()->route('admin.business', $business)->with('status', 'Client dibuat dengan trial. Berikan email dan password awal ke pemiliknya secara langsung; paket bisa diatur di halaman ini.');
    }

    // ---------- laporan SaaS ----------

    public function reports() {
        $tz = 'Asia/Jakarta'; $months = [];
        for ($i = 5; $i >= 0; $i--) {
            $start = CarbonImmutable::now($tz)->startOfMonth()->subMonthsNoOverflow($i); $end = $start->addMonthNoOverflow();
            $months[] = ['label' => $start->locale('id')->translatedFormat('M Y'), 'signups' => Business::whereBetween('created_at', [$start->utc(), $end->utc()])->count(),
                'revenue' => (int) Subscription::whereNull('cancelled_at')->whereBetween('created_at', [$start->utc(), $end->utc()])->sum('amount'),
                'paid' => Subscription::whereNull('cancelled_at')->whereBetween('created_at', [$start->utc(), $end->utc()])->distinct('business_id')->count('business_id')];
        }
        $packages = [];
        foreach (Business::with('subscriptions', 'grants')->get() as $b) {
            $a = $b->currentAccess(); $key = $a['read_only'] ? 'Berakhir' : ($a['source'] === 'trial' ? 'Trial' : (string) $a['package']);
            $packages[$key] = ($packages[$key] ?? 0) + 1;
        }
        arsort($packages);
        $total = max(1, Business::count());
        $converted = Business::whereHas('subscriptions', fn ($s) => $s->whereNull('cancelled_at'))->count();
        return view('admin-reports', ['months' => $months, 'packages' => $packages, 'total' => $total, 'converted' => $converted,
            'active30' => DB::table('sync_records')->where('updated_at', '>=', now()->subDays(30))->distinct('business_id')->count('business_id'),
            'prospects' => DB::table('prospects')->selectRaw('status, count(*) as n')->groupBy('status')->pluck('n', 'status')->all()]);
    }

    // ---------- akun administrator per divisi ----------

    public function admins() {
        return view('admin-admins', ['admins' => User::where('is_platform_admin', true)->orderBy('name')->get(), 'divisions' => config('goyana.admin_divisions')]);
    }

    public function storeAdmin(Request $request) {
        $request->merge(['email' => mb_strtolower(trim((string) $request->input('email')))]);
        $data = $request->validate(['name' => 'required|string|max:120', 'email' => 'required|email|max:254|unique:users,email',
            'password' => ['required', Password::min(12)->letters()->numbers()], 'division' => ['required', Rule::in(array_keys(config('goyana.admin_divisions')))]]);
        $user = new User(['name' => $data['name'], 'email' => $data['email'], 'password' => $data['password']]);
        $user->is_platform_admin = true; $user->admin_division = $data['division']; $user->email_verified_at = now(); $user->save();
        $this->log($request, 'admin.created', ['user_id' => $user->id, 'division' => $data['division']]);
        return back()->with('status', 'Akun '.$user->name.' dibuat. Ia memasang OTP sendiri saat pertama masuk.');
    }

    public function updateAdmin(Request $request, User $admin) {
        abort_unless($admin->is_platform_admin, 404);
        $data = $request->validate(['division' => ['required', Rule::in(array_keys(config('goyana.admin_divisions')))]]);
        if ($admin->adminDivision() === 'owner' && $data['division'] !== 'owner' && $this->owners() <= 1) {
            return back()->withErrors(['division' => 'Harus ada paling sedikit satu akun Pemilik yang aktif.']);
        }
        $admin->admin_division = $data['division']; $admin->save();
        $this->log($request, 'admin.division', ['user_id' => $admin->id, 'division' => $data['division']]);
        return back()->with('status', 'Divisi '.$admin->name.' diperbarui.');
    }

    public function toggleAdmin(Request $request, User $admin) {
        abort_unless($admin->is_platform_admin, 404);
        if ($admin->id === $request->user()->id) return back()->withErrors(['admin' => 'Akun sendiri tidak bisa dinonaktifkan dari sini.']);
        if (!$admin->deactivated_at && $admin->adminDivision() === 'owner' && $this->owners() <= 1) {
            return back()->withErrors(['admin' => 'Harus ada paling sedikit satu akun Pemilik yang aktif.']);
        }
        $admin->deactivated_at = $admin->deactivated_at ? null : now(); $admin->save();
        $this->log($request, $admin->deactivated_at ? 'admin.deactivated' : 'admin.activated', ['user_id' => $admin->id]);
        return back()->with('status', $admin->name.($admin->deactivated_at ? ' dinonaktifkan.' : ' diaktifkan lagi.'));
    }

    private function owners(): int {
        return User::where('is_platform_admin', true)->whereNull('deactivated_at')->get()->filter(fn (User $u) => $u->adminDivision() === 'owner')->count();
    }

    private function log(Request $request, string $action, array $details): void {
        DB::table('platform_audit')->insert(['actor_id' => $request->user()->id, 'action' => $action, 'details' => json_encode($details), 'created_at' => now()]);
    }
}
