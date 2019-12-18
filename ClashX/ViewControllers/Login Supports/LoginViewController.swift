//
//  LoginViewController.swift
//
//
//  Created by yicheng on 2019/1/11.
//

import Cocoa

class LoginViewController: NSViewController {
    @IBOutlet var logoView: NSImageView!

    @IBOutlet var emailTextField: NSTextField!

    @IBOutlet var passwordTextField: NSSecureTextField!

    static func create() -> NSWindowController {
        let sb = NSStoryboard(name: NSStoryboard.Name("LoginSupport"), bundle: nil)
        let vc = sb.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("loginWindowController")) as! NSWindowController
        return vc
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        logoView.image = logoView.image?.tint(color: NSColor.black)
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        view.window?.delegate = self
        view.window?.styleMask.remove(.resizable)
        view.window?.styleMask.remove(.miniaturizable)
        view.window?.level = .floating
        view.window?.center()
        view.window?.title = "DlerCloud"
    }

    @IBAction func actionLogin(_ sender: Any) {
        if emailTextField.stringValue.count == 0 {
            NSAlert.alert(with: "邮箱不能为空")
            return
        }

        if passwordTextField.stringValue.count == 0 {
            NSAlert.alert(with: "密码不能为空")
            return
        }

        view.window?.styleMask.remove(.closable)

        let hud = MBProgressHUD(view: view)!
        hud.labelText = "登录中"
        hud.show(true)
        view.addSubview(hud)
        hud.removeFromSuperViewOnHide = true

        WebPortalManager.shared.login(mail: emailTextField.stringValue, password: passwordTextField.stringValue) {
            errDesp in
            if let errDesp = errDesp {
                NSAlert.alert(with: errDesp)
                hud.hide(true)
                self.view.window?.styleMask.insert(.closable)
                return
            }
            hud.labelText = "获取托管配置文件地址"
            WebPortalManager.shared.refreshConfigUrl() {
                errDesp, config in
                if let errDesp = errDesp {
                    NSAlert.alert(with: errDesp)
                    hud.hide(true)
                    print(errDesp)
                    self.view.window?.styleMask.insert(.closable)
                    return
                }

                guard let config = config else { assertionFailure(); return }

                hud.labelText = "刷新配置文件"
                RemoteConfigManager.updateConfig(config: config, complete: {
                    [weak config, weak self] err in
                    guard let config = config, let self = self else { return }
                    hud.hide(true)

                    if let err = err {
                        NSAlert.alert(with: err)
                        self.view.window?.styleMask.insert(.closable)
                        return
                    }
                    AppDelegate.shared.updateConfig(configName: config.name, showNotification: true, completeHandler: nil)
                    config.updateTime = Date()
                    RemoteConfigManager.shared.saveConfigs()
                    self.dismiss(nil)
                    self.view.window?.close()
                })
            }
        }
    }
}

extension LoginViewController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {}
}
