import SwiftUI

struct PlayerSettingsView: View {
    @EnvironmentObject private var playback: PlaybackManager
    @Environment(\.dismiss) private var dismiss

    private let sleepOptions = [15, 30, 45, 60]
    @State private var customSleepMinutes = 30

    var body: some View {
        NavigationStack {
            Form {
                Section("Kecepatan pemutaran") {
                    Picker(
                        "Kecepatan",
                        selection: Binding(
                            get: { playback.playbackSpeed },
                            set: { playback.setPlaybackSpeed($0) }
                        )
                    ) {
                        ForEach(PlaybackManager.availablePlaybackSpeeds, id: \.self) { speed in
                            Text(speedLabel(speed)).tag(speed)
                        }
                    }
                    .pickerStyle(.menu)

                    Text("Kecepatan diterapkan langsung ke AVPlayer dan disimpan di perangkat ini.")
                        .font(.footnote)
                        .foregroundStyle(MusikKuStyle.secondary)
                }

                Section("Pengulangan") {
                    Picker(
                        "Mode pengulangan",
                        selection: Binding(
                            get: { playback.repeatMode },
                            set: { playback.setRepeatMode($0) }
                        )
                    ) {
                        ForEach(PlaybackRepeatMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Timer tidur") {
                    if let endDate = playback.sleepTimerEndDate {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            let seconds = max(0, Int(endDate.timeIntervalSince(context.date)))
                            HStack {
                                Label("Pemutaran berhenti dalam", systemImage: "moon.zzz")
                                Spacer()
                                Text(timeLabel(seconds))
                                    .font(.body.monospacedDigit().weight(.semibold))
                                    .foregroundStyle(MusikKuStyle.accent)
                            }
                        }
                        Button("Batalkan timer", role: .destructive) {
                            playback.cancelSleepTimer()
                        }
                    } else if playback.sleepTimerAfterTrack {
                        Label("Berhenti setelah lagu ini selesai", systemImage: "moon.zzz")
                            .foregroundStyle(MusikKuStyle.accent)
                        Button("Batalkan timer", role: .destructive) {
                            playback.cancelSleepTimer()
                        }
                    } else {
                        Text("Pilih preset atau atur durasi hingga 12 jam (kelipatan 5 menit).")
                            .font(.footnote)
                            .foregroundStyle(MusikKuStyle.secondary)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(sleepOptions, id: \.self) { minutes in
                                Button {
                                    playback.setSleepTimer(minutes: minutes)
                                } label: {
                                    Text("\(minutes)m")
                                        .font(.subheadline.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 11)
                                        .background(MusikKuStyle.surfaceVariant, in: RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Durasi kustom")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text("\(customSleepMinutes) menit")
                                    .font(.caption.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(MusikKuStyle.accent)
                            }
                            Slider(
                                value: Binding(
                                    get: { Double(customSleepMinutes) },
                                    set: { customSleepMinutes = Int(($0 / 5).rounded()) * 5 }
                                ),
                                in: 5...720,
                                step: 5
                            )
                            Button("Mulai timer kustom") {
                                playback.setSleepTimer(minutes: customSleepMinutes)
                            }
                            .font(.subheadline.weight(.semibold))
                            .buttonStyle(.borderedProminent)
                            .tint(MusikKuStyle.accent)
                        }

                        Button {
                            playback.setSleepTimerAfterTrack()
                        } label: {
                            Label("Setelah lagu ini selesai", systemImage: "music.note")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.top, 2)
                    }

                    Toggle(
                        "Fade out 30 detik",
                        isOn: Binding(
                            get: { playback.sleepTimerFadeOutEnabled },
                            set: { playback.setSleepTimerFadeOutEnabled($0) }
                        )
                    )
                }

                Section {
                    Label("Semua pengaturan ini diterapkan pada pemutar iOS. Equalizer dan DSP lanjutan belum diaktifkan.", systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(MusikKuStyle.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(MusikKuStyle.background)
            .navigationTitle("Pengaturan Pemutar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Selesai") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func speedLabel(_ speed: Double) -> String {
        let value = speed == speed.rounded()
            ? String(Int(speed))
            : String(speed)
        return "\(value)×"
    }

    private func timeLabel(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
