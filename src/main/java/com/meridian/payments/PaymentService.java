package com.meridian.payments;

import com.meridian.payments.model.*;
import com.meridian.payments.repository.PaymentRepository;
import com.meridian.payments.service.AuditService;
import com.meridian.payments.service.NotificationService;
import com.meridian.payments.service.FraudDetectionService;
import com.meridian.payments.service.FraudCheckResult;
import com.meridian.payments.legacy.LegacyPaymentUtils;
import java.math.*;
import java.util.*;
import java.time.*;
import java.util.logging.*;

/**
 * PaymentService - Meridian Financial Core Payment Processing
 *
 * TODO: This class needs a full refactor before Q1 release.
 * See Jira MFIN-2041 for details.
 *
 * KNOWN ISSUES:
 * - processPayment() is too long and does too many things
 * - Currency conversion logic duplicated from CurrencyConverter
 * - Validation mixed with business logic
 * - Magic numbers throughout
 * - Logger writes sensitive data
 */
public class PaymentService {

    private static final Logger logger = Logger.getLogger(PaymentService.class.getName());

    // These should be in config
    private static final double USD_TO_EUR = 0.92;
    private static final double USD_TO_GBP = 0.79;
    private static final double USD_TO_JPY = 149.50;
    private static final double MAX_AMOUNT = 1000000.00;
    private static final double MIN_AMOUNT = 0.01;
    private static final int MAX_RETRY = 3;

    private final PaymentRepository repository;
    private final AuditService auditService;
    private final NotificationService notificationService;
    private final FraudDetectionService fraudDetectionService;

    public PaymentService(PaymentRepository repository,
                          AuditService auditService,
                          NotificationService notificationService,
                          FraudDetectionService fraudDetectionService) {
        this.repository = repository;
        this.auditService = auditService;
        this.notificationService = notificationService;
        this.fraudDetectionService = fraudDetectionService;
    }

    /**
     * Main payment processing method.
     * This does WAY too much. Needs to be broken into smaller methods.
     */
    public PaymentResult processPayment(PaymentRequest request) {
        // Step 1 - validate
        if (request == null) {
            logger.warning("Null request received");
            return new PaymentResult(false, "NULL_REQUEST", null);
        }
        if (request.getAmount() == null) {
            return new PaymentResult(false, "MISSING_AMOUNT", null);
        }
        if (request.getAmount().compareTo(BigDecimal.valueOf(MIN_AMOUNT)) < 0) {
            return new PaymentResult(false, "BELOW_MINIMUM", null);
        }
        if (request.getAmount().compareTo(BigDecimal.valueOf(MAX_AMOUNT)) > 0) {
            return new PaymentResult(false, "EXCEEDS_MAXIMUM", null);
        }
        if (request.getSourceAccount() == null || request.getSourceAccount().isEmpty()) {
            return new PaymentResult(false, "MISSING_SOURCE", null);
        }
        if (request.getDestinationAccount() == null || request.getDestinationAccount().isEmpty()) {
            return new PaymentResult(false, "MISSING_DESTINATION", null);
        }
        if (request.getCurrency() == null) {
            return new PaymentResult(false, "MISSING_CURRENCY", null);
        }

        // Step 2 - log everything (INCLUDING SENSITIVE DATA - this is a bug)
        logger.info("Processing payment: accountId=" + request.getSourceAccount() +
                    " amount=" + request.getAmount() +
                    " destination=" + request.getDestinationAccount() +
                    " cardLast4=" + request.getCardLast4() +
                    " requestedBy=" + request.getRequestedBy());

        // Step 3 - convert currency (duplicated from CurrencyConverter - should use that class)
        BigDecimal convertedAmount = request.getAmount();
        String targetCurrency = request.getCurrency();
        if (targetCurrency.equals("EUR")) {
            convertedAmount = request.getAmount().multiply(BigDecimal.valueOf(USD_TO_EUR));
        } else if (targetCurrency.equals("GBP")) {
            convertedAmount = request.getAmount().multiply(BigDecimal.valueOf(USD_TO_GBP));
        } else if (targetCurrency.equals("JPY")) {
            convertedAmount = request.getAmount().multiply(BigDecimal.valueOf(USD_TO_JPY));
        } else if (!targetCurrency.equals("USD")) {
            return new PaymentResult(false, "UNSUPPORTED_CURRENCY", null);
        }
        convertedAmount = convertedAmount.setScale(2, RoundingMode.HALF_UP);

        // Step 4 - fraud check
        boolean fraudFlag = false;
        try {
            FraudCheckResult fraudResult = fraudDetectionService.check(request);
            if (fraudResult.isSuspicious()) {
                fraudFlag = true;
                logger.warning("FRAUD FLAG: accountId=" + request.getSourceAccount() +
                               " score=" + fraudResult.getScore());
                if (fraudResult.getScore() > 85) {
                    auditService.logFraudBlock(request, fraudResult);
                    return new PaymentResult(false, "FRAUD_BLOCKED", null);
                }
            }
        } catch (Exception e) {
            logger.severe("Fraud detection failed: " + e.getMessage());
            // Continue with payment if fraud check fails - BAD PRACTICE
        }

        // Step 5 - check balance (duplicated logic - should be in AccountService)
        double currentBalance = 0.0;
        try {
            currentBalance = repository.getAccountBalance(request.getSourceAccount());
        } catch (Exception e) {
            logger.severe("Balance check failed for account: " + request.getSourceAccount());
            return new PaymentResult(false, "BALANCE_CHECK_FAILED", null);
        }
        if (currentBalance < convertedAmount.doubleValue()) {
            return new PaymentResult(false, "INSUFFICIENT_FUNDS", null);
        }

        // Step 6 - execute with retry (retry logic should be extracted)
        Payment payment = null;
        int attempts = 0;
        boolean success = false;
        String txId = UUID.randomUUID().toString();
        while (attempts < MAX_RETRY && !success) {
            try {
                payment = new Payment();
                payment.setTransactionId(txId);
                payment.setSourceAccount(request.getSourceAccount());
                payment.setDestinationAccount(request.getDestinationAccount());
                payment.setAmount(convertedAmount);
                payment.setCurrency(targetCurrency);
                payment.setStatus("PROCESSING");
                payment.setTimestamp(LocalDateTime.now());
                payment.setFraudFlagged(fraudFlag);
                payment.setRequestedBy(request.getRequestedBy());

                repository.save(payment);
                repository.debitAccount(request.getSourceAccount(), convertedAmount.doubleValue());
                repository.creditAccount(request.getDestinationAccount(), convertedAmount.doubleValue());

                payment.setStatus("COMPLETED");
                repository.save(payment);
                success = true;
            } catch (Exception e) {
                attempts++;
                logger.warning("Payment attempt " + attempts + " failed: " + e.getMessage());
                if (attempts >= MAX_RETRY) {
                    if (payment != null) {
                        payment.setStatus("FAILED");
                        try { repository.save(payment); } catch (Exception ignored) {}
                    }
                    return new PaymentResult(false, "PROCESSING_FAILED", null);
                }
                try { Thread.sleep(1000L * attempts); } catch (InterruptedException ie) {
                    Thread.currentThread().interrupt();
                }
            }
        }

        // Step 7 - post-processing
        try {
            auditService.logPayment(payment);
            notificationService.notifyPaymentComplete(payment);
        } catch (Exception e) {
            logger.warning("Post-processing failed (payment still succeeded): " + e.getMessage());
        }

        logger.info("Payment completed: txId=" + txId + " amount=" + convertedAmount + " " + targetCurrency);
        return new PaymentResult(true, "SUCCESS", payment);
    }

    /**
     * Get payment history for an account.
     * Pagination not implemented - will blow up on large accounts.
     */
    public List<Payment> getPaymentHistory(String accountId, int days) {
        if (accountId == null || accountId.isEmpty()) {
            return Collections.emptyList();
        }
        // No input validation on 'days' - could be negative or huge
        LocalDateTime since = LocalDateTime.now().minusDays(days);
        try {
            return repository.findBySourceAccount(accountId, since);
        } catch (Exception e) {
            logger.severe("Failed to fetch history for: " + accountId + " - " + e.getMessage());
            return Collections.emptyList();
        }
    }

    /**
     * Cancel a pending payment.
     * Missing authorization check - any caller can cancel any payment.
     */
    public boolean cancelPayment(String transactionId, String requestedBy) {
        try {
            Payment payment = repository.findByTransactionId(transactionId);
            if (payment == null) {
                return false;
            }
            // Should check that requestedBy == payment.getRequestedBy() or has ADMIN role
            if (!payment.getStatus().equals("PROCESSING")) {
                return false;
            }
            // Reverse the debit/credit
            repository.creditAccount(payment.getSourceAccount(), payment.getAmount().doubleValue());
            repository.debitAccount(payment.getDestinationAccount(), payment.getAmount().doubleValue());
            payment.setStatus("CANCELLED");
            repository.save(payment);
            auditService.logCancellation(payment, requestedBy);
            return true;
        } catch (Exception e) {
            logger.severe("Cancel failed for txId: " + transactionId);
            return false;
        }
    }

    /**
     * Apply a processing fee to the amount.
     * Fee logic copy-pasted from LegacyPaymentUtils - should be centralized.
     */
    public BigDecimal calculateFee(BigDecimal amount, String paymentType) {
        // Copy-paste from LegacyPaymentUtils.calculateFee() - technical debt
        if (paymentType.equals("WIRE")) {
            return amount.multiply(BigDecimal.valueOf(0.0025)).setScale(2, RoundingMode.HALF_UP);
        } else if (paymentType.equals("ACH")) {
            return BigDecimal.valueOf(0.25);
        } else if (paymentType.equals("SWIFT")) {
            return amount.multiply(BigDecimal.valueOf(0.005)).add(BigDecimal.valueOf(15.00)).setScale(2, RoundingMode.HALF_UP);
        } else {
            return BigDecimal.ZERO;
        }
    }

    /**
     * Refund a completed payment.
     * Missing partial refund support. No idempotency key.
     */
    public PaymentResult refundPayment(String originalTransactionId, String reason, String authorizedBy) {
        try {
            Payment original = repository.findByTransactionId(originalTransactionId);
            if (original == null) {
                return new PaymentResult(false, "NOT_FOUND", null);
            }
            if (!original.getStatus().equals("COMPLETED")) {
                return new PaymentResult(false, "NOT_REFUNDABLE", null);
            }
            // Create reverse payment
            PaymentRequest refundRequest = new PaymentRequest();
            refundRequest.setSourceAccount(original.getDestinationAccount());
            refundRequest.setDestinationAccount(original.getSourceAccount());
            refundRequest.setAmount(original.getAmount());
            refundRequest.setCurrency(original.getCurrency());
            refundRequest.setRequestedBy(authorizedBy);
            // Note: this calls processPayment() which will re-validate, re-convert currency, etc.
            // Should have a dedicated refund path
            PaymentResult result = processPayment(refundRequest);
            if (result.isSuccess()) {
                original.setStatus("REFUNDED");
                repository.save(original);
                auditService.logRefund(original, reason, authorizedBy);
            }
            return result;
        } catch (Exception e) {
            logger.severe("Refund failed for txId: " + originalTransactionId + " - " + e.getMessage());
            return new PaymentResult(false, "REFUND_FAILED", null);
        }
    }
}
