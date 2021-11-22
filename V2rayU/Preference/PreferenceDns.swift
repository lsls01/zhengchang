//
//  Preferences.swift
//  V2rayU
//
//  Created by yanue on 2018/10/19.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa
import JavaScriptCore
import Preferences

final class PreferenceDnsViewController: NSViewController, PreferencePane {
    let preferencePaneIdentifier = Preferences.PaneIdentifier.dnsTab
    let preferencePaneTitle = "Dns"
    let toolbarItemIcon = NSImage(named: NSImage.multipleDocumentsName)!

    @IBOutlet var tips: NSTextField!
    @IBOutlet var saveBtn: NSButtonCell!

    override var nibName: NSNib.Name? {
        return "PreferenceDns"
    }

    @IBOutlet var dnsJson: NSTextView!

    override func viewDidLoad() {
        super.viewDidLoad()
        // fix: https://github.com/sindresorhus/Preferences/issues/31
        preferredContentSize = NSMakeSize(view.frame.size.width, view.frame.size.height)
        tips.stringValue = ""
        dnsJson.string = UserDefaults.get(forKey: .v2rayDnsJson) ?? "{}"
        saveBtn.state = .on
    }

    @IBAction func save(_: Any) {
        tips.stringValue = "save success"
        saveBtn.state = .on

        if var str = dnsJson?.string {
            if let context = JSContext() {
                context.evaluateScript(jsSourceFormatConfig)
                // call js func
                if let formatFunction = context.objectForKeyedSubscript("JsonBeautyFormat") {
                    if let result = formatFunction.call(withArguments: [str.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) as Any]) {
                        // error occurred with prefix "error:"
                        if let reStr = result.toString(), reStr.count > 0 {
                            if !reStr.hasPrefix("error:") {
                                str = reStr

                                // save user rules into UserDefaults
                                UserDefaults.set(forKey: .v2rayDnsJson, value: str)

                                // replace
                                v2rayConfig.dnsJson = str

                                // set current server item and reload v2ray-core
                                regenerateAllConfig()

                                dnsJson.string = reStr
                            } else {
                                tips.stringValue = reStr
                            }
                        }
                    }
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                // your code here
                self.tips.stringValue = ""
            }
        }
    }

    @IBAction func goHelp(_: Any) {
        guard let url = URL(string: "https://guide.v2fly.org/basics/dns.html") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @IBAction func goViewConfig(_: Any) {
        let confUrl = PACUrl.replacingOccurrences(of: "pac/proxy.js", with: "config.json")
        guard let url = URL(string: confUrl) else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
