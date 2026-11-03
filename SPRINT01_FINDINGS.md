# Sprint 01 — Fondasi terrain dan tebing Nusantara

Tanggal riset: 2 November 2026. Status: **prototipe geometris awal; bukan rekonstruksi ACNH**.

## 1. Bukti primer yang diperiksa

| Sumber | Apa yang langsung terlihat | Yang belum terbukti |
| --- | --- | --- |
| [CylindricalEarth `pbc.py`](https://github.com/Treeki/CylindricalEarth/blob/master/pbc.py) | Header `pbc\0`, ukuran peta, koordinat offset, ukuran record `0x34`, dan pembacaan empat byte di akhir record untuk collision | Aturan collision di mesin game; fungsi setiap field lain |
| [CylindricalEarth `display_pbc.py`](https://github.com/Treeki/CylindricalEarth/blob/master/display_pbc.py) | Pembacaan 12 nilai `float` dan 4 byte lain per record | Apakah setiap `float` berarti elevasi, orientasi, interpolasi, atau data lain |
| [CylindricalEarth `render_map.py`](https://github.com/Treeki/CylindricalEarth/blob/master/render_map.py) | Alur penyusunan peta mengacu ke tabel `FieldOutsideParts` dan `FieldLandMakingUnitModelParam` serta kategori unit tebing, sungai, dan air terjun | Parameter persis pemilihan model serta aturan kombinasi yang dipakai runtime ACNH |

**Pembatasan inferensi:** pembacaan empat byte collision tidak menjadikan keempat byte itu otomatis tinggi terrain. Sebelum ada sampel PBC beserta tangkapan layar yang berkorespondensi, hipotesis 12 `float` belum dapat dipastikan.

## 2. Model orisinal yang berhasil dibuat

`IslandDefinition` menjadi satu sumber kebenaran untuk kisi elevasi. Pembuatan mesh dan collision diderivasi dari kisi yang sama. Dua fixture dibuat manual dan deterministik:

- `fixture_terraces`: 10×8; teras ketinggian 0, 1, dan 2, dengan 38 sisi tebing terbuka.
- `fixture_bend`: 8×8; geometri berbelok dan elevasi bertingkat untuk menguji sambungan dinding.

`TerrainBuilder` memisahkan tiga surface: permukaan tanah, dinding tebing, dan bibir rumput. Dinding memiliki subdivisi horizontal/vertikal, tonjolan terkendali, serta variasi bibir secara kontinu dengan koordinat dunia. Setiap permukaan diberikan material warna vertex. Collider statis dibangun dari mesh tanah dan dinding.

Angka `TILE_SIZE=2.1`, `HEIGHT_STEP=1.55`, lebar bibir, dan besar tonjolan adalah **parameter desain awal**; jangan catat sebagai hasil pengukuran ACNH.

## 3. Hasil pengujian

Automated unit checks di `tests/test_island.gd` memeriksa:

1. Dua fixture memiliki tebing, serta level dan batas peta terbaca benar.
2. Data pulau dapat diserialisasi dan dipulihkan tanpa mengubah isi.
3. Ketiga mesh (`Ground`, `CliffFaces`, `GrassLips`) dihasilkan.
4. Normal tanah dan bibir rumput menghadap atas; normal dinding utara menghadap keluar.
5. Nilai offset pada sambungan antarunit tebing kontinu pada empat arah kardinal dan lima kedalaman dinding.
6. Dua collision shape dibuat dari terrain yang sama.
7. `tests/test_physics.gd` memeriksa raycast vertikal ke tanah dasar dan teras tinggi, serta raycast horizontal ke muka tebing.

Catatan penting: unit test menunjukkan struktur geometri dan normal dasar benar, **belum** menjamin penampilan sempurna, ketiadaan retak di sudut, atau perilaku karakter ketika bergerak.

**Visual QA:** `terrain_preview.png` berhasil dirender pada resolusi 1280×720 menggunakan backend OpenGL perangkat lunak. Bentuk bertingkat, wajah tebing, dan variasi bibir dapat terbaca. Kekurangan yang terlihat: sudut luar masih bersiku tajam, warna tanah menunjukkan petak grid, dan properti penunjuk skala sangat sederhana. Ini bukan target *art direction* akhir.

## 4. Protokol pengukuran ACNH berikutnya

| Eksperimen | Input yang dibutuhkan | Metrik | Kriteria selesai |
| --- | --- | --- | --- |
| T01 — dimensi sel | Capture top-down pulau dengan grid terukur | Rasio jarak dunia per unit grid | Rasio stabil di 3 lokasi |
| T02 — elevasi tebing | Capture samping dengan karakter pembanding; pengukuran layar | Rasio tinggi tebing terhadap lebar sel | Selisih estimasi di 3 contoh dicatat |
| T03 — sambungan tebing | 8 konfigurasi kontur manual dan capture konsisten | Tipe sisi, sudut dalam/luar, lengkungan | Atlas kasus tebing tersedia |
| T04 — semantik PBC | Salinan data milik sendiri yang diperoleh secara sah; pasangan state pulau sebelum/sesudah satu perubahan | Byte/float yang berubah, posisi record, determinisme | Hipotesis field dipisahkan dari bukti dan diuji silang |
| T05 — collision/probe | Karakter `CharacterBody3D` uji di Godot | Jarak tempuh, interpenetrasi, perilaku sudut | Tidak menembus dinding dalam lintasan tes |
| T06 — alur pulau | Sketsa Nusantara: pantai, sawah, kampung, bukit | Topologi traversable dan akses area | Peta konektivitas lolos pengecekan |

Untuk T04, simpan **metadata dan angka hasil ukur saja** dalam catatan riset; proyek publik Nusantara tidak membutuhkan model, tekstur, audio, atau file data game Nintendo.

## 5. Keputusan desain untuk game Nusantara

- Terrain memakai grid logis untuk gameplay, tetapi tampilan bebas memakai tepian organik dan mesh khusus bioma.
- Bentuk teras dapat dikembangkan menjadi **sawah sengkedan, tepian sungai, dan dataran kampung pesisir** tanpa mengikuti desain pulau ACNH.
- Navigasi dan fisika akan dikalibrasi terhadap rasa kontrol yang nyaman, bukan menyalin angka atau implementasi proprietary.
- Level data harus bisa disimpan dalam format orisinal (`schema_version`), agar riset PBC tetap menjadi referensi eksternal.

## 6. Batas versi ini

Belum ada pembuktian ukuran tile ACNH, decoder/renderer PBC produksi, atlas sudut, generasi aliran air, collider yang diuji dengan karakter, pengeditan pulau saat runtime, maupun penataan cerita/progresi. QA visual awal sudah tercatat, tetapi belum ada verifikasi interaksi karakter atau sudut pada semua topologi.

**Tahap selanjutnya:** prototipe sudut tebing (convex/concave), probe karakter berjalan dan berbenturan, kemudian eksperimen sungai dengan aturan aliran per level.
