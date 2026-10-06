# GOYANA branding

Approved by Paduka on 6 October 2026 (latest Gas).

- `launcher.png`: supplied 162919.png, unchanged source; mipmap sizes are build resources.
- `storyboard.png`: supplied 162922.png, unchanged three-panel reference. Flutter animates the cloth and water panels and finishes with native text.
- `mark.svg`: clean outline traced from the supplied launcher emblem, because the supplied wordmark and three imagegen extraction attempts contained stray opaque speckles in negative space. No wordmark text is embedded.
- `mark.png`: transparent 512px rendering of the editable SVG; header text is Flutter Text.

First-open marker: `__goyana_brand_intro_seen_v1`, separate from onboarding and the old app reset prefix. Full introduction: 3000ms. Later opens: 350ms alongside web initialization. No extra legacy 950ms wait.

Historical screenshot tests retain their original baselines. Only the approved logo/text rectangle (x9..224, y40..87 in the 31px-inset header) is excluded when comparing historical coral headers. Scan controls, layout, body and other pixels remain locked. New symbol, native lettering, scan action and launch-marker timing have separate widget tests.
