<?php
namespace App\WhatsApp;
use App\WhatsApp\Contracts\ChatkuGateway;
use App\WhatsApp\Http\{DeviceController,WebhookController,TemplateController};
use Illuminate\Support\Facades\Route;
use Illuminate\Support\ServiceProvider;

/** Explicit opt-in only: do not register until Paduka approves installation. */
final class WhatsAppServiceProvider extends ServiceProvider {
    public function register(): void {
        $this->mergeConfigFrom(__DIR__.'/config.php','whatsapp');
        if(!$this->app->bound(ChatkuGateway::class)) $this->app->bind(ChatkuGateway::class,UnavailableGateway::class);
    }
    public function boot(): void {
        $this->loadMigrationsFrom(__DIR__.'/database');
        $this->loadViewsFrom(__DIR__.'/views','whatsapp');
        $this->commands([RetryOutbox::class]);
        if(!config('whatsapp.enabled'))return;
        Route::middleware(['api','auth:sanctum','active','throttle:30,1'])->prefix('api/whatsapp')->group(function(){
            Route::get('devices',[DeviceController::class,'index']);
            Route::post('devices',[DeviceController::class,'store']);
            Route::put('devices/{id}',[DeviceController::class,'update'])->whereUuid('id');
            Route::delete('devices/{id}',[DeviceController::class,'destroy'])->whereUuid('id');
            Route::post('devices/{id}/pairing',[DeviceController::class,'connect'])->whereUuid('id');
            Route::post('devices/{id}/refresh',[DeviceController::class,'refresh'])->whereUuid('id');
            Route::put('devices/{id}/automation',[DeviceController::class,'automation'])->whereUuid('id');
        });
        Route::middleware(['api','throttle:120,1'])->post('api/whatsapp/chatku/events',WebhookController::class);
        Route::middleware(['web','auth','active','platform.admin'])->prefix('admin/whatsapp')->group(function(){
            Route::get('templates',[TemplateController::class,'index']);
            Route::post('templates',[TemplateController::class,'save']);
            Route::post('templates/preview',[TemplateController::class,'preview']);
            Route::get('templates/{id}/revisions',[TemplateController::class,'revisions'])->whereNumber('id');
            Route::post('templates/propose',[TemplateController::class,'propose'])->middleware('throttle:2,60');
        });
    }
}
