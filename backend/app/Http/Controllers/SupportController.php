<?php
namespace App\Http\Controllers;
use App\Models\Ticket;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
/** Laundry side of CS tickets: owners see every ticket of their business, staff only their own. */
class SupportController {
    private function scope(Request $request) {
        $user = $request->user();
        abort_unless($user->business_id, 403);
        $q = Ticket::where('business_id', $user->business_id);
        return $user->isOwner() ? $q : $q->where('user_id', $user->id);
    }
    public function index(Request $request) {
        return view('support', ['tickets' => $this->scope($request)->latest('last_activity_at')->paginate(20), 'categories' => Ticket::CATEGORIES,
            'cs' => \App\Support\Settings::get('cs_whatsapp')]);
    }
    public function store(Request $request) {
        abort_unless($request->user()->business_id, 403);
        $data = $request->validate(['subject' => 'required|string|max:160', 'category' => ['required', Rule::in(array_keys(Ticket::CATEGORIES))], 'body' => 'required|string|max:5000']);
        $open = Ticket::where('user_id', $request->user()->id)->where('status', '!=', 'closed')->count();
        if ($open >= 5) return back()->withErrors(['subject' => 'Masih ada 5 tiket yang belum selesai. Tunggu balasan CS dulu.'])->withInput();
        $ticket = DB::transaction(function () use ($request, $data) {
            $t = new Ticket(['subject' => $data['subject'], 'category' => $data['category'], 'source' => 'web']);
            $t->business_id = $request->user()->business_id; $t->user_id = $request->user()->id; $t->last_activity_at = now(); $t->save();
            $t->messages()->create(['body' => $data['body'], 'author_type' => 'customer'])->forceFill(['author_id' => $request->user()->id])->save();
            // Program first: answer from the FAQ (no AI cost). The customer can reply to reach CS.
            if ($faq = \App\Support\FaqMatcher::match($data['subject'].' '.$data['body'])) {
                $answer = $faq->answer;
                if (str_contains($faq->keywords, 'paket')) {
                    $a = $request->user()->business->currentAccess();
                    $answer .= "\n\nStatus akun Anda: ".($a['read_only'] ? 'baca saja sejak ' : ($a['package'] ?? '').' aktif sampai ')
                        .($a['ends_at'] ? \Carbon\Carbon::parse($a['ends_at'])->timezone('Asia/Jakarta')->format('d M Y') : '-').'.';
                }
                $t->messages()->create(['body' => "Jawaban otomatis — {$faq->question}:\n\n$answer\n\nBelum selesai? Balas tiket ini, CS akan membantu.", 'author_type' => 'system']);
                DB::table('faqs')->where('id', $faq->id)->increment('hits');
                $t->status = 'answered'; $t->save();
            }
            return $t;
        });
        return redirect()->route('support.show', $ticket)->with('status', 'Tiket terkirim. CS akan membalas di sini.');
    }
    public function show(Request $request, Ticket $ticket) {
        abort_unless($this->scope($request)->whereKey($ticket->id)->exists(), 404);
        return view('support-show', ['ticket' => $ticket, 'messages' => $ticket->messages()->where('internal', false)->with('author')->get()]);
    }
    public function reply(Request $request, Ticket $ticket) {
        abort_unless($this->scope($request)->whereKey($ticket->id)->exists(), 404);
        $data = $request->validate(['body' => 'required|string|max:5000']);
        DB::transaction(function () use ($request, $ticket, $data) {
            $ticket->messages()->create(['body' => $data['body'], 'author_type' => 'customer'])->forceFill(['author_id' => $request->user()->id])->save();
            // A customer reply reopens a closed ticket so CS sees it again.
            $ticket->status = 'open'; $ticket->closed_at = null; $ticket->last_activity_at = now(); $ticket->save();
        });
        return back()->with('status', 'Balasan terkirim.');
    }
}
