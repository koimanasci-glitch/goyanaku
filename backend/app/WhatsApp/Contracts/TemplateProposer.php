<?php
namespace App\WhatsApp\Contracts;
interface TemplateProposer {
    /** Only allowlisted topic counts; NEVER raw messages or tenant/customer records.
     * Return {topic, body}; body is an untrusted proposal and MUST stay inactive.
     */
    public function propose(array $topicCounts): array;
}
