<?php
return [
    // HOLD: provider is not registered in bootstrap/providers.php.
    'enabled' => false,
    'connection_packages' => ['Silver', 'Gold', 'Platinum'],
    'base_slots' => 1,
    // Pending Paduka's decision: no package is implicitly granted status replies.
    'status_packages' => [],
    'services_packages' => ['Gold', 'Platinum'],
    'event_max_age_seconds' => 300,
    'template_ai_enabled' => false,
];
