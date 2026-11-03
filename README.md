# Nusantara World Lab — Godot island prototype

Godot 4.3+ project for a **procedural stylized island** inspired by cozy island-building games. This is an original implementation, not decompiled Nintendo code or assets.

## Run

1. Open this repository's `project.godot` in Godot 4.3 or newer.
2. Press **F6** from `scenes/island_demo.tscn`, or **F5** to run the project.
3. Drag with the **right mouse button** to orbit; scroll to zoom.

## Implemented in this initial source sprint

- Deterministic coastline with multiple low-frequency shape variations.
- Sandy perimeter and inland grass, including an irregular raised terrace.
- Animated two-frequency sea surface and coast-dependent breaking foam shader.
- Seeded tree distribution via MultiMesh instances.
- Configurable radius, grid resolution, tree count and seed on the scene root.

## Next engineering milestones

- Build tile-independent cliff meshes with visible rock faces and grass lips; currently terrace slopes are sampled from a height field.
- Replace shader's analytic coastline estimate with a shared signed-distance texture for arbitrary island layouts.
- Add river / pond paths, waterfalls, collision and editable construction grid.
- Add automated Godot headless validation and visual regression captures.

This repository was initialized with only `.gitignore`; the preceding prototype files were not present here.
