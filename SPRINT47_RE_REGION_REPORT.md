# Sprint 47 — Terrain region / navigation contract from ACNH RE

Status: implemented **bounded clean-room reference**, not integrated into live
terraforming permissions or movement; Godot headless execution still pending.

## Verified evidence consulted

Research repository: [`menuyul312-max/acnh-re-results`](https://github.com/menuyul312-max/acnh-re-results), commit `be226541d9d9437758cf7027e221b65c72353c13` (ACNH 1.0.0 ELF study).

1. [`TERRAIN_RUNTIME.md`](https://github.com/menuyul312-max/acnh-re-results/blob/main/acnh-re/docs/TERRAIN_RUNTIME.md): 52-byte runtime record, four sector attributes, overlay sentinel 7 and the native coordinate converter. These are **not** Godot tile/world units.
2. [`TERRAIN_REGION_CHECK.md`](https://github.com/menuyul312-max/acnh-re-results/blob/main/acnh-re/docs/TERRAIN_REGION_CHECK.md): original `0x181fa0` tested on finite reconstructed grids, 216 comparisons; inclusive rectangle, mode-specific word flags, base/overlay selection and max–min *first height* threshold `0.10999999940395355`.
3. [`TERRAIN_REGION_MUTATION.md`](https://github.com/menuyul312-max/acnh-re-results/blob/main/acnh-re/docs/TERRAIN_REGION_MUTATION.md): original `0x181ae0` and `0x185c80` set/clear bit6/bit2 in inclusive clipped rectangles. Low mode bit chooses operation. Native word decoder `0x185e70` showed bit6 inhibits forwarding bit12 to navigation byte bit4; 164 comparisons.
4. [`WORLD_NAV_BRIDGE.md`](https://github.com/menuyul312-max/acnh-re-results/blob/main/acnh-re/docs/WORLD_NAV_BRIDGE.md): bit mappings 8→2, 9→3, 10→0, 11→1, 12→4 (unless bit6), 13→5, 14→6 on reconstructed runtime flags. It does not establish full Godot/ACNH path passability.

## Implementation

- `scripts/native_terrain_region_reference.gd` models only the above contracts on a **separate record-indexed grid**: packed word flags, first float height of base and optional overlay, and overlay attribute-0 presence/sentinel. It does not mimic the 52-byte binary ABI or undocumented record fields.
- `mutate_region(start, end, bit_mask, mode)`: clipped **inclusive** rectangle, set/clear bit2 or bit6, preserves unrelated word bits; returns our own count of changed-region cells.
- `check_height_region(start, end, mode)`: mode0 requires bit0 and selects overlay when first attribute !=7; mode1 requires bit1 and always selects base. Rejects spread above threshold; empty in-bounds intersection succeeds as observed in RE. Reversed ranges and nonfinite samples are explicitly outside supported domain.
- `decode_navigation_byte(word)`: returns documented seven-bit intermediate value, **not** a Godot collision mask or universal NPC traversability decision.
- `tests/test_re_terrain_region.gd`: engine-level regression covering sentinel 7, low-bit mutation modes, clipped range, independent word bits, height boundaries, out-of-world vacuous result and decoder examples `0x1f00→31`, `0x1f40→15`.

## Validation and limitations

- Offline Python suite: 24 existing tests pass, unchanged. This suite **does not execute** the new GDScript test.
- The GDScript test can be run with Godot 4.7+: `godot --headless --path . --script res://tests/test_re_terrain_region.gd`. It has **not yet been executed here**, so engine correctness remains unverified.
- Live terrain meshes, collision, navigation and save schema intentionally remain unchanged. The RE has not established the complete placement rule, dynamic object override, live terraforming producer, or full navigation/physics integration. Wiring this module into placement denial before that evidence would risk false gameplay behavior.
- The older mistaken entry point/README from initial repository bootstrap were restored to the Sprint 46 project's actual `scenes/main.tscn` and instructions in this sprint.

## Next step

Once a Godot runtime is available, execute all GDScript tests and renderer captures; then provide a **separate, toggleable diagnostic overlay** mapping Nusantara cells onto the bounded native region contract. Keep the game's original build rules authoritative until the RE evidence covers consumer semantics.
