# Kebijakan Privasi MusikKu iOS

**Status dokumen:** draf untuk ditinjau sebelum publikasi  
**Tanggal pembaruan:** 27 November 2026  
**Pengelola aplikasi:** [isi nama pengembang atau badan usaha]  
**Kontak privasi:** [isi alamat email dukungan/privasi]

Kebijakan ini menjelaskan data yang diproses MusikKu iOS, penyedia eksternal yang dihubungi aplikasi, dan pilihan pengguna. Dokumen ini belum menjadi kebijakan final sampai identitas pengelola, kontak, praktik penyedia terkini, dan jawaban App Privacy di App Store Connect diverifikasi.

## 1. Ringkasan

MusikKu iOS adalah aplikasi musik yang saat ini beroperasi tanpa akun MusikKu dan tanpa sinkronisasi cloud milik MusikKu. Playlist lokal, lagu disukai, riwayat dengar, statistik pemutaran, preferensi pemutar, dan file lirik TTML yang diimpor disimpan di perangkat.

Untuk menyediakan katalog, metadata playlist, lirik, terjemahan, dan streaming, aplikasi mengirim permintaan ke layanan pihak ketiga. Layanan tersebut dapat menerima alamat IP, informasi permintaan, dan data lagu/playlist yang diperlukan untuk melayani permintaan. Praktik penyimpanan dan pemrosesan setelah permintaan selesai mengikuti kebijakan masing-masing penyedia.

MusikKu tidak sengaja mengirim cookie akun Google/YouTube atau cookie akun Spotify. Resolver iOS menggunakan sesi HTTP terisolasi; provider Webpage Attestation menolak cookie akun dan hanya menggunakan preferensi consent statis. Token attestation berumur pendek disimpan di memori selama dibutuhkan dan tidak disimpan ke penyimpanan permanen aplikasi.

## 2. Data yang disimpan di perangkat

Aplikasi dapat menyimpan:
- Playlist yang dibuat pengguna dan daftar lagu di dalamnya.
- Lagu favorit/disukai.
- Riwayat pemutaran, jumlah pemutaran, waktu terakhir diputar, dan statistik durasi dengar.
- Riwayat pencarian lokal.
- Aturan Mix Cerdas/Smart Playlist.
- Preferensi kecepatan pemutaran, mode ulang, dan pengaturan timer.
- File lirik TTML yang secara eksplisit diimpor pengguna, beserta metadata track yang diperlukan untuk mengaitkannya.

Data tersebut disimpan di ruang privat aplikasi pada perangkat, termasuk UserDefaults dan direktori dokumen aplikasi. Data lokal ini tidak disinkronkan ke server MusikKu. Pengguna dapat menghapus item melalui fitur aplikasi yang tersedia atau menghapus aplikasi untuk menghapus penyimpanan lokalnya.

## 3. Layanan pihak ketiga dan data yang dikirim

### YouTube dan YouTube Music

Saat pengguna mencari katalog, membuka halaman musik, atau memutar lagu, aplikasi dapat mengirim:
- Kata atau frasa pencarian.
- ID video/lagu dan informasi konteks permintaan yang diperlukan untuk menemukan atau memutar media.
- Bahasa, wilayah, versi client, dan informasi permintaan teknis.
- Untuk alur resolver, visitor data dan token teknis berumur pendek yang diperlukan oleh layanan untuk memproses permintaan playback.

Permintaan jaringan juga secara normal mengungkap alamat IP dan user-agent kepada layanan tujuan. Aplikasi menggunakan endpoint InnerTube/WEB_REMIX dan resolver teknis; integrasi ini bukan pemutar embed resmi YouTube. Tinjau ketentuan YouTube dan persyaratan hak konten sebelum menggunakan atau mendistribusikan aplikasi.

Informasi layanan:
- YouTube Terms: https://www.youtube.com/t/terms
- Google Privacy Policy: https://policies.google.com/privacy

### Spotify

Saat pengguna memilih impor playlist Spotify publik, aplikasi membaca ID playlist dari tautan yang ditempel dan meminta metadata dari halaman embed publik Spotify. Informasi playlist dan metadata track yang tersedia (misalnya judul, artis, album, durasi, serta ID track) digunakan untuk mencocokkan lagu pada katalog MusikKu. Aplikasi tidak meminta login Spotify dan tidak sengaja mengirim cookie akun Spotify.

Informasi layanan:
- Spotify Privacy: https://www.spotify.com/legal/privacy-policy/
- Spotify Terms: https://www.spotify.com/legal/end-user-agreement/

### Penyedia lirik

Saat pengguna meminta lirik, aplikasi dapat mengirim judul lagu, nama artis, album (bila ada), durasi, atau ISRC untuk mencari kecocokan ke penyedia yang tersedia:
- lrc.red — https://lrc.red/
- BiniLyrics — https://lyrics-api.binimum.org/
- BetterLyrics — https://lyrics-api.boidu.dev/
- LRCLIB — https://lrclib.net/

Penyedia dapat mengembalikan lirik tersinkronisasi, lirik biasa, atau metadata kecocokan. Lirik yang diimpor dari file TTML pengguna diproses lokal oleh aplikasi dan tidak diunggah oleh fitur impor tersebut.

### Terjemahan lirik

Hanya ketika pengguna secara aktif meminta terjemahan, teks lirik yang dipilih dikirim ke endpoint Google Translate yang digunakan aplikasi untuk menghasilkan terjemahan. Terjemahan disimpan sementara dalam cache memori selama aplikasi berjalan; aplikasi tidak menyinkronkannya ke akun MusikKu.

Informasi layanan:
- Google Privacy Policy: https://policies.google.com/privacy

### Gambar sampul

Aplikasi dapat memuat thumbnail/sampul dari URL yang dikembalikan layanan katalog. Permintaan gambar mengungkap alamat IP dan informasi teknis standar kepada host gambar yang digunakan.

## 4. Iklan, analitik, pelacakan dan backend

Pada versi source yang ditinjau untuk draf ini:
- Tidak ada SDK iklan atau analitik pihak ketiga yang sengaja ditambahkan.
- Tidak ada akun MusikKu, backend MusikKu, atau sinkronisasi cloud untuk playlist/riwayat.
- Riwayat dan playlist lokal tidak dikirim ke server MusikKu.
- Permintaan katalog, lirik, terjemahan, gambar, dan resolver tetap dikirim ke penyedia terkait seperti dijelaskan di atas.

Pernyataan ini harus ditinjau ulang jika SDK, layanan backend, telemetri, crash reporting, atau fitur akun ditambahkan pada versi berikutnya.

## 5. Retensi dan penghapusan

Data lokal disimpan sampai pengguna menghapusnya melalui aplikasi, menghapus file lirik yang diimpor, membersihkan riwayat, atau menghapus aplikasi. Penghapusan lokal tidak menghapus data yang mungkin sudah diproses atau disimpan oleh penyedia pihak ketiga sesuai kebijakan mereka.

MusikKu tidak mengendalikan jangka waktu retensi, proses penghapusan, atau permintaan privasi di layanan pihak ketiga. Untuk permintaan tersebut, pengguna perlu menghubungi penyedia yang bersangkutan melalui kebijakan privasi/halaman dukungannya.

## 6. Keamanan

Aplikasi menggunakan HTTPS untuk endpoint layanan yang dikonfigurasi sebagai HTTPS. Sesi katalog/Spotify dan resolver iOS dibuat terisolasi dari cookie bersama Safari; resolver dan provider token tidak menggunakan cookie akun. Token playback/attestation yang sensitif tidak dimaksudkan untuk dicatat dalam log atau disimpan permanen.

Tidak ada sistem yang dapat menjamin keamanan mutlak. Pengguna sebaiknya memperbarui aplikasi dan sistem operasi ke versi yang didukung.

## 7. Anak-anak

MusikKu tidak dirancang sebagai layanan akun anak atau layanan khusus anak. Pengelola perlu meninjau persyaratan usia dan aturan perlindungan anak di wilayah distribusi sebelum publikasi.

## 8. Perubahan kebijakan

Kebijakan ini dapat diperbarui bila fitur, penyedia eksternal, atau praktik pemrosesan data berubah. Tanggal pembaruan akan dicantumkan di bagian atas dokumen.

## 9. Kontak

Untuk pertanyaan atau permintaan terkait praktik privasi MusikKu, hubungi:

**[isi alamat email dukungan/privasi sebelum rilis]**

Jangan publikasikan dokumen ini sebelum placeholder identitas pengelola dan alamat kontak diisi, isi diperiksa secara hukum/kebijakan, serta URL publiknya ditautkan dari aplikasi dan App Store Connect.
