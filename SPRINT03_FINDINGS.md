# Sprint 03 — Fondasi sungai, waterfall, dan variasi permukaan air

Tanggal: 2 November 2026. Status: **prototipe awal berjalan dan lolos tes; visual masih perlu iterasi besar**.

## Dasar referensi

- [Nintendo: Island Designer](https://play.nintendo.com/news-tips/tips-tricks/animal-crossing-new-horizons-discover-tips/) menyebut konstruksi tebing, sungai, kolam, dan air terjun sebagai kategori fitur gameplay. Ini referensi kemampuan, **bukan bukti algoritma mesh**.
- [Nintendo: terraforming](https://www.nintendo.com/jp/ichikara/acbaa/03_en.html) menjelaskan izin desain sungai/tebing. Tidak memberikan ukuran grid, rule table, atau rumus hidrodinamika.
- [Godot 4.7 SurfaceTool](https://docs.godotengine.org/en/4.7/classes/class_surfacetool.html) mendokumentasikan pembuatan mesh prosedural dan winding clockwise. Struktur mesh di sini orisinal.
- [Godot 4.7 Spatial Shader](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/spatial_shader.html) menyediakan `TIME`, `UV`, `ALBEDO`, dan `ALPHA` untuk shader air; penulisan `ALPHA` menggunakan jalur transparan dan memerlukan perhatian pada sorting.

Tidak ada parsing data game Nintendo maupun klaim rekonstruksi kode ACNH dalam sprint ini.

## Model logika

| Lapisan | Representasi | Konsekuensi |
| --- | --- | --- |
| Elevasi | `PackedInt32Array levels` | Menentukan tinggi ground/cliff |
| Air | `PackedByteArray water` | Mask tile sungai/kolam, terpisah dari tinggi |
| Waterfall | Relasi dua tile air bertetangga dengan tinggi berbeda | Ditemukan otomatis; penurunan level menggeser letak waterfall |
| Collider air | `Area3D` per tile | Deteksi keberadaan air secara kasar; belum cocok untuk berenang |
| Penyimpanan | JSON `schema_version=2` | Termasuk elevasi dan air; schema 1 tetap dibaca |

Fixture riset: **14×10**, **20 tile air**, dan **1 sisi air terjun**. Dua fixture terrain lama tetap tersedia.

## Implementasi rendering

1. Tile air dibuat sedikit lebih rendah dari tanah sekitarnya, dengan ground bed terpisah untuk membedakan alur dari cat overlay.
2. Kontur masing-masing tile sungai diprofil memakai variasi world-space yang stabil antarpetak; sudut shore ganda menggunakan bevel-lengkung.
3. Bank mesh menghubungkan tepi tanah dengan waterline. Buih berupa patch pendek dengan alpha rendah, bukan garis putih kontinu.
4. Shader water surface memakai *advected value noise* multi-skala dan gangguan vertex kecil. Shader waterfall menggunakan noise bergerak ke arah vertikal.
5. Air terjun dibuat di muka tebing saat ada tetangga air yang lebih rendah; permukaan atas, tirai, dan buih kaki dirakit dari grid yang sama.

## Validasi aktual

- `test_island.gd` **PASS**: normal air ke atas, mesh water/bank/foam/fall tersedia, 20 trigger air, schema v1→v2, dan waterfall hanya ada jika elevasi air berbeda.
- `test_physics.gd` **PASS**: raycast ground/tebing baseline.
- `test_character.gd` **PASS**: kapsul tidak menembus tebing pada fixture uji.
- `test_composer.gd` **PASS**: brush dan save/load mempertahankan topologi air.
- `test_editor_input.gd` **PASS**: pemilihan lewat raycast layar berhasil mengganti elevasi maupun status air, lalu memperbarui trigger.
- `capture_scene.gd` **PASS**: capture 1280×720 menggunakan OpenGL software Mesa.
- `capture_water_motion.gd` **PASS**: 12 frame 960×540. Perbandingan frame 0 vs 10 mengubah **13.420 piksel** (uji `compare -metric AE`), menunjukkan animasi shader aktif; bukan ukuran kualitas artistik.

## Temuan visual dan perbaikan

Versi pertama terlalu cyan seperti overlay di atas tanah. Revisi menurunkan dasar sungai, membuat shade lebih tenang, mengurangi buih kaki waterfall, dan mengganti pasir putih menjadi beige. Hasil akhir lebih terbaca sebagai badan air, tetapi garis besar sungai masih berupa belokan tile yang relatif kaku.

**GAP tertinggi untuk iterasi berikutnya:**

1. Bangun kontur shore global lintas tile (misalnya signed-distance field + marching squares/spline) untuk transisi lengkung dan lebar sungai tidak seragam.
2. Perbaiki transisi waterfall: dinding samping, cap, tebing sekitar, animasi foam/bubbles lokal, dan zona genangan.
3. Bentuk *flow direction field* yang mengikuti gradien elevasi dan topologi koneksi; baru kemudian shader riak yang bereaksi terhadap arus/hambatan.
4. Sinkronkan collider bank dengan mesh visual dan buat aturan swimming/vault/pole/bridge di atas representasi air.
5. Lengkapi pantai, muara, danau, serta permukaan laut sebagai fitur Nusantara yang berbeda tetapi konsisten secara sistem.

Semua parameter visual bersifat **hipotesis desain orisinal**, belum terkalibrasi terhadap dimensi atau fisika ACNH.
