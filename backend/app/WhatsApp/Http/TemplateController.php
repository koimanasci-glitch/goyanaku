<?php
namespace App\WhatsApp\Http;
use App\WhatsApp\{Template, TemplateSuggestions};
use App\WhatsApp\Contracts\TemplateProposer;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
final class TemplateController {
    private const SAMPLE=['nama_outlet'=>'Laundry Contoh','kode_pesanan'=>'GY-261008-0001','status'=>'Sedang disetrika','estimasi'=>'09/10/2026 16:00 WIB (perkiraan)','daftar_pesanan'=>'• GY-261008-0001','daftar_layanan'=>'Cuci reguler: Rp7.000/kg'];
    public function index(){return view('whatsapp::templates',['templates'=>DB::table('wa_templates')->orderBy('purpose')->paginate(30),'purposes'=>array_keys(Template::DEFAULTS),'variables'=>Template::VARIABLES]);}
    public function save(Request $r){
        $v=$r->validate(['purpose'=>'required|in:'.implode(',',array_keys(Template::DEFAULTS)),'name'=>'required|string|max:100','body'=>'required|string|max:4000','version'=>'required|integer|min:0','active'=>'required|boolean']);
        try{Template::validateFor($v['purpose'],$v['body']); Template::render($v['body'],self::SAMPLE);}catch(\InvalidArgumentException $e){return back()->withErrors(['body'=>$e->getMessage()]);}
        DB::transaction(function()use($r,$v){
            // Global templates serialize on the admin user row. Canonical key unique catches cross-admin insert races.
            DB::table('users')->where('id',$r->user()->id)->lockForUpdate()->first();
            $old=DB::table('wa_templates')->where('key',$v['purpose'])->lockForUpdate()->first();
            abort_unless(($old?->version??0)===(int)$v['version'],409,'Template telah berubah. Muat ulang.');
            $version=($old?->version??0)+1;
            $row=['key'=>$v['purpose'],'purpose'=>$v['purpose'],'name'=>$v['name'],'body'=>$v['body'],'active'=>$v['active'],'ai_draft'=>false,'reviewed_by'=>$r->user()->id,'version'=>$version,'updated_at'=>now()];
            if($old){$id=$old->id;DB::table('wa_templates')->where('id',$id)->update($row);}
            else $id=DB::table('wa_templates')->insertGetId($row+['created_at'=>now()]);
            DB::table('wa_template_revisions')->insert(['template_id'=>$id,'version'=>$version,'actor_id'=>$r->user()->id,'body'=>$v['body'],'active'=>$v['active'],'created_at'=>now(),'updated_at'=>now()]);
        });
        return back()->with('status','Template disimpan.');
    }
    public function preview(Request $r){
        $v=$r->validate(['body'=>'required|string|max:4000']);
        try{return response()->json(['preview'=>Template::render($v['body'],self::SAMPLE)]);}
        catch(\InvalidArgumentException $e){return response()->json(['message'=>$e->getMessage()],422);}
    }
    public function revisions(int $id){return response()->json(DB::table('wa_template_revisions')->where('template_id',$id)->orderByDesc('version')->paginate(30));}
    public function propose(Request $r,TemplateSuggestions $suggestions){
        abort_unless(app()->bound(TemplateProposer::class),503,'Penyedia AI belum tersedia.');
        $suggestions->propose($r->user(),app(TemplateProposer::class));return back()->with('status','Usulan AI disimpan sebagai draf, belum aktif.');
    }
}
