# Nusantara World Lab — Sprint 39–42: Continuous Shore + Geometry-refined Surf

**Status:** perubahan kode sudah diterapkan; kualitas visual 3D dan collision aktual masih **belum diverifikasi dengan Godot**. Tanggal checkpoint: 2026-11-03 (Asia/Jakarta).

## Sasaran

1. Menghilangkan pengulangan pola bibir pantai yang kembali ke bentuk grid pada setiap ujung tile.
2. Mengikat kontur daratan, gradien pasir, dan fase pecah ombak pada satu sumber posisi geometri yang konsisten.
3. Mempertahankan sifat deterministik dan tidak membuat penghubung darat melintasi sungai/muara.

## Implementasi Sprint 39: relief pesisir lintas-tile

File: `scripts/coast_contour.gd`.

Masalah sebelumnya: `sin(pi * t)` selalu menuju nol di kedua ujung tile. Untuk segmen panjang, hasilnya terlihat sebagai deretan busur identik dan agak mekanis.

Kini `CoastContour._mask_seam_offset` menggunakan:

- `_same_vertical_bank` dan `_same_horizontal_bank` untuk memastikan kedua segmen tetangga benar-benar memiliki klasifikasi darat–laut yang **sama orientasi**.
- `_coherent_seam_wave` memadukan hump lokal berbasis `sin²(pi*t)` (nilai **dan turunan** mendekati nol pada ujung) dengan dua gelombang frekuensi dunia yang berkelanjutan melintasi tile.
- Kontribusi gelombang panjang hanya aktif hingga titik sambung yang didukung shoreline konsisten. Ujung celah atau muara tidak diberi displacement paksa.
- `RiverContour.field_at` tetap mengatur `dry_strength` sehingga di outlet basah deformasi mereda sebagaimana desain sebelumnya.

Ini masih mesh topologi tile yang di-*warp*, **bukan** kontur bebas yang dihasilkan dari ekstraksi global atau rumus asli ACNH. Hasil referensi 2D: `s42_coherent_coastline_diagnostic.png`, dengan skala deviasi X diperbesar untuk memudahkan melihat perbedaan.

## Implementasi Sprint 40: ombak dan pasir memakai geometri sejenis

File: `scripts/coast_builder.gd`.

Sebelumnya `make_signed_coast_texture` menggunakan *separable Euclidean distance transform* (EDT) terhadap batas klasifikasi raster `CoastContour.on_island`; jarak pasir memakai cache polyline bentuk shoreline 3D. Kedua hasil dapat selisih sekitar resolusi satu piksel SDF, terutama di lengkung teluk.

Kini:

1. EDT lama tetap dihitung cepat untuk seluruh tekstur 256×256.
2. Bila jarak raster kurang dari **3,85 unit**, pantai ditanyakan ke `CoastContour.distance_to_coast`, yang membaca cache segmen skirt/arc/fillet dari Sprint 38.
3. Pada pita hingga **2,10 unit** dari garis pantai, shader mendapat jarak yang dihaluskan dari segmen geometri; di luar pita tersebut hasil di-*blend* secara mulus kembali ke EDT.
4. Tanda negatif/positif SDF tetap berasal dari `CoastContour.on_island`, sehingga status darat–air tidak diubah oleh sekadar perubahan warna atau jarak.

Dengan demikian sistem ombak depan dan *backwash* dari Sprint 32 masih berlaku, tetapi jarak penggeraknya lebih sejalan dengan pembentuk pasir dan mesh. Ini adalah **perbaikan jarak untuk shader yang sudah ada**, bukan implementasi simulasi fluida ataupun bukti paritas ACNH.

## Sprint 41: regresi dan perlindungan edit

- `tests/test_s42_coherent_shore.gd` memverifikasi nilai displacement kontinu pada sambungan antar tile dengan bank yang sama, ujung pantai terputus tetap di tempat, dan area surf mendapat nilai SDF mendekati jarak segmen geometri.
- `tests/test_s42_offline.py` membandingkan turunan kiri/kanan fungsi kontinuitas dengan 100 fase acak; menguji nilai batas tak didukung; memeriksa fungsi interpolasi SDF area ombak; dan inspeksi struktur kode integrasi.
- Semua tes sebelumnya dan sumber RE asli tetap dalam proyek.

## Sprint 42: review visual diagnostik dan konsistensi HUD

- `README.md`, nama `project.godot`, dan `scripts/main.gd` disinkronkan ke **Sprint 42**; `tests/test_probe_ui.gd` menyesuaikan ekspektasi string HUD.
- `s42_coherent_coastline_diagnostic.png` adalah gambar diagnostik CPU untuk membandingkan pengulangan gelombang tiap tile versus gelombang panjang multi-tile. Skala deformasi lateral sengaja diperbesar. **Bukan screenshot render Godot dan bukan capture ACNH.**

## Hasil uji yang sungguh dilaksanakan

```
python3 -m unittest discover -s tests -p 'test*offline.py' -v
```

Hasil: **19/19 tes Python offline PASS** (7 dari Sprint 32; 4 Sprint 35; 4 Sprint 38; 4 Sprint 42). Gambar diagnostik diperiksa secara visual. ZIP final diuji dengan `unzip -tq`.

**38 skrip tes `tests/test_*.gd` masih belum dijalankan**, termasuk tes GDScript baru. Godot CLI/GPU render tidak terpasang dalam lingkungan eksekusi. Di mesin yang memiliki Godot 4.7+:

```
godot --headless --path . --script res://tests/test_s42_coherent_shore.gd
godot --headless --path . --script res://tests/test_s38_shoreline_cache.gd
godot --headless --path . --script res://tests/test_concave_fillet.gd
godot --headless --path . --script res://tests/test_island_mask.gd
godot --headless --path . --script res://tests/test_probe_ui.gd
```

Setelah itu jalankan semua skrip tes satu per satu, lalu capture nyata (kamera tetap, jam air sama) untuk membandingkan scene teluk, garis lurus panjang, kepala pulau, mulut sungai, air terjun, dan gerakan karakter menuju pantai. Audit shader tanpa cuplikan 3D belum cukup.

## Sumber RE dan provenance

Riset implementasi tetap melacak repository pengguna [`menuyul312-max/acnh-re-results`](https://github.com/menuyul312-max/acnh-re-results), terutama [`TERRAIN_RUNTIME.md`](https://github.com/menuyul312-max/acnh-re-results/blob/main/acnh-re/docs/TERRAIN_RUNTIME.md) dan ringkasan `RE_ADOPTION_REPORT_S29_32.md` untuk bukti koordinat, sektor ground, overlay dan landmaking.

**Batas informasi:** dokumen RE yang tersedia **tidak membuktikan** bahwa formula noise lintas-tile atau teknik SDF ini dipakai oleh game ACNH. Implementasi dalam Godot dibuat independen dan menghasilkan rancangan Nusantara orisinal.

## Gap utama untuk sprint berikutnya

1. **Siluet masih tile-based.** Perlu *contour extraction* global multi-ring, triangulasi permukaan pantai yang tidak menambahkan lubang, dan collision yang dibangun dari kontur sama.
2. **Akurasi fisika belum teruji.** Targetkan raycast dan gerak `CharacterBody3D` pada sambungan tile, curved fillet, tebing air, dan waterfall.
3. **Performa shader rebuild belum terukur.** Geometric SDF hanya aktif pada *narrow band*, tetapi profil pada map besar dan brush 3×3 tetap diperlukan. Cache bisa diperbarui memakai *dirty rectangles* jika perlu.
4. **Gelombang masih stylized**, belum simulasi pecahan gelombang 3D, turbulensi bawah air terjun, atau pantai basah berlapis. Butuh referensi video/capture dan iterasi kualitas.
5. **Visual parity tidak dapat diklaim.** Parameter ukuran tile dan fisika adalah pilihan prototipe Nusantara, bukan nilai terverifikasi dari reverse engineering.
