package com.meridian.payments.service;

import com.meridian.payments.model.PaymentRequest;

/**
 * FraudDetectionService — scores payment requests for fraud risk.
 */
public interface FraudDetectionService {

    FraudCheckResult check(PaymentRequest request);
}
