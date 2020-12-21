import Foundation
import SwiftUI


struct LogView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var log: Log
    @EnvironmentObject var settings: Settings

    @State private var showingNFCAlert = false
    @State private var readingCountdown: Int = 0

    @State private var showingSearchField = false
    @State private var searchString = ""

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationView {
            HStack(spacing: 4) {

                VStack {

                    if showingSearchField {
                        HStack {
                            TextField("Search", text: $searchString)
                                .autocapitalization(.none)
                                .foregroundColor(Color.accentColor)
                            Button {
                                searchString = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                        }
                    }

                    ScrollView(showsIndicators: true) {
                        if searchString.isEmpty {
                            Text(log.text)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                                .padding(4)
                        } else {
                            Text(log.text.split(separator: "\n").filter({$0.contains(searchString
                            )}).joined(separator: ("\n")))
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(4)
                        }
                        // TODO: clear button
                    }
                    .font(.system(.footnote, design: .monospaced)).foregroundColor(Color(UIColor.lightGray))
                }

                VStack(alignment: .center, spacing: 8) {

                    Spacer()

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

                        Button {
                            app.main.rescan()
                        } label: {
                            VStack {
                                Image("Bluetooth").renderingMode(.template).resizable().frame(width: 32, height: 32)
                                Text("Scan")
                            }
                        }
                    }.foregroundColor(.accentColor)


                    if (app.status.hasPrefix("Scanning") || app.status.hasSuffix("retrying...")) && app.main.centralManager.state != .poweredOff {
                        Button {
                            app.main.centralManager.stopScan()
                            app.main.status("Stopped scanning")
                            app.main.log("Bluetooth: stopped scanning")
                        } label: {
                            Image(systemName: "stop.circle").resizable().frame(width: 32, height: 32)
                        }.foregroundColor(.red)
                    } else {
                        Image(systemName: "stop.circle").resizable().frame(width: 32, height: 32)
                            .hidden()
                    }

                    if app.deviceState == "Connected" {
                        Text(readingCountdown > 0 || app.status.hasSuffix("sensor") ?
                                "\(readingCountdown) s" : "")
                            .fixedSize()
                            .onReceive(timer) { _ in
                                readingCountdown = settings.readingInterval * 60 - Int(Date().timeIntervalSince(app.lastReadingDate))
                            }.font(Font.caption.monospacedDigit()).foregroundColor(.orange)
                    } else {
                        Text("").fixedSize().font(Font.caption.monospacedDigit()).hidden()
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
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .foregroundColor(settings.debugLevel == 1 ? .black : .accentColor)
                    .padding(.bottom, 6)

                    VStack(spacing: 0) {

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

                }.font(.footnote)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Log")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {

                    HStack(alignment: .bottom) {

                        Button {
                            withAnimation { showingSearchField.toggle() }
                        } label: {
                            VStack(spacing: 0) {
                                Image(systemName: "magnifyingglass").font(.title2)
                                Text("Filter").font(.footnote)
                            }
                        }

                        // FIXME: closes when the log and the countdown update

                        Menu {

                            Button {
                                if app.main.nfcReader.isNFCAvailable {
                                    app.main.nfcReader.taskRequest = .enableStreaming
                                } else {
                                    showingNFCAlert = true
                                }
                            } label: {
                                Label {
                                    Text("RePair Streaming")
                                } icon: {
                                    Image("NFC").renderingMode(.template).resizable().frame(width: 26, height: 18)
                                }
                            }

                            Button {
                                if app.main.nfcReader.isNFCAvailable {
                                    app.main.nfcReader.taskRequest = .dump
                                } else {
                                    showingNFCAlert = true
                                }
                            } label: {
                                Label("Dump Memory", systemImage: "cpu")
                            }

                            // TODO:
//                            Button {
//                                if app.main.nfcReader.isNFCAvailable {
//                                    app.main.nfcReader.taskRequest = .readFRAM
//                                } else {
//                                    showingNFCAlert = true
//                                }
//                            } label: {
//                                Label("Read FRAM", systemImage: "memorychip")
//                            }

                        } label: {
                            Label {
                                Text("Tools")
                            } icon: {
                                VStack(spacing: 0) {
                                    Image(systemName: "wrench.and.screwdriver").font(.title3)
                                    Text("Tools").font(.footnote).fixedSize()
                                }
                            }.labelStyle(IconOnlyLabelStyle())
                        }
                    }
                }
            }
        }
        .alert(isPresented: $showingNFCAlert) {
            Alert(
                title: Text("NFC not supported"),
                message: Text("This device doesn't allow scanning the Libre."))
        }
        .background(Color.black)
        .navigationViewStyle(StackNavigationViewStyle())
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
