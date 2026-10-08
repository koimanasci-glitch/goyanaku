<?php
namespace Tests\WhatsApp;
use App\Models\{Business,User};
use App\WhatsApp\{Devices,Inbound,Phone,Replies,Template,UnavailableGateway,WhatsAppServiceProvider};
use App\WhatsApp\Contracts\ChatkuGateway;
use App\WhatsApp\Jobs\SendReply;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\{DB,Queue};
use Illuminate\Support\Str;
use Tests\TestCase;

class ModuleTest extends TestCase {
    use RefreshDatabase;
    protected function setUp(): void {
        parent::setUp();
        config(['whatsapp.enabled'=>true,'whatsapp.connection_packages'=>['Silver','Gold','Platinum'],'whatsapp.status_packages'=>['Gold'],'whatsapp.services_packages'=>['Gold']]);
        $this->app->register(WhatsAppServiceProvider::class);
        // Base migrations have already run through RefreshDatabase; explicit module activation only in tests.
        $migration=require app_path('WhatsApp/database/2026_10_08_100000_whatsapp_module.php');
        if(!\Illuminate\Support\Facades\Schema::hasTable('wa_devices'))$migration->up();
        $this->app->instance(ChatkuGateway::class,new FakeChatku);
        Queue::fake();
    }
    private function owner(): User {
        $b=Business::create(['name'=>'Laundry','trial_ends_at'=>now()->addMonth()]);
        $b->outlets()->create(['name'=>'Pusat']);
        $b->subscriptions()->create(['package'=>'Gold','starts_at'=>now()->subDay(),'ends_at'=>now()->addMonth(),'source'=>'manual','reference'=>(string)Str::uuid()]);
        $u=new User(['name'=>'Owner','email'=>Str::uuid().'@example.test','password'=>'Password123456']);$u->business_id=$b->id;$u->save();return $u;
    }
    private function device(User $u,string $phone='081234567890'): object {
        return app(Devices::class)->save($u,['id'=>(string)Str::uuid(),'name'=>'Pusat','phone'=>$phone,'outlet_id'=>$u->business->outlets()->first()->id],true);
    }
    public function test_phone_and_template_validation(): void {
        $this->assertSame('6281234567890',Phone::normalize('+62 812-3456-7890'));
        $this->assertSame('Status {{secret}}',Template::render('Status {{status}}',['status'=>'{{secret}}']));
        $this->expectException(\InvalidArgumentException::class);Template::validateFor('status','{{daftar_layanan}}');
    }
    public function test_one_slot_idempotent_create_and_no_free_slot_from_extra_outlet(): void {
        $u=$this->owner();$d=$this->device($u);$u->business->outlets()->create(['name'=>'Cabang']);
        $same=app(Devices::class)->save($u,['id'=>$d->id,'name'=>$d->name,'phone'=>$d->phone,'outlet_id'=>$d->outlet_id],true);
        $this->assertSame($d->id,$same->id);
        $this->actingAs($u)->postJson('/api/whatsapp/devices',['id'=>(string)Str::uuid(),'name'=>'Dua','phone'=>'081299999999','outlet_id'=>$d->outlet_id])->assertStatus(409);
        $this->assertSame(1,DB::table('wa_devices')->count());
    }
    public function test_foreign_business_and_staff_cannot_manage_devices(): void {
        $a=$this->owner();$b=$this->owner();$d=$this->device($a);
        $this->actingAs($b)->deleteJson('/api/whatsapp/devices/'.$d->id)->assertNotFound();
        $this->actingAs($b)->postJson('/api/whatsapp/devices',['id'=>(string)Str::uuid(),'name'=>'Bad','phone'=>'081299999999','outlet_id'=>$d->outlet_id])->assertNotFound();
        $b->role='kurir';$b->save();$this->actingAs($b)->getJson('/api/whatsapp/devices')->assertForbidden();
    }
    public function test_status_lookup_is_exact_business_outlet_phone_and_order_code(): void {
        $a=$this->owner();$b=$this->owner();$d=$this->device($a);
        $other=$a->business->outlets()->create(['name'=>'Other']);
        foreach([
            ['GY-261008-0001',$a->business_id,$d->outlet_id,'6281234567890','setrika'],
            ['GY-261008-0002',$b->business_id,$b->business->outlets()->first()->id,'6281234567890','siap'],
            ['GY-261008-0003',$a->business_id,$other->id,'6281234567890','siap'],
            ['GY-261008-0004',$a->business_id,$d->outlet_id,'62812345678901','siap'],
        ]as[$key,$business,$outlet,$phone,$status])DB::table('order_index')->insert(['business_id'=>$business,'outlet_id'=>$outlet,'record_key'=>$key,'customer'=>'Nama Sama','customer_key'=>'phone:'.$phone,'status'=>$status,'ordered_at'=>now(),'created_at'=>now(),'updated_at'=>now()]);
        $reply=app(Replies::class)->status($d,'081234567890','status');
        $this->assertStringContainsString('0001',$reply);$this->assertStringContainsString('disetrika',$reply);
        foreach(['0002','0003','0004']as$forbidden)$this->assertStringNotContainsString($forbidden,$reply);
        $this->assertStringNotContainsString('0002',app(Replies::class)->status($d,'081234567890','GY-261008-0002'));
        $this->assertStringContainsString('belum ditemukan',app(Replies::class)->status($d,'081234567891','GY-261008-0001'));
    }
    public function test_status_lookup_accepts_new_note_numbers_with_branch_and_phone_codes(): void {
        $a=$this->owner();$d=$this->device($a);
        foreach([['BKS-261008-1-0133','cuci'],['BKS-261008-K7-0002','selesaiproses']]as[$key,$status])DB::table('order_index')->insert(['business_id'=>$a->business_id,'outlet_id'=>$d->outlet_id,'record_key'=>$key,'customer'=>'Siti','customer_key'=>'phone:6281234567890','status'=>$status,'ordered_at'=>now(),'created_at'=>now(),'updated_at'=>now()]);
        $this->assertStringContainsString('Balas dengan kode pesanan',app(Replies::class)->status($d,'081234567890','status cucian saya'));
        $reply=app(Replies::class)->status($d,'081234567890','bks-261008-1-0133 sudah selesai?');
        $this->assertStringContainsString('BKS-261008-1-0133',$reply);$this->assertStringContainsString('dicuci',$reply);
        $this->assertStringContainsString('menunggu konfirmasi kasir',app(Replies::class)->status($d,'081234567890','BKS-261008-K7-0002'));
        // Kode nota saja (tanpa kata "status") tetap dikenali sebagai pertanyaan status.
        DB::table('wa_devices')->where('id',$d->id)->update(['remote_id'=>'remote','status'=>'connected','reply_status'=>true]);
        app(Inbound::class)->receive(['id'=>'kode-1','device'=>'remote','from'=>'6281234567890','text'=>'BKS-261008-1-0133','occurred_at'=>now()->toIso8601String(),'from_me'=>false,'group'=>false]);
        $this->assertSame(1,DB::table('wa_outbox')->count());
    }
    public function test_status_requires_package_and_toggle_and_deduplicates_event(): void {
        $u=$this->owner();$d=$this->device($u);DB::table('wa_devices')->where('id',$d->id)->update(['remote_id'=>'remote','status'=>'connected','reply_status'=>true]);
        $event=['id'=>'event-1','device'=>'remote','from'=>'6281234567890','text'=>'status','occurred_at'=>now()->toIso8601String(),'from_me'=>false,'group'=>false];
        app(Inbound::class)->receive($event);app(Inbound::class)->receive($event);
        $this->assertSame(1,DB::table('wa_outbox')->count());Queue::assertPushed(SendReply::class,1);
        config(['whatsapp.status_packages'=>[]]);$event['id']='event-2';app(Inbound::class)->receive($event);
        $this->assertSame(1,DB::table('wa_outbox')->count());
    }
    public function test_bad_webhook_never_reaches_order_lookup(): void {
        $this->postJson('/api/whatsapp/chatku/events',['from'=>'6281234567890'])->assertUnauthorized();
        $this->assertSame(0,DB::table('wa_events')->count());
    }
    public function test_unconfigured_gateway_never_returns_fake_pairing(): void {
        $this->app->instance(ChatkuGateway::class,new UnavailableGateway);
        $u=$this->owner();$d=$this->device($u);
        $this->actingAs($u)->postJson('/api/whatsapp/devices/'.$d->id.'/pairing',['method'=>'qr'])->assertStatus(503);
        $this->assertDatabaseHas('wa_devices',['id'=>$d->id,'status'=>'disconnected']);
    }
    public function test_settings_changed_after_queue_cancel_send(): void {
        $u=$this->owner();$d=$this->device($u);DB::table('wa_devices')->where('id',$d->id)->update(['remote_id'=>'remote','status'=>'connected','reply_status'=>true]);
        app(Inbound::class)->receive(['id'=>'x','device'=>'remote','from'=>'6281234567890','text'=>'status','occurred_at'=>now()->toIso8601String(),'from_me'=>false,'group'=>false]);
        app(Devices::class)->automation($u,$d->id,false,false);
        $id=DB::table('wa_outbox')->value('id');(new SendReply($id))->handle(app(Devices::class),app(ChatkuGateway::class));
        $this->assertDatabaseHas('wa_outbox',['id'=>$id,'state'=>'cancelled','body'=>'','recipient'=>'']);
    }
    public function test_ai_drafts_not_used_as_live_template(): void {
        DB::table('wa_templates')->insert(['key'=>'proposal-test','purpose'=>'not_found','name'=>'AI','body'=>'NEVER PUBLISH','active'=>false,'ai_draft'=>true,'created_at'=>now(),'updated_at'=>now()]);
        $this->assertStringNotContainsString('NEVER PUBLISH',app(Replies::class)->render('not_found'));
    }
}
final class FakeChatku implements ChatkuGateway {
    public function provision(string $key,string $phone,string $label): string{return 'fake-'.$key;}
    public function pairing(string $remoteId,string $method): array{return ['kind'=>$method,'value'=>'TEST ONLY','expires_at'=>now()->addMinute()->toIso8601String()];}
    public function status(string $remoteId): array{return ['status'=>'connected','phone'=>'6281234567890'];}
    public function disconnect(string $remoteId): void{}
    public function send(string $remoteId,string $phone,string $text,string $key): string{return 'test-receipt-'.$key;}
    public function verifyInbound(\Illuminate\Http\Request $r): array{abort(401);}
}
