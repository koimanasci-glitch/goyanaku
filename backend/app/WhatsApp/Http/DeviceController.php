<?php
namespace App\WhatsApp\Http;
use App\WhatsApp\Devices;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
final class DeviceController {
    public function __construct(private Devices $devices) {}
    private function publicDevice(object $d): array {
        return collect((array)$d)->only(['id','outlet_id','name','phone','status','reply_status','reply_services','version','status_checked_at'])->all();
    }
    public function index(Request $r) {
        $b=$this->devices->owner($r->user());
        return response()->json(['devices'=>DB::table('wa_devices')->where('business_id',$b->id)->get()->map(fn($d)=>$this->publicDevice($d)), 'quota'=>$this->devices->entitlement($b)]);
    }
    public function store(Request $r) {return $this->save($r,true);}
    public function update(Request $r,string $id) {$r->merge(['id'=>$id]);return $this->save($r,false);}
    private function save(Request $r,bool $create) {
        $v=$r->validate(['id'=>'required|uuid','name'=>'required|string|max:80','phone'=>'required|string|max:40','outlet_id'=>'required|integer','version'=>$create?'nullable|integer':'required|integer|min:1']);
        return response()->json($this->publicDevice($this->devices->save($r->user(),$v,$create)),$create?201:200);
    }
    public function connect(Request $r,string $id) {
        $v=$r->validate(['method'=>'required|in:qr,code']);
        return response()->json($this->devices->connect($r->user(),$id,$v['method']))->header('Cache-Control','no-store');
    }
    public function refresh(Request $r,string $id){return response()->json($this->publicDevice($this->devices->refresh($r->user(),$id)));}
    public function destroy(Request $r,string $id){$this->devices->remove($r->user(),$id);return response()->noContent();}
    public function automation(Request $r,string $id){
        $v=$r->validate(['reply_status'=>'required|boolean','reply_services'=>'required|boolean']);
        return response()->json($this->publicDevice($this->devices->automation($r->user(),$id,$v['reply_status'],$v['reply_services'])));
    }
}
