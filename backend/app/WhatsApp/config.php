<?php
return [
    // HOLD: provider is not registered in bootstrap/providers.php.
    'enabled' => false,
    'connection_packages' => ['Silver', 'Gold', 'Platinum'],
    'base_slots' => 1,
    // Keputusan Paduka 8 Oktober 2026: Balas Status WhatsApp mulai dari Silver (Basic tidak).
    'status_packages' => ['Silver', 'Gold', 'Platinum'],
    'services_packages' => ['Gold', 'Platinum'],
    'event_max_age_seconds' => 300,
    'template_ai_enabled' => false,
];
