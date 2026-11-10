# Nusa Character Kit v3 — lima model TRELLIS asli, bukan probe

**Status: auto-rig prototype + Godot import smoke; belum production-ready.**

Sumber privat pengguna: `chr_bahari_s3.glb`, `chr_lintang_s3.glb`,
`elder_gajah_s3.glb`, `elder_gurita_s3.glb`, dan `elder_komo_s3.glb`.
Kelima file merupakan **mesh statis** (satu mesh, UV/material, nol skin,
nol tulang, nol animasi). Binary asli dan hasil rig ditempatkan pada direktori
lokal `upload/` dan `generated/private_originals/` di luar kontrol versi.

## Ringkasan hasil

| Model asli | Tipe | Bone setelah auto-rig | Klip baru | Komponen spesies | Batasan nyata |
| --- | --- | ---: | ---: | --- | --- |
| Bahari | Biped | 21 | 16 | Biped umum | **Cangkang tidak ada dalam source**; tidak ditambahkan secara fiktif |
| Lintang | Biped + sayap | 25 | 16 | Sayap kanan-kiri, telinga kanan-kiri | Membran sayap perlu weight mask/rangka lanjutan |
| Gajah | Biped + belalai | 25 | 16 | Dua telinga, belalai dua segmen | Kulit telinga dan belalai belum di-weight manual |
| Gurita | Octopus | 18 | 6 | Root + head + 8 × 2 segmen tentakel | Mask pemisahan tiap tentakel masih berbasis posisi sudut |
| Komo | Biped + ekor | 24 | 16 | Ekor dua segmen, moncong | Pose ekor dan skin bahu/tumit perlu QA visual |

Setiap GLB hasil pipeline mempertahankan mesh dan material asli,
memiliki `skin` glTF, joint indices/weights ternormalisasi, dan action klip
yang dapat dibaca oleh `AnimationPlayer` Godot. Python auditor dan tes Godot
memverifikasi struktur, bukan kualitas artistik.

### Reuse aktual dan hubungannya dengan ACNH

`biped_bones()` membuat **kontrak bone bersama** (Hips, Spine, Chest, Neck,
Head, bahu, lengan, telapak, paha, betis, kaki, jari kaki) dengan perbedaan
panjang tulang sesuai bounding box tiap model. Aksi biped `idle`, `walk`,
`run`, `turn`, `start_stop`, `sit`, `wade`, `swim`, `shovel`, `pickup`,
`carry`, `interact`, `watering`, `talk`, `wave`, dan `clap` diturunkan
dari **satu generator gerakan original** dan dipasang pada empat rig.
Tidak ada file animasi/bone Nintendo yang disalin.

Gurita tidak diretarget sebagai humanoid; generator khususnya menyediakan
`idle`, `swim`, `wave`, `talk`, `celebrate`, `rest` dan rig 8 tentakel.
Gajah/Lintang/Komo mendapat bone kontrol spesies yang ikut digerakkan
terpisah dari core biped.

`NusaOriginalActor` adalah pembungkus `CharacterBody3D` untuk kelima jenis:
memuat GLB yang sudah dirig, memasang kapsul gerak yang sesuai profil,
area interaksi independen, dan memainkan action bawaan (`play_clip`).
Ini **bukan** pengganti controller dunia `RiverCharacter` yang memiliki
logika air, tebing, dan foot-IK lebih spesifik.

Wajah kelima model saat ini **sudah tergambar langsung pada tekstur**.
Karena itu atlas mata/mulut `v2` tidak dipasang otomatis: overlay akan
membuat mata dan mulut dobel. Untuk ekspresi ala ACNH secara arsitektural,
perlu memisahkan piksel wajah menjadi UV layer/mask/material variants,
menyesuaikan permukaan pipi/moncong, lalu menghubungkannya dengan state
`blink`, `look`, `mouth`, dan emosi. Script ini belum mengklaim fitur itu.

## Jalankan ulang dari model pengguna

Salin kelima GLB privat ke folder input lokal (misal `../upload/`).
Blender 4.3+ dan Godot 4.6+ diperlukan.

```bash
blender -b --factory-startup --python tools/rig_nusa_original_glbs.py -- \
  --input-dir ../upload --output-dir generated/private_originals

godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/test_nusa_original_glbs.gd

blender -b --factory-startup --python tools/render_nusa_original_lineup.py -- \
  --source-dir generated/private_originals \
  --output-dir generated/original_lineup_16

python3 tools/encode_nusa_motion.py --mode originals \
  --frames-dir generated/original_lineup_16 \
  --video generated/nusa_lima_asli_16_animasi.mp4 \
  --gif generated/nusa_lima_asli_16_animasi.gif
```

Audit material dan skin:

```bash
python3 tools/audit_character_glb.py \
  generated/private_originals/elder_komo_s3_rigged.glb \
  --profile data/characters/profiles/animal_biped.json

python3 tools/audit_character_glb.py \
  generated/private_originals/elder_gurita_s3_rigged.glb \
  --profile data/characters/profiles/octopus.json
```

Contoh memunculkan aktor pada scene/game:

```gdscript
var komo := NusaOriginalActor.new()
komo.species = "komo"
add_child(komo)
komo.play_clip("walk")

var gurita := NusaOriginalActor.new()
gurita.species = "gurita"
add_child(gurita)
gurita.play_clip("swim")
```

> Semua file GLB yang direferensikan harus digenerate dahulu. Binari privat
> tidak berada di repository ini. Render animasi dibuat Blender CPU dari
> action GLB yang juga terbukti dapat diimpor dan disampling Godot; render
> bukan screenshot gameplay Godot.

## Penilaian untuk keputusan produksi

**Lulus struktur:** seluruh 5 GLB punya 1 skin valid; 21/25/25/18/24 tulang;
seluruh atribut `JOINTS_0`/`WEIGHTS_0` valid dan bernilai total ≈1;
16/16/16/6/16 animasi dapat dibaca Godot. Profil skeleton dan collision
valid; gerak sendi diuji di Godot; body/interaction collider dibuat aktor.

**Belum lulus animasi final:** model TRELLIS berupa permukaan tunggal,
belum retopo quad berarah aliran sendi, skin-weight memakai aturan posisi,
deformasi paha/ketiak dan membran/tentakel masih rentan. Belum ada IK kaki,
foot lock, animasi duduk dengan kontak kursi, renang berorientasi tubuh,
ekspresi tekstur yang benar, lipsync, collider tentakel per-segmen, atau
penambahan cangkang Bahari yang hilang. Audio maupun ekspresi muka pada
demo tetap merupakan piksel statis sumber.

**Target berikutnya (urut QA):** Komo `walk/run/wave/dig/sit` + perbaikan
vertex groups/retopo pada bahu/engkel/tumit; Gajah belalai dan telinga;
Lintang sayap; Gurita per-tentakel; Bahari desain cangkang dari referensi
pengguna; setelah itu face texture decomposition dan collision appendage.

Lihat juga [V2.1](NUSA_CHARACTER_KIT_V2_1.md) untuk retarget antar-rig.
