package com.example.tadatwo;

import android.os.AsyncTask;
import android.util.Log;

import net.authorize.Merchant;
import net.authorize.aim.Transaction;

import io.flutter.plugin.common.MethodChannel.Result;


class ChargeAuthNetTask extends AsyncTask<Object, Void, Boolean> {
    private static final String TAG = "ChargeAuthNetTask";

    protected Boolean doInBackground(Object... args) {
        Transaction txn;
        Merchant merchant;
        Result result;
        try {
            txn = (Transaction) args[0];
            merchant = (Merchant) args[1];
            result = (Result) args[2];
        } catch (ClassCastException e) {
            return Boolean.FALSE;
        }

        Log.d(TAG, "Submitting auth-capture request");
        net.authorize.aim.Result res = (net.authorize.aim.Result) merchant.postTransaction(txn);
        if (res.isOk()) {
            Log.d(TAG, "Charge OK");
            try {
                String txnId = res.getTransId();
                Log.d(TAG, "Got transaction ID " + txnId);
                result.success(txnId);
                return Boolean.TRUE;
            } catch (Exception ex) {
                Log.e(TAG, "Exception trying to parse response! " + ex.getMessage());
                result.error("CAUGHT_EXCEPTION", ex.getMessage(), null);
                return Boolean.FALSE;
            }
        } else {
            Log.e(TAG, "Charge FAIL" + res.getXmlResponse());
            result.error("RESULT_NOT_OK", "Got a response that was not OK", null);
            return Boolean.FALSE;
        }
    }
}
