# Nusantara World Lab — Sprint 33–35: Concave Inlet / Smooth Shoreline

Status: **implemented prototype; not yet 3D runtime validated**. Date: 2026-11-03 (Asia/Jakarta).

## Tujuan

Sprint sebelumnya menyimpan pulau sebagai mask tile yang dapat diedit, dengan 4× terrain ground contract dan dua strip ombak. Kelemahan visual dominan yang tersisa adalah teluk yang membentuk sudut siku-siku di pertemuan dua tile. Versi ini membuat *reentrant inlet* berisi tambalan kecil berkurva, menjaga grounding gerak/collision seragam, dan memperbaiki kualitas jarak untuk buih laut. Ini **prototipe renderer Godot Nusantara**, bukan algoritme atau aset hasil dump game.

## Implementasi

### Sprint 33 — triangulasi concave inlet

- `scripts/terrain_builder.gd`: konstanta `INLET_FILLET_RADIUS` (0,72 unit prototipe, tile 2,1); cek ` _is_concave_mask_corner` pada sel `land_mask=0`.
- Fillet hanya dibangun jika **tiga penopang** (tetangga X, tetangga Z, dan diagonal) semuanya land level-0 dan kering; menghindari jembatan tanpa sengaja pada muara sungai, air, atau tebing tinggi.
- Titik kurva mengikuti quarter-circle pada bidang XZ. Segitiga kipas di-warp dengan `_ground_point` sehingga cocok dengan model relief. Segitiga ditambahkan langsung ke `ground_tool`, lalu `ground_mesh.create_trimesh_shape()` membangun collision dari mesh yang identik.
- `MaskedShoreSkirts` memakai arc fillet, sedangkan skirt pantai dua sisi dipangkas pada titik pertemuan. Tujuannya mengurangi garis L yang sebelumnya tampak melewati lereng pasir.

### Sprint 34 — distance field Euklides

- `scripts/coast_builder.gd`: `make_signed_coast_texture()` mengambil klasifikasi raster dari `CoastContour.on_island()` lalu menjalankan *separable Euclidean distance transform* horizontal dan vertikal. Kompleksitas **O(N²)** untuk citra N×N (sebelumnya pendekatan chamfer).
- Hasilnya adalah jarak Euclidean ke **sampel batas raster**, diberi koreksi setengah piksel. Ini **bukan** jarak eksak ke garis polycurve kontinyu.
- Format `Image.FORMAT_RF` dipertahankan sehingga `OCEAN_SHADER` dual-breaker versi Sprint 32 menerima data tanpa migrasi texture/saved game.

### Sprint 35 — traversal, regresi dan review

- `scripts/coast_contour.gd`: apabila titik berada pada missing mask cell, pemeriksa menguji titik terhadap segitiga fillet yang **sama** dengan ground mesh (`TerrainBuilder.on_concave_fillet`). Dengan demikian terrain yang terlihat dan dapat ditabrak tidak diklasifikasikan sebagai laut begitu saja.
- `tests/test_concave_fillet.gd`: memeriksa sampel transformasi jarak, empat sudut inlet terisolasi, ada/tidaknya land di dekat sudut versus tengah air, mesh collision aktual, dan larangan bridging bila tetangga menjadi sungai.
- `tests/test_s35_offline.py`: 4 pengujian matematika dan struktur, serta generator diagram `s35_fillet_topdown_schematic.png`.
- HUD dan nama project sudah disinkronkan ke `WORLD LAB 35`, termasuk ekspektasi pada `test_probe_ui.gd`.

## Diagram topologi, bukan capture dari Godot

Lihat `s35_fillet_topdown_schematic.png`. Hijau menunjukkan daratan, biru laut, kuning patch kecil di sudut teluk. Diagram tersebut dihitung dari rumus geometri secara CPU dengan PIL, **tidak boleh dibaca sebagai screenshot rendering 3D**.

## Audit sumber RE ACNH

Rujukan utama proyek: [`menuyul312-max/acnh-re-results`](https://github.com/menuyul312-max/acnh-re-results), terutama [`acnh-re/docs/TERRAIN_RUNTIME.md`](https://github.com/menuyul312-max/acnh-re-results/blob/main/acnh-re/docs/TERRAIN_RUNTIME.md). Riset RE Sprint 29–32 membedakan bukti *native coordinate*, sub-sektor ground empat segitiga, overlay, dan landmaking dari keputusan desain visual Nusantara. **Tidak ditemukan validasi yang cukup untuk menyatakan fillet pantai dan transformasi jarak baru adalah rumus asli Nintendo.** Catatan koordinat/ground tetap mengikuti batasan di `RE_ADOPTION_REPORT_S29_32.md`.

## Pengujian yang benar-benar dilakukan

Perintah yang berhasil di sesi ini:

```
python3 -m unittest discover -s tests -p 'test*offline.py' -v
```

Hasil: **11/11 PASS** (7 pengujian kontrak RE terdahulu + 4 pengujian matematis/struktural baru). Generator diagram juga berhasil dan hasil PNG diperiksa.

Pengujian yang **belum** dilakukan: **36 skrip `tests/test_*.gd`**, termasuk `test_concave_fillet.gd`, karena Godot CLI/runtime dan tampilan 3D tidak tersedia di lingkungan sesi ini. Oleh sebab itu **belum ada klaim pass runtime Godot, frame rate, atau visual parity ACNH**.

Saat tersedia Godot 4.7+, jalankan minimal:

```
godot --headless --path . --script res://tests/test_concave_fillet.gd
godot --headless --path . --script res://tests/test_island_mask.gd
godot --headless --path . --script res://tests/test_probe_ui.gd
```

Kemudian jalankan semua `tests/test_*.gd` pada runner CI dan bandingkan capture top-down/oblique dengan referensi video milik sendiri. Penting memeriksa jalinan mesh di batas fillet–skirt, terutama pada tikungan tajam dan bibir sungai.

## Masalah yang masih ada — bukan selesai

1. **Grid masih terlihat** di segmen pantai lurus: fillet baru hanya pada sudut cekung yang memenuhi tiga penopang kering. Solusi mendatang: contour extraction per kepulauan dan spline/dual contour surface dengan *collision rebuilt* dari kurva.
2. **Tidak ada QA 3D aktual** untuk mesh normal, culling, shader biru laut, depth and foam, overdraw, dan potensi *micro-cracks* saat edge warp berubah. Tambahkan capture real frame dan physics queries, bukan hanya diagram.
3. **SDF tetap terdiskretisasi:** kualitas ombak dekat bay mengikuti raster 256×256; zoom ekstrim dapat memperlihatkan langkah piksel. Perlu pemilihan resolusi adaptif dan perbandingan *temporal aliasing*.
4. **Performansi belum diprofil:** query titik terhadap segitiga fillet menggunakan rekonstruksi vertex; peta besar dapat membutuhkan cache `CurveFootprint`/BSP dan invalidasi per brush mutation.
5. **Tata pulau dan fisika belum dapat dinyatakan setara ACNH:** hanya batas fisika dan topologi yang didekati secara observasional, bukan port source code; angka tile dan radius tetap orisinal.

## Prioritas berikutnya

1. Jalankan Godot + semua tes, simpan tangkapan kamera identik dan audit mesh seam berpixel tinggi.
2. Tambahkan pengukuran profil CPU saat editor brush 3×3 dan regenerasi signed distance texture.
3. Bangun contour global multi-ring, tanpa kasus khusus 3 penopang, lalu integrasikan triangulasi dengan collision/traversal dan efek buih.
4. Setelah kontur valid, kalibrasi pantai berpasir, *waterline*, gelombang pecah, aliran muara, dan tumpuan air terjun dari capture observasi ACNH yang sah, sambil menjaga visual Nusantara tetap orisinal.
