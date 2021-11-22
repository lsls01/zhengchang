//
//  AppDelegate.swift
//  V2rayULauncher
//
//  Created by yanue on 2018/10/19.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa
import os.log

class V2rayULauncherApplication: NSApplication {
    let strongDelegate = AppDelegate()

    override init() {
        super.init()
        delegate = strongDelegate
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_: Notification) {
        let mainAppIdentifier = "net.yanue.V2rayU"
        let running = NSWorkspace.shared.runningApplications
        var alreadyRunning = false

        for app in running {
            if app.bundleIdentifier == mainAppIdentifier {
                alreadyRunning = true
                break
            }
        }

        if !alreadyRunning {
            DistributedNotificationCenter.default().addObserver(NSApp as Any, selector: #selector(NSApplication.terminate(_:)), name: Notification.Name("terminateV2rayU"), object: mainAppIdentifier)

            let path = Bundle.main.bundlePath as NSString
            var components = path.pathComponents
            components.removeLast()
            components.removeLast()
            components.removeLast()
            components.append("MacOS")
            components.append("V2rayU")

            let newPath = NSString.path(withComponents: components)
            let newURL = URL(fileURLWithPath: newPath)
            NSWorkspace.shared.openApplication(at: newURL, configuration: .init()) { _, _ in
            }
        } else {
            NSApp.terminate(self)
        }
    }

    func applicationWillTerminate(_: Notification) {
        // Insert code here to tear down your application
    }
}
