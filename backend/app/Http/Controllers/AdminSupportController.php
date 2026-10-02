<?php
namespace App\Http\Controllers;
use App\Models\Ticket;
use App\Support\Settings;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
class AdminSupportController {
    public function index(Request $request) {
        $status = $request->query('status', 'active');
        $q = Ticket::with(['business', 'user']);
        if ($status === 'active') $q->where('status', '!=', 'closed');
        elseif (array_key_exists($status, Ticket::STATUSES)) $q->where('status', $status);
        $counts = Ticket::selectRaw('status, count(*) as n')->groupBy('status')->pluck('n', 'status');
        return view('admin-tickets', ['tickets' => $q->orderByRaw("priority = 'high' desc")->orderByRaw("status = 'open' desc")->latest('last_activity_at')->paginate(30)->withQueryString(),
            'status' => $status, 'counts' => $counts]);
    }
    public function show(Ticket $ticket) {
        return view('admin-ticket', ['ticket' => $ticket->load('business', 'user'), 'messages' => $ticket->messages()->with('author')->get()]);
    }
    public function reply(Request $request, Ticket $ticket) {
        $data = $request->validate(['body' => 'required|string|max:5000', 'internal' => 'nullable|boolean', 'close' => 'nullable|boolean']);
        DB::transaction(function () use ($request, $ticket, $data) {
            $internal = (bool) ($data['internal'] ?? false);
            $ticket->messages()->create(['body' => $data['body'], 'author_type' => 'admin', 'internal' => $internal])->forceFill(['author_id' => $request->user()->id])->save();
            if (!$internal) $ticket->status = ($data['close'] ?? false) ? 'closed' : 'answered';
            $ticket->closed_at = $ticket->status === 'closed' ? now() : null;
            $ticket->last_activity_at = now(); $ticket->save();
        });
        return back()->with('status', ($data['internal'] ?? false) ? 'Catatan internal disimpan.' : 'Balasan terkirim ke klien.');
    }
    public function update(Request $request, Ticket $ticket) {
        $data = $request->validate(['status' => ['required', Rule::in(array_keys(Ticket::STATUSES))], 'priority' => ['required', Rule::in(['normal', 'high'])]]);
        $ticket->status = $data['status']; $ticket->priority = $data['priority'];
        $ticket->closed_at = $data['status'] === 'closed' ? ($ticket->closed_at ?? now()) : null; $ticket->save();
        return back()->with('status', 'Tiket diperbarui.');
    }

    public function settings() {
        return view('admin-settings', ['s' => Settings::all(), 'history' => DB::table('platform_audit')->leftJoin('users', 'users.id', '=', 'platform_audit.actor_id')
            ->where('action', 'settings.updated')->orderByDesc('platform_audit.id')->limit(10)->get(['platform_audit.*', 'users.name as actor_name'])]);
    }
    public function saveSettings(Request $request) {
        $data = $request->validate([
            'ai_margin_percent' => 'required|integer|min:0|max:300',
            'ai_min_topup' => 'required|integer|min:10000|max:10000000',
            'fx_cushion_percent' => 'required|numeric|min:0|max:20',
            'ai_daily_budget_usd' => 'required|numeric|min:0|max:1000',
            'bot_pause_minutes' => 'required|integer|min:1|max:1440',
            'cs_whatsapp' => ['nullable', 'regex:/^62\d{8,13}$/'],
        ], ['cs_whatsapp.regex' => 'Nomor WA diawali 62, contoh 6281234567890.']);
        foreach (['msg_welcome', 'msg_expiry_reminder', 'msg_expired', 'msg_payment'] as $flag) $data[$flag] = $request->boolean($flag);
        $data['cs_whatsapp'] = (string) ($data['cs_whatsapp'] ?? '');
        $data['fx_cushion_percent'] = (float) $data['fx_cushion_percent']; $data['ai_daily_budget_usd'] = (float) $data['ai_daily_budget_usd'];
        $before = Settings::all();
        Settings::put($data, $request->user()->id);
        $changed = array_keys(array_filter($data, fn ($v, $k) => ($before[$k] ?? null) != $v, ARRAY_FILTER_USE_BOTH));
        if ($changed) DB::table('platform_audit')->insert(['actor_id' => $request->user()->id, 'action' => 'settings.updated',
            'details' => json_encode(array_intersect_key($data, array_flip($changed))), 'created_at' => now()]);
        return back()->with('status', 'Pengaturan disimpan.');
    }
}
