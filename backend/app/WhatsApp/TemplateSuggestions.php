<?php
namespace App\WhatsApp;
use App\Models\User;
use App\WhatsApp\Contracts\TemplateProposer;
use Illuminate\Support\Facades\DB;
final class TemplateSuggestions {
    public function propose(User $admin,TemplateProposer $ai): int {
        abort_unless($admin->isActive() && $admin->is_platform_admin,403);
        abort_unless(config('whatsapp.template_ai_enabled'),503,'Penyedia AI dan anggaran belum dikonfigurasi.');
        $counts=DB::table('wa_unknown_topics')->where('day','>=',now()->subDays(30)->toDateString())->whereIn('topic',TopicStats::TOPICS)->selectRaw('topic, SUM(count) as total')->groupBy('topic')->get()->map(fn($r)=>['topic'=>$r->topic,'count'=>(int)$r->total])->all();
        $proposal=$ai->propose($counts);
        validator($proposal,['topic'=>'required|in:status,choose,not_found,services,unknown_service','body'=>'required|string|max:4000'])->validate();
        Template::validateFor($proposal['topic'],$proposal['body']);
        $key='proposal-'.hash('sha256',$proposal['topic'].':'.$proposal['body']);
        DB::table('wa_templates')->insertOrIgnore(['key'=>$key,'purpose'=>$proposal['topic'],'name'=>'Usulan AI — perlu ditinjau','body'=>$proposal['body'],'active'=>false,'ai_draft'=>true,'created_at'=>now(),'updated_at'=>now()]);
        return DB::table('wa_templates')->where('key',$key)->value('id');
    }
}
