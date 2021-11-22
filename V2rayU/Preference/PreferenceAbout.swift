//
//  Preferences.swift
//  V2rayU
//
//  Created by yanue on 2018/10/19.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa
import Preferences

final class PreferenceAboutViewController: NSViewController, PreferencePane {
    let preferencePaneIdentifier = Preferences.PaneIdentifier.aboutTab
    let preferencePaneTitle = "About"
    let toolbarItemIcon = NSImage(named: NSImage.infoName)!

    @IBOutlet var VersionLabel: NSTextField!
    @IBOutlet var V2rayCoreVersion: NSTextField!

    override var nibName: NSNib.Name? {
        return "PreferenceAbout"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // fix: https://github.com/sindresorhus/Preferences/issues/31
        preferredContentSize = NSMakeSize(view.frame.size.width, view.frame.size.height)

        VersionLabel.stringValue = "Version " + appVersion

        if let v2rayCoreVersion = UserDefaults.get(forKey: .xRayCoreVersion) {
            V2rayCoreVersion.stringValue = "based on v2ray-core " + v2rayCoreVersion
        }
    }
}
