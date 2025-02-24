//
// Created by yanue on 2021/6/5.
// Copyright (c) 2021 yanue. All rights reserved.
//

import Foundation
import SwiftyJSON

// see: https://github.com/v2ray/v2ray-core/issues/1139
class VmessUri {
    var error = ""
    var remark = ""

    var address = ""
    var port: Int = 8379
    var id = ""
    var alterId: Int = 0
    var security = "aes-128-gcm"

    var network = "tcp"
    var netHost = ""
    var netPath = ""
    var tls = ""
    var type = "none"
    var uplinkCapacity: Int = 50
    var downlinkCapacity: Int = 20
    var allowInsecure: Bool = false
    var tlsServer = ""
    var mux: Bool = true
    var muxConcurrency: Int = 8

    /**
     vmess://base64(security:uuid@host:port)?[urlencode(parameters)]
     其中 base64、urlencode 为函数，security 为加密方式，parameters 是以 & 为分隔符的参数列表，例如：network=kcp&aid=32&remark=服务器1 经过 urlencode 后为 network=kcp&aid=32&remark=%E6%9C%8D%E5%8A%A1%E5%99%A81
     可选参数（参数名称不区分大小写）：
     network - 可选的值为 "tcp"、 "kcp"、"ws"、"h2" 等
     wsPath - WebSocket 的协议路径
     wsHost - WebSocket HTTP 头里面的 Host 字段值
     kcpHeader - kcp 的伪装类型
     uplinkCapacity - kcp 的上行容量
     downlinkCapacity - kcp 的下行容量
     h2Path - h2 的路径
     h2Host - h2 的域名
     aid - AlterId
     tls - 是否启用 TLS，为 0 或 1
     allowInsecure - TLS 的 AllowInsecure，为 0 或 1
     tlsServer - TLS 的服务器端证书的域名
     mux - 是否启用 mux，为 0 或 1
     muxConcurrency - mux 的 最大并发连接数
     remark - 备注名称
     导入配置时，不在列表中的参数一般会按照 Core 的默认值处理。
     */
    func parseType1(url: URL) {
        let urlStr = url.absoluteString
        // vmess://
        let base64Begin = urlStr.index(urlStr.startIndex, offsetBy: 8)
        let base64End = urlStr.firstIndex(of: "?")
        let encodedStr = String(urlStr[base64Begin ..< (base64End ?? urlStr.endIndex)])

        var paramsStr = ""
        if base64End != nil {
            let paramsAll = urlStr.components(separatedBy: "?")
            paramsStr = paramsAll[1]
        }

        guard let decodeStr = encodedStr.base64Decoded() else {
            error = "error decode Str"
            return
        }
        print("decodeStr", decodeStr)
        // main
        var uuid_ = ""
        var host_ = ""
        let mainArr = decodeStr.components(separatedBy: "@")
        if mainArr.count > 1 {
            uuid_ = mainArr[0]
            host_ = mainArr[1]
        }

        let uuid_security = uuid_.components(separatedBy: ":")
        if uuid_security.count > 1 {
            security = uuid_security[0]
            id = uuid_security[1]
        }

        let host_port = host_.components(separatedBy: ":")
        if host_port.count > 1 {
            address = host_port[0]
            port = Int(host_port[1]) ?? 0
        }
        print("VmessUri self", self)

        // params
        let params = paramsStr.components(separatedBy: "&")
        for item in params {
            let param = item.components(separatedBy: "=")
            if param.count < 2 {
                continue
            }
            switch param[0] {
            case "network":
                network = param[1]
            case "h2path":
                netPath = param[1]
            case "h2host":
                netHost = param[1]
            case "aid":
                alterId = Int(param[1]) ?? 0
            case "tls":
                tls = param[1] == "1" ? "tls" : "none"
            case "allowInsecure":
                allowInsecure = param[1] == "1" ? true : false
            case "tlsServer":
                tlsServer = param[1]
            case "mux":
                mux = param[1] == "1" ? true : false
            case "muxConcurrency":
                muxConcurrency = Int(param[1]) ?? 8
            case "kcpHeader":
                // type 是所有传输方式的伪装类型
                type = param[1]
            case "uplinkCapacity":
                uplinkCapacity = Int(param[1]) ?? 50
            case "downlinkCapacity":
                downlinkCapacity = Int(param[1]) ?? 20
            case "remark":
                remark = param[1].urlDecoded()
            default:
                break
            }
        }
    }

    /** s
     分享的链接（二维码）格式：vmess://(Base64编码的json格式服务器数据
     json数据如下
     {
     "v": "2",
     "ps": "备注别名",
     "add": "111.111.111.111",
     "port": "32000",
     "id": "1386f85e-657b-4d6e-9d56-78badb75e1fd",
     "aid": "100",
     "net": "tcp",
     "type": "none",
     "host": "www.bbb.com",
     "path": "/",
     "tls": "tls"
     }
     v:配置文件版本号,主要用来识别当前配置
     net ：传输协议（tcp\kcp\ws\h2)
     type:伪装类型（none\http\srtp\utp\wechat-video）
     host：伪装的域名
     1)http host中间逗号(,)隔开
     2)ws host
     3)h2 host
     path:path(ws/h2)
     tls：底层传输安全（tls)
     */
    func parseType2(url: URL) {
        let urlStr = url.absoluteString
        // vmess://
        let base64Begin = urlStr.index(urlStr.startIndex, offsetBy: 8)
        let base64End = urlStr.firstIndex(of: "?")
        let encodedStr = String(urlStr[base64Begin ..< (base64End ?? urlStr.endIndex)])
        guard let decodeStr = encodedStr.base64Decoded() else {
            error = "decode vmess error"
            return
        }

        guard let json = try? JSON(data: decodeStr.data(using: String.Encoding.utf8, allowLossyConversion: false)!) else {
            error = "invalid json"
            return
        }

        if !json.exists() {
            error = "invalid json"
            return
        }

        remark = json["ps"].stringValue.urlDecoded()
        address = json["add"].stringValue
        port = json["port"].intValue
        id = json["id"].stringValue
        alterId = json["aid"].intValue
        network = json["net"].stringValue
        netHost = json["host"].stringValue
        netPath = json["path"].stringValue
        tls = json["tls"].stringValue
        // type:伪装类型（none\http\srtp\utp\wechat-video）
        type = json["type"].stringValue
        print("json", json)
    }
}

// link: https://github.com/shadowsocks/ShadowsocksX-NG
// file: ServerProfile.swift
class ShadowsockUri {
    var host = ""
    var port: Int = 8379
    var method = "aes-128-gcm"
    var password = ""
    var remark = ""

    var error = ""

    // ss://bf-cfb:test@192.168.100.1:8888#remark
    func encode() -> String {
        let base64 = method + ":" + password + "@" + host + ":" + String(port)
        let ss = base64.base64Encoded()
        if ss != nil {
            return "ss://" + ss! + "#" + remark
        }
        error = "encode base64 fail"
        return ""
    }

    func Init(url: URL) {
        let (_decodedUrl, _tag) = decodeUrl(url: url)
        guard let decodedUrl = _decodedUrl else {
            error = "error: decodeUrl"
            return
        }
        guard let parsedUrl = URLComponents(string: decodedUrl) else {
            error = "error: parsedUrl"
            return
        }
        guard let host = parsedUrl.host else {
            error = "error:missing host"
            return
        }
        guard let port = parsedUrl.port else {
            error = "error:missing port"
            return
        }
        guard let user = parsedUrl.user else {
            error = "error:missing user"
            return
        }

        self.host = host
        self.port = Int(port)

        // This can be overriden by the fragment part of SIP002 URL
        remark = (parsedUrl.queryItems?.filter { $0.name == "Remark" }.first?.value ?? "").urlDecoded()

        if let password = parsedUrl.password {
            method = user.lowercased()
            self.password = password
            if let tag = _tag {
                remark = tag
            }
        } else {
            // SIP002 URL have no password section
            guard let data = Data(base64Encoded: padBase64(string: user)), let userInfo = String(data: data, encoding: .utf8) else {
                error = "URL: have no password section"
                return
            }

            let parts = userInfo.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            if parts.count != 2 {
                error = "error:url userInfo"
                return
            }

            method = String(parts[0]).lowercased()
            password = String(parts[1])

            // SIP002 defines where to put the profile name
            if let profileName = parsedUrl.fragment {
                remark = profileName.urlDecoded()
            }
        }
    }

    func decodeUrl(url: URL) -> (String?, String?) {
        let urlStr = url.absoluteString
        let base64Begin = urlStr.index(urlStr.startIndex, offsetBy: 5)
        let base64End = urlStr.firstIndex(of: "#")
        let encodedStr = String(urlStr[base64Begin ..< (base64End ?? urlStr.endIndex)])

        guard let decoded = encodedStr.base64Decoded() else {
            error = "decode ss error"
            return (url.absoluteString, nil)
        }

        let s = decoded.trimmingCharacters(in: .whitespacesAndNewlines)

        if let index = base64End {
            let i = urlStr.index(index, offsetBy: 1)
            let fragment = String(urlStr[i...]).removingPercentEncoding
            return ("ss://\(s)", fragment)
        }
        return ("ss://\(s)", nil)
    }

    func padBase64(string: String) -> String {
        var length = string.utf8.count
        if length % 4 == 0 {
            return string
        } else {
            length = 4 - length % 4 + length
            return string.padding(toLength: length, withPad: "=", startingAt: 0)
        }
    }
}

// link: https://coderschool.cn/2498.html
class ShadowsockRUri: ShadowsockUri {
    override func Init(url: URL) {
        let (_decodedUrl, _tag) = decodeUrl(url: url)
        guard let decodedUrl = _decodedUrl else {
            error = "error: decodeUrl"
            return
        }

        let parts: [Substring] = decodedUrl.split(separator: ":")
        if parts.count != 6 {
            error = "error:url"
            return
        }

        let host = String(parts[0])
        let port = String(parts[1])
        let method = String(parts[3])
        let passwordBase64 = String(parts[5])

        self.host = host
        if let aPort = Int(port) {
            self.port = aPort
        }

        self.method = method.lowercased()
        if let tag = _tag {
            remark = tag.urlDecoded()
        }

        guard let data = Data(base64Encoded: padBase64(string: passwordBase64)), let password = String(data: data, encoding: .utf8) else {
            error = "URL: password decode error"
            return
        }
        self.password = password
    }

    override func decodeUrl(url: URL) -> (String?, String?) {
        let urlStr = url.absoluteString
        // remove left ssr://
        let base64Begin = urlStr.index(urlStr.startIndex, offsetBy: 6)
        let encodedStr = String(urlStr[base64Begin...])

        guard let decoded = encodedStr.base64Decoded() else {
            error = "decode ssr error"
            return (url.absoluteString, nil)
        }

        let raw = decoded.trimmingCharacters(in: .whitespacesAndNewlines)

        let sep = raw.range(of: "/?")
        let s = String(raw[..<(sep?.lowerBound ?? raw.endIndex)])
        if let iBeg = raw.range(of: "remarks=")?.upperBound {
            let fragment = String(raw[iBeg...])
            let iEnd = fragment.firstIndex(of: "&")
            let aRemarks = String(fragment[..<(iEnd ?? fragment.endIndex)])
            guard let tag = aRemarks.base64Decoded() else {
                return (s, aRemarks)
            }
            return (s, tag)
        }

        return (s, nil)
    }
}

// trojan
class TrojanUri {
    var host = ""
    var port: Int = 443
    var password = ""
    var remark = ""

    var error = ""

    // trojan://password@remote_host:remote_port
    func encode() -> String {
        let uri = password + "@" + host + ":" + String(port)
        return "trojan://" + uri + "#" + remark
    }

    func Init(url: URL) {
        guard let host = url.host else {
            error = "error:missing host"
            return
        }
        guard let port = url.port else {
            error = "error:missing port"
            return
        }
        guard let password = url.user else {
            error = "error:missing password"
            return
        }
        self.host = host
        self.port = Int(port)
        self.password = password
        remark = (url.fragment ?? "trojan").urlDecoded()
    }
}

// 待定标准方案: https://github.com/XTLS/Xray-core/issues/91
// # VMess + TCP，不加密（仅作示例，不安全）
// vmess://99c80931-f3f1-4f84-bffd-6eed6030f53d@qv2ray.net:31415?encryption=none#VMessTCPNaked
// # VMess + TCP，自动选择加密。编程人员特别注意不是所有的 URL 都有问号，注意处理边缘情况。
// vmess://f08a563a-674d-4ffb-9f02-89d28aec96c9@qv2ray.net:9265#VMessTCPAuto
// # VMess + TCP，手动选择加密
// vmess://5dc94f3a-ecf0-42d8-ae27-722a68a6456c@qv2ray.net:35897?encryption=aes-128-gcm#VMessTCPAES
// # VMess + TCP + TLS，内层不加密
// vmess://136ca332-f855-4b53-a7cc-d9b8bff1a8d7@qv2ray.net:9323?encryption=none&security=tls#VMessTCPTLSNaked
// # VMess + TCP + TLS，内层也自动选择加密
// vmess://be5459d9-2dc8-4f47-bf4d-8b479fc4069d@qv2ray.net:8462?security=tls#VMessTCPTLS
// # VMess + TCP + TLS，内层不加密，手动指定 SNI
// vmess://c7199cd9-964b-4321-9d33-842b6fcec068@qv2ray.net:64338?encryption=none&security=tls&sni=fastgit.org#VMessTCPTLSSNI
// # VLESS + TCP + XTLS
// vless://b0dd64e4-0fbd-4038-9139-d1f32a68a0dc@qv2ray.net:3279?security=xtls&flow=rprx-xtls-splice#VLESSTCPXTLSSplice
// # VLESS + mKCP + Seed
// vless://399ce595-894d-4d40-add1-7d87f1a3bd10@qv2ray.net:50288?type=kcp&seed=69f04be3-d64e-45a3-8550-af3172c63055#VLESSmKCPSeed
// # VLESS + mKCP + Seed，伪装成 Wireguard
// vless://399ce595-894d-4d40-add1-7d87f1a3bd10@qv2ray.net:41971?type=kcp&headerType=wireguard&seed=69f04be3-d64e-45a3-8550-af3172c63055#VLESSmKCPSeedWG
// # VMess + WebSocket + TLS
// vmess://44efe52b-e143-46b5-a9e7-aadbfd77eb9c@qv2ray.net:6939?type=ws&security=tls&host=qv2ray.net&path=%2Fsomewhere#VMessWebSocketTLS

class VlessUri {
    var error = ""
    var remark = ""

    var address = ""
    var port: Int = 0
    var id = ""

    var level: Int = 0
    var flow = ""

    var encryption = "" // auto,aes-128-gcm,...
    var security = "" // xtls,tls

    var type = "" // tcp,http
    var host = ""
    var sni = ""
    var path = ""

    // vless://f2a5064a-fabb-43ed-a2b6-8ffeb970df7f@00.com:443?flow=xtls-rprx-splite&encryption=none&security=xtls&sni=aaaaa&type=http&host=00.com&path=%2fvl#vless1
    func encode() -> String {
        var uri = URLComponents()
        uri.scheme = "vless"
        uri.user = id
        uri.host = address
        uri.port = port
        uri.queryItems = [
            URLQueryItem(name: "flow", value: flow),
            URLQueryItem(name: "security", value: security),
            URLQueryItem(name: "encryption", value: encryption),
            URLQueryItem(name: "type", value: type),
            URLQueryItem(name: "host", value: host),
            URLQueryItem(name: "path", value: path),
            URLQueryItem(name: "sni", value: sni),
        ]

        return (uri.url?.absoluteString ?? "") + "#" + remark
    }

    func Init(url: URL) {
        guard let address = url.host else {
            error = "error:missing host"
            return
        }
        guard let port = url.port else {
            error = "error:missing port"
            return
        }
        guard let id = url.user else {
            error = "error:missing id"
            return
        }
        self.address = address
        self.port = Int(port)
        self.id = id
        let queryItems = url.queryParams()
        for item in queryItems {
            switch item.key {
            case "level":
                level = item.value as! Int
            case "flow":
                flow = item.value as! String
            case "encryption":
                encryption = item.value as! String
                if encryption.count == 0 {
                    encryption = "none"
                }
            case "security":
                security = item.value as! String
            case "type":
                type = item.value as! String
            case "host":
                host = item.value as! String
            case "sni":
                sni = item.value as! String
            case "path":
                path = item.value as! String
            default:
                break
            }
        }

        remark = (url.fragment ?? "vless").urlDecoded()
    }
}
