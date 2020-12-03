import Foundation
import SwiftUI


struct LogView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var log: Log
    @EnvironmentObject var settings: Settings

    @State private var showingNFCAlert = false
    @State private var readingCountdown: Int = 0

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationView {
            HStack(spacing: 4) {
                ScrollView(showsIndicators: true) {
                    Text(log.text)
                        .font(.system(.footnote, design: .monospaced)).foregroundColor(Color(UIColor.lightGray))
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(4)
                }

                VStack(alignment: .center, spacing: 8) {

                    VStack(spacing: 0) {

                        Button {
                            if app.main.nfcReader.isNFCAvailable {
                                app.main.nfcReader.startSession()
                            } else {
                                showingNFCAlert = true
                            }
                        } label: {
                            Image("NFC").renderingMode(.template).resizable().frame(width: 26, height: 18).padding(EdgeInsets(top: 10, leading: 6, bottom: 14, trailing: 0))
                        }
                        .alert(isPresented: $showingNFCAlert) {
                            Alert(
                                title: Text("NFC not supported"),
                                message: Text("This device doesn't allow scanning the Libre."))
                        }

                        Button {
                            app.main.rescan()
                        } label: {
                            VStack {
                                Image("Bluetooth").renderingMode(.template).resizable().frame(width: 32, height: 32)
                                Text("Scan")
                            }
                        }
                    }.foregroundColor(.accentColor)

                    if app.deviceState == "Connected" {

                        Text(readingCountdown > 0 || app.status.hasSuffix("sensor") ?
                                "\(readingCountdown) s" : "")
                            .fixedSize()
                            .onReceive(timer) { _ in
                                readingCountdown = settings.readingInterval * 60 - Int(Date().timeIntervalSince(app.lastReadingDate))
                            }.font(Font.caption.monospacedDigit()).foregroundColor(.orange)
                    }

                    // Same as in Monitor
                    if app.status.hasPrefix("Scanning") || app.status.hasSuffix("retrying...") {
                        Button {
                            app.main.centralManager.stopScan()
                            app.main.status("Stopped scanning")
                            app.main.log("Bluetooth: stopped scanning")
                        } label: {
                            Image(systemName: "stop.circle").resizable().frame(width: 32, height: 32)
                        }.foregroundColor(.blue)
                    }

                    Spacer()

                    Button {
                        settings.debugLevel = 1 - settings.debugLevel
                    } label: {
                        VStack {
                            Image(systemName: "wrench.fill").resizable().frame(width: 24, height: 24)
                            Text(settings.debugLevel == 1 ? "Devel" : "Basic").font(.caption).offset(y: -6)
                        }
                    }
                    .background(settings.debugLevel == 1 ? Color.accentColor : Color.clear)
                    .foregroundColor(settings.debugLevel == 1 ? .black : .accentColor)
                    .padding(.bottom, 6)

                    Button {
                        UIPasteboard.general.string = log.text
                    } label: {
                        VStack {
                            Image(systemName: "doc.on.doc").resizable().frame(width: 24, height: 24)
                            Text("Copy").offset(y: -6)
                        }
                    }

                    Button {
                        log.text = "Log cleared \(Date().local)\n"
                    } label: {
                        VStack {
                            Image(systemName: "clear").resizable().frame(width: 24, height: 24)
                            Text("Clear").offset(y: -6)
                        }
                    }

                    Button {
                        settings.reversedLog.toggle()
                        log.text = log.text.split(separator:"\n").reversed().joined(separator: "\n")
                        if !settings.reversedLog { log.text.append(" \n") }
                    } label: {
                        VStack {
                            Image(systemName: "backward.fill").resizable().frame(width: 12, height: 12).offset(y: 5)
                            Text(" REV ").offset(y: -2)
                        }
                    }
                    .background(settings.reversedLog ? Color.accentColor : Color.clear)
                    .border(Color.accentColor, width: 3)
                    .cornerRadius(5)
                    .foregroundColor(settings.reversedLog ? .black : .accentColor)


                    Button {
                        settings.logging.toggle()
                        app.main.log("\(settings.logging ? "Log started" : "Log stopped") \(Date().local)")
                    } label: {
                        VStack {
                            Image(systemName: settings.logging ? "stop.circle" : "play.circle").resizable().frame(width: 32, height: 32)
                        }
                    }.foregroundColor(settings.logging ? .red : .green)

                    Spacer()

                }.font(.system(.footnote))
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Log")
            .background(Color.black)
        }.navigationViewStyle(StackNavigationViewStyle())
    }
}



struct LogView_Previews: PreviewProvider {

    static var previews: some View {
        Group {
            ContentView()
                .environmentObject(AppState.test(tab: .log))
                .environmentObject(Log())
                .environmentObject(History.test)
                .environmentObject(Settings())
                .environment(\.colorScheme, .dark)
        }
    }
}
