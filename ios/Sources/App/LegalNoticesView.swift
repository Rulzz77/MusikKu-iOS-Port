import SwiftUI

struct LegalNoticesView: View {
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Tentang MusikKu") {
                    HStack(spacing: 13) {
                        Image(systemName: "waveform")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(MusikKuStyle.accent)
                            .frame(width: 46, height: 46)
                            .background(MusikKuStyle.accent.opacity(0.16), in: RoundedRectangle(cornerRadius: 13))

                        VStack(alignment: .leading, spacing: 3) {
                            Text("MusikKu")
                                .font(.headline)
                            Text("Music for your moment")
                                .font(.caption)
                                .foregroundStyle(MusikKuStyle.secondary)
                            Text("Versi \(appVersion)")
                                .font(.caption2)
                                .foregroundStyle(MusikKuStyle.secondary)
                        }
                    }
                    .padding(.vertical, 5)

                    Text("MusikKu merupakan perangkat lunak bebas yang disediakan tanpa jaminan selain yang diwajibkan oleh hukum.")
                        .font(.footnote)
                        .foregroundStyle(MusikKuStyle.secondary)
                }

                Section("Lisensi perangkat lunak") {
                    NavigationLink {
                        BundledLegalDocumentView(
                            title: "GNU GPL versi 3",
                            resourceName: "GPL-3.0",
                            fileExtension: "txt"
                        )
                    } label: {
                        Label("Baca lisensi GNU GPL-3.0", systemImage: "doc.text")
                    }

                    NavigationLink {
                        BundledLegalDocumentView(
                            title: "Atribusi pihak ketiga",
                            resourceName: "THIRD_PARTY_NOTICES",
                            fileExtension: "md"
                        )
                    } label: {
                        Label("Atribusi dan lisensi pihak ketiga", systemImage: "list.bullet.rectangle")
                    }
                }

                Section {
                    Text("Playlist, favorit, dan riwayat pemutaran disimpan secara lokal di perangkat. Lihat kebijakan privasi resmi sebelum rilis publik.")
                        .font(.footnote)
                        .foregroundStyle(MusikKuStyle.secondary)
                } header: {
                    Text("Privasi")
                }
            }
            .scrollContentBackground(.hidden)
            .background(MusikKuStyle.background.ignoresSafeArea())
            .navigationTitle("Tentang & Lisensi")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct BundledLegalDocumentView: View {
    let title: String
    let resourceName: String
    let fileExtension: String

    @State private var documentText = ""
    @State private var loadFailed = false

    var body: some View {
        Group {
            if !documentText.isEmpty {
                ScrollView {
                    Text(documentText)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(16)
                }
            } else if loadFailed {
                VStack(spacing: 10) {
                    Image(systemName: "doc.questionmark")
                        .font(.largeTitle)
                        .foregroundStyle(MusikKuStyle.secondary)
                    Text("Dokumen lisensi tidak dapat dibuka.")
                        .font(.subheadline)
                    Text("Silakan periksa kembali paket aplikasi.")
                        .font(.caption)
                        .foregroundStyle(MusikKuStyle.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView("Memuat dokumen…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(MusikKuStyle.background.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard documentText.isEmpty, !loadFailed,
                  let url = Bundle.main.url(forResource: resourceName, withExtension: fileExtension),
                  let value = try? String(contentsOf: url, encoding: .utf8) else {
                loadFailed = true
                return
            }
            documentText = value
        }
    }
}
