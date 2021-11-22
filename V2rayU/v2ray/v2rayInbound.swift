//
//  V2rayInbound.swift
//  V2rayU
//
//  Created by yanue on 2018/10/26.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa

// Inbound
struct V2rayInbound: Codable {
    var port = "1080"
    var listen = "127.0.0.1"
    var `protocol`: V2rayProtocolInbound = .socks
    var tag: String?
    var streamSettings: V2rayStreamSettings?
    var sniffing: V2rayInboundSniffing?
    var allocate: V2rayInboundAllocate?

    var settingHttp = V2rayInboundHttp()
    var settingSocks = V2rayInboundSocks()
    var settingShadowsocks: V2rayInboundShadowsocks?
    var settingVMess: V2rayInboundVMess?
    var settingVLess: V2rayInboundVLess?
    var settingTrojan: V2rayInboundTrojan?

    enum CodingKeys: String, CodingKey {
        case port
        case listen
        case `protocol`
        case tag
        case streamSettings
        case sniffing
        case settings // auto switch
    }
}

extension V2rayInbound {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        port = try container.decode(String.self, forKey: CodingKeys.port)
        listen = try container.decode(String.self, forKey: CodingKeys.listen)
        `protocol` = try container.decode(V2rayProtocolInbound.self, forKey: CodingKeys.protocol)
        tag = try container.decode(String.self, forKey: CodingKeys.tag)

        // ignore nil
        if !(try container.decodeNil(forKey: .streamSettings)) {
            streamSettings = try container.decode(V2rayStreamSettings.self, forKey: CodingKeys.streamSettings)
        }

        // ignore nil
        if !(try container.decodeNil(forKey: .sniffing)) {
            sniffing = try container.decode(V2rayInboundSniffing.self, forKey: CodingKeys.sniffing)
        }

        // decode settings depends on `protocol`
        switch `protocol` {
        case .http:
            settingHttp = try container.decode(V2rayInboundHttp.self, forKey: CodingKeys.settings)
        case .shadowsocks:
            settingShadowsocks = try container.decode(V2rayInboundShadowsocks.self, forKey: CodingKeys.settings)
        case .socks:
            settingSocks = try container.decode(V2rayInboundSocks.self, forKey: CodingKeys.settings)
        case .vmess:
            settingVMess = try container.decode(V2rayInboundVMess.self, forKey: CodingKeys.settings)
        case .vless:
            settingVLess = try container.decode(V2rayInboundVLess.self, forKey: CodingKeys.settings)
        case .trojan:
            settingTrojan = try container.decode(V2rayInboundTrojan.self, forKey: CodingKeys.settings)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(port, forKey: .port)
        try container.encode(listen, forKey: .listen)
        try container.encode(`protocol`, forKey: .protocol)

        // ignore nil
        if tag != nil {
            try container.encode(tag, forKey: .tag)
        }

        // ignore nil
        if streamSettings != nil {
            try container.encode(streamSettings, forKey: .streamSettings)
        }

        // ignore nil
        if sniffing != nil {
            try container.encode(sniffing, forKey: .sniffing)
        }

        // encode settings depends on `protocol`
        switch `protocol` {
        case .http:
            try container.encode(settingHttp, forKey: .settings)
        case .shadowsocks:
            try container.encode(settingShadowsocks, forKey: .settings)
        case .socks:
            try container.encode(settingSocks, forKey: .settings)
        case .vmess:
            try container.encode(settingVMess, forKey: .settings)
        case .vless:
            try container.encode(settingVLess, forKey: .settings)
        case .trojan:
            try container.encode(settingTrojan, forKey: .settings)
        }
    }
}

struct V2rayInboundAllocate: Codable {
    enum strategy: String, Codable {
        case always
        case random
    }

    var strategy: strategy = .always // always or random
    var refresh: Int = 2 // val is 2-5 where strategy = random
    var concurrency: Int = 3 // suggest 3, min 1
}

struct V2rayInboundSniffing: Codable {
    enum dest: String, Codable {
        case tls
        case http
    }

    var enabled: Bool = true
    var destOverride: [dest] = [.tls, .http]
}

struct ProxySettings: Codable {
    var Tag: String?
}

struct V2rayInboundHttp: Codable {
    var timeout: Int = 360
    var allowTransparent: Bool?
    var userLevel: Int?
    var accounts: [V2rayInboundHttpAccount]?
}

struct V2rayInboundHttpAccount: Codable {
    var user: String?
    var pass: String?
}

struct V2rayInboundShadowsocks: Codable {
    var email, method, password: String?
    var udp = false
    var level = 0
    var ota = true
    var network = "tcp" // "tcp" | "udp" | "tcp,udp"
}

struct V2rayInboundSocks: Codable {
    var auth = "noauth" // noauth | password
    var accounts: [V2rayInboundSockAccount]?
    var udp = true
    var ip: String?
    var userLevel: Int?
}

struct V2rayInboundSockAccount: Codable {
    var user: String?
    var pass: String?
}

struct V2rayInboundVMess: Codable {
    var clients: [V2RayInboundVMessClient]?
    var `default`: V2RayInboundVMessDefault? = V2RayInboundVMessDefault()
    var detour: V2RayInboundVMessDetour?
    var disableInsecureEncryption: Bool = false
}

struct V2RayInboundVMessClient: Codable {
    var id: String?
    var level = 0
    var alterId = 64
    var email: String?
}

struct V2RayInboundVMessDetour: Codable {
    var to: String?
}

struct V2RayInboundVMessDefault: Codable {
    var level = 0
    var alterId = 64
}

struct V2rayInboundVLess: Codable {
    var clients: [V2rayInboundVLessClient]?
    var decryption = "none"
    var fallbacks: [V2rayInboundVLessFallback]? = [V2rayInboundVLessFallback()]
}

struct V2rayInboundVLessClient: Codable {
    var id: String?
    var flow = ""
    var level = 0
    var email: String?
}

struct V2rayInboundVLessFallback: Codable {
    var alpn: String? = ""
    var path: String? = ""
    var dest = 80
    var xver = 0
}

struct V2rayInboundTrojan: Codable {
    var clients: [V2rayInboundTrojanClient]?
    var decryption = "none"
    var fallbacks: [V2rayInboundTrojanFallback]? = [V2rayInboundTrojanFallback()]
}

struct V2rayInboundTrojanClient: Codable {
    var password = ""
    var level = 0
    var email: String?
}

struct V2rayInboundTrojanFallback: Codable {
    var alpn: String? = ""
    var path: String? = ""
    var dest = 80
    var xver = 0
}
