# Sprint 04 — Kontur sungai global, bank collision, dan flow field

**Tanggal:** 2 November 2026. **Status:** Prototipe Godot 4.7.2 berhasil dijalankan; 6 pengujian otomatis lulus dan capture visual tersimpan.

## Pertanyaan riset

Bagaimana mempertahankan edit pulau berbasis petak tetapi menampilkan sungai melengkung antartile, sambil menjaga physics, arah aliran, dan air terjun mengambil topologi yang selaras?

**Dasar rujukan dan batas klaim:** Nintendo mendokumentasikan *Island Designer* untuk sungai, tebing, dan air terjun, tetapi **tidak membuka algoritma rendering, geometri, atau fisika internal**. Godot mendokumentasikan alat pembangunan mesh/shader/collider; implementasi di sini adalah **hipotesis rekayasa orisinal**.

- [Nintendo — Island Designer](https://play.nintendo.com/news-tips/tips-tricks/animal-crossing-new-horizons-discover-tips/)
- [Nintendo — Terraforming](https://www.nintendo.com/jp/ichikara/acbaa/03_en.html)
- [Godot 4.7 — SurfaceTool](https://docs.godotengine.org/en/4.7/classes/class_surfacetool.html)
- [Godot 4.7 — Spatial shaders](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/spatial_shader.html)
- [Godot 4.7 — ConcavePolygonShape3D](https://docs.godotengine.org/en/4.7/classes/class_concavepolygonshape3d.html)

## A. Scalar field dan kontur global

1. Topologi tetap disimpan sebagai `water[x,z]` dan `height[x,z]` yang terpisah.
2. Setiap pusat petak menjadi sampel occupancy biner bagi level elevasi yang sama.
3. Occupancy diinterpolasi antarpusat petak memakai *smoothstep bilinear* dan diberi sedikit variasi world-space.
4. Pulau disampel pada resolusi **12×12 sampel per tile**. Dua segitiga per sel dipotong terhadap ambang 0,5; segitiga hasil potong membentuk air, sedangkan segmen perpotongan menghasilkan bank.
5. Dasar tanah juga turun secara kontinu mendekati occupancy tinggi. Dengan koordinat dunia yang konsisten, tepi antarpetak tersambung tanpa mesh border per tile.

**Temuan visual:** `terrain_preview_sprint03.png` menunjukkan sungai bersudut seperti tangga; `terrain_preview.png` memperlihatkan belokan lebih halus pada sungai atas dan laguna bawah. Pada `waterfall_closeup.png`, bank masih memperlihatkan facet kecil, sehingga normal, triangulasi, dan material perlu iterasi.

## B. Arah arus dari graf topologi

1. Pilih satu petak air berlevel paling rendah sebagai outlet, dengan tie-break selatan/timur.
2. Hitung jarak graf di antara petak basah menggunakan BFS.
3. Pada tiap petak, pilih tetangga basah dengan elevasi **tidak lebih tinggi** dan jarak graf lebih pendek; bila tidak tersedia, vektor bernilai nol.
4. Interpolasi arah pada posisi dunia dan simpan dalam kanal warna vertex; shader memakai arah ini untuk mengadveksi noise.

Ini memberi animasi yang responsif terhadap denah, **bukan simulasi volume, debit, tekanan, atau kecepatan air yang dikalibrasi**. Peta multi-outlet, sungai terisolasi, serta pola aliran kompleks belum dipecahkan.

## C. Collision dan waterfall

- Collider dasar sungai kini mengikuti geometri dasar tanah yang menurun ke tepian.
- Bank mesh ditambahkan sebagai `StaticBody3D` dengan trimesh shape; raycast dalam tes mengenai node `RiverBankCollision`.
- `RiverContour.contains_water(Vector3)` dapat menguji basah/kering berdasarkan kurva kontur dan elevasi permukaan. Area trigger lama tetap kotak per tile untuk broadphase; gameplay belum memakai kueri presisi ini.
- Air terjun terdeteksi di perbatasan air level tinggi-rendah. Bukaan tirainya disesuaikan dengan kontur kedua sisi, dan foam kaki ditempatkan mendekati waterline. Bentuknya masih berupa lembaran tipis transparan.

## Pengujian aktual

| Tes | Hasil | Verifikasi utama |
| --- | --- | --- |
| `test_island.gd` | **PASS** | Fixture, mesh air, kontur, normal, collision, serialisasi |
| `test_physics.gd` | **PASS** | Raycast dasar tanah dan tebing |
| `test_character.gd` | **PASS** | Kapsul tertahan di bawah tebing |
| `test_composer.gd` | **PASS** | Brush elevasi/air, switch fixture, save/load |
| `test_editor_input.gd` | **PASS** | Edit melalui layar membangun ulang mesh dan air |
| `test_bank_collision.gd` | **PASS** | Kueri kontur, arah non-naik, dan raycast mengenai bank |

Capture berhasil pada Godot 4.7.2 memakai OpenGL/Mesa: `terrain_preview.png` dan `waterfall_closeup.png` (1280×720). GIF `water_motion.gif` berisi 12 frame 960×540. Perbandingan frame 0 dengan 10 melalui ImageMagick menemukan **14.731 piksel berubah**; metrik ini membuktikan shader bergerak, **bukan** ukuran kualitas artistik.

## Prioritas Sprint 05

1. **Gameplay tepi air:** kueri kontur presisi dipakai navigasi karakter; bedakan dangkal/dalam dan buat aturan tepi yang bisa diinjak.
2. **Air terjun:** curtain bervolume, splash dan foam lokal yang bergerak, kontak tebing, dan kolam bawah yang terlihat alami.
3. **Validasi topologi:** muara ganda, kolam buntu, lebar minimum, konektivitas sungai, serta area untuk jembatan.
4. **Editor:** brush pelebaran/persempitan sungai, preview kontur, undo/redo, dan umpan balik peraturan terrain.
5. **Identitas Nusantara:** aliran sungai tropis, teras sawah, mangrove, pesisir pasang-surut, dan permukiman tepi air orisinal.

## Kesimpulan

Kontur global, bank collision, serta arus terarah sudah cukup untuk menjadi fondasi eksperimen penataan pulau yang dapat diperluas. Kesamaan dengan ACNH masih sebatas **konsep dan fenomena visual yang bisa diamati**—bukan bukti rekonstruksi algoritma proprietary Nintendo.
