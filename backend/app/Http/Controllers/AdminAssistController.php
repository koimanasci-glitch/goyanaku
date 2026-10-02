<?php
namespace App\Http\Controllers;
use App\Models\Business;
use App\Support\Assist;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
class AdminAssistController {
    private function records(Business $b, string $collection) {
        return DB::table('sync_records')->where(['business_id' => $b->id, 'collection' => $collection, 'deleted' => false])->orderBy('record_key')->get()
            ->map(fn ($r) => (object) ['key' => $r->record_key, 'data' => json_decode((string) $r->data, true) ?: []]);
    }
    public function show(Business $business) {
        return view('admin-assist', ['business' => $business, 'session' => Assist::active($business),
            'services' => $this->records($business, 'services')->filter(fn ($s) => isset($s->data['prices'])),
            'outlets' => $this->records($business, 'outlet_profiles'),
            'changes' => DB::table('audit_events')->where(['business_id' => $business->id, 'action' => 'assist.changed'])->orderByDesc('id')->limit(15)->get()]);
    }
    public function saveService(Request $request, Business $business) {
        $data = $request->validate(['key' => 'required|string|max:160', 'prices' => 'required|array', 'prices.*' => 'nullable|integer|min:0|max:10000000', 'enabled' => 'array']);
        $rec = $this->records($business, 'services')->firstWhere('key', $data['key']);
        abort_unless($rec && isset($rec->data['prices']), 404);
        $new = $rec->data;
        foreach (array_keys($new['prices']) as $dur) {
            if (array_key_exists($dur, $data['prices'])) $new['prices'][$dur] = (int) $data['prices'][$dur];
            if (isset($new['enabled'])) $new['enabled'][$dur] = isset(($data['enabled'] ?? [])[$dur]);
        }
        if ($new === $rec->data) return back()->with('status', 'Tidak ada perubahan.');
        Assist::write($business, $request->user()->id, 'services', $data['key'], $new, 'Ubah harga '.($new['name'] ?? $data['key']));
        return back()->with('status', 'Harga '.($new['name'] ?? '').' disimpan. HP owner menerima dalam ±20 detik.');
    }
    public function saveOutlet(Request $request, Business $business) {
        $data = $request->validate(['key' => 'required|string|max:160', 'name' => 'required|string|max:120', 'address' => 'nullable|string|max:300', 'phone' => 'nullable|string|max:30']);
        $rec = $this->records($business, 'outlet_profiles')->firstWhere('key', $data['key']);
        abort_unless($rec, 404);
        $new = array_replace($rec->data, ['name' => $data['name'], 'address' => (string) ($data['address'] ?? ''), 'phone' => (string) ($data['phone'] ?? '')]);
        if ($new === $rec->data) return back()->with('status', 'Tidak ada perubahan.');
        Assist::write($business, $request->user()->id, 'outlet_profiles', $data['key'], $new, 'Ubah profil outlet '.$data['name']);
        return back()->with('status', 'Profil outlet disimpan.');
    }
    public function revert(Request $request, Business $business, int $event) {
        $e = DB::table('audit_events')->where(['id' => $event, 'business_id' => $business->id, 'action' => 'assist.changed'])->first();
        abort_unless($e, 404);
        $d = json_decode($e->details, true);
        Assist::write($business, $request->user()->id, $d['collection'], $d['key'], $d['before'], 'Batalkan: '.($d['note'] ?? ''));
        return back()->with('status', 'Perubahan dibatalkan.');
    }
}
