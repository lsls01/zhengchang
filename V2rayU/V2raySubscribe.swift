//
//  V2raySubscribe.swift
//  V2rayU
//
//  Created by yanue on 2019/5/15.
//  Copyright © 2019 yanue. All rights reserved.
//

import Alamofire
import Cocoa
import SwiftyJSON

// ----- v2ray subscribe manager -----
class V2raySubscribe: NSObject {
    static var shared = V2raySubscribe()

    // Initialization
    override init() {
        super.init()
        print("V2raySubscribe init")
        V2raySubscribe.loadConfig()
    }

    // v2ray subscribe list
    private static var v2raySubList: [V2raySubItem] = []

    // (init) load v2ray subscribe list from UserDefaults
    static func loadConfig() {
        // static reset
        v2raySubList = []

        // load name list from UserDefaults
        let list = UserDefaults.getArray(forKey: .v2raySubList)

        if list == nil {
            return
        }
        // load each V2raySubItem
        for item in list! {
            guard let v2ray = V2raySubItem.load(name: item) else {
                // delete from UserDefaults
                V2raySubItem.remove(name: item)
                continue
            }
            // append
            v2raySubList.append(v2ray)
        }
    }

    // get list from v2ray subscribe list
    static func list() -> [V2raySubItem] {
        return v2raySubList
    }

    // get count from v2ray subscribe list
    static func count() -> Int {
        return v2raySubList.count
    }

    static func edit(rowIndex: Int, remark: String) {
        if !v2raySubList.indices.contains(rowIndex) {
            NSLog("index out of range", rowIndex)
            return
        }

        // update list
        v2raySubList[rowIndex].remark = remark

        // save
        let v2ray = v2raySubList[rowIndex]
        v2ray.remark = remark
        v2ray.store()
    }

    static func edit(rowIndex: Int, url: String) {
        if !v2raySubList.indices.contains(rowIndex) {
            NSLog("index out of range", rowIndex)
            return
        }

        // update list
        v2raySubList[rowIndex].url = url

        // save
        let v2ray = v2raySubList[rowIndex]
        v2ray.url = url
        v2ray.store()
    }

    // move item to new index
    static func move(oldIndex: Int, newIndex: Int) {
        if !V2raySubscribe.v2raySubList.indices.contains(oldIndex) {
            NSLog("index out of range", oldIndex)
            return
        }
        if !V2raySubscribe.v2raySubList.indices.contains(newIndex) {
            NSLog("index out of range", newIndex)
            return
        }

        let o = v2raySubList[oldIndex]
        v2raySubList.remove(at: oldIndex)
        v2raySubList.insert(o, at: newIndex)

        // update subscribe list UserDefaults
        saveItemList()
    }

    // add v2ray subscribe (by scan qrcode)
    static func add(remark: String, url: String) {
        // name is : subscribe. + uuid
        let name = "subscribe." + UUID().uuidString

        let v2ray = V2raySubItem(name: name, remark: remark, url: url)
        // save to v2ray UserDefaults
        v2ray.store()

        // just add to mem
        v2raySubList.append(v2ray)

        // update subscribe list UserDefaults
        saveItemList()
    }

    // remove v2ray subscribe (tmp and UserDefaults and config json file)
    static func remove(idx: Int) {
        if !V2raySubscribe.v2raySubList.indices.contains(idx) {
            NSLog("index out of range", idx)
            return
        }

        let v2ray = V2raySubscribe.v2raySubList[idx]

        // delete from tmp
        v2raySubList.remove(at: idx)

        // delete from v2ray UserDefaults
        V2raySubItem.remove(name: v2ray.name)

        // update subscribe list UserDefaults
        saveItemList()
    }

    // update subscribe list UserDefaults
    private static func saveItemList() {
        var v2raySubList: [String] = []
        for item in V2raySubscribe.list() {
            v2raySubList.append(item.name)
        }

        UserDefaults.setArray(forKey: .v2raySubList, value: v2raySubList)
    }

    // load json file data
    static func loadSubItem(idx: Int) -> V2raySubItem? {
        if !V2raySubscribe.v2raySubList.indices.contains(idx) {
            NSLog("index out of range", idx)
            return nil
        }

        return v2raySubList[idx]
    }
}

// ----- v2ray subscribe item -----
class V2raySubItem: NSObject, NSCoding {
    var name: String
    var remark: String
    var isValid: Bool
    var url: String

    // init
    required init(name: String, remark: String, url: String, isValid: Bool = true) {
        self.name = name
        self.remark = remark
        self.isValid = isValid
        self.url = url
    }

    // decode
    required init(coder decoder: NSCoder) {
        name = decoder.decodeObject(forKey: "Name") as? String ?? ""
        remark = decoder.decodeObject(forKey: "Remark") as? String ?? ""
        isValid = decoder.decodeBool(forKey: "IsValid")
        url = decoder.decodeObject(forKey: "Url") as? String ?? ""
    }

    // object encode
    func encode(with coder: NSCoder) {
        coder.encode(name, forKey: "Name")
        coder.encode(remark, forKey: "Remark")
        coder.encode(isValid, forKey: "IsValid")
        coder.encode(url, forKey: "Url")
    }

    // store into UserDefaults
    func store() {
        if let modelData = try? NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: true) {
            UserDefaults.standard.set(modelData, forKey: name)
        }
    }

    // static load from UserDefaults
    static func load(name: String) -> V2raySubItem? {
        guard let myModelData = UserDefaults.standard.data(forKey: name) else {
            return nil
        }
        do {
            let result = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(myModelData)
            return result as? V2raySubItem
        } catch {
            print("load userDefault error:", error)
            return nil
        }
    }

    // remove from UserDefaults
    static func remove(name: String) {
        UserDefaults.standard.removeObject(forKey: name)
    }
}

// ----- v2ray subscribe  updater -----
let NOTIFY_UPDATE_SubSync = Notification.Name(rawValue: "NOTIFY_UPDATE_SubSync")

class V2raySubSync: NSObject {
    // sync from Subscribe list
    public func sync() {
        print("sync from Subscribe list")
        V2raySubscribe.loadConfig()
        let list = V2raySubscribe.list()

        if list.count == 0 {
            logTip(title: "fail: ", uri: "", informativeText: " please add Subscription Url")
        }

        for item in list {
            dlFromUrl(url: item.url, subscribe: item.name)
        }
    }

    public func dlFromUrl(url: String, subscribe: String) {
        logTip(title: "loading from : ", uri: "", informativeText: url + "\n\n")

        var request = URLRequest(url: URL(string: url)!)
        request.cachePolicy = .reloadIgnoringCacheData

        AF.request(request).responseString { response in
            switch response.result {
            case let .success(data):
                self.handle(base64Str: data, subscribe: subscribe, url: url)

            case let .failure(error):
                print("dlFromUrl error:", url, " -- ", error)
                self.logTip(title: "loading fail : ", uri: "", informativeText: url)
            }
        }
    }

    func handle(base64Str: String, subscribe: String, url: String) {
        let strTmp = base64Str.trimmingCharacters(in: .whitespacesAndNewlines).base64Decoded()
        if strTmp == nil {
            logTip(title: "parse fail : ", uri: "", informativeText: base64Str)
            return
        }

        logTip(title: "del old from url : ", uri: "", informativeText: url + "\n\n")

        // remove old v2ray servers by subscribe
        V2rayServer.remove(subscribe: subscribe)

        let id = String(url.suffix(32))

        let list = strTmp!.trimmingCharacters(in: .newlines).components(separatedBy: CharacterSet.newlines)
        for item in list {
            // import every server
            if item.count == 0 {
                continue
            } else {
                importUri(uri: item.trimmingCharacters(in: .whitespacesAndNewlines), subscribe: subscribe, id: id)
            }
        }
    }

    func importUri(uri: String, subscribe: String, id: String) {
        if uri.count == 0 {
            logTip(title: "fail: ", uri: uri, informativeText: "uri not found")
            return
        }

        if URL(string: uri) == nil {
            logTip(title: "fail: ", uri: uri, informativeText: "no found ss://, ssr://, vmess://")
            return
        }

        if let importUri = ImportUri.importUri(uri: uri, id: id) {
            if importUri.isValid {
                // add server
                V2rayServer.add(remark: importUri.remark, json: importUri.json, isValid: true, url: importUri.uri, subscribe: subscribe)
                // refresh server
                menuController.showServers()

                // reload server
                if menuController.configWindow != nil {
                    menuController.configWindow.serversTableView.reloadData()
                }

                logTip(title: "success: ", uri: uri, informativeText: importUri.remark)
            } else {
                logTip(title: "fail: ", uri: uri, informativeText: importUri.error)
            }

            return
        }
    }

    func logTip(title: String = "", uri: String = "", informativeText: String = "") {
        NotificationCenter.default.post(name: NOTIFY_UPDATE_SubSync, object: title + informativeText + "\n")
        print("SubSync", title + informativeText)
        if uri != "" {
            NotificationCenter.default.post(name: NOTIFY_UPDATE_SubSync, object: "url: " + uri + "\n\n\n")
        }
    }
}
