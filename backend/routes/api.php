<?php
use App\Http\Controllers\ApiSessionController;
use Illuminate\Support\Facades\Route;
Route::post('/session', [ApiSessionController::class, 'login'])->middleware('throttle:login');
Route::middleware(['auth:sanctum', 'active', 'throttle:api'])->group(function () {
    Route::get('/me', [ApiSessionController::class, 'me']);
    Route::delete('/session', [ApiSessionController::class, 'logout']);
});
