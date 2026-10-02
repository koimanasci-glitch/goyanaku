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
            'roles' => collect(config('goyana.roles'))->except('owner')]);
    }
}
