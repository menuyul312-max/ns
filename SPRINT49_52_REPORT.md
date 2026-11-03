# Sprint 49–52 — Outer Coast Mask, Moving Surf, Cache and Godot CI

> Historical note (Sprint 54): The experimental GitHub Actions workflow described below was subsequently **removed at the user's request**. The rest of the Sprint 49–51 implementation remains. CI should not be considered active.

Status: implementation complete in source; CPU tests and comparison diagram executed. **Godot engine execution and screenshots remain pending CI result.**

## Sprint 49: Outer coastline and mask consistency

Discovered a real mismatch: `CoastContour.on_island()` rejected any X/Z outside the raw rectangular grid before considering the warped outer coast. Yet terrain vertices can extend beyond that rectangle under the procedural harmonics. This produced potential unrecognized land where mesh/collision exists, and would rasterize the wrong water/land silhouette into the ocean signed distance texture.

Change: a finite 2.40-world-unit guard, clamped logical grid lookup, and **unclamped** world coordinates compared against all four authored warped boundaries. New `tests/test_s49_outer_warp.gd` probes east/west outward coast and water outside it; a companion Python test covers the harmonic bound (not engine collision).

Remaining caveat: geometry curvature at all displaced corner combinations and actual triangle containment still require Godot runtime screenshots/tests; the analytic coastal inclusion check is an approximation, not exact triangle point-in-mesh.

## Sprint 50: Two moving breaker trains

Previously the main ocean crest positions were sinusoids around a fixed distance band, so the white foam could look like lines vibrating in place. The new `CoastBuilder.OCEAN_SHADER` uses two staggered moving fronts traveling from offshore (~2.38 units) to nearshore (~0.18 units). Both have smooth birth/fade envelopes to avoid temporal popping at the fractional phase wrap. A delayed low-strength backwash and existing spatial fracture preserve irregular foam gaps.

The new `surf_train_rate` shader uniform defaults to 0.115 cycles per second. It controls this **original stylized shader**, not a value recovered from ACNH. CPU math checks verify direction, finite range, and cyclic continuity. `tools/surf_train_preview.py` renders `s50_surf_train_cpu_frames.png` using a simplified wavy coast and the same authored equation; **not a screenshot from Godot**.

## Sprint 51: Avoid redundant shoreline SDF work

- `IslandDefinition` now advances `coastline_revision` only after actual changes to coast inset, land, height, and river presence. Repeated no-op edits leave revision stable.
- `CoastContour.prepare_shoreline_cache()` returns early on unchanged island instance/revision.
- `CoastBuilder.make_shoreline_texture()` and `make_signed_coast_texture()` reuse `ImageTexture` for unchanged instance/revision; mutations invalidate and rebuild. The SDF is still 256×256, and edit processing is **not yet** benchmarked on Godot GPU.
- Added `tests/test_s51_cache.gd` for resource identity/invalidation and offline source check.

## Sprint 52: First automated engine test/capture route

GitHub workflow `.github/workflows/godot-validation.yml` targets stable Godot **4.7.2** on Ubuntu. It imports the project, runs Python and GDScript test suites, captures historical Sprint46 island, Sprint48 region overlay and new Sprint51 coast phase A/B via Xvfb/OpenGL compatibility, then uploads a GitHub Actions artifact.

`tests/capture_sprint51_coast.gd` renders two genuine engine frames separated by 2.7 seconds if CI succeeds. No actual Godot renderer capture is represented as already produced in this report.

Run locally (with Godot and graphics/display support):

```bash
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/test_s49_outer_warp.gd
godot --headless --path . --script res://tests/test_s51_cache.gd
godot --path . --script res://tests/capture_sprint51_coast.gd
```

## Research bounds and next step

`acnh-re-results` remains the source for observed native tile index, overlays, region checks and navigation flags. Wave geometry, colors, SDF, surf patterns and editor mechanics in this repository are **original implementations**, not extracted Nintendo shader code or verified ACNH visual parameters. In particular, successful CPU math tests do not validate renderer blending, temporal motion, shoreline collision geometry, or ACNH visual similarity.

Next: inspect GitHub CI failures and generated image artifacts. Correct actual Godot parser/renderer errors and compare phase A/B captures before attempting detailed aesthetic tuning of beach foam, cliff lip and cove junctions.
