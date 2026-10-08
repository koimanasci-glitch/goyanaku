<?php
namespace App\Http\Controllers;

use App\Support\Outlets;
use Illuminate\Http\Request;

/** Owner menambah cabang dari dashboard web sesuai batas paket (1 pusat + cabang paket). */
class OutletController {
    public function store(Request $request) {
        $owner = $request->user();
        Outlets::create($owner, $request->validate(Outlets::rules($owner)));
        return back()->with('status', 'Cabang ditambahkan.');
    }
}
