package com.meridian.payments.model;

/**
 * PaymentResult — outcome of a payment operation.
 */
public class PaymentResult {

    private final boolean success;
    private final String code;
    private final Payment payment;

    public PaymentResult(boolean success, String code, Payment payment) {
        this.success = success;
        this.code = code;
        this.payment = payment;
    }

    public boolean isSuccess() { return success; }
    public String getCode() { return code; }
    public Payment getPayment() { return payment; }
}
