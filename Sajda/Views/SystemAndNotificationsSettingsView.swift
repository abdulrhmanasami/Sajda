
import SwiftUI
import NavigationStack

struct SystemAndNotificationsSettingsView: View {
    static let id = "SystemAndNotificationsSettingsStack"

    @EnvironmentObject var vm: PrayerTimeViewModel
    @EnvironmentObject var navigationModel: NavigationModel
    
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("isPrayerTimerEnabled") private var isPrayerTimerEnabled = false
    @AppStorage("prayerTimerDuration") private var prayerTimerDuration = 5
    @State private var isHeaderHovering = false

    private var viewWidth: CGFloat {
        return vm.useCompactLayout ? 220 : 260
    }

    var body: some View {
        NavigationStackView(Self.id) {
            VStack(alignment: .leading, spacing: 6) {
                Button(action: {
                    navigationModel.hideView(SettingsView.id, animation: vm.backwardAnimation())
                }) {
                    HStack {
                        Image(systemName: "chevron.left").font(.body.weight(.semibold))
                        Text("System & Notifications").font(.body).fontWeight(.bold)
                        Spacer()
                    }
                    .padding(.vertical, 5).padding(.horizontal, 8)
                    .background(isHeaderHovering ? Color("HoverColor") : .clear).cornerRadius(5)
                }.buttonStyle(.plain).padding(.horizontal, 5).padding(.top, 2).onHover { hovering in isHeaderHovering = hovering }
                
                Rectangle()
                    .fill(Color("DividerColor"))
                    .frame(height: 0.5)
                    .padding(.horizontal, 12)

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Group {
                            Text("System").font(.caption).foregroundColor(Color("SecondaryTextColor"))
                            StyledToggle(label: "Run at Login", isOn: $launchAtLogin)
                                .onChange(of: launchAtLogin) { newValue in
                                    StartupManager.toggleLaunchAtLogin(isEnabled: newValue)
                                }
                            
                            HStack {
                                Text("Animation Style").font(.subheadline)
                                Spacer()
                                Picker("", selection: $vm.animationType) {
                                    ForEach(AnimationType.allCases) { type in
                                        Text(type.localized).tag(type)
                                    }
                                }.fixedSize()
                            }
                        }

                        Rectangle()
                            .fill(Color("DividerColor"))
                            .frame(height: 0.5)
                        
                        Group {
                            Text("Notifications").font(.caption).foregroundColor(Color("SecondaryTextColor"))
                            StyledToggle(label: "Prayer Notifications", isOn: $vm.isNotificationsEnabled)
                            
                            VStack(alignment: .leading, spacing: 10) {
                                HStack { Text("Notification Sound").font(.subheadline); Spacer(); Picker("", selection: $vm.adhanSound) { ForEach(AdhanSound.allCases) { sound in Text(sound.rawValue).tag(sound) } }.fixedSize() }
                                if vm.adhanSound == .custom {
                                    HStack { Text("Custom File").font(.subheadline); Spacer(); Button("Browse...") { vm.selectCustomAdhanSound() } }
                                    Text(URL(string: vm.customAdhanSoundPath)?.lastPathComponent ?? NSLocalizedString("No file selected", comment: ""))
                                        .font(.caption)
                                        .foregroundColor(Color("SecondaryTextColor"))
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                            }.disabled(!vm.isNotificationsEnabled)
                        }

                        Rectangle()
                            .fill(Color("DividerColor"))
                            .frame(height: 0.5)
                        
                        Group {
                            Text("Persistent Adhan").font(.caption).foregroundColor(Color("SecondaryTextColor"))
                            StyledToggle(label: "Enable Persistent Adhan", isOn: $vm.isPersistentAdhanEnabled)
                            
                            if vm.isPersistentAdhanEnabled {
                                HStack {
                                    Text("Override Volume").font(.subheadline)
                                    Spacer()
                                    Text("\(Int(vm.persistentAdhanVolume * 100))%")
                                        .font(.caption)
                                        .foregroundColor(Color("SecondaryTextColor"))
                                        .frame(width: 35, alignment: .trailing)
                                }
                                Slider(value: $vm.persistentAdhanVolume, in: 0.1...1.0, step: 0.05)
                                    .controlSize(.small)
                                
                                Text("Adhan will play at full volume, override mute, prevent sleep, and stop on any key press")
                                    .font(.caption)
                                    .foregroundColor(Color("SecondaryTextColor"))
                            }
                        }

                        Rectangle()
                            .fill(Color("DividerColor"))
                            .frame(height: 0.5)

                        Group {
                            Text("Prayer Timer").font(.caption).foregroundColor(Color("SecondaryTextColor"))
                            StyledToggle(label: "Enable Prayer Timer", isOn: $isPrayerTimerEnabled)
                            
                            if isPrayerTimerEnabled {
                                HStack {
                                    Text("Alert After").font(.subheadline)
                                    Spacer()
                                    Stepper("\(prayerTimerDuration) min", value: $prayerTimerDuration, in: 1...30)
                                        .fixedSize()
                                }
                                Text("Shows an alert after prayer time has passed")
                                    .font(.caption)
                                    .foregroundColor(Color("SecondaryTextColor"))
                            }
                        }
                    }
                    .controlSize(.small)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .scrollIndicators(.hidden)
            }
            .padding(.vertical, 8)
            .frame(width: viewWidth)
        }
    }
}
