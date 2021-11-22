//
//  V2rayOutbound.swift
//  V2rayU
//
//  Created by yanue on 2018/10/26.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa

// protocol
enum V2rayProtocolOutbound: String, Codable {
    case blackhole
    case freedom
    case shadowsocks
    case socks
    case vmess
    case dns
    case http
    case vless
    case trojan
}

struct V2rayOutbound: Codable {
    var sendThrough: String?
    var `protocol`: V2rayProtocolOutbound = .freedom
    var tag: String? = ""
    var streamSettings: V2rayStreamSettings?
    var proxySettings: ProxySettings?
    var mux: V2rayOutboundMux?

    var settingBlackhole: V2rayOutboundBlackhole?
    var settingFreedom: V2rayOutboundFreedom?
    var settingShadowsocks: V2rayOutboundShadowsocks?
    var settingSocks: V2rayOutboundSocks?
    var settingVMess: V2rayOutboundVMess?
    var settingDns: V2rayOutboundDns?
    var settingHttp: V2rayOutboundHttp?
    var settingVLess: V2rayOutboundVLess?
    var settingTrojan: V2rayOutboundTrojan?

    enum CodingKeys: String, CodingKey {
        case sendThrough
        case `protocol`
        case tag
        case streamSettings
        case proxySettings
        case mux
        case settings // auto switch by protocol
    }
}

extension V2rayOutbound {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        `protocol` = try container.decode(V2rayProtocolOutbound.self, forKey: CodingKeys.protocol)
        tag = try container.decode(String.self, forKey: CodingKeys.tag)

        // ignore nil
        if !(try container.decodeNil(forKey: .sendThrough)) {
            sendThrough = try container.decode(String.self, forKey: CodingKeys.sendThrough)
        }

        // ignore nil
        if !(try container.decodeNil(forKey: .proxySettings)) {
            proxySettings = try container.decode(ProxySettings.self, forKey: CodingKeys.proxySettings)
        }

        // ignore nil
        if !(try container.decodeNil(forKey: .streamSettings)) {
            streamSettings = try container.decode(V2rayStreamSettings.self, forKey: CodingKeys.streamSettings)
        }

        // ignore nil
        if !(try container.decodeNil(forKey: .mux)) {
            mux = try container.decode(V2rayOutboundMux.self, forKey: CodingKeys.mux)
        }

        // decode settings depends on `protocol`
        switch `protocol` {
        case .blackhole:
            settingBlackhole = try container.decode(V2rayOutboundBlackhole.self, forKey: CodingKeys.settings)
        case .freedom:
            settingFreedom = try container.decode(V2rayOutboundFreedom.self, forKey: CodingKeys.settings)
        case .shadowsocks:
            settingShadowsocks = try container.decode(V2rayOutboundShadowsocks.self, forKey: CodingKeys.settings)
        case .socks:
            settingSocks = try container.decode(V2rayOutboundSocks.self, forKey: CodingKeys.settings)
        case .vmess:
            settingVMess = try container.decode(V2rayOutboundVMess.self, forKey: CodingKeys.settings)
        case .dns:
            settingDns = try container.decode(V2rayOutboundDns.self, forKey: CodingKeys.settings)
        case .http:
            settingHttp = try container.decode(V2rayOutboundHttp.self, forKey: CodingKeys.settings)
        case .vless:
            settingVLess = try container.decode(V2rayOutboundVLess.self, forKey: CodingKeys.settings)
        case .trojan:
            settingTrojan = try container.decode(V2rayOutboundTrojan.self, forKey: CodingKeys.settings)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(`protocol`, forKey: .protocol)
        try container.encode(tag, forKey: .tag)

        // ignore nil
        if streamSettings != nil {
            try container.encode(streamSettings, forKey: .streamSettings)
        }

        // ignore nil
        if sendThrough != nil, sendThrough!.count > 0 {
            try container.encode(sendThrough, forKey: .sendThrough)
        }

        // ignore nil
        if proxySettings != nil {
            try container.encode(proxySettings, forKey: .proxySettings)
        }

        // ignore nil
        if mux != nil {
            try container.encode(mux, forKey: .mux)
        }

        // encode settings depends on `protocol`
        switch `protocol` {
        case .shadowsocks:
            try container.encode(settingShadowsocks, forKey: .settings)
        case .socks:
            try container.encode(settingSocks, forKey: .settings)
        case .vmess:
            try container.encode(settingVMess, forKey: .settings)
        case .blackhole:
            try container.encode(settingBlackhole, forKey: .settings)
        case .freedom:
            try container.encode(settingFreedom, forKey: .settings)
        case .dns:
            try container.encode(settingDns, forKey: .settings)
        case .http:
            try container.encode(settingHttp, forKey: .settings)
        case .vless:
            try container.encode(settingVLess, forKey: .settings)
        case .trojan:
            try container.encode(settingTrojan, forKey: .settings)
        }
    }
}

struct V2rayOutboundMux: Codable {
    var enabled = false
    var concurrency = 8
}

// protocol
// Blackhole
struct V2rayOutboundBlackhole: Codable {
    var response = V2rayOutboundBlackholeResponse()
}

struct V2rayOutboundBlackholeResponse: Codable {
    var type: String? = "none" // none | http
}

struct V2rayOutboundFreedom: Codable {
    // Freedom
    var domainStrategy = "UseIP" // UseIP | AsIs
    var redirect: String?
    var userLevel = 0
}

struct V2rayOutboundShadowsocks: Codable {
    var servers: [V2rayOutboundShadowsockServer] = [V2rayOutboundShadowsockServer()]
}

let V2rayOutboundShadowsockMethod = ["rc4-md5", "aes-128-cfb", "aes-192-cfb", "aes-256-cfb", "aes-128-ctr", "aes-192-ctr", "aes-256-ctr", "aes-128-gcm", "aes-192-gcm", "aes-256-gcm", "camellia-128-cfb", "camellia-192-cfb", "camellia-256-cfb", "bf-cfb", "salsa20", "chacha20", "chacha20-ietf", "chacha20-ietf-poly1305"]

struct V2rayOutboundShadowsockServer: Codable {
    var email = ""
    var address = ""
    var port = 0
    // V2rayOutboundShadowsockMethod
    var method = "aes-256-cfb"
    var password = ""
    var ota = false
    var level = 0
}

struct V2rayOutboundSocks: Codable {
    var servers: [V2rayOutboundSockServer] = [V2rayOutboundSockServer()]
}

struct V2rayOutboundSockServer: Codable {
    var address = ""
    var port = 0
    var users: [V2rayOutboundSockUser]?
}

struct V2rayOutboundSockUser: Codable {
    var user = ""
    var pass = ""
    var level = 0
}

struct V2rayOutboundVMess: Codable {
    var vnext: [V2rayOutboundVMessItem] = [V2rayOutboundVMessItem()]
}

struct V2rayOutboundVMessItem: Codable {
    var address = ""
    var port = 443
    var users: [V2rayOutboundVMessUser] = [V2rayOutboundVMessUser()]
}

let V2rayOutboundVMessSecurity = ["aes-128-gcm", "chacha20-poly1305", "auto", "none"]

struct V2rayOutboundVMessUser: Codable {
    var id = ""
    var alterId = 64 // 0-65535
    var level = 0
    // V2rayOutboundVMessSecurity
    var security = "auto" // aes-128-gcm/chacha20-poly1305/auto/none
}

struct V2rayOutboundDns: Codable {
    var network = "" // "tcp" | "udp" | ""
    var address = ""
    var port: Int?
}

struct V2rayOutboundHttp: Codable {
    var servers: [V2rayOutboundHttpServer] = [V2rayOutboundHttpServer()]
}

struct V2rayOutboundHttpServer: Codable {
    var address = ""
    var port = 0
    var users: [V2rayOutboundHttpUser] = [V2rayOutboundHttpUser()]
}

struct V2rayOutboundHttpUser: Codable {
    var user = ""
    var pass = ""
}

struct V2rayOutboundVLess: Codable {
    var vnext: [V2rayOutboundVLessItem] = [V2rayOutboundVLessItem()]
}

struct V2rayOutboundVLessItem: Codable {
    var address = ""
    var port = 443
    var users: [V2rayOutboundVLessUser] = [V2rayOutboundVLessUser()]
}

struct V2rayOutboundVLessUser: Codable {
    var id = ""
    var flow = ""
    var encryption = "none"
    var level = 0
}

struct V2rayOutboundTrojan: Codable {
    var servers: [V2rayOutboundTrojanServer] = [V2rayOutboundTrojanServer()]
}

struct V2rayOutboundTrojanServer: Codable {
    var address = ""
    var port = 0
    var password = ""
    var level = 0
    var email = ""
}
