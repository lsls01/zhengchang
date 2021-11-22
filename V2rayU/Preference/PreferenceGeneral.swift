//
//  Preferences.swift
//  V2rayU
//
//  Created by yanue on 2018/10/19.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa
import Preferences
import ServiceManagement

final class PreferenceGeneralViewController: NSViewController, PreferencePane {
    let preferencePaneIdentifier = Preferences.PaneIdentifier.generalTab
    let preferencePaneTitle = "General"
    let toolbarItemIcon = NSImage(named: NSImage.preferencesGeneralName)!

    override var nibName: NSNib.Name? {
        return "PreferenceGeneral"
    }

    @IBOutlet var autoLaunch: NSButtonCell!
    @IBOutlet var autoCheckVersion: NSButtonCell!
    @IBOutlet var autoUpdateServers: NSButtonCell!
//    @IBOutlet weak var autoSelectFastestServer: NSButtonCell!

    override func viewDidLoad() {
        super.viewDidLoad()
        // fix: https://github.com/sindresorhus/Preferences/issues/31
        preferredContentSize = NSMakeSize(view.frame.size.width, view.frame.size.height)

        if UserDefaults.getBool(forKey: .autoLaunch) {
            autoLaunch.state = .on
        }
        if UserDefaults.getBool(forKey: .autoCheckVersion) {
            autoCheckVersion.state = .on
        }
        if UserDefaults.getBool(forKey: .autoUpdateServers) {
            autoUpdateServers.state = .on
        }
//        if UserDefaults.getBool(forKey: .autoSelectFastestServer) {
//            autoSelectFastestServer.state = .on
//        }
    }

    @IBAction func SetAutoLogin(_ sender: NSButtonCell) {
        SMLoginItemSetEnabled(launcherAppIdentifier as CFString, sender.state == .on)
        UserDefaults.setBool(forKey: .autoLaunch, value: sender.state == .on)
    }

    @IBAction func SetAutoCheckVersion(_ sender: NSButtonCell) {
        UserDefaults.setBool(forKey: .autoCheckVersion, value: sender.state == .on)
    }

    @IBAction func SetAutoUpdateServers(_ sender: NSButtonCell) {
        UserDefaults.setBool(forKey: .autoUpdateServers, value: sender.state == .on)
    }

//    @IBAction func SetAutoSelectFastestServer(_ sender: NSButton) {
//        UserDefaults.setBool(forKey: .autoSelectFastestServer, value: sender.state == .on)
//    }

    @IBAction func goFeedback(_: NSButton) {
        guard let url = URL(string: "https://github.com/yanue/v2rayu/issues") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @IBAction func checkVersion(_ sender: NSButton) {
        // need set SUFeedURL into plist
        V2rayUpdater.checkForUpdates(sender)
    }
}
