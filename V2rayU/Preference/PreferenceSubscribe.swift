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
import SwiftyJSON

final class PreferenceSubscribeViewController: NSViewController, PreferencePane {
    let preferencePaneIdentifier = Preferences.PaneIdentifier.subscribeTab
    let preferencePaneTitle = "Subscribe"
    let toolbarItemIcon = NSImage(named: NSImage.userAccountsName)!
    let tableViewDragType: String = "v2ray.subscribe"
    var tip: String = ""

    @IBOutlet var remark: NSTextField!
    @IBOutlet var url: NSTextField!
    @IBOutlet var tableView: NSTableView!
    @IBOutlet var upBtn: NSButton!
    @IBOutlet var logView: NSView!
    @IBOutlet var subscribeView: NSView!
    @IBOutlet var logArea: NSTextView!
    @IBOutlet var hideLogs: NSButton!

    // our variable
    override var nibName: NSNib.Name? {
        return "PreferenceSubscribe"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // fix: https://github.com/sindresorhus/Preferences/issues/31
        preferredContentSize = NSMakeSize(view.frame.size.width, view.frame.size.height)

        logView.isHidden = true
        subscribeView.isHidden = false
        logArea.string = ""

        // reload tableview
        V2raySubscribe.loadConfig()

        // set global hotkey
        let notifyCenter = NotificationCenter.default
        notifyCenter.addObserver(forName: NOTIFY_UPDATE_SubSync, object: nil, queue: nil, using: {
            notice in
            self.tip += notice.object as? String ?? ""

            self.logArea.string = self.tip
            self.logArea.scrollToEndOfDocument("")
        })
    }

    @IBAction func addSubscribe(_: Any) {
        var url = self.url.stringValue
        var remark = self.remark.stringValue
        // trim
        url = url.trimmingCharacters(in: .whitespacesAndNewlines)
        remark = remark.trimmingCharacters(in: .whitespacesAndNewlines)

        if url.count == 0 {
            self.url.becomeFirstResponder()
            return
        }

        // special char
        let charSet = NSMutableCharacterSet()
        charSet.formUnion(with: CharacterSet.urlQueryAllowed)
        charSet.addCharacters(in: "#")

        guard let rUrl = URL(string: url.addingPercentEncoding(withAllowedCharacters: charSet as CharacterSet)!) else {
            self.url.becomeFirstResponder()
            return
        }

        if rUrl.scheme == nil || rUrl.host == nil {
            self.url.becomeFirstResponder()
            return
        }

        if remark.count == 0 {
            self.remark.becomeFirstResponder()
            return
        }

        // add to server
        V2raySubscribe.add(remark: remark, url: url)

        // reset
        self.remark.stringValue = ""
        self.url.stringValue = ""

        // reload tableview
        tableView.reloadData()
    }

    @IBAction func removeSubscribe(_: Any) {
        let idx = tableView.selectedRow
        if tableView.selectedRow > -1 {
            if let item = V2raySubscribe.loadSubItem(idx: idx) {
                print("remove sub item", item.name, item.url)
                // remove old v2ray servers by subscribe
                V2rayServer.remove(subscribe: item.name)
            }
            // remove subscribe
            V2raySubscribe.remove(idx: idx)

            // selected prev row
            let cnt: Int = V2raySubscribe.count()
            var rowIndex: Int = idx - 1
            if idx > 0, idx < cnt {
                rowIndex = idx
            }
            if rowIndex == -1 {
                rowIndex = 0
            }

            // reload tableview
            tableView.reloadData()

            // fix
            if cnt > 0 {
                // selected row
                tableView.selectRowIndexes(NSIndexSet(index: rowIndex) as IndexSet, byExtendingSelection: true)
            }
        }
    }

    @IBAction func hideLogs(_: Any) {
        subscribeView.isHidden = false
        logView.isHidden = true
    }

    // update servers from subscribe url list
    @IBAction func updateSubscribe(_: Any) {
        upBtn.state = .on
        subscribeView.isHidden = true
        logView.isHidden = false
        logArea.string = ""
        tip = ""

        // update Subscribe
        V2raySubSync().sync()
    }
}

extension PreferenceSubscribeViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in _: NSTableView) -> Int {
        return V2raySubscribe.count()
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = tableColumn?.identifier as NSString?
        let data = V2raySubscribe.list()
        if identifier == "remarkCell" {
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "remarkCell"), owner: self) as! NSTableCellView
            cell.textField?.stringValue = data[row].remark
            return cell
        } else if identifier == "urlCell" {
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "urlCell"), owner: self) as! NSTableCellView
            cell.textField?.stringValue = data[row].url
            return cell
        }
        return nil
    }
}
