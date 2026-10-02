<?php
namespace App\Http\Controllers;
use Illuminate\Http\Request;
class DashboardController {
    public function __invoke(Request $request) {
        if ($request->user()->is_platform_admin) return redirect()->route('admin.index');
        $business = $request->user()->business;
        abort_unless($business, 403);
        return view('dashboard', ['business' => $business, 'access' => $business->currentAccess(), 'outlets' => $business->outlets()->with('devices')->get()]);
    }
}
