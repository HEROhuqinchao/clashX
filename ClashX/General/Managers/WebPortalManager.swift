//
//  WebPortalManager.swift
//  ClashX
//
//  Created by yicheng on 2019/1/11.
//  Copyright © 2019 west2online. All rights reserved.
//

import Alamofire
import Cocoa
import SwiftyJSON

class WebPortalManager: NSObject {
    static let shared = WebPortalManager()
    static let hasWebProtal = true

    private let entranceUrl = "https://dler.cloud"
    private lazy var apiUrl: String = entranceUrl
    
    private var loginWC: NSWindowController? = nil
    
    private lazy var webPortalMenuItem: NSMenuItem = {
        let menuItem = NSMenuItem(title: "DlerCloud", action: #selector(actionLogin), keyEquivalent: "")
        menuItem.target = self
        return menuItem
    }()

    private lazy var accountItem: NSMenuItem = {
        return NSMenuItem(title: username ?? "", action: nil, keyEquivalent: "")
    }()

    private lazy var refreshRemoteConfigItem: NSMenuItem = {
        let item = NSMenuItem(title: "更新托管配置", action: #selector(actionRefreshConfigUrl), keyEquivalent: "")
        item.target = self
        return item
    }()

    private lazy var logoutItem: NSMenuItem = {
        let item = NSMenuItem(title: "注销", action: #selector(actionLogout), keyEquivalent: "")
        item.target = self
        return item
    }()
    
    private lazy var menus: NSMenu = {
        let m = NSMenu(title: "")
        m.items = [accountItem, refreshRemoteConfigItem, logoutItem]
        return m
    }()

    private var isLogin: Bool {
        return username != nil && token != nil
    }

    private var username: String? {
        get {
            return UserDefaults.standard.string(forKey: "kwebusername")
        }
        set {
            if let name = newValue {
                accountItem.title = name
                UserDefaults.standard.set(name, forKey: "kwebusername")
            } else {
                UserDefaults.standard.removeObject(forKey: "kwebusername")
            }
        }
    }

    private var token: String? {
        get {
            return UserDefaults.standard.string(forKey: "ktoken")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "ktoken")
        }
    }

    func addWebProtalMenuItem(_ menu: inout NSMenu) {
        menu.insertItem(webPortalMenuItem, at: 0)
        updateWebProtalMenu()
    }
    
    func updateWebProtalMenu() {
        if WebPortalManager.shared.isLogin {
            webPortalMenuItem.title = "Dler Cloud：已登录"
            webPortalMenuItem.submenu = menus
        } else {
            webPortalMenuItem.title = "Dler Cloud：未登录"
            webPortalMenuItem.submenu = nil
        }
    }
    
    @IBAction func actionWebProtal(_ sender: Any) {
        if WebPortalManager.shared.isLogin {return}
        
        
    }

    func refreshApiUrl(complete: (() -> Void)? = nil) {
        print("getting real api url")
        AF.request(entranceUrl, method: .head).response(queue: DispatchQueue.global()) { res in
            guard let targetUrl = res.response?.url,
                let scheme = targetUrl.scheme,
                let host = targetUrl.host
            else {
                self.apiUrl = self.entranceUrl
                complete?()
                return
            }
            print("get target url:\(targetUrl.absoluteString)")
            self.apiUrl = "\(scheme)://\(host)"
            complete?()
        }
    }

    private func req(
        _ url: String,
        method: HTTPMethod = .get,
        parameters: Parameters? = nil,
        encoding: ParameterEncoding = URLEncoding.default
    )
        -> DataRequest {
        //            guard let apiUrl = apiUrl else {
        //                let sema = DispatchSemaphore(value: 0)
        //                refreshApiUrl(){
        //                    sema.signal()
        //                }
        //                sema.wait()
        //                return self.req(url, method: method, parameters: parameters, encoding: encoding)
        //            }

        return AF.request(apiUrl + url,
                          method: method,
                          parameters: parameters,
                          encoding: encoding,
                          headers: [:])
    }

    func login(mail: String, password: String, complete: ((String?) -> Void)? = nil) {
        req("/api/v1/login",
            method: .post,
            parameters: ["email": mail, "passwd": password]).responseJSON {
            [weak self]
            resp in
            guard let self = self else { return }
            guard let r = try? resp.result.get() else {
                if resp.response?.statusCode == 200 {
                    self.username = mail
                    complete?(nil)
                } else {
                    complete?("请求失败")
                }
                return
            }

            let json = JSON(r)

            if let token = json["data"]["token"].string {
                self.username = mail
                self.token = token
                complete?(nil)
            } else {
                complete?("登录失败" + json["msg"].stringValue)
            }
        }
    }

    func getRemoteConfig(token: String, complete: ((String?, String?) -> Void)? = nil) {
        req("/api/v1/managed/clash_ss", method: .post, parameters: ["access_token": token], encoding: JSONEncoding.default).responseJSON { res in
            guard let value = try? res.result.get() else {
                complete?("请求失败", nil)
                return
            }

            let json = JSON(value)
            guard let token = json["data"].string else {
                complete?("解析失败", nil)
                return
            }

            complete?(nil, token)
        }
    }

    func refreshConfigUrl(complete: ((String?, RemoteConfigModel?) -> Void)? = nil) {
        guard let token = self.token else {
            complete?("登录失效！请重新登录", nil)
            return
        }

        getRemoteConfig(token: token) {
            err, url in

            if let err = err {
                complete?(err, nil)
                return
            }

            let name = "DlerCloud"
            let finalConfig: RemoteConfigModel
            if let model = RemoteConfigManager.shared.configs.first(where: { $0.name == name }) {
                model.url = url!
                finalConfig = model
            } else {
                let config = RemoteConfigModel(url: url!, name: "DlerCloud")
                RemoteConfigManager.shared.configs.append(config)
                finalConfig = config
            }

            RemoteConfigManager.shared.saveConfigs()
            complete?(nil, finalConfig)
        }
    }
    
    @objc func actionLogin() {
        if let wc = loginWC {
            wc.becomeFirstResponder()
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let win = LoginViewController.create()
        win.showWindow(webPortalMenuItem)
        NSApp.activate(ignoringOtherApps: true)
        loginWC = win
        win.window?.delegate = self
    }

    @objc func actionLogout() {
        username = nil
        token = nil
        updateWebProtalMenu()
    }

    @objc func actionRefreshConfigUrl() {
        NSUserNotificationCenter.default.post(title: "开始更新", info: "请稍后")
        refreshConfigUrl { err, config in
            if let err = err {
                NSUserNotificationCenter.default.post(title: "更新失败", info: err)
                return
            }

            guard let config = config else { assertionFailure(); return }

            RemoteConfigManager.updateConfig(config: config, complete: { [weak config] error in
                NSUserNotificationCenter.default.post(title: "更新成功", info: "Done")
                guard let config = config else { return }
                config.updateTime = Date()
                RemoteConfigManager.shared.saveConfigs()
                ConfigManager.selectConfigName = config.name
                AppDelegate.shared.updateConfig()
            })
        }
    }
}

extension WebPortalManager : NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        loginWC = nil
        updateWebProtalMenu()
    }
}
