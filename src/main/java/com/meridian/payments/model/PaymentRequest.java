package com.meridian.payments.model;

import java.math.BigDecimal;

/**
 * PaymentRequest — inbound payment instruction.
 * Plain data holder used by PaymentService.processPayment().
 */
public class PaymentRequest {

    private BigDecimal amount;
    private String currency;
    private String sourceAccount;
    private String destinationAccount;
    private String cardLast4;
    private String requestedBy;
    private String paymentType;

    public PaymentRequest() {
    }

    public BigDecimal getAmount() { return amount; }
    public void setAmount(BigDecimal amount) { this.amount = amount; }

    public String getCurrency() { return currency; }
    public void setCurrency(String currency) { this.currency = currency; }

    public String getSourceAccount() { return sourceAccount; }
    public void setSourceAccount(String sourceAccount) { this.sourceAccount = sourceAccount; }

    public String getDestinationAccount() { return destinationAccount; }
    public void setDestinationAccount(String destinationAccount) { this.destinationAccount = destinationAccount; }

    public String getCardLast4() { return cardLast4; }
    public void setCardLast4(String cardLast4) { this.cardLast4 = cardLast4; }

    public String getRequestedBy() { return requestedBy; }
    public void setRequestedBy(String requestedBy) { this.requestedBy = requestedBy; }

    public String getPaymentType() { return paymentType; }
    public void setPaymentType(String paymentType) { this.paymentType = paymentType; }
}
