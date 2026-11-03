# Sprint 48 — Live RE region diagnostic + CPU comparison captures

## Implemented

- Opt-in `TerrainRegionDiagnostic` panel in the Godot island editor: **J** toggles it; **H** switches between region-check mode0 and mode1. The panel refreshes after terrain edits and fixture swaps.
- Modeled by `NativeTerrainRegionReference` from Sprint47, with 3×3 inclusive rectangles. This is a **synthetic projection** from Nusantara terrain levels and river flags onto a minimal record grid; no assertion is made that those flags are ACNH's actual live game values.
- The mapping gives dry land both permission word bits 0/1, uses Nusantara height×1.55 as the first record height, and uses a temporary +0.16 height overlay for water in mode0 (mode1 ignores overlays). Missing land is flagged as absent. These are demonstration inputs, **not proven native gameplay semantics**.
- Panel shows four categories: sea, river, diagnostic pass, diagnostic fail. Neither editing rules nor `WorldCollision`, actor navigation, file saves or native reference constants change.
- Added `tests/test_s48_region_diagnostic.gd` and renderer capture harness `tests/capture_sprint48.gd`.
- `tools/cpu_island_preview.py` can draw two repeatable CPU-based previews from `fixture_coast_mask()` and the same synthetic 3×3 comparison model.

## Capture results (CPU, not Godot renderer)

| Capture | Allowed dry land | Flagged dry land | River | Sea |
| --- | ---: | ---: | ---: | ---: |
| `s48_region_cpu_mode0.png` | 37 | 104 | 18 | 121 |
| `s48_region_cpu_mode1.png` | 50 | 91 | 18 | 121 |

The 13-cell difference follows from the **synthetic** water overlay used only by mode0. Its color scheme is a diagnostic, not an ACNH image match. The CPU 3D panel approximates straight tile prisms; it does not simulate Godot's warped coastline mesh, wave shader, physics, collision, animation or actual render pipeline.

To make the actual Godot screenshot on a system with Godot 4.7+ and a compatible renderer:

```bash
godot --path . --script res://tests/capture_sprint48.gd
```

Expected output when run successfully: `s48_godot_region_overlay.png`. **This file was not generated here** because Godot is absent.

## Verification

```bash
python3 -m unittest discover -s tests -p 'test*offline.py' -v
```

Expected: 27 offline CPU/math/source-contract tests. Engine tests `tests/test_re_terrain_region.gd`, `tests/test_s48_region_diagnostic.gd` and older Godot suites remain unexecuted until a Godot runtime is available. A passing Python suite does not prove GDScript compiles or renders.

## RE bounds

Based on the user's [`acnh-re-results`](https://github.com/menuyul312-max/acnh-re-results), particularly [`TERRAIN_REGION_CHECK.md`](https://github.com/menuyul312-max/acnh-re-results/blob/main/acnh-re/docs/TERRAIN_REGION_CHECK.md) and [`TERRAIN_REGION_MUTATION.md`](https://github.com/menuyul312-max/acnh-re-results/blob/main/acnh-re/docs/TERRAIN_REGION_MUTATION.md). Those proofs use reconstructed grids; complete placement, live terraforming callbacks and NPC passability remain open.

## Next sprint

Run actual Godot captures and engine tests; compare debug overlay placement with the renderer. Only then use visual regressions to guide shoreline, cove, cliff-lip and coastal surf changes. Keep diagnostic state separate from gameplay collision.
