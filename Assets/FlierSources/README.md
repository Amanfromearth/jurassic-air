# Additional flier artwork

Created with the built-in imagegen tool from the existing `head-dino.png` and
`plane-red-base.png` references. Source PNGs are preserved here; app-ready PNGs
and thumbnails live in `Sources/JurassicAir/Resources`.

Generation specifications:

- **Porco Rosso:** right-facing pig aviator, salmon-pink snout, dark aviator
  sunglasses, brown leather flying cap, cream scarf and brown jacket. Match the
  reference's chunky 64×64 pixel style, dark plum outline and limited palette.
  Isolated head and shoulders on transparent square canvas, matching the
  reference pilot's placement, with no plane, text, background or shadow.
- **Soldier (new character):** start from scratch using the Dino only as a
  coarse-pixel style reference and the fighter only as a palette reference.
  Friendly right-facing toy soldier with rounded olive steel M1 helmet, simple
  brim, round peach face, tiny eye, button nose and small relaxed smile. Olive
  field jacket, khaki collar, small brass buttons and matching shoulder strap.
  No leather flight cap, goggles or scarf. Head and chest only; compact rounded
  proportions, simple flat color clusters, dark plum outline, transparent canvas.
- **WWII Fighter (angle corrected):** keep the distinct WWII warbird silhouette,
  long nose, slim fuselage, compact tail and belly radiator. Match the red plane's
  shallow side-on camera angle and horizontal flight axis. Near wing projects
  down and left from mid-fuselage; far wing is mostly hidden behind the middle
  instead of fanning up over the nose. Olive upper surface, blue-grey belly,
  cream star and wing stripes, small red spinner. Empty cockpit; no pilot,
  propeller blades, canopy, guns, text or background. Coarse 64×64 pixel style.
  The separate propeller now shares the standard vertical axis and has a small
  horizontal adjustment, applied in both the flight rig and Settings preview.

- **Shark Fighter:** additional Flying Tigers-inspired shark-mouth variant of the
  WWII fighter. Preserve its shallow side view, level flight axis, empty cockpit,
  silhouette and spinner placement. Large red jaw and dark mouth with three or
  four big cream teeth, plus a small shark eye on the nose. Muted tan camouflage
  over olive surfaces and blue-grey underside, cream wing stripes and rear star.
  Match the coarse 64×64 pixel grid and dark plum outlines. Single transparent
  airframe layer, no pilot, propeller blades, weapons, text or background.

Run `swift scripts/prepare-flier-assets.swift` from the repository root to
normalize these sources to the existing 64×64 grid, upscale to the shared
1088×1088 canvas with exact 17×17 blocks, register the heads at the cockpit (the human uses the full reference head area
for a broader, rounder face) and
export tightly cropped thumbnails. Transparent source pixels stay transparent.
The new pilots keep the user's current sound pack when selected.

## Tail-to-nose alignment correction

Both fighter sources were edited with the built-in imagegen tool: lower the
rear tail assembly and rear fuselage by two coarse pixel rows, tapering to zero
at the cockpit, so the tail stabilizer/root shares a horizontal row with the
nose spinner. Preserve the upright fin, forward fuselage, wing perspective,
markings, pixel style and transparent canvas. This corrects the nose-down pitch.
The preparation script registers these airframes two rows lower to keep their
cockpit and spinner aligned with the existing pilot and propeller layers.

## Navy Fighter

Generated with the built-in imagegen tool from the level WWII fighter reference.
Prompt specification: change only paint colors to deep midnight navy upper
surfaces with slate-blue highlight blocks and a cool pale-grey underside. Keep
cream star markings, cream wing stripes and the red spinner. Preserve the level
tail-to-nose axis, cockpit, silhouette, wing angle, coarse pixel grid, dark outline
and transparent full canvas. No shark mouth, pilot, canopy, propeller blades,
weapons, text, background or shadow. Source: `navy-plane.png`; prepared assets:
`plane-navy-base.png` and `thumb-plane-navy.png` in the app's Resources directory.

## Navy Shark

Built-in imagegen edit of the Navy Fighter, using Shark Fighter only as a
nose-art reference. Prompt: add a large curved red jaw with a dark mouth, three
or four big cream teeth and a small shark eye behind the spinner. Preserve dark
navy paint, slate-blue highlights, pale-grey underside, cream markings, red
spinner, silhouette, level tail-to-nose axis, cockpit position, wing angle,
coarse pixel grid and transparent full canvas. No olive/tan paint, pilot,
canopy, propeller blades, weapons, text, shadow or background. Source:
`navy-shark-plane.png`; app assets: `plane-navy-shark-base.png` and
`thumb-plane-navy-shark.png` in Resources.
