# GOYANA branding

Approved by Paduka on 6 October 2026 (latest Gas).

- `launcher.png`: supplied 162919.png, unchanged source; mipmap sizes are build resources.
- `mark.svg`: clean outline traced from the supplied launcher emblem, because the supplied wordmark and three imagegen extraction attempts contained stray opaque speckles in negative space. No wordmark text is embedded.
- `mark.png`: transparent 512px rendering of the editable SVG; header text is Flutter Text.

First-open marker: `__goyana_brand_intro_seen_v1`, separate from onboarding and the old app reset prefix. Opening animation: the white dove (`dove.png`, cut from the supplied artwork) perched on the G looks left, then right, while name and tagline fade in: 1200ms on the first open, 900ms later, plus a 160ms fade out once the app is ready. The cloth/water storyboard and its asset were removed.

Historical screenshot tests retain their original baselines. Only the approved logo/text rectangle (x9..224, y40..87 in the 31px-inset header) is excluded when comparing historical coral headers. Scan controls, layout, body and other pixels remain locked. New symbol, native lettering, scan action and launch-marker timing have separate widget tests.
