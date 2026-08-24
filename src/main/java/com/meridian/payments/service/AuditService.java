package com.meridian.payments.service;

import com.meridian.payments.model.Payment;
import com.meridian.payments.model.PaymentRequest;

/**
 * AuditService — records payment lifecycle events for compliance.
 */
public interface AuditService {

    void logPayment(Payment payment);

    void logFraudBlock(PaymentRequest request, FraudCheckResult result);

    void logCancellation(Payment payment, String requestedBy);

    void logRefund(Payment payment, String reason, String authorizedBy);
}
