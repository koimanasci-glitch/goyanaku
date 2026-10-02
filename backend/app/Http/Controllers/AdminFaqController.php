<?php
namespace App\Http\Controllers;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
class AdminFaqController {
    private function rules(): array {
        return ['question' => 'required|string|max:200', 'keywords' => 'required|string|max:500', 'answer' => 'required|string|max:3000'];
    }
    public function index(Request $request) {
        $test = trim((string) $request->query('test', ''));
        return view('admin-faqs', ['faqs' => DB::table('faqs')->orderByDesc('active')->orderByDesc('hits')->orderBy('id')->get(),
            'test' => $test, 'match' => $test !== '' ? \App\Support\FaqMatcher::match($test) : null]);
    }
    public function store(Request $request) {
        $data = $request->validate($this->rules());
        DB::table('faqs')->insert($data + ['active' => true, 'hits' => 0, 'created_at' => now(), 'updated_at' => now()]);
        return back()->with('status', 'FAQ ditambahkan.');
    }
    public function update(Request $request, int $faq) {
        $data = $request->validate($this->rules());
        abort_unless(DB::table('faqs')->where('id', $faq)->update($data + ['active' => $request->boolean('active'), 'updated_at' => now()]), 404);
        return back()->with('status', 'FAQ disimpan.');
    }
    public function destroy(int $faq) {
        abort_unless(DB::table('faqs')->where('id', $faq)->delete(), 404);
        return back()->with('status', 'FAQ dihapus.');
    }
}
