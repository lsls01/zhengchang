//
//  Preferences.swift
//  V2rayU
//
//  Created by yanue on 2018/10/19.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa
import Preferences

final class PreferenceAdvanceViewController: NSViewController, PreferencePane {
    let preferencePaneIdentifier = Preferences.PaneIdentifier.advanceTab
    let preferencePaneTitle = "Advance"
    let toolbarItemIcon = NSImage(named: NSImage.advancedName)!

    @IBOutlet var saveBtn: NSButtonCell!
    @IBOutlet var sockPort: NSTextField!
    @IBOutlet var httpPort: NSTextField!
    @IBOutlet var sockHost: NSTextField!
    @IBOutlet var httpHost: NSTextField!
    @IBOutlet var pacPort: NSTextField!

    @IBOutlet var enableUdp: NSButton!
    @IBOutlet var enableMux: NSButton!
    @IBOutlet var enableSniffing: NSButton!

    @IBOutlet var muxConcurrent: NSTextField!
    @IBOutlet var logLevel: NSPopUpButton!
    @IBOutlet var tips: NSTextField!

    override var nibName: NSNib.Name? {
        return "PreferenceAdvance"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // fix: https://github.com/sindresorhus/Preferences/issues/31
        preferredContentSize = NSMakeSize(view.frame.size.width, view.frame.size.height)
        tips.stringValue = ""

        let enableMuxState = UserDefaults.getBool(forKey: .enableMux)
        let enableUdpState = UserDefaults.getBool(forKey: .enableUdp)
        let enableSniffingState = UserDefaults.getBool(forKey: .enableSniffing)

        let localSockPort = UserDefaults.get(forKey: .localSockPort) ?? "1080"
        let localSockHost = UserDefaults.get(forKey: .localSockHost) ?? "127.0.0.1"
        let localHttpPort = UserDefaults.get(forKey: .localHttpPort) ?? "1087"
        let localHttpHost = UserDefaults.get(forKey: .localHttpHost) ?? "127.0.0.1"
        let localPacPort = UserDefaults.get(forKey: .localPacPort) ?? "11085"
        let muxConcurrent = UserDefaults.get(forKey: .muxConcurrent) ?? "8"

        // select item
        print("host", localSockHost, localHttpHost)
        logLevel.selectItem(withTitle: UserDefaults.get(forKey: .v2rayLogLevel) ?? "info")

        enableUdp.state = enableUdpState ? .on : .off
        enableMux.state = enableMuxState ? .on : .off
        enableSniffing.state = enableSniffingState ? .on : .off
        sockPort.stringValue = localSockPort
        sockHost.stringValue = localSockHost
        httpPort.stringValue = localHttpPort
        httpHost.stringValue = localHttpHost
        pacPort.stringValue = localPacPort
        self.muxConcurrent.intValue = Int32(muxConcurrent) ?? 8
    }

    @IBAction func saveSettings(_: Any) {
        saveBtn.state = .on
        saveSettingsAndReload()
    }

    func saveSettingsAndReload() {
        let httpPortVal = String(httpPort.intValue)
        let sockPortVal = String(sockPort.intValue)
        let pacPortVal = String(pacPort.intValue)

        let enableUdpVal = enableUdp.state.rawValue > 0
        let enableMuxVal = enableMux.state.rawValue > 0
        let enableSniffingVal = enableSniffing.state.rawValue > 0

        let muxConcurrentVal = muxConcurrent.intValue

        if httpPortVal == sockPortVal || httpPortVal == pacPortVal || sockPortVal == pacPortVal {
            tips.stringValue = "the ports(http,sock,pac) cannot be the same"

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                // your code here
                self.tips.stringValue = ""
            }
            return
        }

        // save
        UserDefaults.setBool(forKey: .enableUdp, value: enableUdpVal)
        UserDefaults.setBool(forKey: .enableMux, value: enableMuxVal)
        UserDefaults.setBool(forKey: .enableSniffing, value: enableSniffingVal)

        UserDefaults.set(forKey: .localHttpPort, value: httpPortVal)
        UserDefaults.set(forKey: .localHttpHost, value: httpHost.stringValue)
        UserDefaults.set(forKey: .localSockPort, value: sockPortVal)
        UserDefaults.set(forKey: .localSockHost, value: sockHost.stringValue)
        UserDefaults.set(forKey: .localPacPort, value: pacPortVal)
        UserDefaults.set(forKey: .muxConcurrent, value: String(muxConcurrentVal))
        print("self.sockHost.stringValue", sockHost.stringValue)

        var logLevelName = "info"

        if let logLevelVal = logLevel.selectedItem {
            print("logLevelVal", logLevelVal)
            logLevelName = logLevelVal.title
            UserDefaults.set(forKey: .v2rayLogLevel, value: logLevelVal.title)
        }
        // replace
        v2rayConfig.httpPort = httpPortVal
        v2rayConfig.socksPort = sockPortVal
        v2rayConfig.enableUdp = enableUdpVal
        v2rayConfig.enableMux = enableMuxVal
        v2rayConfig.mux = Int(muxConcurrentVal)
        v2rayConfig.logLevel = logLevelName

        // set current server item and reload v2ray-core
        regenerateAllConfig()

        // set HttpServerPacPort
        HttpServerPacPort = pacPortVal
        PACUrl = "http://127.0.0.1:" + String(HttpServerPacPort) + "/pac/proxy.js"

        _ = GeneratePACFile(rewrite: true)
        // restart pac http server
        V2rayLaunch.startHttpServer()

        tips.stringValue = "save success."

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // your code here
            self.tips.stringValue = ""
        }
    }
}
