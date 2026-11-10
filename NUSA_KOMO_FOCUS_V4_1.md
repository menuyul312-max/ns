# Komo — Single-Character Rig, Face, and Collision Study (v4.1)

> Status: **working character prototype, not production-final character art**.
> Single-character scope: Komo only. Every input/model is a user-owned Nusa
> Trellis GLB or an original procedural Nusa asset; Nintendo character assets,
> motion clips and textures are **not** embedded or redistributed.

## Verified facts versus design interpretations

The ACNH RE reference repository contains BFRES/FMDL/FSKL loaders and animation
format discoveries, including FSKA (skeleton), FMAA (material), FVIS
(visibility). These establish *format capabilities*, not that the specific ACNH
character face pipeline uses the same precise layers, masks, parameters or
topology as this Nusa implementation. **We have not proven the exact ACNH facial
system.** The Komo implementation is *ACNH-inspired*, with original assets.

## One-character baseline

Original source: `elder_komo_s3.glb` (uploaded by the project owner, kept private).

| Measurement | Original Trellis source | Komo v4.1 retopo candidate |
|---|---:|---:|
| Mesh vertices | 17,111 | 12,146 |
| Faces | 17,539 | 12,178, mostly quads |
| Disconnected pieces | 1,979 | 1 |
| Open/boundary edges | 12,791 | 3 remaining |
| Head facial pixels | Painted directly in damaged albedo | Separate left eye, right eye, mouth atlases |
| Rig | None | 24 skeletal bones |
| Animation | None | 16 original rig-prototype clips |
| Runtime collisions | None | Independent Komo capsule + interaction sphere |

The first intermediate voxel remesh was **watertight** (72,586 vertices,
72,640 quads, one component). QuadriFlow reduced density, but left **three
boundary edges**; the final retopo candidate must not be advertised as
perfectly watertight. The original surface also has defects around the jaw,
right shoulder and a foot. A curved face shell masks much of the facial damage,
but **some defects remain visible in close-up and under animation**.

## How the facial architecture works

`scripts/nusa_komo_face.gd` constructs four visible layers:

1. Soft curved **base face shell** to mask original gouges / baked artifacts.
2. **Left eye**: independently addressed 9-cell texture atlas.
3. **Right eye**: independently addressed 9-cell texture atlas.
4. **Mouth**: independently addressed 6-cell texture atlas.

All layers follow a `BoneAttachment3D` bound to the `Head` bone, with an
inverse rest-space offset. The rest of the body remains a skinned mesh.
Expressions are not achieved by cutting new geometry for each pose.

Available presets: `neutral`, `blink`, `blink_left`, `blink_right`, `happy`,
`sad`, `angry`, `surprised`, `look_left`, `look_right`, `talk_a`, `talk_o`.

Use `actor.set_expression("happy")`, or set individual eye/mouth states on
`actor.komo_face`. The player uses independent state maps, so one eye can blink
without changing the other. These simple procedural graphics are placeholders
for art-directed final atlases, not copied ACNH textures.

`NusaOriginalActor.play_clip()` also maps each Komo clip to an appropriate
starting expression. A lightweight timer provides natural short blinks during
neutral/happy/sad states, and the talk/interact clips alternate two original
mouth phoneme shapes. This is **not** audio-driven lip sync yet.

## Runtime setup

With the private generated refined GLB present:

```gdscript
var actor := NusaOriginalActor.new()
actor.species = "komo"
actor.visual_resource_override = \
	"res://generated/komo_v41_rigged/elder_komo_clean_paint_rigged.glb"
add_child(actor)
actor.play_clip("walk")
actor.set_expression("happy")
```

The existing prototype GLBs for all five Nusa characters keep their previous
default paths; **only Komo** is opted into this experimental refined variant.

Komo collision is defined in `data/characters/collisions/komo.json`: capsule
radius 0.25 and height 1.00 in project units, plus an independently configured
interaction sphere. Physics is not derived directly from the deforming mesh.

## Reproduce locally (the uploaded source stays private)

From the Nusa Godot project root:

```bash
blender -b --factory-startup --python tools/audit_nusa_komo_geometry.py -- \
  --model ../upload/elder_komo_s3.glb --output generated/komo_geometry_baseline.json

blender -b --factory-startup --python tools/repair_nusa_komo_mesh.py -- \
  --model ../upload/elder_komo_s3.glb \
  --output-dir generated/komo_retopo --voxel 0.008

blender -b --factory-startup --python tools/optimize_nusa_komo_mesh.py -- \
  --blend generated/komo_retopo/komo_repair_study.blend \
  --out-dir generated/komo_quadflow --faces 12000

blender -b --factory-startup --python tools/stylize_nusa_komo_surface.py -- \
  --blend generated/komo_quadflow/komo_game_candidate.blend \
  --out-dir generated/komo_clean_v41

blender -b --factory-startup --python tools/rig_nusa_original_glbs.py -- \
  --input-dir generated/komo_clean_v41 \
  --output-dir generated/komo_v41_rigged --only elder_komo_clean_paint

godot --headless --path . --script res://tools/export_nusa_komo_face_atlases.gd
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/test_nusa_komo_v4.gd
```

Move intermediate `.blend` files outside `res://` before importing in Godot if
the headless editor warns about an unconfigured Blender executable. They are
working artifacts, not runtime assets. Generated GLBs, atlas PNGs, renders and
private checkpoint files are covered by `/generated/` in `.gitignore`.

Render and encode review reels:

```bash
blender -b --factory-startup --python tools/render_nusa_komo_polish_reel.py -- \
  --model generated/komo_v41_rigged/elder_komo_clean_paint_rigged.glb \
  --atlas generated/komo_atlases \
  --out-dir generated/komo_v41_expressions_frames \
  --mode expressions --size 600 --samples 16

blender -b --factory-startup --python tools/render_nusa_komo_polish_reel.py -- \
  --model generated/komo_v41_rigged/elder_komo_clean_paint_rigged.glb \
  --atlas generated/komo_atlases \
  --out-dir generated/komo_v41_motion_frames \
  --mode motions --size 520 --samples 12 --frames-per-clip 10

python tools/encode_nusa_komo_review.py --mode expressions \
  --input generated/komo_v41_expressions_frames \
  --out generated/komo_v41_review

python tools/encode_nusa_komo_review.py --mode motions \
  --input generated/komo_v41_motion_frames \
  --out generated/komo_v41_review
```

## Automated verification and real quality gates

`tests/test_nusa_komo_v4.gd` passed in Godot 4.6.3 after the private refined
GLB was imported: **24 bones, 16 imported clips, 12 facial presets, separate
left/right atlas controls, independent body and reach collision**, plus an
automatic blink cycle and alternating talk phonemes.

These mechanical checks are **not equivalent to visual approval**. Still needed
for a genuinely polished Komo:

- Manual sculpt/retopo at chin corners and head-to-shoulder join; close the 3
  remaining mesh boundary edges.
- Correct skin weights around hip, knees, ankles, heels and shoulders. Replace
  spatial weighting with mesh-aware binding and anatomical joint placement.
- Feet ground-lock / IK through walk, run, sit and shovel. Validate no knee
  collapse, foot penetration or arm-to-body clipping.
- Add expression art pass: masks for curved head, brows, pupils, occlusion and
  phonemes; validate eyes from front and both 3/4 angles.
- QA all 16 clips at normal speed, front/side/back and turning; only then mark
  the character production-ready.

**No claim of perfect motion, exact Nintendo implementation, or final art is
made by this experiment.**
