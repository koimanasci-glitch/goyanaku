<?php
namespace Tests\Feature;

use App\Models\{Business, User};
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class AutomationTest extends TestCase {
    use RefreshDatabase;

    private function sent(): array {
        return array_map(fn ($m) => $m->getOriginalMessage()->getSubject(), app('mailer')->getSymfonyTransport()->messages()->all());
    }

    protected function setUp(): void {
        parent::setUp();
        config(['cache.default' => 'array', 'mail.default' => 'array']);
        $admin = new User(['name' => 'Admin', 'email' => 'admin@goyana.test', 'password' => 'PasswordAman123']);
        $admin->is_platform_admin = true; $admin->save();
    }

    public function test_health_monitor_alerts_once_per_problem_and_when_recovered(): void {
        $this->app['env'] = 'production'; config(['app.debug' => true]);
        $this->artisan('goyana:health')->assertExitCode(1);
        $this->artisan('goyana:health')->assertExitCode(1);
        $this->assertSame(['[GOYANA] Gangguan sistem'], $this->sent(), 'a lasting problem is reported once');
        config(['app.debug' => false]);
        $this->artisan('goyana:health');
        $this->assertSame(['[GOYANA] Gangguan sistem', '[GOYANA] Sistem pulih'], $this->sent());
        $this->assertNotNull(cache('goyana.health.beat'));
    }

    public function test_weekly_report_and_prune(): void {
        $b = Business::create(['name' => 'Laundry Laporan', 'trial_ends_at' => now()->addDays(3)]);
        $this->artisan('goyana:weekly-report --print')->expectsOutputToContain('Usaha baru: 1')->expectsOutputToContain('Trial berakhir 7 hari ke depan: 1')->assertExitCode(0);
        $this->artisan('goyana:weekly-report')->assertExitCode(0);
        $this->assertSame(['[GOYANA] Laporan mingguan'], $this->sent());

        DB::table('sync_ops')->insert([['business_id' => $b->id, 'op_id' => 'old', 'result' => '{}', 'created_at' => now()->subDays(40)],
            ['business_id' => $b->id, 'op_id' => 'new', 'result' => '{}', 'created_at' => now()]]);
        $this->artisan('goyana:prune')->assertExitCode(0);
        $this->assertSame(['new'], DB::table('sync_ops')->pluck('op_id')->all());
    }
}
