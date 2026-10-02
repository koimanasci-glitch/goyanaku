<?php
// Test fixture for tests/sync-e2e.cjs: php tests/fixtures/create_owner.php owner@x.test [kasir@x.test]
require __DIR__.'/../../vendor/autoload.php';
$app = require __DIR__.'/../../bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
$business = App\Models\Business::create(['name' => 'Laundry Uji Sync', 'trial_ends_at' => now()->addMonth()]);
$outlet = $business->outlets()->create(['name' => 'Pusat Uji']);
$owner = new App\Models\User(['name' => 'Owner Uji', 'email' => $argv[1], 'password' => 'PasswordAman123']);
$owner->business_id = $business->id; $owner->role = 'owner'; $owner->save();
if (!empty($argv[2])) {
    $kasir = new App\Models\User(['name' => 'Kasir Uji', 'email' => $argv[2], 'password' => 'PasswordAman123']);
    $kasir->business_id = $business->id; $kasir->role = 'kasir'; $kasir->outlet_id = $outlet->id; $kasir->save();
}
echo json_encode(['business' => $business->id, 'outlet' => $outlet->id]);
