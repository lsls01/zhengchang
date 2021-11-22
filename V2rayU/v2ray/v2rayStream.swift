//
//  v2rayStream.swift
//  V2rayU
//
//  Created by yanue on 2018/10/26.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa

struct V2rayTransport: Codable {
    var tlsSettings: TlsSettings?
    var tcpSettings: TcpSettings?
    var kcpSettings: KcpSettings?
    var wsSettings: WsSettings?
    var httpSettings: HttpSettings?
    var dsSettings: DsSettings?
    var quicSettings: QuicSettings?
    var xtlsSettings: XtlsSettings?
}

struct V2rayStreamSettings: Codable {
    enum network: String, Codable {
        case tcp
        case kcp
        case ws
        case http
        case h2
        case domainsocket
        case quic
    }

    enum security: String, Codable {
        case none
        case tls
        case xtls
    }

    var network: network = .tcp
    var security: security = .none
    var sockopt: V2rayStreamSettingSockopt?
    var tlsSettings: TlsSettings?
    var tcpSettings: TcpSettings?
    var kcpSettings: KcpSettings?
    var wsSettings: WsSettings?
    var httpSettings: HttpSettings?
    var dsSettings: DsSettings?
    var quicSettings: QuicSettings?
    var xtlsSettings: XtlsSettings?
}

struct TlsSettings: Codable {
    var serverName: String?
    var alpn: String?
    var allowInsecure: Bool?
    var allowInsecureCiphers: Bool?
    var certificates: TlsCertificates?
}

struct XtlsSettings: Codable {
    var serverName: String?
    var alpn: String?
    var allowInsecure: Bool?
    var allowInsecureCiphers: Bool?
    var certificates: TlsCertificates?
}

struct TlsCertificates: Codable {
    enum usage: String, Codable {
        case encipherment
        case verify
        case issue
    }

    var usage: usage? = .encipherment
    var certificateFile: String?
    var keyFile: String?
    var certificate: String?
    var key: String?
}

struct TcpSettings: Codable {
    var header = TcpSettingHeader()
}

struct TcpSettingHeader: Codable {
    var type = "none" // http or none
    var request: TcpSettingHeaderRequest?
    var response: TcpSettingHeaderResponse?
}

struct TcpSettingHeaderRequest: Codable {
    var version = ""
    var method = ""
    var path = [String]()
    var headers = TcpSettingHeaderRequestHeaders()
}

struct TcpSettingHeaderRequestHeaders: Codable {
    var host = [String]()
    var userAgent = [String]()
    var acceptEncoding = [String]()
    var connection = [String]()
    var pragma = ""

    enum CodingKeys: String, CodingKey {
        case host = "Host"
        case userAgent = "User-Agent"
        case acceptEncoding = "Accept-Encoding"
        case connection = "Connection"
        case pragma = "Pragma"
    }
}

struct TcpSettingHeaderResponse: Codable {
    var version, status, reason: String?
    var headers: TcpSettingHeaderResponseHeaders?
}

struct TcpSettingHeaderResponseHeaders: Codable {
    var contentType, transferEncoding, connection: [String]?
    var pragma: String?

    enum CodingKeys: String, CodingKey {
        case contentType = "Content-Type"
        case transferEncoding = "Transfer-Encoding"
        case connection = "Connection"
        case pragma = "Pragma"
    }
}

struct KcpSettings: Codable {
    var mtu = 1350
    var tti = 20
    var uplinkCapacity = 50
    var downlinkCapacity = 20
    var congestion = false
    var readBufferSize = 1
    var writeBufferSize = 1
    var header = KcpSettingsHeader()
}

var KcpSettingsHeaderType = ["none", "srtp", "utp", "wechat-video", "dtls", "wireguard"]

struct KcpSettingsHeader: Codable {
    // KcpSettingsHeaderType
    var type = "none"
}

struct WsSettings: Codable {
    var path = ""
    var headers = WsSettingsHeader()
}

struct WsSettingsHeader: Codable {
    var host = ""
}

struct HttpSettings: Codable {
    var host: [String] = [""]
    var path: String = ""
}

struct DsSettings: Codable {
    var path = ""
}

struct V2rayStreamSettingSockopt: Codable {
    enum tproxy: String, Codable {
        case redirect
        case tproxy
        case off
    }

    var mark = 0
    var tcpFastOpen = false // 是否启用 TCP Fast Open。
    var tproxy: tproxy = .off // 是否开启透明代理 (仅适用于 Linux)。
}

var QuicSettingsSecurity = ["none", "aes-128-gcm", "chacha20-poly1305"]

struct QuicSettings: Codable {
    //  QuicSettingsSecurity
    var security = "none"
    var key = ""
    var header = QuicSettingHeader()
}

var QuicSettingsHeaderType = ["none", "srtp", "utp", "wechat-video", "dtls", "wireguard"]

struct QuicSettingHeader: Codable {
    // QuicSettingsHeaderType
    var type = "none"
}
