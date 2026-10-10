<?php
namespace App\Http\Controllers;

use App\Models\User;
use App\Support\Team;
use Illuminate\Http\Request;
use Illuminate\Validation\Rules\Password;

/** Kelola Pegawai dari aplikasi (hanya owner). Aturannya sama dengan dashboard web: App\Support\Team. */
class ApiTeamController {
    public function index(Request $request) {
        $owner = $request->user();
        $query = $owner->business->users()->where('role', '!=', 'owner')->orderBy('name');
        if ($request->filled('outlet_id')) $query->where('outlet_id', (int) $request->query('outlet_id'));
        return response()->json([
            'team' => $query->get()->map(fn (User $u) => Team::present($u))->values(),
            'roles' => collect(config('goyana.roles'))->except('owner')->map(fn ($r, $k) => ['key' => $k, 'label' => $r['label']])->values(),
            // Batas akun per outlet untuk tiap tugas (paket); aplikasi menampilkan "Kasir 1/2".
            'limits' => collect(Team::roles())->mapWithKeys(fn ($k) => [$k => Team::seatLimit($owner->business, $k)]),
            'package' => $owner->business->currentAccess()['package'],
        ]);
    }

    public function store(Request $request) {
        $owner = $request->user();
        if ($request->filled('email')) $request->merge(['email' => mb_strtolower(trim((string) $request->input('email')))]);
        $user = Team::create($owner, $request->validate(Team::rules($owner)));
        return response()->json(['member' => Team::present($user->fresh())], 201);
    }

    public function update(Request $request, User $member) {
        $owner = $request->user(); Team::guard($owner, $member);
        if ($request->filled('email')) $request->merge(['email' => mb_strtolower(trim((string) $request->input('email')))]);
        $data = $request->validate(collect(Team::rules($owner, $member))->except(['pin', 'password'])->all());
        foreach (['phone', 'email'] as $k) if (!$request->has($k)) unset($data[$k]);
        return response()->json(['member' => Team::present(Team::update($owner, $member, $data)->fresh())]);
    }

    public function pin(Request $request, User $member) {
        $owner = $request->user(); Team::guard($owner, $member);
        $data = $request->validate(['pin' => ['required', 'string', 'regex:/^\d{'.(int) config('goyana.pin.length').'}$/']]);
        Team::setPin($owner, $member, $data['pin']);
        return response()->noContent();
    }

    public function password(Request $request, User $member) {
        $owner = $request->user(); Team::guard($owner, $member);
        $data = $request->validate(['password' => ['required', Password::min(12)->letters()->numbers()]]);
        Team::setPassword($owner, $member, $data['password']);
        return response()->noContent();
    }

    public function deactivate(Request $request, User $member) {
        Team::deactivate($request->user(), $member);
        return response()->json(['member' => Team::present($member->fresh())]);
    }

    public function activate(Request $request, User $member) {
        Team::activate($request->user(), $member);
        return response()->json(['member' => Team::present($member->fresh())]);
    }
}
