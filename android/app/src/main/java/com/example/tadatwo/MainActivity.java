package com.example.tadatwo;

import android.os.Bundle;
import android.os.StrictMode;
import android.util.Log;

import net.authorize.Environment;
import net.authorize.Merchant;
import net.authorize.auth.PasswordAuthentication;
import net.authorize.data.creditcard.CreditCard;
import net.authorize.data.mobile.MobileDevice;

import java.math.BigDecimal;

import io.flutter.app.FlutterActivity;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugins.GeneratedPluginRegistrant;

public class MainActivity extends FlutterActivity {
	private static final String TAG = "FlutterAuthNetActivity";
	private static final String CHANNEL = "tadatwo.example.com/authnet";

	private String deviceID;
	private Merchant merchant;

	private boolean isInit() {
		return this.merchant != null;
	}

	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		GeneratedPluginRegistrant.registerWith(this);

		new MethodChannel(getFlutterView(), CHANNEL).setMethodCallHandler(
				new MethodCallHandler() {
					@Override
					public void onMethodCall(MethodCall call, Result result) {
						switch(call.method) {
							case "initAuthNet":
								final String e = call.argument("env"),
										d = call.argument("deviceID"),
										u = call.argument("user"),
										p = call.argument("pass");
								initAuthNet(e, d, u, p, result);
								break;
							case "chargeIt":
								chargeIt(result);
								break;
							default:
								result.notImplemented();
						}
					}
				});
	}

	private void initAuthNet(String env, String devID, String user, String pass, Result result) {
		if (this.isInit()) {
			result.error("ANET_ALREADY_INIT", "Authorize merchant interface already initialized!", null);
			return;
		}
		if (!(env.equalsIgnoreCase("live") || env.equalsIgnoreCase("test"))) {
			Log.e(TAG, "Provided environment was neither 'test' nor 'live'.");
			result.error("BAD_ENV", "Provided environment was neither 'test' nor 'live'.", null);
			return;
		}

		this.deviceID = devID;

		Environment environment = env.equalsIgnoreCase("live") ? Environment.PRODUCTION : Environment.SANDBOX;
		Log.d(TAG, "Received environment: " + env);
		PasswordAuthentication passAuth = PasswordAuthentication.createMerchantAuthentication(user, pass, this.deviceID);
		Log.d(TAG, "Creating merchant with password auth");
		this.merchant = Merchant.createMerchant(environment, passAuth);

        Log.d(TAG, "Attempting mobile login");
        net.authorize.mobile.Transaction logTxn = merchant.createMobileTransaction(net.authorize.mobile.TransactionType.MOBILE_DEVICE_LOGIN);
        MobileDevice mobileDevice = MobileDevice.createMobileDevice(deviceID, "Test EMV Android", "555-555-5555", "Android");
        logTxn.setMobileDevice(mobileDevice);

        new InitAuthNetTask().execute(logTxn, this.deviceID, this.merchant, result);
	}

	private void chargeIt(Result result) {
		if (!this.isInit()) {
			result.error("ANET_NOT_INIT", "Not logged in to Authorize merchant interface!", null);
			return;
		}

		Log.d(TAG, "Trying to charge it");
		net.authorize.aim.Transaction txn = net.authorize.aim.Transaction.createTransaction(this.merchant, net.authorize.TransactionType.AUTH_CAPTURE, new BigDecimal(1.00));

		CreditCard creditCard = CreditCard.createCreditCard();
		creditCard.setCreditCardNumber("4111111111111111");
		creditCard.setExpirationMonth("11");
		creditCard.setExpirationYear("2020");
		creditCard.setCardCode("123");
		txn.setCreditCard(creditCard);

        new ChargeAuthNetTask().execute(txn, this.merchant, result);
	}
}
