package com.meridian.payments;

import com.meridian.payments.model.*;
import com.meridian.payments.repository.PaymentRepository;
import com.meridian.payments.service.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import java.math.BigDecimal;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/**
 * Baseline test suite for the Part 2 lab.
 *
 * This suite is deliberately INCOMPLETE. It compiles and passes green so you have a
 * clean starting point — but several public methods on PaymentService have no coverage
 * at all, and processPayment() is only tested on its earliest validation branches.
 *
 * Finding those gaps is Stage 2's job. Do not fill them in by hand before you get there.
 */
class PaymentServiceTest {

    private PaymentService service;

    @BeforeEach
    void setUp() {
        service = new PaymentService(
            mock(PaymentRepository.class),
            mock(AuditService.class),
            mock(NotificationService.class),
            mock(FraudDetectionService.class)
        );
    }

    // --- processPayment: validation branches only (return before touching any mock) ---

    @Test
    void processPayment_nullRequest_returnsNullRequestCode() {
        PaymentResult result = service.processPayment(null);
        assertFalse(result.isSuccess());
        assertEquals("NULL_REQUEST", result.getCode());
    }

    @Test
    void processPayment_missingAmount_returnsMissingAmountCode() {
        PaymentRequest request = new PaymentRequest();
        request.setAmount(null);

        PaymentResult result = service.processPayment(request);
        assertFalse(result.isSuccess());
        assertEquals("MISSING_AMOUNT", result.getCode());
    }

    @Test
    void processPayment_belowMinimum_returnsBelowMinimumCode() {
        PaymentRequest request = new PaymentRequest();
        request.setAmount(new BigDecimal("-1.00"));

        PaymentResult result = service.processPayment(request);
        assertFalse(result.isSuccess());
        assertEquals("BELOW_MINIMUM", result.getCode());
    }

    // --- calculateFee: the business constant that must never regress ---

    @Test
    void calculateFee_wireIsQuarterOfOnePercent() {
        // The current schedule is 0.25% for WIRE. LegacyPaymentUtils still carries the
        // retired 1% rate. If this assertion ever reads 1.00, context poisoning shipped.
        BigDecimal fee = service.calculateFee(new BigDecimal("100.00"), "WIRE");
        assertEquals(new BigDecimal("0.25"), fee);
    }

    @Test
    void calculateFee_unknownTypeIsZero() {
        BigDecimal fee = service.calculateFee(new BigDecimal("100.00"), "CARRIER_PIGEON");
        assertEquals(BigDecimal.ZERO, fee);
    }

    // --- Deliberate gaps below this line. Stage 2 will find them. ---
    //
    // Not covered anywhere in this file:
    //   getPaymentHistory(String, int)
    //   cancelPayment(String, String)
    //   refundPayment(String, String, String)
    //   calculateFee for ACH and SWIFT
    //   processPayment beyond the first three validation branches
    //     (currency conversion, fraud check, balance check, retry loop, post-processing)
}
