package com.meridian.payments.service;

import com.meridian.payments.model.Payment;

/**
 * NotificationService — sends customer notifications on payment events.
 */
public interface NotificationService {

    void notifyPaymentComplete(Payment payment);
}
