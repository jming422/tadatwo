import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate, AuthNetDelegate {
    
    // --- Stored properties --- //
    
    var deviceID: String? = nil
    var anetInstance: AuthNet? = nil
    var sessionToken: String? = nil
    
    var loginResult: FlutterResult? = nil
    var txnResult: FlutterResult? = nil

    // --- Convenience Functions --- //
    
    func makeTransactionObject(_ amount: String) -> AnetEMVTransactionRequest {
        let req = AnetEMVTransactionRequest()
        req.emvTransactionType = .payment
        req.anetApiRequest.merchantAuthentication.sessionToken = self.sessionToken
        req.anetApiRequest.merchantAuthentication.mobileDeviceId = self.deviceID
        req.amount = amount
        req.retail = TransRetailInfoType()
        req.retail.marketType = "2"
        req.retail.deviceType = "7"
        
        return req
    }

    // --- AuthNetDelegate Functions --- //
    
    func mobileDeviceLoginSucceeded(_ res: MobileDeviceLoginResponse!) {
        print("Hit @mobileDeviceLoginSucceeded")
        guard let result = loginResult else {
            print("@mobileDeviceLoginSucceeded: Error! Nothing stored in loginResult!")
            return
        }
        
        print("Login response")
        if res.errorType != NO_ERROR {
            let messages = res.anetApiResponse.messages.messageArray ?? ["Nope, can't find them"]
            result(FlutterError(code: String(describing: res.errorType), message: "@mobileDeviceLoginSucceeded: Got an error from Authorize! \(messages)", details: nil))
            return
        }
        
        print("Successfully captured session token")
        sessionToken = res.sessionToken
        
        result(true)
        loginResult = nil
    }

    func paymentSucceeded(_ res: CreateTransactionResponse!) {
        print("Hit @paymentSucceeded")
        guard let result = txnResult else {
            print("@paymentSucceeded: Error! Nothing stored in txnResult!")
            return
        }
        
        print("Txn response")
        if res.errorType != NO_ERROR {
            let messages = res.anetApiResponse.messages.messageArray ?? ["Nope, can't find them"]
            result(FlutterError(code: String(describing: res.errorType), message: "@paymentSucceeded: Got an error from Authorize! \(messages)", details: nil))
            return
        }
        
        print("Charge OK")
        result(res.transactionResponse.transId)
        txnResult = nil
    }
    
    func requestFailed(_ res: AuthNetResponse!) {
        print("Hit @requestFailed!")
        
        let messages = res.anetApiResponse.messages.messageArray ?? ["Nope, can't find them"]
        let errString = "@paymentSucceeded: Got an error '\(String(describing: res.errorType))' from Authorize! \(messages)"
        print(errString)
        let flutterErr = FlutterError(code: "ANET_RES_ERROR", message: errString, details: nil)
        loginResult?(flutterErr)
        txnResult?(flutterErr)
        return
    }
    
    // --- Flutter-exposed Functions --- //
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
        ) -> Bool {
        
        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
        let authNetChannel = FlutterMethodChannel(name: "tadatwo.example.com/authnet", binaryMessenger: controller)
        
        authNetChannel.setMethodCallHandler({[weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            switch call.method {
            case "initAuthNet":
                let argErr = FlutterError(code: "BAD_ARGS", message: "Failed to parse arguments!", details: nil)
                guard let args = call.arguments as? Dictionary<String, String> else {result(argErr); return }
                guard let e = args["env"] else { result(argErr); return }
                guard let d = args["deviceID"] else { result(argErr); return }
                guard let u = args["user"] else { result(argErr); return }
                guard let p = args["pass"] else { result(argErr); return }
                
                self?.initAuthNet(env: e, devID: d, user: u, pass: p, result: result)
            case "chargeIt":
                self?.chargeIt(result: result)
            case "chargeBT":
                self?.chargeBT(result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        })
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    private func initAuthNet(env: String, devID: String, user: String, pass: String, result: @escaping FlutterResult) {
        guard loginResult == nil else {
            result(FlutterError(code: "IN_PROGRESS", message: "Another login attempt already in progress", details: nil))
            return
        }
        guard anetInstance == nil else {
            result(FlutterError(code: "ALREADY_INIT", message: "Authorize merchant interface already initialized", details: nil))
            return
        }
        
        let lEnv = env.lowercased()
        if !(lEnv == "live" || lEnv == "test") {
            print("Provided envrionment was neither 'test' nor 'live'.")
            result(FlutterError(code: "BAD_ENV", message: "Provided envrionment was neither 'test' nor 'live'.", details: nil))
            return
        }
        
        print("Received envrionment: \(lEnv)")
        // Set the stored property so we can hold on to this instance of the Authorize.Net client
        anetInstance = AuthNet(environment: lEnv == "live" ? ENV_LIVE : ENV_TEST)
        guard let anet = anetInstance else {
            result(FlutterError(code:"ANET_INIT_FAIL", message: "Failed to initialize Authorize.Net client", details: nil))
            return
        }
        // Instruct the Authorize.Net client to use this class as its AuthNetDelegate
        anet.delegate = self
        
        // Set the device ID stored property
        deviceID = devID
        
        print("Attempting mobile login")
        let loginReq = MobileDeviceLoginRequest()
        loginReq.anetApiRequest.merchantAuthentication.name = user
        loginReq.anetApiRequest.merchantAuthentication.password = pass
        loginReq.anetApiRequest.merchantAuthentication.mobileDeviceId = deviceID
        
        // Store this call's result into a property so the delegate function can access it when it's called
        loginResult = result
        anet.mobileDeviceLoginRequest(loginReq)
        // Execution should then hit mobileDeviceLoginSucceeded
    }
    
    private func chargeIt(result: @escaping FlutterResult) {
        guard let anet = anetInstance else {
            result(FlutterError(code: "ANET_NOT_INIT", message: "Authorize merchant interface not initialized!", details: nil))
            return
        }
        guard let token = sessionToken else {
            result(FlutterError(code: "ANET_NOT_LOGGED_IN", message: "Not logged in to Authorize merchant interface!", details: nil))
            return
        }
        
        print("Trying to charge it")
        let explode = { (x: String) in
            print("AAAH explosions!! \(x)")
            result(FlutterError(code: "ANET_SDK_ERROR", message: "This thing failed: \(x)", details: nil))
        }
        
        guard let cc = CreditCardType.creditCardType() as? CreditCardType else { explode("cc type"); return }
        
        cc.cardNumber = "4111111111111111"
        cc.expirationDate = "1120"
        cc.cardCode = "123"
        let payment = PaymentType()
        payment.creditCard = cc
        
        guard let txn = TransactionRequestType.transactionRequest() else { explode("txn request type"); return }
        txn.amount = "1.0"
        txn.payment = payment
        let txnReq = CreateTransactionRequest()
        txnReq.transactionType = AUTH_CAPTURE
        txnReq.transactionRequest = txn
        txnReq.anetApiRequest.merchantAuthentication.mobileDeviceId = deviceID
        txnReq.anetApiRequest.merchantAuthentication.sessionToken = token
        
        txnResult = result
        anet.purchase(with: txnReq)
        // Execution should then hit paymentSucceeded
    }
    
    private func chargeBT(result: @escaping FlutterResult) {
        let emvManager = AnetEMVManager.initWithCurrecyCode("840", terminalID: "", skipSignature: true, showReceipt: false)
        emvManager.setConnectionMode(.bluetooth)
        emvManager.setTerminalMode(.modeInsertOrSwipe)
        emvManager.startEMV(with: makeTransactionObject("1.00"), presenting: window.rootViewController!, completionBlock: {
            (response: AnetEMVTransactionResponse?, error : AnetEMVError?) -> Void in
            print("Oh no...")
            if (response?.isTransactionSuccessful == true && error == nil) {
                self.sessionToken = response?.sessionToken
                print("Transaction successful")
            } else {
                print("Aaahhhh errrorrrrr")
                self.requestFailed(response)
            }
        }, andCancelActionBlock: { print("No no no!") })
    }
    
}
