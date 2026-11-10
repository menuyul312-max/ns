# Nusa Character Kit v2 — wajah modular, retarget pose, dan collision per spesies

**Status: prototipe yang berjalan dan diuji pada satu GLB chibi pengguna (23 bone).** Ini sistem **orisinal untuk Nusa**, bukan dump material/bone/animasi Nintendo. Aset ACNH tidak disertakan. Bentuk dan ukuran dalam tabel ini merupakan keputusan produksi Nusa, **bukan hasil pengukuran ACNH**.

## Apa yang benar-benar bisa direuse?

| Komponen | Implementasi saat ini | Syarat agar bisa dipakai karakter lain |
| --- | --- | --- |
| Struktur skeleton humanoid | `data/characters/profiles/humanoid.json` (7 role wajib; forearm, tangan, tulang jari, kaki dll. opsional) | Nama bone dan hierarki memenuhi kontrak; skinning/weight painting tetap per mesh |
| Hewan humanoid | `profiles/animal_biped.json` menambah telinga, muzzle, dan tail opsional | Reuse locomotion biped bila orientasi dan panjang tungkai telah dikalibrasi |
| Spirit bersayap | `profiles/winged_spirit.json` mensyaratkan dua root wing | Perlu rigging sayap dan gerak terbang khusus; animasi biped bukan solver terbang |
| Hewan empat kaki | `profiles/quadruped.json`, **topologi terpisah** | Tidak memakai animasi biped secara langsung; perlu four-leg gait dan IK |
| Gerak skeleton | 16 klip demonstrasi (`SkeletonAnimationBridge`) plus pemetaan per role (`NusaAnimationRetargeter`) | Role target harus cocok; lakukan retarget *sampel pose* saat diperlukan. Belum ada konverter otomatis seluruh animasi `.glb` atau adaptasi topologi |
| Mata/mulut/ekspresi | `NusaFaceAtlas`: 8 region mata dan 6 region mulut, di `BoneAttachment3D` kepala | Kalibrasi posisi muka setiap bentuk kepala; ganti gambar atlas placeholder dengan seni Nusa final |
| Facial morph lama | `NusaFaceController` tetap menerima preset ekspresi dan blink; morph mulut/jaw/viseme dimatikan saat atlas aktif | Opsional untuk perubahan volume pipi/kelopak; tidak perlu membuat ulang 78 morph pada semua karakter |
| Collision fisik | File JSON per kategori: kapsul `CharacterBody3D` untuk fisika dan `Area3D` untuk jangkauan interaksi | Ukuran, offset kaki dan sensor wajib disesuaikan terhadap proporsi model baru |

## Landasan dari studi ACNH vs asumsi

Hasil RE di [`acnh-re-results`](https://github.com/menuyul312-max/acnh-re-results) memperlihatkan bahwa reader BFRES menangani struktur skeleton dan beberapa kanal animasi seperti skeleton, material, visibility serta shape. Dokumentasi modding publik menjelaskan model karakter terpisah, weight painting, dan praktik animasi; laporan modder juga mendeskripsikan variasi tekstur mata dan mulut pada salah satu karakter. Bukti tersebut mendukung **pendekatan data-driven dan face texture variants**, tetapi **belum** membuktikan satu jumlah tulang, jumlah frame ekspresi, pipeline skin, atau ukuran collision yang universal untuk semua karakter ACNH. Kita **tidak** mengimpor file Nintendo ataupun mengklaim motion Nusa persis ACNH.

Rujukan:

- [`acnh-re` BFRES reference parser](https://github.com/menuyul312-max/acnh-re-results/blob/main/acnh-re/tools/reference/acnh_rip/formats/bfres.py)
- [ACNH Modding Wiki — model villager](https://acnhmodding.github.io/creating-mods/creating-npc-model/)
- [ACNH Modding Wiki — animating models](https://acnhmodding.github.io/creating-mods/animating-models/)
- [Modder texture example](https://archive.vg-resource.com/showthread.php?mode=threaded&pid=677372&tid=38362)
- [`COLLISION_RESPONSE.md` di RE](https://github.com/menuyul312-max/acnh-re-results/blob/main/acnh-re/docs/COLLISION_RESPONSE.md): bentuk collider asli masih belum diketahui.

## 1. Wajah modular

`NusaFaceAtlas` membangun dua kanal yang independen:

1. Mata: neutral, blink, blink kiri, blink kanan, happy, sad, angry, surprised.
2. Mulut: neutral, smile, frown, open, round, press. Preset `talk_a`, `talk_o`, dan `talk_m` memakai region mulut tanpa perlu memindahkan mesh wajah.
3. Dua sprite mengikuti `Head` dengan `BoneAttachment3D`. Konfigurasi ruang rest ada di `data/characters/face_profiles/humanoid.json`; wajah user GLB ini menghadap **+Z di Godot** (−Y di Blender), bukan −Z.
4. Saat wajah tekstur aktif, morph `mouth*`, `viseme*`, `jaw*` pada legacy 78-shape GLB diredam untuk menghindari tonjolan mulut ganda. Eye morph tetap dapat bekerja.

**Catatan visual penting:** bentuk mata/mulut saat ini digambar prosedural dari primitive bitmap sederhana—belum final, belum mengikuti lengkungan kulit, dan masih berupa bidang datar yang dapat tampak melayang pada kepala berbeda. Untuk hasil rilis, gunakan atlas desain Nusa sendiri, atur UV/mask/decal atau geometri mata tempel mengikuti kepala, dan sinkronkan audio/lip-sync.

### Menggunakan pada karakter baru

```gdscript
var visual := CharacterRigVisual.new()
visual.configure_asset(
    "res://assets/komo.glb",
    "res://data/characters/profiles/animal_biped.json",
    1.0,
    Vector3.ZERO,
    "res://data/characters/face_profiles/humanoid.json"
)
add_child(visual)
visual.setup()
visual.set_expression("happy")
visual.set_expression("blink_left")
```

File `face_profiles/humanoid.json` **adalah kalibrasi spesifik GLB prototipe**. Untuk Komo/hewan lain, duplikasi dan kalibrasi `face_origin_rest`, ukuran sprite, arah muka dan offset mata/mulut; jangan berasumsi parameter manusia cocok otomatis.

## 2. Rig dan animasi yang bisa dipakai ulang

- `NusaRigProfile.inspect()` memvalidasi struktur dan memetakan role tulang sesuai alias. Kesalahan `Wing_L` pada karakter tanpa sayap akan ditolak, bukan diam-diam berpura-pura kompatibel.
- `NusaAnimationRetargeter.retarget_pose()` memindahkan *satu pose bone* dari dua skeleton valid dengan koreksi orientasi quaternion rest, pilihan role, dan skala translasi root berdasarkan panjang tungkai apabila tersedia. Ini **belum** animator otomatis untuk semua klip; perlu sampler yang membaca pose di source rig dan memberi pose target pada frame animasi.
- Klip `idle`, `walk`, `run`, `turn`, `start_stop`, `sit`, `wade`, `swim`, `shovel`, `pickup`, `carry`, `interact`, `watering`, `talk`, `wave`, `clap` dari v1 **dipertahankan tanpa perubahan pose** supaya tidak merusak gerakan yang sudah lulus tes. Eksperimen lutut/siku dan translasi root pada v2 memperlihatkan deformasi ekstrem di render model contoh, maka dibatalkan. Klip `sit` **belum merupakan duduk yang benar**—butuh kursi, IK dan pose torso/lutut yang ditata ulang. Semua masih prototipe keyframe, belum motion studio/foot-lock per siklus.
- IK kaki yang sudah ada hanya mengoreksi posisi saat idle pada tanah; belum otomatis untuk semua karakter dan belum mencakup tangan, ekor, sayap, atau kaki depan/belakang hewan.
- Tulang jempol/index sekarang dikenali bila tersedia, tetapi model contoh **tidak** memiliki finger rig yang kaya. Nama bone kompatibel saja tidak memperbaiki mesh cacat, weight paint, atau retopology.

Contoh transfer *pose* untuk skeleton yang sudah ada:

```gdscript
var source_profile := NusaRigProfile.load_profile()
var target_profile := NusaRigProfile.load_profile()
var report := NusaAnimationRetargeter.retarget_pose(
    source_skeleton, target_skeleton, source_profile, target_profile
)
assert(report.valid)
```

Untuk spesies dengan rantai berbeda (sayap, naga empat kaki, kaki belakang pendek, ekor panjang), buat retarget/IK/motion **khusus spesies** terlebih dahulu. Jangan memetakan `Leg_L` langsung menjadi front leg naga.

## 3. Collider tubuh dan interaksi

`RiverCharacter` sekarang memuat `collision_profile_path` (default humanoid). Profil tersedia:

| Profil | Capsule radius | Capsule height | Sensor radius | Kegunaan |
| --- | ---: | ---: | ---: | --- |
| `humanoid` | 0,22 | 1,24 | 0,62 | humanoid prototipe |
| `animal_biped` | 0,25 | 1,24 | 0,72 | hewan berdiri, perkiraan awal |
| `winged_spirit` | 0,27 | 1,24 | 0,82 | spirit dengan wings (wings bukan solid hitbox) |
| `quadruped` | 0,37 | 1,05 | 0,82 | angka fallback; perlu uji locomotion 4 kaki |

`CollisionShape3D` kapsul utama mencegah tubuh menembus tanah/prop, **bukan** hitbox detail tiap jari/telinga. `InteractionPivot/InteractionReach` adalah `Area3D` berlapis mask berbeda untuk mendeteksi objek di depan karakter. Arah sensor mengikuti yaw karakter. Sensor ini belum terhubung ke sistem interaksi gameplay; deteksi saja belum memicu pickup/talk otomatis. Collider akan tetap utuh ketika animasi duduk, menyapu, atau menggali—wajar untuk navigasi prototipe, tetapi nanti perlu aturan posture clearance agar duduk tidak menembus bangku.

## 4. Verifikasi dan preview

Simpan GLB yang dimiliki sendiri ke `assets/character_nusantara.glb` (gitignore sengaja menjaga aset privat), lalu jalankan Godot 4.7+:

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/test_nusa_character_kit.gd
godot --headless --path . --script res://tests/test_nusa_face_atlas_v2.gd
godot --headless --path . --script res://tests/test_nusa_collision_profiles.gd
godot --headless --path . --script res://tests/test_nusa_retargeter.gd
godot --headless --path . --script res://tests/test_nusa_animation_catalog.gd
godot --headless --path . --script res://tests/test_river_character.gd
```

Untuk melihat bidang wajah di Blender **(bukan capture Godot)**, ekspor atlas procedurally:

```bash
NUSA_FACE_ATLAS_DIR=/tmp/nusa_face_atlas godot --headless --path . \
  --script res://tests/test_nusa_face_atlas_v2.gd
blender -b --factory-startup --python tools/render_nusa_face_atlas_v2.py -- \
  --model assets/character_nusantara.glb \
  --atlas-dir /tmp/nusa_face_atlas --output-dir /tmp/nusa_face_frames
```

Skrip render mengonversi orientasi GLB untuk kamera Blender; ekspresi yang ditampilkan menggunakan region tekstur yang sama dengan `NusaFaceAtlas`. Render bukan bukti bahwa shader, anchor, occlusion atau wajah semua spesies sudah benar saat dijalankan secara real-time di Godot.

## Pekerjaan berikutnya untuk mutu produksi

1. **Art/mesh:** retopology bersih pada jari, bahu, tumit, telinga; weight-paint dan UV wajah yang menempel ke bentuk kepala.
2. **Sistem wajah:** source atlas per spesies, UV/decal terpadu, pola mata yang lebih kaya, audio-driven phoneme blend, state blink independent, bukan hanya sprite datar.
3. **Animasi:** fase gait + foot-lock, hand IK dua tangan untuk sekop, adaptasi ke panjang tulang, four-leg gait, tail/wings sim, retarget per-klip terotomatisasi.
4. **Collision:** regression lintas tinggi tubuh/props, pose clearance, ledge/swim profiles; uji kontak asli dalam render Godot.
5. **Audit ACNH:** cocokkan ulang hanya setelah tersedia data struktur tulang/ekspresi/collision yang **terverifikasi**, tanpa memindahkan aset Nintendo ke game Nusa.
