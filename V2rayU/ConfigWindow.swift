//
//  Config.swift
//  V2rayU
//
//  Created by yanue on 2018/10/9.
//  Copyright © 2018 yanue. All rights reserved.
//

import Alamofire
import Cocoa

var v2rayConfig = V2rayConfig()

class ConfigWindowController: NSWindowController, NSWindowDelegate, NSTabViewDelegate {
    override var windowNibName: String? {
        return "ConfigWindow" // no extension .xib here
    }

    let tableViewDragType = "v2ray.item"

    @IBOutlet var tabView: NSTabView!
    @IBOutlet var okBtn: NSButtonCell!
    @IBOutlet var errTip: NSTextField!
    @IBOutlet var configText: NSTextView!
    @IBOutlet var serversTableView: NSTableView!
    @IBOutlet var addRemoveButton: NSSegmentedControl!
    @IBOutlet var jsonUrl: NSTextField!
    @IBOutlet var selectFileBtn: NSButton!
    @IBOutlet var importBtn: NSButton!

    @IBOutlet var sockPort: NSButton!
    @IBOutlet var httpPort: NSButton!
    @IBOutlet var dnsServers: NSButton!
    @IBOutlet var enableUdp: NSButton!
    @IBOutlet var enableMux: NSButton!
    @IBOutlet var muxConcurrent: NSButton!
    @IBOutlet var version4: NSButton!

    @IBOutlet var switchProtocol: NSPopUpButton!

    @IBOutlet var serverView: NSView!
    @IBOutlet var VmessView: NSView!
    @IBOutlet var VlessView: NSView!
    @IBOutlet var ShadowsocksView: NSView!
    @IBOutlet var SocksView: NSView!
    @IBOutlet var TrojanView: NSView!

    // vmess
    @IBOutlet var vmessAddr: NSTextField!
    @IBOutlet var vmessPort: NSTextField!
    @IBOutlet var vmessAlterId: NSTextField!
    @IBOutlet var vmessLevel: NSTextField!
    @IBOutlet var vmessUserId: NSTextField!
    @IBOutlet var vmessSecurity: NSPopUpButton!

    // vless
    @IBOutlet var vlessAddr: NSTextField!
    @IBOutlet var vlessPort: NSTextField!
    @IBOutlet var vlessUserId: NSTextField!
    @IBOutlet var vlessLevel: NSTextField!
    @IBOutlet var vlessFlow: NSTextField!

    // shadowsocks
    @IBOutlet var shadowsockAddr: NSTextField!
    @IBOutlet var shadowsockPort: NSTextField!
    @IBOutlet var shadowsockPass: NSTextField!
    @IBOutlet var shadowsockMethod: NSPopUpButton!

    // socks5
    @IBOutlet var socks5Addr: NSTextField!
    @IBOutlet var socks5Port: NSTextField!
    @IBOutlet var socks5User: NSTextField!
    @IBOutlet var socks5Pass: NSTextField!

    // for trojan
    @IBOutlet var trojanAddr: NSTextField!
    @IBOutlet var trojanPort: NSTextField!
    @IBOutlet var trojanPass: NSTextField!
    @IBOutlet var trojanAlpn: NSTextField!

    @IBOutlet var networkView: NSView!

    @IBOutlet var tcpView: NSView!
    @IBOutlet var kcpView: NSView!
    @IBOutlet var dsView: NSView!
    @IBOutlet var wsView: NSView!
    @IBOutlet var h2View: NSView!
    @IBOutlet var quicView: NSView!

    @IBOutlet var switchNetwork: NSPopUpButton!

    // kcp setting
    @IBOutlet var kcpMtu: NSTextField!
    @IBOutlet var kcpTti: NSTextField!
    @IBOutlet var kcpUplinkCapacity: NSTextField!
    @IBOutlet var kcpDownlinkCapacity: NSTextField!
    @IBOutlet var kcpReadBufferSize: NSTextField!
    @IBOutlet var kcpWriteBufferSize: NSTextField!
    @IBOutlet var kcpHeader: NSPopUpButton!
    @IBOutlet var kcpCongestion: NSButton!

    @IBOutlet var tcpHeaderType: NSPopUpButton!

    @IBOutlet var wsHost: NSTextField!
    @IBOutlet var wsPath: NSTextField!

    @IBOutlet var h2Host: NSTextField!
    @IBOutlet var h2Path: NSTextField!

    @IBOutlet var dsPath: NSTextField!

    @IBOutlet var quicKey: NSTextField!
    @IBOutlet var quicSecurity: NSPopUpButton!
    @IBOutlet var quicHeaderType: NSPopUpButton!

    @IBOutlet var streamSecurity: NSPopUpButton!
    @IBOutlet var streamAllowSecure: NSButton!
    @IBOutlet var streamTlsServerName: NSTextField!

    override func awakeFromNib() {
        // set table drag style
        serversTableView.registerForDraggedTypes([NSPasteboard.PasteboardType(rawValue: tableViewDragType)])
        serversTableView.allowsMultipleSelection = true

        if V2rayServer.count() == 0 {
            // add default
            V2rayServer.add(remark: "default", json: "", isValid: false)
        }
        shadowsockMethod.removeAllItems()
        shadowsockMethod.addItems(withTitles: V2rayOutboundShadowsockMethod)

        configText.isAutomaticQuoteSubstitutionEnabled = false
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        // table view
        serversTableView.delegate = self
        serversTableView.dataSource = self
        serversTableView.reloadData()
        // tab view
        tabView.delegate = self
    }

    @IBAction func addRemoveServer(_: NSSegmentedCell) {
        // 0 add,1 remove
        let seg = addRemoveButton.indexOfSelectedItem

        switch seg {
        // add server config
        case 0:
            // add
            V2rayServer.add()

            // reload data
            serversTableView.reloadData()
            // selected current row
            serversTableView.selectRowIndexes(NSIndexSet(index: V2rayServer.count() - 1) as IndexSet, byExtendingSelection: false)

        // delete server config
        case 1:
            // get seleted index
            let idx = serversTableView.selectedRow
            // remove
            V2rayServer.remove(idx: idx)

            // selected prev row
            let cnt: Int = V2rayServer.count()
            var rowIndex: Int = idx - 1
            if idx > 0, idx < cnt {
                rowIndex = idx
            }

            // reload
            serversTableView.reloadData()

            // fix
            if cnt > 1 {
                // selected row
                serversTableView.selectRowIndexes(NSIndexSet(index: rowIndex) as IndexSet, byExtendingSelection: false)
            }

            if rowIndex >= 0 {
                loadJsonData(rowIndex: rowIndex)
            } else {
                serversTableView.becomeFirstResponder()
            }

            // refresh menu
            menuController.showServers()

        // unknown action
        default:
            return
        }
    }

    // switch tab view
    func tabView(_: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        guard let item = tabViewItem else {
            print("not found tab view")
            return
        }

        let tab = item.identifier! as! String
        if tab == "Manual" {
            switchToManualView()
        } else {
            switchToImportView()
        }
    }

    // switch to manual
    func switchToManualView() {
        v2rayConfig = V2rayConfig()

        defer {
            if self.configText.string.count > 0 {
                self.bindDataToView()
            }
        }

        // re parse json
        v2rayConfig.parseJson(jsonText: configText.string)
        if v2rayConfig.errors.count > 0 {
            errTip.stringValue = v2rayConfig.errors[0]
            return
        }

        saveConfig()
    }

    // switch to import
    func switchToImportView() {
        // reset error
        errTip.stringValue = ""

        exportData()

        v2rayConfig.checkManualValid()

        if v2rayConfig.isValid {
            let jsonText = v2rayConfig.combineManual()
            configText.string = jsonText
            saveConfig()
        } else {
            errTip.stringValue = v2rayConfig.error
        }
    }

    // export data to V2rayConfig
    func exportData() {
        // ========================== server start =======================
        if switchProtocol.indexOfSelectedItem >= 0 {
            v2rayConfig.serverProtocol = switchProtocol.titleOfSelectedItem!
        }

        // vmess
        v2rayConfig.serverVmess.address = vmessAddr.stringValue
        v2rayConfig.serverVmess.port = Int(vmessPort.intValue)
        var user = V2rayOutboundVMessUser()
        user.alterId = Int(vmessAlterId.intValue)
        user.level = Int(vmessLevel.intValue)
        user.id = vmessUserId.stringValue
        if vmessSecurity.indexOfSelectedItem >= 0 {
            user.security = vmessSecurity.titleOfSelectedItem!
        }
        if v2rayConfig.serverVmess.users.count == 0 {
            v2rayConfig.serverVmess.users = [user]
        } else {
            v2rayConfig.serverVmess.users[0] = user
        }

        // vless
        v2rayConfig.serverVless.address = vlessAddr.stringValue
        v2rayConfig.serverVless.port = Int(vlessPort.intValue)
        var vless_user = V2rayOutboundVLessUser()
        vless_user.id = vlessUserId.stringValue
        vless_user.level = Int(vlessLevel.intValue)
        vless_user.flow = vlessFlow.stringValue
        if v2rayConfig.serverVless.users.count == 0 {
            v2rayConfig.serverVless.users = [vless_user]
        } else {
            v2rayConfig.serverVless.users[0] = vless_user
        }

        // shadowsocks
        v2rayConfig.serverShadowsocks.address = shadowsockAddr.stringValue
        v2rayConfig.serverShadowsocks.port = Int(shadowsockPort.intValue)
        v2rayConfig.serverShadowsocks.password = shadowsockPass.stringValue
        if vmessSecurity.indexOfSelectedItem >= 0 {
            v2rayConfig.serverShadowsocks.method = shadowsockMethod.titleOfSelectedItem ?? "aes-256-cfb"
        }

        // trojan
        v2rayConfig.serverTrojan.address = trojanAddr.stringValue
        v2rayConfig.serverTrojan.port = Int(trojanPort.intValue)
        v2rayConfig.serverTrojan.password = trojanPass.stringValue

        // socks5
        if v2rayConfig.serverSocks5.servers.count == 0 {
            v2rayConfig.serverSocks5.servers = [V2rayOutboundSockServer()]
        }
        v2rayConfig.serverSocks5.servers[0].address = socks5Addr.stringValue
        v2rayConfig.serverSocks5.servers[0].port = Int(socks5Port.intValue)

        var sockUser = V2rayOutboundSockUser()
        sockUser.user = socks5User.stringValue
        sockUser.pass = socks5Pass.stringValue
        if socks5User.stringValue.count > 0 || socks5Pass.stringValue.count > 0 {
            v2rayConfig.serverSocks5.servers[0].users = [sockUser]
        } else {
            v2rayConfig.serverSocks5.servers[0].users = nil
        }
        // ========================== server end =======================

        // ========================== stream start =======================
        if switchNetwork.indexOfSelectedItem >= 0 {
            v2rayConfig.streamNetwork = switchNetwork.titleOfSelectedItem!
        }
        v2rayConfig.streamTlsAllowInsecure = streamAllowSecure.state.rawValue > 0
        v2rayConfig.streamXtlsAllowInsecure = streamAllowSecure.state.rawValue > 0
        if streamSecurity.indexOfSelectedItem >= 0 {
            v2rayConfig.streamTlsSecurity = streamSecurity.titleOfSelectedItem!
        }
        v2rayConfig.streamTlsServerName = streamTlsServerName.stringValue
        v2rayConfig.streamXtlsServerName = streamTlsServerName.stringValue
        // tcp
        if tcpHeaderType.indexOfSelectedItem >= 0 {
            v2rayConfig.streamTcp.header.type = tcpHeaderType.titleOfSelectedItem!
        }

        // kcp
        if kcpHeader.indexOfSelectedItem >= 0 {
            v2rayConfig.streamKcp.header.type = kcpHeader.titleOfSelectedItem!
        }
        v2rayConfig.streamKcp.mtu = Int(kcpMtu.intValue)
        v2rayConfig.streamKcp.tti = Int(kcpTti.intValue)
        v2rayConfig.streamKcp.uplinkCapacity = Int(kcpUplinkCapacity.intValue)
        v2rayConfig.streamKcp.downlinkCapacity = Int(kcpDownlinkCapacity.intValue)
        v2rayConfig.streamKcp.readBufferSize = Int(kcpReadBufferSize.intValue)
        v2rayConfig.streamKcp.writeBufferSize = Int(kcpWriteBufferSize.intValue)
        v2rayConfig.streamKcp.congestion = kcpCongestion.state.rawValue > 0

        // h2
        let h2HostString = h2Host.stringValue
        if h2HostString.count != 0 {
            v2rayConfig.streamH2.host = [h2HostString]
        } else {
            v2rayConfig.streamH2.host = []
        }
        v2rayConfig.streamH2.path = h2Path.stringValue

        // ws
        v2rayConfig.streamWs.path = wsPath.stringValue
        v2rayConfig.streamWs.headers.host = wsHost.stringValue

        // domainsocket
        v2rayConfig.streamDs.path = dsPath.stringValue

        // quic
        v2rayConfig.streamQuic.key = quicKey.stringValue
        if quicHeaderType.indexOfSelectedItem >= 0 {
            v2rayConfig.streamQuic.header.type = quicHeaderType.titleOfSelectedItem!
        }
        if quicSecurity.indexOfSelectedItem >= 0 {
            v2rayConfig.streamQuic.security = quicSecurity.titleOfSelectedItem!
        }
        // ========================== stream end =======================
    }

    func bindDataToView() {
        // ========================== base start =======================
        // base
        httpPort.title = v2rayConfig.httpPort
        sockPort.title = v2rayConfig.socksPort
        enableUdp.intValue = v2rayConfig.enableUdp ? 1 : 0
        enableMux.intValue = v2rayConfig.enableMux ? 1 : 0
        muxConcurrent.intValue = Int32(v2rayConfig.mux)
        // ========================== base end =======================

        // ========================== server start =======================
        switchProtocol.selectItem(withTitle: v2rayConfig.serverProtocol)
        switchOutboundView(protocolTitle: v2rayConfig.serverProtocol)

        // vmess
        vmessAddr.stringValue = v2rayConfig.serverVmess.address
        vmessPort.intValue = Int32(v2rayConfig.serverVmess.port)
        if v2rayConfig.serverVmess.users.count > 0 {
            let user = v2rayConfig.serverVmess.users[0]
            vmessAlterId.intValue = Int32(user.alterId)
            vmessLevel.intValue = Int32(user.level)
            vmessUserId.stringValue = user.id
            vmessSecurity.selectItem(withTitle: user.security)
        }

        // vless
        vlessAddr.stringValue = v2rayConfig.serverVless.address
        vlessPort.intValue = Int32(v2rayConfig.serverVless.port)
        if v2rayConfig.serverVless.users.count > 0 {
            let user = v2rayConfig.serverVless.users[0]
            vlessLevel.intValue = Int32(user.level)
            vlessFlow.stringValue = user.flow
            vlessUserId.stringValue = user.id
        }

        // shadowsocks
        shadowsockAddr.stringValue = v2rayConfig.serverShadowsocks.address
        if v2rayConfig.serverShadowsocks.port > 0 {
            shadowsockPort.stringValue = String(v2rayConfig.serverShadowsocks.port)
        }
        shadowsockPass.stringValue = v2rayConfig.serverShadowsocks.password
        shadowsockMethod.selectItem(withTitle: v2rayConfig.serverShadowsocks.method)

        // socks5
        if v2rayConfig.serverSocks5.servers.count > 0 {
            socks5Addr.stringValue = v2rayConfig.serverSocks5.servers[0].address
            socks5Port.stringValue = String(v2rayConfig.serverSocks5.servers[0].port)
            let users = v2rayConfig.serverSocks5.servers[0].users
            if users != nil, users!.count > 0 {
                let user = users![0]
                socks5User.stringValue = user.user
                socks5Pass.stringValue = user.pass
            }
        }

        // trojan
        trojanAddr.stringValue = v2rayConfig.serverTrojan.address
        trojanPass.stringValue = v2rayConfig.serverTrojan.password
        if v2rayConfig.serverTrojan.port > 0 {
            trojanPort.stringValue = String(v2rayConfig.serverTrojan.port)
        }

        // ========================== server end =======================

        // ========================== stream start =======================
        switchNetwork.selectItem(withTitle: v2rayConfig.streamNetwork)
        switchSteamView(network: v2rayConfig.streamNetwork)

        streamAllowSecure.intValue = v2rayConfig.streamTlsAllowInsecure ? 1 : 0
        streamSecurity.selectItem(withTitle: v2rayConfig.streamTlsSecurity)
        streamTlsServerName.stringValue = v2rayConfig.streamTlsServerName
        if v2rayConfig.streamTlsSecurity == "xtls" {
            streamTlsServerName.stringValue = v2rayConfig.streamXtlsServerName
            streamAllowSecure.intValue = v2rayConfig.streamXtlsAllowInsecure ? 1 : 0
        }

        // tcp
        tcpHeaderType.selectItem(withTitle: v2rayConfig.streamTcp.header.type)

        // kcp
        kcpHeader.selectItem(withTitle: v2rayConfig.streamKcp.header.type)
        kcpMtu.intValue = Int32(v2rayConfig.streamKcp.mtu)
        kcpTti.intValue = Int32(v2rayConfig.streamKcp.tti)
        kcpUplinkCapacity.intValue = Int32(v2rayConfig.streamKcp.uplinkCapacity)
        kcpDownlinkCapacity.intValue = Int32(v2rayConfig.streamKcp.downlinkCapacity)
        kcpReadBufferSize.intValue = Int32(v2rayConfig.streamKcp.readBufferSize)
        kcpWriteBufferSize.intValue = Int32(v2rayConfig.streamKcp.writeBufferSize)
        kcpCongestion.intValue = v2rayConfig.streamKcp.congestion ? 1 : 0

        // h2
        h2Host.stringValue = v2rayConfig.streamH2.host.count > 0 ? v2rayConfig.streamH2.host[0] : ""
        h2Path.stringValue = v2rayConfig.streamH2.path

        // ws
        wsPath.stringValue = v2rayConfig.streamWs.path
        wsHost.stringValue = v2rayConfig.streamWs.headers.host

        // domainsocket
        dsPath.stringValue = v2rayConfig.streamDs.path

        // quic
        quicKey.stringValue = v2rayConfig.streamQuic.key
        quicSecurity.selectItem(withTitle: v2rayConfig.streamQuic.security)
        quicHeaderType.selectItem(withTitle: v2rayConfig.streamQuic.header.type)

        // ========================== stream end =======================
    }

    func loadJsonData(rowIndex: Int) {
        defer {
            self.bindDataToView()
            // replace current
            self.switchToImportView()
        }

        // reset
        v2rayConfig = V2rayConfig()
        if rowIndex < 0 {
            return
        }

        let item = V2rayServer.loadV2rayItem(idx: rowIndex)
        configText.string = item?.json ?? ""
        v2rayConfig.isValid = item?.isValid ?? false
        jsonUrl.stringValue = item?.url ?? ""

        v2rayConfig.parseJson(jsonText: configText.string)
        if v2rayConfig.errors.count > 0 {
            errTip.stringValue = v2rayConfig.errors[0]
            return
        }
    }

    func saveConfig() {
        let text = configText.string

        v2rayConfig.parseJson(jsonText: configText.string)
        if v2rayConfig.errors.count > 0 {
            errTip.stringValue = v2rayConfig.errors[0]
        }

        // save
        let errMsg = V2rayServer.save(idx: serversTableView.selectedRow, isValid: v2rayConfig.isValid, jsonData: text)
        if errMsg.count == 0 {
            if errTip.stringValue == "" {
                errTip.stringValue = "save success"
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    // your code here
                    self.errTip.stringValue = ""
                }
            }
            refreshServerList(ok: errMsg.count == 0)
        } else {
            errTip.stringValue = errMsg
        }
    }

    func refreshServerList(ok: Bool = true) {
        // refresh menu
        menuController.showServers()
        // if server is current
        if let curName = UserDefaults.get(forKey: .v2rayCurrentServerName) {
            let v2rayItemList = V2rayServer.list()
            if curName == v2rayItemList[serversTableView.selectedRow].name {
                if ok {
                    menuController.startV2rayCore()
                } else {
                    menuController.stopV2rayCore()
                }
            }
        }
    }

    @IBAction func ok(_: NSButton) {
        // set always on
        okBtn.state = .on
        // in Manual tab view
        if tabView.selectedTabViewItem?.identifier as! String == "Manual" {
            switchToImportView()
        } else {
            saveConfig()
        }
    }

    @IBAction func importConfig(_: NSButton) {
        configText.string = ""
        if jsonUrl.stringValue.trimmingCharacters(in: .whitespaces) == "" {
            errTip.stringValue = "error: invaid url"
            return
        }

        importJson()
    }

    func saveImport(importUri: ImportUri) {
        if importUri.isValid {
            configText.string = importUri.json
            if importUri.remark.count > 0 {
                V2rayServer.edit(rowIndex: serversTableView.selectedRow, remark: importUri.remark)
            }

            // refresh
            refreshServerList(ok: true)
        } else {
            errTip.stringValue = importUri.error
        }
    }

    func importJson() {
        let text = configText.string
        let uri = jsonUrl.stringValue.trimmingCharacters(in: .whitespaces)
        // edit item remark
        V2rayServer.edit(rowIndex: serversTableView.selectedRow, url: uri)

        if let importUri = ImportUri.importUri(uri: uri, checkExist: false) {
            saveImport(importUri: importUri)
        } else {
            // download json file
            AF.request(jsonUrl.stringValue).responseString { DataResponse in
                if DataResponse.error != nil {
                    self.errTip.stringValue = "error: " + DataResponse.error.debugDescription
                    return
                }

                if DataResponse.value != nil {
                    self.configText.string = v2rayConfig.formatJson(json: DataResponse.value ?? text)
                }
            }
        }
    }

    @IBAction func goTcpHelp(_: NSButtonCell) {
        guard let url = URL(string: "https://www.v2ray.com/chapter_02/transport/tcp.html") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @IBAction func goDsHelp(_: Any) {
        guard let url = URL(string: "https://www.v2ray.com/chapter_02/transport/domainsocket.html") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @IBAction func goQuicHelp(_: Any) {
        guard let url = URL(string: "https://www.v2ray.com/chapter_02/transport/quic.html") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @IBAction func goProtocolHelp(_: NSButton) {
        guard let url = URL(string: "https://www.v2ray.com/chapter_02/protocols/vmess.html") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @IBAction func goVersionHelp(_: Any) {
        guard let url = URL(string: "https://www.v2ray.com/chapter_02/01_overview.html") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @IBAction func goStreamHelp(_: Any) {
        guard let url = URL(string: "https://www.v2ray.com/chapter_02/05_transport.html") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func switchSteamView(network: String) {
        networkView.subviews.forEach {
            $0.isHidden = true
        }

        switch network {
        case "tcp":
            tcpView.isHidden = false
        case "kcp":
            kcpView.isHidden = false
        case "domainsocket":
            dsView.isHidden = false
        case "ws":
            wsView.isHidden = false
        case "h2":
            h2View.isHidden = false
        case "quic":
            quicView.isHidden = false
        default: // vmess
            tcpView.isHidden = false
        }
    }

    func switchOutboundView(protocolTitle: String) {
        serverView.subviews.forEach {
            $0.isHidden = true
        }

        switch protocolTitle {
        case "vmess":
            VmessView.isHidden = false
        case "vless":
            VlessView.isHidden = false
        case "shadowsocks":
            ShadowsocksView.isHidden = false
        case "socks":
            SocksView.isHidden = false
        case "trojan":
            TrojanView.isHidden = false
        default: // vmess
            VmessView.isHidden = true
        }
    }

    @IBAction func switchSteamNetwork(_: NSPopUpButtonCell) {
        if let item = switchNetwork.selectedItem {
            switchSteamView(network: item.title)
        }
    }

    @IBAction func switchOutboundProtocol(_: NSPopUpButtonCell) {
        if let item = switchProtocol.selectedItem {
            switchOutboundView(protocolTitle: item.title)
        }
    }

    @IBAction func switchUri(_ sender: NSPopUpButton) {
        guard let item = sender.selectedItem else {
            return
        }
        // url
        if item.title == "url" {
            jsonUrl.stringValue = ""
            selectFileBtn.isHidden = true
            importBtn.isHidden = false
            jsonUrl.isEditable = true
        } else {
            // local file
            jsonUrl.stringValue = ""
            selectFileBtn.isHidden = false
            importBtn.isHidden = true
            jsonUrl.isEditable = false
        }
    }

    @IBAction func browseFile(_: NSButton) {
        jsonUrl.stringValue = ""
        let dialog = NSOpenPanel()

        dialog.title = "Choose a .json file"
        dialog.showsResizeIndicator = true
        dialog.showsHiddenFiles = false
        dialog.canChooseDirectories = true
        dialog.canCreateDirectories = true
        dialog.allowsMultipleSelection = false

        if dialog.runModal() == NSApplication.ModalResponse.OK {
            let result = dialog.url // Pathname of the file

            if result != nil {
                jsonUrl.stringValue = result?.absoluteString ?? ""
                importJson()
            }
        } else {
            // User clicked on "Cancel"
            return
        }
    }

    @IBAction func openLogs(_: NSButton) {
        V2rayLaunch.OpenLogs()
    }

    @IBAction func clearLogs(_: NSButton) {
        V2rayLaunch.ClearLogs()
    }

    @IBAction func cancel(_: NSButton) {
        // hide dock icon and close all opened windows
        _ = menuController.showDock(state: false)
    }

    @IBAction func goAdvanceSetting(_: Any) {
        preferencesWindowController.show(preferencePane: .advanceTab)
    }

    @IBAction func goSubscribeSetting(_: Any) {
        preferencesWindowController.show(preferencePane: .subscribeTab)
    }

    @IBAction func goRoutingRuleSetting(_: Any) {
        preferencesWindowController.show(preferencePane: .routingTab)
    }
}

// NSv2rayItemListSource
extension ConfigWindowController: NSTableViewDataSource {
    func numberOfRows(in _: NSTableView) -> Int {
        return V2rayServer.count()
    }

    func tableView(_: NSTableView, objectValueFor _: NSTableColumn?, row: Int) -> Any? {
        let v2rayItemList = V2rayServer.list()
        // set cell data
        if v2rayItemList.count >= row {
            return v2rayItemList[row].remark
        }
        return nil
    }

    // edit cell
    func tableView(_ tableView: NSTableView, setObjectValue: Any?, for _: NSTableColumn?, row: Int) {
        guard let remark = setObjectValue as? String else {
            NSLog("remark is nil")
            return
        }
        // edit item remark
        V2rayServer.edit(rowIndex: row, remark: remark)
        // reload table
        tableView.reloadData()
        // reload menu
        menuController.showServers()
    }
}

// NSTableViewDelegate
extension ConfigWindowController: NSTableViewDelegate {
    // For NSTableViewDelegate
    func tableViewSelectionDidChange(_: Notification) {
        loadJsonData(rowIndex: serversTableView.selectedRow)
        errTip.stringValue = ""
    }

    // Drag & Drop reorder rows
    func tableView(_: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        let item = NSPasteboardItem()
        item.setString(String(row), forType: NSPasteboard.PasteboardType(rawValue: tableViewDragType))
        return item
    }

    func tableView(_: NSTableView, validateDrop _: NSDraggingInfo, proposedRow _: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        if dropOperation == .above {
            return .move
        }
        return NSDragOperation()
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation _: NSTableView.DropOperation) -> Bool {
        var oldIndexes = [Int]()
        info.enumerateDraggingItems(options: [], for: tableView, classes: [NSPasteboardItem.self], searchOptions: [:], using: {
            (draggingItem: NSDraggingItem, _: Int, _: UnsafeMutablePointer<ObjCBool>) in
                if let str = (draggingItem.item as! NSPasteboardItem).string(forType: NSPasteboard.PasteboardType(rawValue: self.tableViewDragType)),
                   let index = Int(str)
                {
                    oldIndexes.append(index)
                }
        })

        var oldIndexOffset = 0
        var newIndexOffset = 0
        var oldIndexLast = 0
        var newIndexLast = 0

        // For simplicity, the code below uses `tableView.moveRowAtIndex` to move rows around directly.
        // You may want to move rows in your content array and then call `tableView.reloadData()` instead.
        for oldIndex in oldIndexes {
            if oldIndex < row {
                oldIndexLast = oldIndex + oldIndexOffset
                newIndexLast = row - 1
                oldIndexOffset -= 1
            } else {
                oldIndexLast = oldIndex
                newIndexLast = row + newIndexOffset
                newIndexOffset += 1
            }
        }

        // move
        V2rayServer.move(oldIndex: oldIndexLast, newIndex: newIndexLast)
        // set selected
        serversTableView.selectRowIndexes(NSIndexSet(index: newIndexLast) as IndexSet, byExtendingSelection: false)
        // reload table
        serversTableView.reloadData()
        // reload menu
        menuController.showServers()

        return true
    }
}
