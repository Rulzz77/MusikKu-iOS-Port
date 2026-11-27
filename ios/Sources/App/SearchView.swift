import SwiftUI

struct SearchView: View {
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                        .foregroundStyle(MusikKuStyle.secondary)
                    Text("Cari lagu, artis, atau album")
                        .font(.subheadline)
                        .foregroundStyle(MusikKuStyle.secondary)
                    Spacer()
                }
                .padding(16)
                .background(MusikKuStyle.surface, in: RoundedRectangle(cornerRadius: 15))

                VStack(spacing: 14) {
                    Image(systemName: "music.mic")
                        .font(.system(size: 38))
                        .foregroundStyle(MusikKuStyle.accent)

                    Text("Pencarian belum aktif")
                        .font(.title3.bold())

                    Text("MusikKu belum terhubung ke penyedia katalog. Pencarian akan diaktifkan setelah API dan izin penggunaan streaming untuk aplikasi iOS dipastikan.")
                        .font(.subheadline)
                        .foregroundStyle(MusikKuStyle.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(MusikKuStyle.surface, in: RoundedRectangle(cornerRadius: 20))

                Spacer()
            }
            .padding(20)
            .background(MusikKuStyle.background.ignoresSafeArea())
            .navigationTitle("Cari Musik")
        }
    }
}
