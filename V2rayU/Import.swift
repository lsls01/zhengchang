//
// Created by yanue on 2018/11/22.
// Copyright (c) 2018 yanue. All rights reserved.
//

import Cocoa
import CoreGraphics
import CoreImage
import SwiftyJSON

class ImportUri {
    var isValid: Bool = false
    var json = ""
    var remark = ""
    var error = ""
    var uri = ""

    static func importUri(uri: String, id: String = "", checkExist: Bool = true) -> ImportUri? {
        if checkExist, V2rayServer.exist(url: uri) {
            let importUri = ImportUri()
            importUri.isValid = false
            importUri.error = "Url already exists"
            return importUri
        }

        if uri.hasPrefix("vmess://") {
            let importUri = ImportUri()
            importUri.importVmessUri(uri: uri, id: id)
            return importUri
        }
        if uri.hasPrefix("trojan://") {
            let importUri = ImportUri()
            importUri.importTrojanUri(uri: uri)
            return importUri
        }
        if uri.hasPrefix("vless://") {
            let importUri = ImportUri()
            importUri.importVlessUri(uri: uri)
            return importUri
        }
        if uri.hasPrefix("ss://") {
            let importUri = ImportUri()
            importUri.importSSUri(uri: uri)
            return importUri
        }
        if uri.hasPrefix("ssr://") {
            let importUri = ImportUri()
            importUri.importSSRUri(uri: uri)
            return importUri
        }
        return nil
    }

    static func supportProtocol(uri: String) -> Bool {
        if uri.hasPrefix("ss://") || uri.hasPrefix("ssr://") || uri.hasPrefix("vmess://") || uri.hasPrefix("vless://") || uri.hasPrefix("trojan://") {
            return true
        }
        return false
    }

    func importSSUri(uri: String) {
        var url = URL(string: uri)
        if url == nil {
            let aUri = uri.split(separator: "#")
            url = URL(string: String(aUri[0]))
            if url == nil {
                error = "invalid ss url"
                return
            }
            // 支持 ss://YWVzLTI1Ni1jZmI6ZjU1LmZ1bi0wNTM1NDAxNkA0NS43OS4xODAuMTExOjExMDc4#翻墙党300.16美国 格式
            if aUri.count > 1 {
                remark = String(aUri[1])
            }
        }

        self.uri = uri

        let ss = ShadowsockUri()
        ss.Init(url: url!)
        if ss.error.count > 0 {
            error = ss.error
            isValid = false
            return
        }
        if ss.remark.count > 0 {
            remark = ss.remark
        }

        let v2ray = V2rayConfig()
        var ssServer = V2rayOutboundShadowsockServer()
        ssServer.address = ss.host
        ssServer.port = ss.port
        ssServer.password = ss.password
        ssServer.method = ss.method
        v2ray.serverShadowsocks = ssServer
        v2ray.enableMux = false
        v2ray.serverProtocol = V2rayProtocolOutbound.shadowsocks.rawValue
        // check is valid
        v2ray.checkManualValid()
        if v2ray.isValid {
            isValid = true
            json = v2ray.combineManual()
        } else {
            error = v2ray.error
            isValid = false
        }
    }

    func importSSRUri(uri: String) {
        if URL(string: uri) == nil {
            error = "invalid ssr url"
            return
        }
        self.uri = uri

        let ssr = ShadowsockRUri()
        ssr.Init(url: URL(string: uri)!)
        if ssr.error.count > 0 {
            error = ssr.error
            isValid = false
            return
        }
        remark = ssr.remark

        let v2ray = V2rayConfig()
        var ssServer = V2rayOutboundShadowsockServer()
        ssServer.address = ssr.host
        ssServer.port = ssr.port
        ssServer.password = ssr.password
        ssServer.method = ssr.method
        v2ray.serverShadowsocks = ssServer
        v2ray.enableMux = false
        v2ray.serverProtocol = V2rayProtocolOutbound.shadowsocks.rawValue
        // check is valid
        v2ray.checkManualValid()
        if v2ray.isValid {
            isValid = true
            json = v2ray.combineManual()
        } else {
            error = v2ray.error
            isValid = false
        }
    }

    func importVmessUri(uri: String, id: String = "") {
        if URL(string: uri) == nil {
            error = "invalid vmess url"
            return
        }

        self.uri = uri

        var vmess = VmessUri()
        vmess.parseType2(url: URL(string: uri)!)
        if vmess.error.count > 0 {
            vmess = VmessUri()
            vmess.parseType1(url: URL(string: uri)!)
            if vmess.error.count > 0 {
                print("error", vmess.error)
                isValid = false
                error = vmess.error
                return
            }
        }
        remark = vmess.remark

        let v2ray = V2rayConfig()

        var vmessItem = V2rayOutboundVMessItem()
        vmessItem.address = vmess.address
        vmessItem.port = vmess.port
        var user = V2rayOutboundVMessUser()
        if id.count > 0 {
//            vmess.id = id
        }
        user.id = vmess.id
        user.alterId = vmess.alterId
        user.security = vmess.security
        vmessItem.users = [user]
        v2ray.serverVmess = vmessItem
        v2ray.serverProtocol = V2rayProtocolOutbound.vmess.rawValue

        // stream
        v2ray.streamNetwork = vmess.network
        v2ray.streamTlsAllowInsecure = vmess.allowInsecure
        v2ray.streamTlsSecurity = vmess.tls
        v2ray.streamTlsServerName = vmess.tlsServer

        // tls servername for h2 or ws
        if vmess.tlsServer.count == 0, vmess.network == V2rayStreamSettings.network.h2.rawValue || vmess.network == V2rayStreamSettings.network.ws.rawValue {
            v2ray.streamTlsServerName = vmess.netHost
        }

        // kcp
        v2ray.streamKcp.header.type = vmess.type
        v2ray.streamKcp.uplinkCapacity = vmess.uplinkCapacity
        v2ray.streamKcp.downlinkCapacity = vmess.downlinkCapacity

        // h2
        if v2ray.streamH2.host.count == 0 {
            v2ray.streamH2.host = [""]
        }
        v2ray.streamH2.host[0] = vmess.netHost
        v2ray.streamH2.path = vmess.netPath

        // ws
        v2ray.streamWs.path = vmess.netPath
        v2ray.streamWs.headers.host = vmess.netHost

        // tcp
        v2ray.streamTcp.header.type = vmess.type

        // quic
        v2ray.streamQuic.header.type = vmess.type

        // check is valid
        v2ray.checkManualValid()
        if v2ray.isValid {
            isValid = true
            json = v2ray.combineManual()
        } else {
            error = v2ray.error
            isValid = false
        }
    }

    func importVlessUri(uri: String, id _: String = "") {
        if URL(string: uri) == nil {
            error = "invalid vless url"
            return
        }

        self.uri = uri

        let vmess = VlessUri()
        vmess.Init(url: URL(string: uri)!)
        if vmess.error.count > 0 {
            error = vmess.error
            return
        }
        remark = vmess.remark
        let v2ray = V2rayConfig()
        v2ray.serverProtocol = V2rayProtocolOutbound.vless.rawValue

        var vmessItem = V2rayOutboundVLessItem()
        vmessItem.address = vmess.address
        vmessItem.port = vmess.port
        var user = V2rayOutboundVLessUser()
        user.id = vmess.id
        user.flow = vmess.flow
        user.encryption = vmess.encryption
        user.level = vmess.level
        vmessItem.users = [user]
        v2ray.serverVless = vmessItem

        // stream
        v2ray.streamNetwork = vmess.type
        v2ray.streamTlsSecurity = vmess.security
        v2ray.streamXtlsServerName = vmess.host
        if vmess.host.count == 0 {
            v2ray.streamXtlsServerName = vmess.address
        }

        // kcp
        v2ray.streamKcp.header.type = vmess.type

        // h2
        if v2ray.streamH2.host.count == 0 {
            v2ray.streamH2.host = [""]
        }
        v2ray.streamH2.host[0] = vmess.host
        v2ray.streamH2.path = vmess.path

        // ws
        v2ray.streamWs.path = vmess.path
        v2ray.streamWs.headers.host = vmess.host

        // tcp
        v2ray.streamTcp.header.type = vmess.type

        // quic
        v2ray.streamQuic.header.type = vmess.type

        // check is valid
        v2ray.checkManualValid()
        if v2ray.isValid {
            isValid = true
            json = v2ray.combineManual()
        } else {
            error = v2ray.error
            isValid = false
        }
    }

    func importTrojanUri(uri: String) {
        if URL(string: uri) == nil {
            error = "invalid ssr url"
            return
        }
        self.uri = uri

        let trojan = TrojanUri()
        trojan.Init(url: URL(string: uri)!)
        if trojan.error.count > 0 {
            error = trojan.error
            isValid = false
            return
        }
        remark = trojan.remark

        let v2ray = V2rayConfig()
        var svr = V2rayOutboundTrojanServer()
        svr.address = trojan.host
        svr.port = trojan.port
        svr.password = trojan.password
        NSLog("\(svr)")
        v2ray.serverTrojan = svr
        v2ray.enableMux = false
        v2ray.serverProtocol = V2rayProtocolOutbound.trojan.rawValue
        // check is valid
        v2ray.checkManualValid()
        if v2ray.isValid {
            isValid = true
            json = v2ray.combineManual()
            NSLog("\(json)")
        } else {
            error = v2ray.error
            isValid = false
        }
    }
}

enum Scanner {
    // scan from screen
    static func scanQRCodeFromScreen() -> String {
        var displayCount: UInt32 = 0
        var result = CGGetActiveDisplayList(0, nil, &displayCount)
        if Int(result.rawValue) != 0 {
            return ""
        }
        let allocated = Int(displayCount)
        let activeDisplays: UnsafeMutablePointer<UInt32> = UnsafeMutablePointer<CGDirectDisplayID>.allocate(capacity: allocated)

        result = CGGetActiveDisplayList(displayCount, activeDisplays, &displayCount)
        if Int(result.rawValue) != 0 {
            return ""
        }

        var qrStr = ""

        for i in 0 ..< displayCount {
            let str = getQrcodeStr(displayID: activeDisplays[Int(i)])
            // support: ss:// | ssr:// | vmess://
            if ImportUri.supportProtocol(uri: str) {
                qrStr = str
                break
            }
        }

        activeDisplays.deallocate()

        return qrStr
    }

    private static func getQrcodeStr(displayID: CGDirectDisplayID) -> String {
        guard let qrcodeImg = CGDisplayCreateImage(displayID) else {
            return ""
        }

        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])!
        let ciImage = CIImage(cgImage: qrcodeImg)
        let features = detector.features(in: ciImage)

        var qrCodeLink = ""

        for feature in features as! [CIQRCodeFeature] {
            qrCodeLink += feature.messageString ?? ""
        }

        return qrCodeLink
    }
}
