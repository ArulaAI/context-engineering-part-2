package com.meridian.payments.repository;

import com.meridian.payments.model.Payment;
import java.time.LocalDateTime;
import java.util.List;

/**
 * PaymentRepository — persistence boundary for payments and account balances.
 */
public interface PaymentRepository {

    void save(Payment payment);

    Payment findByTransactionId(String transactionId);

    List<Payment> findBySourceAccount(String accountId, LocalDateTime since);

    double getAccountBalance(String accountId);

    void debitAccount(String accountId, double amount);

    void creditAccount(String accountId, double amount);
}
