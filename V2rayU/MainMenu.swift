//
//  Menu.swift
//  V2rayU
//
//  Created by yanue on 2018/10/16.
//  Copyright © 2018 yanue. All rights reserved.
//

import Alamofire
import Cocoa
import Preferences
import ServiceManagement
import Sparkle

let menuController = (NSApplication.shared.delegate as? AppDelegate)?.statusMenu.delegate as! MenuController
let V2rayUpdater = SUUpdater()

extension Preferences.PaneIdentifier {
    static let generalTab = Preferences.PaneIdentifier("generalTab")
    static let advanceTab = Preferences.PaneIdentifier("advanceTab")
    static let subscribeTab = Preferences.PaneIdentifier("subscribeTab")
    static let pacTab = Preferences.PaneIdentifier("pacTab")
    static let routingTab = Preferences.PaneIdentifier("routingTab")
    static let dnsTab = Preferences.PaneIdentifier("dnsTab")
    static let aboutTab = Preferences.PaneIdentifier("aboutTab")
}

let preferencesWindowController = PreferencesWindowController(
    preferencePanes: [
        PreferenceGeneralViewController(),
        PreferenceAdvanceViewController(),
        PreferenceSubscribeViewController(),
        PreferencePacViewController(),
        PreferenceRoutingViewController(),
        PreferenceDnsViewController(),
        PreferenceAboutViewController(),
    ]
)
var qrcodeWindow = QrcodeWindowController()

var toastWindowCtrl: ToastWindowController!

func makeToast(message: String, displayDuration: Double? = 2) {
    if toastWindowCtrl != nil {
        toastWindowCtrl.close()
    }
    toastWindowCtrl = ToastWindowController()
    toastWindowCtrl.message = message
    toastWindowCtrl.showWindow(Any.self)
    toastWindowCtrl.fadeInHud(displayDuration)
}

func ToggleRunning(_ toast: Bool = true) {
    // turn off
    if UserDefaults.getBool(forKey: .v2rayTurnOn) {
        menuController.stopV2rayCore()
        if toast {
            makeToast(message: "v2ray-core: Off")
        }
        return
    }

    // start
    menuController.startV2rayCore()
    if toast {
        makeToast(message: "v2ray-core: On")
    }
}

func SwitchProxyMode() {
    let runMode = RunMode(rawValue: UserDefaults.get(forKey: .runMode) ?? "manual") ?? .manual

    switch runMode {
    case .pac:
        menuController.switchRunMode(runMode: .global)
        makeToast(message: "V2rayU: global Mode")
    case .global:
        menuController.switchRunMode(runMode: .manual)
        makeToast(message: "V2rayU: manual Mode")
    case .manual:
        menuController.switchRunMode(runMode: .pac)
        makeToast(message: "V2rayU: pac Mode")

    default: break
    }
}

// regenerate All Config when base setting changed
func regenerateAllConfig() {
    NSLog("regenerateAllConfig.")

    for (idx, item) in V2rayServer.list().enumerated() {
        if !item.isValid {
            continue
        }

        // parse old
        let vCfg = V2rayConfig()
        vCfg.parseJson(jsonText: item.json)

        // combine
        let text = vCfg.combineManual()
        _ = V2rayServer.save(idx: idx, isValid: vCfg.isValid, jsonData: text)

        print("regenerate config", item.remark)
    }

    // restart service
    let item = V2rayServer.loadSelectedItem()
    if item != nil {
        menuController.startV2rayCore()
    }

    // reload config window
    if menuController.configWindow != nil {
        menuController.configWindow.serversTableView.reloadData()
    }
}

// menu controller
class MenuController: NSObject, NSMenuDelegate {
    var closedByConfigWindow: Bool = false
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var statusItemClicked: (() -> Void)?
    var configWindow: ConfigWindowController!
    var lastRunMode = "" // for backup system proxy

    @IBOutlet var pacMode: NSMenuItem!
    @IBOutlet var manualMode: NSMenuItem!
    @IBOutlet var globalMode: NSMenuItem!
    @IBOutlet var statusMenu: NSMenu!
    @IBOutlet var toggleV2rayItem: NSMenuItem!
    @IBOutlet var v2rayStatusItem: NSMenuItem!
    @IBOutlet var serverItems: NSMenuItem!
    @IBOutlet var newVersionItem: NSMenuItem!

    // when menu.xib loaded
    override func awakeFromNib() {
        newVersionItem.isHidden = true

        // install before launch
        V2rayLaunch.install()

        // windowWillClose Notification
        NotificationCenter.default.addObserver(self, selector: #selector(configWindowWillClose(notification:)), name: NSWindow.willCloseNotification, object: nil)

        // backup system proxy when init
        V2rayLaunch.setSystemProxy(mode: .backup)

        // Do any additional setup after loading the view.
        // initial auth ref
        let runMode = UserDefaults.get(forKey: .runMode) ?? "pac"
        switch runMode {
        case "pac":
            pacMode.state = .on
            globalMode.state = .off
            manualMode.state = .off

        case "global":
            pacMode.state = .off
            globalMode.state = .on
            manualMode.state = .off

        default: // manual
            pacMode.state = .off
            globalMode.state = .off
            manualMode.state = .on
        }

        statusMenu.delegate = self
        NSLog("start menu")
        // load server list
        V2rayServer.loadConfig()
        // show server list
        showServers()

        statusItem.menu = statusMenu

        // version before 1.5.2: res.rawValue is 0 or -1
        let isOldConfigVersion = appVersion.compare("1.5.2", options: .numeric).rawValue > 0
        print("isOldConfigVersion", isOldConfigVersion)
        if !isOldConfigVersion {
            regenerateAllConfig()
        }

        if UserDefaults.getBool(forKey: .v2rayTurnOn) {
            // start
            // on status
            startV2rayCore()
        } else {
            // show off status
            setStatusOff()
        }

        // auto update subscribe servers
        if UserDefaults.getBool(forKey: .autoUpdateServers) {
            V2raySubSync().sync()
        }

        // ping
        PingSpeed().pingAll()
    }

    @IBAction func openLogs(_: NSMenuItem) {
        V2rayLaunch.OpenLogs()
    }

    func setStatusOff() {
        v2rayStatusItem.title = "v2ray-core: Off" + ("  (v" + appVersion + ")")
        toggleV2rayItem.title = "Turn v2ray-core On"

        if let button = statusItem.button {
            button.image = NSImage(named: NSImage.Name("IconOff"))
        }

        // set off
        UserDefaults.setBool(forKey: .v2rayTurnOn, value: false)
    }

    func setStatusOn(runMode: RunMode) {
        v2rayStatusItem.title = "v2ray-core: On" + ("  (v" + appVersion + ")")
        toggleV2rayItem.title = "Turn v2ray-core Off"

        var iconName = "IconOn"

        switch runMode {
        case .global:
            iconName = "IconOnG"
        case .manual:
            iconName = "IconOnM"
        case .pac:
            iconName = "IconOnP"
        default:
            break
        }

        if let button = statusItem.button {
            button.image = NSImage(named: NSImage.Name(iconName))
        }

        // set on
        UserDefaults.setBool(forKey: .v2rayTurnOn, value: true)
    }

    func stopV2rayCore() {
        // set status
        setStatusOff()
        // stop launch
        V2rayLaunch.Stop()
        // restore system proxy
        V2rayLaunch.setSystemProxy(mode: .restore)
    }

    // start v2ray core
    func startV2rayCore() {
        NSLog("start v2ray-core begin")

        guard let v2ray = V2rayServer.loadSelectedItem() else {
            noticeTip(title: "start v2ray fail", subtitle: "", informativeText: "v2ray config not found")
            setStatusOff()
            return
        }

        if !v2ray.isValid {
            noticeTip(title: "start v2ray fail", subtitle: "", informativeText: "invalid v2ray config")
            setStatusOff()
            return
        }

        let runMode = RunMode(rawValue: UserDefaults.get(forKey: .runMode) ?? "manual") ?? .manual

        // create json file
        V2rayConfig.createJsonFile(item: v2ray)

        // set status
        setStatusOn(runMode: runMode)

        // launch
        V2rayLaunch.Start()
        NSLog("start v2ray-core done.")

        // switch run mode
        switchRunMode(runMode: runMode)
    }

    @IBAction func start(_: NSMenuItem) {
        ToggleRunning(false)
    }

    @IBAction func quitClicked(_: NSMenuItem) {
        NSApplication.shared.terminate(self)
    }

    @IBAction func openPreferenceGeneral(_: NSMenuItem) {
        preferencesWindowController.show(preferencePane: .generalTab)
    }

    @IBAction func openPreferenceSubscribe(_: NSMenuItem) {
        preferencesWindowController.show(preferencePane: .subscribeTab)
    }

    @IBAction func openPreferencePac(_: NSMenuItem) {
        preferencesWindowController.show(preferencePane: .pacTab)
    }

    // switch server
    @IBAction func switchServer(_ sender: NSMenuItem) {
        guard let obj = sender.representedObject as? V2rayItem else {
            NSLog("switchServer err")
            return
        }

        if !obj.isValid {
            NSLog("current server is invalid", obj.remark)
            return
        }
        // set current
        UserDefaults.set(forKey: .v2rayCurrentServerName, value: obj.name)
        // stop first
        V2rayLaunch.Stop()
        // start
        startV2rayCore()
        // reload menu
        showServers()
    }

    // open config window
    @IBAction func openConfig(_: NSMenuItem) {
        if configWindow != nil {
            // close before
            if closedByConfigWindow {
                configWindow.close()
                // renew
                configWindow = ConfigWindowController()
            }
        } else {
            // renew
            configWindow = ConfigWindowController()
        }

        showDock(state: true)
//        // show window
        configWindow.showWindow(nil)
        configWindow.window?.makeKeyAndOrderFront(self)
//        // bring to front
        NSApp.activate(ignoringOtherApps: true)
    }

    /// When a window was closed this methods takes care of releasing its controller.
    ///
    /// - parameter notification: The notification.
    @objc private func configWindowWillClose(notification: Notification) {
        guard let object = notification.object as? NSWindow else {
            return
        }

        // config window title is "V2rayU"
        if object.title == "V2rayU" {
            _ = showDock(state: false)
        }
    }

    @discardableResult func showDock(state: Bool) -> Bool {
        // Get transform state.
        var transformState: ProcessApplicationTransformState
        if state {
            transformState = ProcessApplicationTransformState(kProcessTransformToForegroundApplication)
        } else {
            transformState = ProcessApplicationTransformState(kProcessTransformToUIElementApplication)
        }

        // Show / hide dock icon.
        var psn = ProcessSerialNumber(highLongOfPSN: 0, lowLongOfPSN: UInt32(kCurrentProcess))
        let transformStatus: OSStatus = TransformProcessType(&psn, transformState)

        return transformStatus == 0
    }

    @IBAction func goHelp(_: NSMenuItem) {
        guard let url = URL(string: "https://github.com/yanue/v2rayu/issues") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func showServers() {
        // reomve old items
        serverItems.submenu?.removeAllItems()
        let curSer = UserDefaults.get(forKey: .v2rayCurrentServerName)

        // add new
        var validCount = 0
        for item in V2rayServer.list() {
            if !item.isValid {
                continue
            }

            let menuItem = NSMenuItem()
            let ping = item.speed.count > 0 ? item.speed : "-1ms"
            let totalSpaceCnt = 10
            var spaceCnt = totalSpaceCnt - ping.count
            // littleSpace: 1,.
            if ping.contains(".") || ping.contains("1") {
                let littleSpaceCount = ping.filter { $0 == "." }.count + ping.filter { $0 == "1" }.count
                spaceCnt = totalSpaceCnt - ((ping.count - littleSpaceCount) + Int((ping.count - littleSpaceCount) / 2))
            }
            if ping.contains("-1ms") {
                spaceCnt = 9
            }
            let space = String(repeating: " ", count: spaceCnt < 0 ? 0 : spaceCnt) + "　"

            menuItem.title = ping + space + item.remark
            menuItem.action = #selector(switchServer(_:))
            menuItem.representedObject = item
            menuItem.target = self
            menuItem.isEnabled = true

            if curSer == item.name || V2rayServer.count() == 1 {
                menuItem.state = NSControl.StateValue.on
            }

            serverItems.submenu?.addItem(menuItem)
            validCount += 1
        }

        if validCount == 0 {
            let menuItem = NSMenuItem()
            menuItem.title = "no available servers."
            menuItem.isEnabled = false
            serverItems.submenu?.addItem(menuItem)
        }
    }

    @IBAction func switchManualMode(_: NSMenuItem) {
        // disable
        switchRunMode(runMode: .manual)
        lastRunMode = RunMode.manual.rawValue
    }

    @IBAction func switchPacMode(_: NSMenuItem) {
        // switch mode
        switchRunMode(runMode: .pac)
        lastRunMode = RunMode.pac.rawValue
    }

    // MARK: - actions

    @IBAction func switchGlobalMode(_: NSMenuItem) {
        // switch mode
        switchRunMode(runMode: .global)
        lastRunMode = RunMode.global.rawValue
    }

    func switchRunMode(runMode: RunMode) {
        // save
        UserDefaults.set(forKey: .runMode, value: runMode.rawValue)
        // state
        globalMode.state = runMode == .global ? .on : .off
        pacMode.state = runMode == .pac ? .on : .off
        manualMode.state = runMode == .manual ? .on : .off
        // enable
        var sockPort = ""
        var httpPort = ""

        let v2ray = V2rayServer.loadSelectedItem()

        if v2ray != nil, v2ray!.isValid {
            let cfg = V2rayConfig()
            cfg.parseJson(jsonText: v2ray!.json)
            sockPort = cfg.socksPort
            httpPort = cfg.httpPort
        }

        // set icon
        setStatusOn(runMode: runMode)
        // launch
        V2rayLaunch.Start()
        // manual mode
        if lastRunMode == RunMode.manual.rawValue {
            // backup first
            V2rayLaunch.setSystemProxy(mode: .backup)
        }

        // global
        if runMode == .global {
            V2rayLaunch.setSystemProxy(mode: .global, httpPort: httpPort, sockPort: sockPort)
            return
        }

        V2rayLaunch.setSystemProxy(mode: runMode)
    }

    @IBAction func checkForUpdate(_ sender: NSMenuItem) {
        menuController.checkV2rayUVersion()
        // need set SUFeedURL into plist
        V2rayUpdater.checkForUpdates(sender)
    }

    @IBAction func generateQrcode(_: NSMenuItem) {
        guard let v2ray = V2rayServer.loadSelectedItem() else {
            NSLog("v2ray config not found")
            noticeTip(title: "generate Qrcode fail", subtitle: "", informativeText: "no available servers")
            return
        }

        let share = ShareUri()
        share.qrcode(item: v2ray)
        if share.error.count > 0 {
            noticeTip(title: "generate Qrcode fail", subtitle: "", informativeText: share.error)
            return
        }

        // close before
        qrcodeWindow.close()
        // renew
        qrcodeWindow = QrcodeWindowController()
        // show window
        qrcodeWindow.showWindow(nil)
        // center
        qrcodeWindow.window?.center()
        // set uri
        qrcodeWindow.setShareUri(uri: share.uri)
        // bring to front
        NSApp.activate(ignoringOtherApps: true)
    }

    @IBAction func copyExportCommand(_: NSMenuItem) {
        // Get the Http proxy config.
        let httpPort = UserDefaults.get(forKey: .localHttpPort) ?? "1087"
        let sockPort = UserDefaults.get(forKey: .localSockPort) ?? "1080"

        // Format an export string.
        let command = "export http_proxy=http://127.0.0.1:\(httpPort);export https_proxy=http://127.0.0.1:\(httpPort);export ALL_PROXY=socks5://127.0.0.1:\(sockPort)"

        // Copy to paste board.
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: NSPasteboard.PasteboardType.string)

        // Show a toast notification.
        noticeTip(title: "Export Command Copied.", subtitle: "", informativeText: command)
    }

    @IBAction func scanQrcode(_: NSMenuItem) {
        let uri = Scanner.scanQRCodeFromScreen()
        if uri.count > 0 {
            importUri(url: uri)
        } else {
            noticeTip(title: "import server fail", subtitle: "", informativeText: "no found qrcode")
        }
    }

    @IBAction func ImportFromPasteboard(_: NSMenuItem) {
        if let uri = NSPasteboard.general.string(forType: .string), uri.count > 0 {
            importUri(url: uri)
        } else {
            noticeTip(title: "import server fail", subtitle: "", informativeText: "no found vmess:// or vless:// or trojan:// or ss:// from Pasteboard")
        }
    }

    @IBAction func pingSpeed(_: NSMenuItem) {
        PingSpeed().pingAll()
    }

    @IBAction func viewConfig(_: Any) {
        let confUrl = PACUrl.replacingOccurrences(of: "pac/proxy.js", with: "config.json")
        guard let url = URL(string: confUrl) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func importUri(url: String) {
        let urls = url.split(separator: "\n")

        for url in urls {
            let uri = url.trimmingCharacters(in: .whitespaces)

            if uri.count == 0 {
                noticeTip(title: "import server fail", subtitle: "", informativeText: "import error: uri not found")
                continue
            }

            // ss://YWVzLTI1Ni1jZmI6ZUlXMERuazY5NDU0ZTZuU3d1c3B2OURtUzIwMXRRMERAMTcyLjEwNS43MS44Mjo4MDk5#翻墙党325.06美国 类型这种含中文的格式不是标准的URL格式
//            if URL(string: uri) == nil {
            if !ImportUri.supportProtocol(uri: uri) {
                noticeTip(title: "import server fail", subtitle: "", informativeText: "no found vmess:// or vless:// or trojan:// or ss:// ")
                continue
            }

            if let importUri = ImportUri.importUri(uri: uri) {
                saveServer(importUri: importUri)
                continue
            }

            noticeTip(title: "import server fail", subtitle: "", informativeText: "no found vmess:// or vless:// or trojan:// or ss:// ")
        }
    }

    func saveServer(importUri: ImportUri) {
        if importUri.isValid {
            // add server
            V2rayServer.add(remark: importUri.remark, json: importUri.json, isValid: true, url: importUri.uri)
            // refresh server
            showServers()

            // reload server
            if menuController.configWindow != nil {
                menuController.configWindow.serversTableView.reloadData()
            }

            noticeTip(title: "import server success", subtitle: "", informativeText: importUri.remark)
        } else {
            noticeTip(title: "import server fail", subtitle: "", informativeText: importUri.error)
        }
    }

    func noticeTip(title: String = "", subtitle: String = "", informativeText: String = "") {
        makeToast(message: title + (subtitle.count > 0 ? " - " + subtitle : "") + " : " + informativeText)
    }

    @IBAction func goRelease(_: Any) {
        guard let url = URL(string: "https://github.com/yanue/v2rayu/releases") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func checkV2rayUVersion() {
        // 当前版本检测
        AF.request("https://api.github.com/repos/yanue/V2rayU/releases/latest").responseJSON { [self] response in
            // to get status code
            if let status = response.response?.statusCode {
                if status != 200 {
                    NSLog("error with response status: ", status)
                    return
                }
            }

            // to get JSON return value
            switch response.result {
            case let .success(result):
                let JSON = result as! NSDictionary

                // get tag_name (verion)
                guard let tag_name = JSON["tag_name"] else {
                    NSLog("error: no tag_name")
                    return
                }

                // get prerelease and draft
                guard let prerelease = JSON["prerelease"], let draft = JSON["draft"] else {
                    // get
                    NSLog("error: get prerelease or draft")
                    return
                }

                // not pre release or draft
                if prerelease as! Bool == true || draft as! Bool == true {
                    NSLog("this release is a prerelease or draft")
                    return
                }

                let newVer = (tag_name as! String)
                // get old versiion
                let oldVer = appVersion.replacingOccurrences(of: "v", with: "").versionToInt()
                let curVer = newVer.replacingOccurrences(of: "v", with: "").versionToInt()

                // compare with [Int]
                if oldVer.lexicographicallyPrecedes(curVer) {
                    newVersionItem.isHidden = false
                    newVersionItem.title = "has new version " + newVer
                } else {
                    newVersionItem.isHidden = true
                }
            case .failure:
                break
            }
        }
    }
}
