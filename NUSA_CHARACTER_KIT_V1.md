# Nusa Character Base Kit v1 — fondasi karakter modular Godot 4.7+

Status: **fondasi rig, ekspresi, animasi prototipe, skin transfer terbatas, dan pengujian otomatis tersedia**. Ini **bukan** paket rigging otomatis final bagi semua hasil Trellis dan **bukan** salinan aset/animasi Nintendo.

## Apa yang bisa digunakan ulang dari studi ACNH?

Repo riset [`acnh-re-results`](https://github.com/menuyul312-max/acnh-re-results) berisi pembaca format model/animasi Nintendo, antara lain `acnh-re/tools/reference/acnh_rip/formats/bfres.py`, `bfres_anim.py`, dan `gltf.py`. Pembaca tersebut menjadi **referensi untuk konsep pemisahan mesh, skeleton, skin weights, morph/face, dan animation clips**; kit ini mengimplementasikan kontrak karakter **orisinal** di Godot/GLB. Repo RE tidak menyediakan satu set karakter ACNH terlisensi untuk langsung dipasang dalam Nusa.

| Komponen karakter | Implementasi Nusa v1 | Bisa dipakai antar karakter? |
| --- | --- | --- |
| Bentuk tubuh/T-pose | Mesh GLB masing-masing karakter | Hanya template proporsi serumpun, bukan mesh identik |
| Skeleton dan bone-role | `NusaRigProfile`; 7 peran minimum, 15 opsional | **Ya**, untuk biped yang hierarkinya kompatibel |
| Skin weights | Dipasok GLB; utilitas Blender dapat *transfer* dari basis selaras | **Bersyarat**, perlu geometri/rest pose sebanding |
| Animasi | `SkeletonAnimationBridge`; 8 locomotion + 8 action demo | **Ya**, pada bone-role dan rest-pose yang cocok |
| Ekspresi wajah | `NusaFaceController`; 11 preset dan 78 target yang terdeteksi pada contoh | **Jika nama blendshape kompatibel** |
| Pakaian/peralatan/sayap | Socket `BoneAttachment3D` | **Ya** untuk modul terpisah; deformasi kain/sayap belum otomatis |
| Fisika/interaksi | CharacterBody dan aksi shovel lama dipertahankan | **Ya**, visual rig tidak mengganti aturan terrain/air |

## Susunan aset karakter yang disarankan

```text
CharacterRoot (CharacterBody3D; collision dan state gameplay)
  CharacterRigVisual (adapter GLB + profile)
    ImportedNusantaraGLB (PackedScene hasil impor GLB)
      Armature / Skeleton3D
        BodyMesh (skinned mesh; dapat berisi 78 blendshape)
        Module_hand_right (BoneAttachment3D; contoh alat)
        Module_back (BoneAttachment3D; contoh cangkang/tas)
    NusaFaceController (preset wajah)
  SkeletonAnimationBridge (AnimationPlayer dan AnimationTree)
  ShovelTool / FootGroundProbe / FootIKController (sistem gameplay)
```

Mesh dan kulit dapat berupa satu atau lebih MeshInstance3D; hanya satu Skeleton3D utama diperlukan untuk profil humanoid saat ini. Tulang pokok: pinggul, tulang belakang, kepala, lengan kiri/kanan, tungkai kiri/kanan. Saat tersedia, tambahkan bahu, siku, pergelangan tangan, leher/rahang, lutut, pergelangan kaki dan ujung kaki untuk deformasi yang lebih layak. Pada hewan tambahkan telinga, ekor, moncong; pada spirit bersayap tambahkan pangkal sayap kiri dan kanan.

### Hasil audit aset pengguna saat ini

Contoh sumber `Chibi_Gray_T_Pose_Clay_Model_s3.glb` (file milik pengguna yang dipasang **secara lokal** sebagai `assets/character_nusantara.glb`):

- 1 mesh, 1 skin, **23 joint**, 10.488 vertex, 17.672 triangle.
- **78 morph target** untuk wajah (termasuk kelopak mata kiri/kanan dan bentuk mulut), 2 animasi bawaan (`Idle`, `FaceTest`).
- Normals dan UV ditemukan. Tidak ditemukan indeks tulang/berat tidak valid; hingga 4 pengaruh tulang tiap vertex.
- Model sumber **tidak dikomit ke repo publik**; kit tetap bisa menjalankan fallback rig debug jika GLB tidak tersedia.

## Struktur yang ditambahkan

```text
data/characters/
  profiles/humanoid.json       # dasar manusia atau hewan humanoid
  profiles/animal_biped.json   # mengembangkan humanoid + telinga/ekor/muzzle
  profiles/winged_spirit.json  # menuntut Wing_L/Wing_R
  expressions.json             # 11 ekspresi wajah
scripts/
  nusa_rig_profile.gd          # role alias, aturan hierarki, socket
  nusa_face_controller.gd      # transisi blendshape
  character_rig_visual.gd      # impor, fallback, socket, kalibrasi
  skeleton_animation_bridge.gd # katalog animasi, state machine, action overlay
tools/
  audit_character_glb.py      # audit offline glTF 2.0
  blender_fit_skin.py          # transfer skin dari GLB referensi
  render_nusa_preview.py       # pratinjau model via Blender (bukan Godot)
tests/
  test_nusa_character_kit.gd
  test_nusa_animation_catalog.gd
  test_character_audit.py
  capture_nusa_character_kit.gd
```

## Menggunakan karakter baru

1. Buat model orisinal posisi **T-pose** dengan proporsi dan orientasi konsisten. Buat/retopologikan mesh, UV dan material. Jangan otomatis menyatukan jempol, daun telinga, tumit, cangkang, atau sayap bila silhouette memerlukan bagian tersendiri.
2. Rig di Blender. Sesuaikan armature ke joint **asli**, pisahkan deformasi bahu, siku, jempol, lutut, tumit dan pergelangan kaki. Buat blendshape sesuai kebutuhan wajah.
3. Ekspor GLB, jalankan audit, lalu buat profil baru atau gunakan profil yang ada. `winged_spirit` sengaja **menolak** humanoid tanpa tulang sayap, supaya salah template tidak lolos diam-diam.
4. Di GDScript, sebelum `setup()`, atur GLB/profil/skala: `rig.configure_asset("res://assets/nusa_kartika.glb", "res://data/characters/profiles/humanoid.json", 1.0, Vector3.ZERO)`.
5. Setelah `setup()`, panggil `rig.set_expression("happy")`, `rig.attach_module("hand_right", module_scene, tool_offset)`, atau `animator.fire_action("wave")` sesuai gameplay. Aksi lain: `pickup`, `carry`, `interact`, `watering`, `talk`, `clap`, `shovel`.
6. Periksa walk/run, pose sit, grasp alat, benturan lengan–torso, gerakan jempol, lipatan tumit/engkel, kedalaman mata, dan animasi sayap untuk tiap mesh. *Transfer skin* hanya titik awal.

### Audit GLB tanpa Blender

```bash
python3 tools/audit_character_glb.py assets/character_nusantara.glb --profile data/characters/profiles/humanoid.json
python3 tools/audit_character_glb.py assets/character_nusantara.glb --profile data/characters/profiles/winged_spirit.json
```

Perintah kedua seharusnya **gagal** untuk basis humanoid karena tidak mempunyai `Wing_L`/`Wing_R`. Tampilkan laporan JSON dengan `--output path/hasil.json` jika perlu.

### Transfer skin dari template yang sudah memiliki rig

Hanya untuk retopo biped **dengan rest pose, orientasi, pusat, dan ukuran yang mendekati template**. Tidak boleh diperlakukan sebagai auto-rigger universal; kaki tambahan, cangkang, selendang, serta sayap harus dibentuk dan diberi rig tersendiri.

```bash
blender -b --factory-startup --python tools/blender_fit_skin.py -- \
  --reference /lokasi/template_biped_berig.glb \
  --target /lokasi/mesh_retopo_selaras.glb \
  --output /lokasi/nusa_biped_skinned.glb
python3 tools/audit_character_glb.py /lokasi/nusa_biped_skinned.glb
```

Skrip mengimpor 2 GLB, menolak selisih *bounding box* besar, menyalin vertex groups via nearest-surface interpolation, membatasi ke 4 bone influences, normalisasi, memasang armature, dan mengekspor GLB. Pada uji sumber–target **identik** dari model pengguna, auditor menyatakan valid, 23 joint, 78 morph targets, bobot tulang valid. Itu **bukan** uji hasil Trellis berbeda sehingga tidak membuktikan retopologi/weighting baik untuk mesh lain.

## Menjalankan pengujian

Gunakan Godot 4.7+ dan letakkan model pengguna secara lokal di `assets/character_nusantara.glb` sebelum tes yang mensyaratkan GLB nyata.

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/test_nusa_character_kit.gd
godot --headless --path . --script res://tests/test_nusa_animation_catalog.gd
godot --headless --path . --script res://tests/test_skeleton_rig.gd
godot --headless --path . --script res://tests/test_foot_ik.gd
python3 -m unittest discover -s tests -p test_character_audit.py
```

Untuk gambar karakter 3D asli, jalankan `godot --path . --script res://tests/capture_nusa_character_kit.gd` di lingkungan yang memiliki **display renderer**, opsional `NUSA_CAPTURE_DIR=/lokasi/hasil`. `--headless` tidak dapat menghasilkan viewport 3D pada build ini.

## Batasan yang tetap perlu dibangun

- Retopologi otomatis khusus ACNH-style/Trellis, fitting armature untuk anatomi berbeda dan validasi *deformation quality* belum selesai.
- Bentuk lengkap humanoid/hewan/spirits dan modul baju/sayap/selendang masih perlu desain aset orisinal masing-masing.
- 16 animasi adalah **klip prosedural prototipe** untuk integrasi; belum tersedia *authored keyframes*, gait profesional, root-motion penuh, cloth simulation, eye tracking, atau lip-sync audio.
- Tes fungsi dapat berjalan headless, sedangkan kualitas visual memerlukan capture nyata dan tinjauan manusia.
