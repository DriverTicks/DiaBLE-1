import Foundation
import SwiftUI


struct SettingsView: View {
    @EnvironmentObject var app: DiaBLEAppState
    @EnvironmentObject var settings: Settings

    @State private var showingCalendarPicker = false


    var body: some View {

        NavigationView {
            VStack {

                Spacer()

                VStack(spacing: 20) {
                    VStack {
                        HStack(spacing: 0) {
                            Button(action: {} ) { Image("Bluetooth").resizable().frame(width: 32, height: 32) }
                            Picker(selection: $settings.preferredTransmitter, label: Text("Preferred")) {
                                ForEach(TransmitterType.allCases) { t in
                                    Text(t.name).tag(t)
                                }
                            }.pickerStyle(SegmentedPickerStyle())
                        }
                        HStack(spacing: 0) {
                            Button(action: {} ) { Image(systemName: "line.horizontal.3.decrease.circle").resizable().frame(width: 20, height: 20).padding(.leading, 6)
                            }
                            TextField("device name pattern", text: $settings.preferredDevicePattern)
                                .padding(.horizontal, 12)
                                .frame(alignment: .center)
                        }
                    }.foregroundColor(.accentColor)

                    NavigationLink(destination: Details().environmentObject(app).environmentObject(settings)) {
                        Text("Details").font(.footnote).bold().padding(.horizontal, 4).padding(2).overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.accentColor, lineWidth: 2))
                    }
                }

                Spacer()

                HStack {
                    Stepper(value: $settings.readingInterval,
                            in: settings.preferredTransmitter == .miaomiao || (settings.preferredTransmitter == .none && app.transmitter != nil && app.transmitter.type == .transmitter(.miaomiao)) ?
                                1 ... 5 : settings.preferredTransmitter == .blu || (settings.preferredTransmitter == .none && app.transmitter != nil && app.transmitter.type == .transmitter(.blu)) ?
                                5 ... 5 : 1 ... 15,
                            step: settings.preferredTransmitter == .miaomiao || (settings.preferredTransmitter == .none && app.transmitter != nil && app.transmitter.type == .transmitter(.miaomiao)) ?
                                2 : 1,
                            label: {
                                Image(systemName: "timer").resizable().frame(width: 32, height: 32)
                                Text(" \(settings.readingInterval) min") })
                }
                .foregroundColor(.orange)
                .padding(.horizontal, 80)

                Spacer()

                Button(action: {
                    let device = self.app.device
                    self.app.selectedTab = (self.settings.preferredTransmitter != .none) ? .monitor : .log
                    let centralManager = self.app.main.centralManager
                    if device != nil {
                        centralManager.cancelPeripheralConnection(device!.peripheral!)
                    }
                    if centralManager.state == .poweredOn {
                        centralManager.scanForPeripherals(withServices: nil, options: nil)
                        self.app.main.status("Scanning...")
                    }
                    if let healthKit = self.app.main.healthKit { healthKit.read() }
                    if let nightscout = self.app.main.nightscout { nightscout.read() }
                }
                ) { Text("Rescan").bold().padding(.horizontal, 4).padding(2).overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.accentColor, lineWidth: 2)) }

                Spacer()

                VStack {
                    VStack(spacing: 0) {
                        Image(systemName: "hand.thumbsup.fill").foregroundColor(.green).padding(4)
                        Text("\(Int(settings.targetLow), specifier: "%3lld") - \(Int(settings.targetHigh))").foregroundColor(.green)
                        HStack {
                            Slider(value: $settings.targetLow,  in: 40 ... 99, step: 1)
                            Slider(value: $settings.targetHigh, in: 140 ... 299, step: 1)
                        }
                    }.accentColor(.green)

                    VStack(spacing: 0) {
                        Image(systemName: "bell.fill").foregroundColor(.red).padding(4)
                        Text("<\(Int(settings.alarmLow), specifier: "%3lld")   > \(Int(settings.alarmHigh))").foregroundColor(.red)
                        HStack {
                            Slider(value: $settings.alarmLow,  in: 40 ... 99, step: 1)
                            Slider(value: $settings.alarmHigh, in: 140 ... 299, step: 1)
                        }
                    }.accentColor(.red)
                }.padding(.horizontal, 40)

                HStack(spacing: 24) {
                    Button(action: {
                        self.settings.mutedAudio.toggle()
                    }) {
                        Image(systemName: settings.mutedAudio ? "speaker.slash.fill" : "speaker.2.fill").resizable().frame(width: 24, height: 24).foregroundColor(.accentColor)
                    }

                    Button(action: {
                        self.settings.disabledNotifications.toggle()
                        if self.settings.disabledNotifications {
                            UIApplication.shared.applicationIconBadgeNumber = 0
                        } else {
                            UIApplication.shared.applicationIconBadgeNumber = self.app.currentGlucose
                        }
                    }) {
                        Image(systemName: settings.disabledNotifications ? "zzz" : "app.badge.fill").resizable().frame(width: 24, height: 24).foregroundColor(.accentColor)
                    }

                    Button(action: {
                        self.showingCalendarPicker = true
                    }) {
                        Image(systemName: settings.calendarTitle != "" ? "calendar.circle.fill" : "calendar.circle").resizable().frame(width: 32, height: 32).foregroundColor(.accentColor)
                    }
                    .popover(isPresented: $showingCalendarPicker, arrowEdge: .bottom) {
                        VStack {
                            Section {
                                Button(action: {
                                    self.settings.calendarTitle = ""
                                    self.showingCalendarPicker = false
                                    self.app.main.eventKit?.sync()
                                }
                                ) { Text("None").bold().padding(.horizontal, 4).padding(2).overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.accentColor, lineWidth: 2)) }
                                    .disabled(self.settings.calendarTitle == "")
                            }
                            Section {
                                Picker(selection: self.$settings.calendarTitle, label: Text("Calendar")) {
                                    ForEach([""] + (self.app.main.eventKit?.calendarTitles ?? [""]), id: \.self) { title in
                                        Text(title != "" ? title : "None")
                                    }
                                }
                            }
                            Section {
                                HStack {
                                    Image(systemName: "bell.fill").foregroundColor(.red).padding(8)
                                    Toggle("High / Low", isOn: self.$settings.calendarAlarmIsOn)
                                        .disabled(self.settings.calendarTitle == "")
                                }
                            }
                            Section {
                                Button(action: {
                                    self.showingCalendarPicker = false
                                    self.app.main.eventKit?.sync()
                                }
                                ) { Text(self.settings.calendarTitle == "" ? "Don't remind" : "Remind").bold().padding(.horizontal, 4).padding(2).overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.accentColor, lineWidth: 2)).animation(.default) }

                            }.padding(.top, 40)
                        }.padding(60)
                    }
                }.padding(.top, 16)

                Spacer()

            }
            .font(Font.body.monospacedDigit())
            .navigationBarTitle("DiaBLE  \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String)  -  Settings", displayMode: .inline)
        }.navigationViewStyle(StackNavigationViewStyle())
    }
}


struct SettingsView_Previews: PreviewProvider {
    @EnvironmentObject var app: DiaBLEAppState
    @EnvironmentObject var log: Log
    @EnvironmentObject var history: History
    @EnvironmentObject var settings: Settings
    static var previews: some View {
        Group {
            ContentView()
                .environmentObject(DiaBLEAppState.test(tab: .settings))
                .environmentObject(Log())
                .environmentObject(History.test)
                .environmentObject(Settings())
                .environment(\.colorScheme, .dark)
        }
    }
}
