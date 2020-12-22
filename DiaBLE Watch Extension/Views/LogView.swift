import Foundation
import SwiftUI


struct LogView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var log: Log
    @EnvironmentObject var settings: Settings

    @State private var readingCountdown: Int = 0

    @State private var showingSearchField = false
    @State private var searchString = ""

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {

            if showingSearchField {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundColor(Color(UIColor.lightGray))
                    TextField("Search", text: $searchString)
                        .foregroundColor(.blue)
                    if searchString.count > 0 {
                        Button {
                            searchString = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .frame(maxWidth: 24)
                        .padding(0)
                        .buttonStyle(PlainButtonStyle())
                        .foregroundColor(.blue)
                    }
                }
            }

            ScrollView(showsIndicators: true) {
                if searchString.isEmpty {
                    Text(log.text)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    Text(log.text.split(separator: "\n").filter({$0.contains(searchString
                    )}).joined(separator: ("\n")))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            // .font(.system(.footnote, design: .monospaced)).foregroundColor(Color(UIColor.lightGray))
            .font(.footnote).foregroundColor(Color(UIColor.lightGray))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        withAnimation { showingSearchField.toggle() }
                    } label: {
                        Image(systemName: searchString.isEmpty ? "line.horizontal.3.decrease.circle" : "line.horizontal.3.decrease.circle.fill").font(.title3)
                        Text("Filter")
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.blue)


            HStack(alignment: .center, spacing: 0) {

                VStack(spacing: 0) {

                    Button {
                        app.main.rescan()
                    } label: {
                        VStack {
                            Image("Bluetooth").renderingMode(.template).resizable().frame(width: 24, height: 24)
                        }
                    }
                }.foregroundColor(.blue)

                if app.deviceState == "Connected" {
                    Text(readingCountdown > 0 || app.status.hasSuffix("sensor") ?
                            "\(readingCountdown) s" : "")
                        .fixedSize()
                        .onReceive(timer) { _ in
                            readingCountdown = settings.readingInterval * 60 - Int(Date().timeIntervalSince(app.lastReadingDate))
                        }.font(Font.footnote.monospacedDigit()).foregroundColor(.orange)
                }

                if (app.status.hasPrefix("Scanning") || app.status.hasSuffix("retrying...")) && app.main.centralManager.state != .poweredOff {
                    Button {
                        app.main.centralManager.stopScan()
                        app.main.status("Stopped scanning")
                        app.main.log("Bluetooth: stopped scanning")
                    } label: {
                        Image(systemName: "stop.circle").resizable().frame(width: 24, height: 24).foregroundColor(.blue)
                    }
                }

                Spacer()

                Button {
                    settings.debugLevel = 1 - settings.debugLevel
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 5).fill(settings.debugLevel == 1 ? Color.blue : Color.clear)
                        Image(systemName: "wrench.fill").resizable().frame(width: 22, height: 22).foregroundColor(settings.debugLevel == 1 ? .black : .blue)
                    }.frame(width: 24, height: 24)
                }

                //      Button {
                //          UIPasteboard.general.string = log.text
                //      } label: {
                //          VStack {
                //              Image(systemName: "doc.on.doc").resizable().frame(width: 24, height: 24)
                //              Text("Copy").offset(y: -6)
                //          }
                //      }

                Button {
                    log.text = "Log cleared \(Date().local)\n"
                } label: {
                    VStack {
                        Image(systemName: "clear").resizable().foregroundColor(.blue).frame(width: 24, height: 24)
                    }
                }

                Button {
                    settings.reversedLog.toggle()
                    log.text = log.text.split(separator:"\n").reversed().joined(separator: "\n")
                    if !settings.reversedLog { log.text.append(" \n") }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 5).fill(settings.reversedLog ? Color.blue : Color.clear)
                        RoundedRectangle(cornerRadius: 5).stroke(settings.reversedLog ? Color.clear : Color.blue, lineWidth: 2)
                        Image(systemName: "backward.fill").resizable().frame(width: 12, height: 12).foregroundColor(settings.reversedLog ? .black : .blue)
                    }.frame(width: 24, height: 24)
                }

                Button {
                    settings.logging.toggle()
                    app.main.log("\(settings.logging ? "Log started" : "Log stopped") \(Date().local)")
                } label: {
                    VStack {
                        Image(systemName: settings.logging ? "stop.circle" : "play.circle").resizable().frame(width: 24, height: 24).foregroundColor(settings.logging ? .red : .green)
                    }
                }

            }.font(.footnote)
        }
        .edgesIgnoringSafeArea(.bottom)
        .navigationTitle("Log")
    }
}


struct LogView_Previews: PreviewProvider {

    static var previews: some View {
        Group {
            LogView()
                .environmentObject(AppState.test(tab: .log))
                .environmentObject(Log())
                .environmentObject(Settings())
        }
    }
}
