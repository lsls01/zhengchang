//
// Created by yanue on 2021/6/5.
// Copyright (c) 2021 yanue. All rights reserved.
//

import Foundation
import SwiftyJSON

struct VmessShare: Codable {
    var v = "2"
    var ps = ""
    var add = ""
    var port = ""
    var id = ""
    var aid = ""
    var net = ""
    var type = "none"
    var host = ""
    var path = ""
    var tls = "none"
}

class ShareUri {
    var error = ""
    var remark = ""
    var uri = ""
    var v2ray = V2rayConfig()
    var share = VmessShare()

    func qrcode(item: V2rayItem) {
        v2ray.parseJson(jsonText: item.json)
        if !v2ray.isValid {
            error = v2ray.errors.count > 0 ? v2ray.errors[0] : ""
            return
        }

        remark = item.remark

        if v2ray.serverProtocol == V2rayProtocolOutbound.vmess.rawValue {
            genVmessUri()

            let encoder = JSONEncoder()
            if let data = try? encoder.encode(self.share) {
                let uri = String(data: data, encoding: .utf8)!
                self.uri = "vmess://" + uri.base64Encoded()!
            } else {
                error = "encode uri error"
            }
            return
        }

        if v2ray.serverProtocol == V2rayProtocolOutbound.vless.rawValue {
            genVlessUri()
            return
        }

        if v2ray.serverProtocol == V2rayProtocolOutbound.shadowsocks.rawValue {
            genShadowsocksUri()
            return
        }

        if v2ray.serverProtocol == V2rayProtocolOutbound.trojan.rawValue {
            genTrojanUri()
            return
        }

        error = "not support"
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
    private func genVmessUri() {
        share.add = v2ray.serverVmess.address
        share.ps = remark
        share.port = String(v2ray.serverVmess.port)
        if v2ray.serverVmess.users.count > 0 {
            share.id = v2ray.serverVmess.users[0].id
            share.aid = String(v2ray.serverVmess.users[0].alterId)
        }
        share.net = v2ray.streamNetwork

        if v2ray.streamNetwork == "h2" {
            if v2ray.streamH2.host.count > 0 {
                share.host = v2ray.streamH2.host[0]
            }
            share.path = v2ray.streamH2.path
        }

        if v2ray.streamNetwork == "ws" {
            share.host = v2ray.streamWs.headers.host
            share.path = v2ray.streamWs.path
        }

        share.tls = v2ray.streamTlsSecurity
    }

    // Shadowsocks
    func genShadowsocksUri() {
        let ss = ShadowsockUri()
        ss.host = v2ray.serverShadowsocks.address
        ss.port = v2ray.serverShadowsocks.port
        ss.password = v2ray.serverShadowsocks.password
        ss.method = v2ray.serverShadowsocks.method
        ss.remark = remark
        uri = ss.encode()
        error = ss.error
    }

    // trojan
    func genTrojanUri() {
        let ss = TrojanUri()
        ss.host = v2ray.serverTrojan.address
        ss.port = v2ray.serverTrojan.port
        ss.password = v2ray.serverTrojan.password
        ss.remark = remark
        uri = ss.encode()
        error = ss.error
    }

    func genVlessUri() {
        let ss = VlessUri()
        ss.address = v2ray.serverVless.address
        ss.port = v2ray.serverVless.port

        if v2ray.serverVless.users.count > 0 {
            ss.id = v2ray.serverVless.users[0].id
            ss.level = v2ray.serverVless.users[0].level
            ss.flow = v2ray.serverVless.users[0].flow
            ss.encryption = v2ray.serverVless.users[0].encryption
        }
        ss.remark = remark

        ss.security = v2ray.streamTlsSecurity
        ss.host = v2ray.streamXtlsServerName

        ss.type = v2ray.streamNetwork

        if v2ray.streamNetwork == "h2" {
            if v2ray.streamH2.host.count > 0 {
                ss.host = v2ray.streamH2.host[0]
            }
            ss.path = v2ray.streamH2.path
        }

        if v2ray.streamNetwork == "ws" {
            ss.host = v2ray.streamWs.headers.host
            ss.path = v2ray.streamWs.path
        }

        uri = ss.encode()
        error = ss.error
    }
}
