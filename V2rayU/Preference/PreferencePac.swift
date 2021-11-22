//
//  Preferences.swift
//  V2rayU
//
//  Created by yanue on 2018/10/19.
//  Copyright © 2018 yanue. All rights reserved.
//

import Alamofire
import Cocoa
import Preferences

let PACRulesDirPath = AppHomePath + "/pac/"
let PACUserRuleFilePath = PACRulesDirPath + "user-rule.txt"
let PACFilePath = PACRulesDirPath + "proxy.js"
var PACUrl = "http://127.0.0.1:" + String(HttpServerPacPort) + "/pac/proxy.js"
let PACAbpFile = PACRulesDirPath + "abp.js"
let GFWListFilePath = PACRulesDirPath + "gfwlist.txt"
let GFWListURL = "https://raw.githubusercontent.com/gfwlist/gfwlist/master/gfwlist.txt"

final class PreferencePacViewController: NSViewController, PreferencePane {
    let preferencePaneIdentifier = Preferences.PaneIdentifier.pacTab
    let preferencePaneTitle = "Pac"
    let toolbarItemIcon = NSImage(named: NSImage.bookmarksTemplateName)!

    @IBOutlet var tips: NSTextField!

    override var nibName: NSNib.Name? {
        return "PreferencePac"
    }

    @IBOutlet var gfwPacListUrl: NSTextField!
    @IBOutlet var userRulesView: NSTextView!

    override func viewDidLoad() {
        super.viewDidLoad()
        // fix: https://github.com/sindresorhus/Preferences/issues/31
        preferredContentSize = NSMakeSize(view.frame.size.width, view.frame.size.height)
        tips.stringValue = ""

        let gfwUrl = UserDefaults.get(forKey: .gfwPacListUrl)
        if gfwUrl != nil {
            gfwPacListUrl.stringValue = gfwUrl!
        } else {
            gfwPacListUrl.stringValue = GFWListURL
        }

        // read userRules from UserDefaults
        let txt = UserDefaults.get(forKey: .userRules)
        var userRuleTxt = """
        ! Put user rules line by line in this file.
        ! See https://adblockplus.org/en/filter-cheatsheet
        ||api.github.com
        ||githubusercontent.com
        """
        if txt != nil {
            if txt!.count > 0 {
                userRuleTxt = txt!
            }
        } else {
            let str = try? String(contentsOfFile: PACUserRuleFilePath, encoding: String.Encoding.utf8)
            if str?.count ?? 0 > 0 {
                userRuleTxt = str!
            }
        }
        // auto include githubusercontent.com api.github.com
        if !userRuleTxt.contains("githubusercontent.com") {
            userRuleTxt.append("\n||api.github.com")
            userRuleTxt.append("\n||githubusercontent.com")
        }
        userRulesView.string = userRuleTxt
    }

    @IBAction func viewPacFile(_: Any) {
        print("viewPacFile PACUrl", PACUrl)
        guard let url = URL(string: PACUrl) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @IBAction func updatePac(_: Any) {
        tips.stringValue = "Updating Pac Rules ..."

        if let str = userRulesView?.string {
            // save user rules into UserDefaults
            UserDefaults.set(forKey: .userRules, value: str)
            UpdatePACFromGFWList(gfwPacListUrl: gfwPacListUrl.stringValue)

            if GeneratePACFile(rewrite: true) {
                // Popup a user notification
                tips.stringValue = "PAC has been updated by User Rules."
            } else {
                tips.stringValue = "It's failed to update PAC by User Rules."
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                // your code here
                self.tips.stringValue = ""
            }
        }
    }

    func UpdatePACFromGFWList(gfwPacListUrl: String) {
        // Make the dir if rulesDirPath is not exesited.
        if !FileManager.default.fileExists(atPath: PACRulesDirPath) {
            do {
                try FileManager.default.createDirectory(atPath: PACRulesDirPath, withIntermediateDirectories: true, attributes: nil)
            } catch {}
        }

        AF.request(gfwPacListUrl).responseString {
            response in
            switch response.result {
            case let .success(v):
                do {
                    try v.write(toFile: GFWListFilePath, atomically: true, encoding: String.Encoding.utf8)

                    // save to UserDefaults
                    UserDefaults.set(forKey: .gfwPacListUrl, value: gfwPacListUrl)
                    UserDefaults.set(forKey: .gfwPacFileContent, value: v)

                    if GeneratePACFile(rewrite: true) {
                        // Popup a user notification
                        self.tips.stringValue = "PAC has been updated by latest GFW List."
                    }
                } catch {
                    // Popup a user notification
                    self.tips.stringValue = "Failed to Write latest GFW List."
                }
            case .failure:
                // Popup a user notification
                self.tips.stringValue = "Failed to download latest GFW List."
            }
        }
    }
}

// Because of LocalSocks5.ListenPort may be changed
func GeneratePACFile(rewrite: Bool) -> Bool {
    let socks5Address = "127.0.0.1"

    let sockPort = UserDefaults.get(forKey: .localSockPort) ?? "1080"

    // permission
    _ = shell(launchPath: "/bin/bash", arguments: ["-c", "cd " + AppHomePath + " && /bin/chmod -R 755 ./pac"])

    // if PACFilePath exist and not need rewrite
    if !(rewrite || !FileManager.default.fileExists(atPath: PACFilePath)) {
        return true
    }

    print("GeneratePACFile rewrite", sockPort)

    let gfwlist = UserDefaults.get(forKey: .gfwPacFileContent) ?? ""
    if let data = Data(base64Encoded: gfwlist, options: .ignoreUnknownCharacters) {
        let str = String(data: data, encoding: String.Encoding.utf8)
        var lines = str!.components(separatedBy: CharacterSet.newlines)
        // read userRules from UserDefaults
        let userRules = UserDefaults.get(forKey: .userRules) ?? ""
        let userRuleLines = userRules.components(separatedBy: CharacterSet.newlines)
        lines = userRuleLines + lines
        // Filter empty and comment lines
        lines = lines.filter { (s: String) -> Bool in
            if s.isEmpty {
                return false
            }
            let c = s[s.startIndex]
            if c == "!" || c == "[" {
                return false
            }
            return true
        }

        do {
            // rule lines to json array
            let rulesJsonData: Data = try JSONSerialization.data(withJSONObject: lines, options: .prettyPrinted)
            let rulesJsonStr = String(data: rulesJsonData, encoding: String.Encoding.utf8)

            // Get raw pac js
            let jsData = try? Data(contentsOf: URL(fileURLWithPath: PACAbpFile))
            var jsStr = String(data: jsData!, encoding: String.Encoding.utf8)

            // Replace rules placeholder in pac js
            jsStr = jsStr!.replacingOccurrences(of: "__RULES__", with: rulesJsonStr!)
            // Replace __SOCKS5PORT__ palcholder in pac js
            jsStr = jsStr!.replacingOccurrences(of: "__SOCKS5PORT__", with: "\(sockPort)")
            // Replace __SOCKS5ADDR__ palcholder in pac js
            var sin6 = sockaddr_in6()
            if socks5Address.withCString({ cstring in inet_pton(AF_INET6, cstring, &sin6.sin6_addr) }) == 1 {
                jsStr = jsStr!.replacingOccurrences(of: "__SOCKS5ADDR__", with: "[\(socks5Address)]")
            } else {
                jsStr = jsStr!.replacingOccurrences(of: "__SOCKS5ADDR__", with: socks5Address)
            }
            print("PACFilePath", PACFilePath)

            // Write the pac js to file.
            try jsStr!.data(using: String.Encoding.utf8)?.write(to: URL(fileURLWithPath: PACFilePath), options: .atomic)
            return true
        } catch {}
    }
    return false
}
