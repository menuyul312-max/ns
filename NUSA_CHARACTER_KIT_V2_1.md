# Nusa Character Kit v2.1 — Uji reuse pada rig berbeda (23 → 26 bone)

**Status:** code-driven test rig kedua, bukan model Komo asli. GLB Komo produksi tidak ada di checkout/repo ini. Prototipe berikut dibuat secara independen untuk **membuktikan atau menggugurkan reuse**, bukan untuk menggantikan sculpt/rigging Komo.

## Bukti dan batasnya

| Pengujian | Hasil |
| --- | --- |
| Source | GLB humanoid 23 bone milik pengguna (gitignored) |
| Target | GLB hewan biped 26 bone, dihasilkan oleh skrip Blender, memiliki muzzle, telinga L/R, ekor 2 bone |
| Import | Kedua GLB diimpor Godot sebagai mesh skinned `Skeleton3D`, dengan profil yang cocok |
| Animasi | Semua 16 klip sumber berhasil **disampling dan diretarget** ke 26 bone |
| Wajah | Atlas dua kanal eye/mouth yang sama dipasang pada `Head`, tetapi kalibrasi posisi berbeda |
| Collision | Capsule radius 0,25 dan interaction sensor dari profil `animal_biped.json` |
| Gameplay actor | `RiverCharacter` berhasil memakai **GLB hewan 26 bone**, face profile hewan, dan kapsul hewan secara bersamaan |
| Anatomi spesies | Bone telinga/ekor/muzzle tetap ada, bone ekor **tidak ditimpa** pose humanoid |
| Uji gerak | Ada perubahan quaternion paha di walk; validasi visual tetap diperlukan |

Hasil tersebut membuktikan kontrak data dan transfer pose **antara dua skeleton biped yang berbeda**, **belum** membuktikan gerakan natural tanpa clipping/weight-paint baru. Hasil yang berhasil pada hewan biped **tidak otomatis berlaku** pada naga quadruped, burung, roh bersayap atau makhluk berekor panjang.

### Audit visual semua klip

`tools/render_nusa_motion.py` sekarang mendukung `--face-atlas-dir` serta `--face-profile` agar kedua tekstur wajah mengikuti transform kepala selama pose di-render. Video/GIF yang dibuat dari **196 frame (16 klip)** diperiksa satu per satu dengan kontakt-sit pose tengah. Ini adalah render Blender dari quaternion pose hasil Godot, bukan tangkapan engine Godot.

| Kategori | Temuan visual |
| --- | --- |
| `idle`, `walk`, `run`, `turn`, `wade` | Badan dan lengan tidak lagi terlipat ke wajah. Gerak kaki masih kaku dan kadang terlihat melayang. |
| `sit` | **Tidak terlihat sebagai duduk nyata**; masih seperti karakter berdiri dengan paha terangkat. |
| `swim` | Tangan bergerak keluar/masuk, tetapi belum ada cycle renang berfase dan body pitch. |
| `wave`, `clap`, `watering`, `pickup`, `interact` | Pose dapat diputar dan tidak merusak rig, tetapi gesture terlalu kecil/kurang ekspresif. |
| `talk`, ekspresi muka | Mata/mulut atlas berubah; sinkron phoneme, bentuk pipi dan animasi emosi masih placeholder. |

**Keputusan QA:** tidak mengklaim semua gerakan production-ready. Reuse terbukti secara struktur dan jalur pemutaran; kualitas gerak harus dibangun lagi sebagai pustaka pose artistik dan IK per spesies.

## Perbaikan penting setelah melihat hasil render

Transfer pose mentah pada versi awal membuat lengan target terlipat ke wajah walaupun seluruh tes struktural lulus. Penyebabnya: source clip memiliki **base pose** tersendiri (bahu yang sudah turun), sementara GLB target memiliki rest pose berbeda. `NusaRetargetPlayback` kini:

1. Membangun rencana pasangan bone hanya sekali (`NusaAnimationRetargeter.make_plan`) agar tidak mengulang inspeksi role setiap frame.
2. Merekam pose sumber saat idle frame 0 dan pose default target per bone.
3. Mengambil *selisih rotasi* dari idle sumber untuk setiap frame lalu mentransfernya lewat basis rest tulang target, relatif terhadap pose default target.
4. Mengukur translasi root sebagai selisih dari posisi dasar, dengan faktor panjang tungkai jika tersedia.
5. Hanya memindahkan **role bersama**. Bone spesies yang tidak ada pada manusia tidak disentuh.

Ini koreksi praktis untuk retarget dua biped yang berorientasi berbeda, bukan motion retargeting lengkap dengan constraints, stride warping, foot locking, atau perbaikan weight painting.

### Memasang karakter hewan pada aktor gameplay

`RiverCharacter` sekarang mengizinkan pilihan asset, kontrak skeleton, konfigurasi wajah, scale/offset, serta profil collision secara independen:

```gdscript
var actor := RiverCharacter.new()
actor.character_model_path = "res://generated/nusa_animal_biped_probe.glb"
actor.character_rig_profile_path = "res://data/characters/profiles/animal_biped.json"
actor.character_face_profile_path = "res://data/characters/face_profiles/animal_biped_probe.json"
actor.collision_profile_path = "res://data/characters/collisions/animal_biped.json"
actor.character_visual_scale = 1.0
add_child(actor)
```

Gunakan `NusaRetargetPlayback` jika animasi manusia akan diterapkan kepada rig hewan tersebut. Rig/face/collider di aktor dapat ditukar, tetapi `SkeletonAnimationBridge` default masih membuat pose procedural berdasarkan rig terpasang; **automatic avatar-retarget hookup ke gameplay AnimationTree masih pekerjaan lanjutan**.

## Reproduksi seluruh pipeline

Jalankan dari root proyek menggunakan Blender 4.3+ dan Godot 4.7+. GLB pengguna tetap diperlukan di `assets/character_nusantara.glb` (dikecualikan dari git).

```bash
# 1) Buat GLB hewan biped 26-bone original untuk tes (bukan Komo asli).
blender -b --factory-startup --python tools/make_nusa_animal_biped_probe.py -- \
  --output generated/nusa_animal_biped_probe.glb

# 2) Minta Godot mengimpor GLB baru ke cache proyek.
godot --headless --path . --editor --quit

# 3) Tes end-to-end import, face, retarget 16 klip, collision.
godot --headless --path . --script res://tests/test_nusa_second_character.gd

# 4) Ekspor sampel pose yang BENAR-BENAR dihitung Godot untuk target baru.
godot --headless --path . --script res://tools/export_nusa_second_motion_samples.gd

# Ekspor dua atlas mata/mulut original sebelum preview.
NUSA_FACE_ATLAS_DIR=/tmp/nusa_face_atlas godot --headless --path . \
  --script res://tests/test_nusa_face_atlas_v2.gd

# 5) Render pose Godot via Blender CPU (bukan Godot runtime screenshot).
blender -b --factory-startup --python tools/render_nusa_motion.py -- \
  --model generated/nusa_animal_biped_probe.glb \
  --samples-json generated/nusa_second_motion_samples.json \
  --output-dir generated/second_motion_frames \
  --face-atlas-dir /tmp/nusa_face_atlas \
  --face-profile data/characters/face_profiles/animal_biped_probe.json

# 6) Encode SEMUA 16 klip hasil render menjadi GIF/MP4 berlabel.
python3 tools/encode_nusa_motion.py --mode second \
  --frames-dir generated/second_motion_frames \
  --video generated/nusa_hewan_16_animasi.mp4 \
  --gif generated/nusa_hewan_16_animasi.gif
```

Untuk wajah, gunakan `NUSA_FACE_ATLAS_DIR=/tmp/nusa_face_atlas` dengan tes `test_nusa_face_atlas_v2.gd` (lihat panduan v2). Lalu:

```bash
blender -b --factory-startup --python tools/render_nusa_face_atlas_v2.py -- \
  --model generated/nusa_animal_biped_probe.glb \
  --face-profile data/characters/face_profiles/animal_biped_probe.json \
  --atlas-dir /tmp/nusa_face_atlas --output-dir generated/second_face_frames
```

GLB dan JSON sampling yang dihasilkan sengaja **diabaikan git**. Repo hanya menyimpan generator, implementasi, profil, dan tes agar aset uji bisa dibangun ulang. Tidak ada model Nintendo dan tidak ada GLB Komo pengguna yang dipublikasikan.

## Pekerjaan lanjutan, wajib sebelum dianggap final

- Saat GLB Komo tersedia, jalankan audit nama/hierarki bone 26 vs profil dan tes animasi yang sama pada mesh **asli**. Rig uji rigid-part ini tidak membuktikan retopology dan skin deformasi Komo.
- Evaluasi visual setiap klip (`sit`, `wave`, `clap`, `swim`, `shovel`) dan tambahkan retarget per-clip, IK tangan/kaki serta constraint postur untuk menghindari deformasi.
- Revisi atlas agar menempel mengikuti UV atau decal permukaan moncong/kepala, bukan dua sprite bidang datar. Parameter `animal_biped_probe.json` hanya untuk GLB generator ini.
- Bangun empat-langkah gait tersendiri untuk quadruped; jangan mengimpor biped animation langsung.

Lihat [kit v2](NUSA_CHARACTER_KIT_V2.md) untuk kontrak rig, boundary RE ACNH, dan API collision.
