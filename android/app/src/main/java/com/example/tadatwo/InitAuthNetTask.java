package com.example.tadatwo;

import android.os.AsyncTask;
import android.util.Log;

import net.authorize.Merchant;
import net.authorize.aim.cardpresent.DeviceType;
import net.authorize.aim.cardpresent.MarketType;
import net.authorize.auth.SessionTokenAuthentication;
import net.authorize.mobile.Transaction;

import io.flutter.plugin.common.MethodChannel.Result;

class InitAuthNetTask extends AsyncTask<Object, Void, Boolean> {
    private static final String TAG = "InitAuthNetTask";

    protected Boolean doInBackground(Object... args) {
        Transaction logTxn;
        String deviceID;
        Merchant merchant;
        Result result;
        try {
            logTxn = (Transaction) args[0];
            deviceID = (String) args[1];
            merchant = (Merchant) args[2];
            result = (Result) args[3];
        } catch (ClassCastException e) {
            return Boolean.FALSE;
        }

        net.authorize.mobile.Result logRes = (net.authorize.mobile.Result) merchant.postTransaction(logTxn);
        if (logRes.isOk()) {
            Log.d(TAG, "Login OK");
            try {
                SessionTokenAuthentication sTok1 = SessionTokenAuthentication.createMerchantAuthentication(merchant.getMerchantAuthentication().getName(), logRes.getSessionToken(), deviceID);
                if (logRes.getSessionToken() != null) {
                    Log.d(TAG, "Successfully captured session token");
                    merchant.setMerchantAuthentication(sTok1);
                    merchant.setDeviceType(DeviceType.WIRELESS_POS);
                    merchant.setMarketType(MarketType.RETAIL);
                    result.success(true);
                    return Boolean.TRUE;
                } else {
                    throw new Exception("Could not capture session token!");
                }
            } catch (Exception ex) {
                Log.e(TAG, "Exception trying to capture token! " + ex.getMessage());
                result.error("CAUGHT_EXCEPTION", ex.getMessage(), null);
                return Boolean.FALSE;
            }
        } else {
            Log.e(TAG, "Login FAIL: " + logRes.getXmlResponse());
            result.error("RESULT_NOT_OK", "Got a log response back that was not OK", null);
            return Boolean.FALSE;
        }
    }
}