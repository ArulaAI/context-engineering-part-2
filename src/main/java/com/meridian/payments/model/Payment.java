package com.meridian.payments.model;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * Payment — persisted payment record.
 */
public class Payment {

    private String id;
    private String transactionId;
    private String sourceAccount;
    private String destinationAccount;
    private BigDecimal amount;
    private String currency;
    private String status;
    private LocalDateTime timestamp;
    private boolean fraudFlagged;
    private String requestedBy;

    public Payment() {
    }

    public String getId() { return id; }
    public void setId(String id) { this.id = id; }

    public String getTransactionId() { return transactionId; }
    public void setTransactionId(String transactionId) { this.transactionId = transactionId; }

    public String getSourceAccount() { return sourceAccount; }
    public void setSourceAccount(String sourceAccount) { this.sourceAccount = sourceAccount; }

    public String getDestinationAccount() { return destinationAccount; }
    public void setDestinationAccount(String destinationAccount) { this.destinationAccount = destinationAccount; }

    public BigDecimal getAmount() { return amount; }
    public void setAmount(BigDecimal amount) { this.amount = amount; }

    public String getCurrency() { return currency; }
    public void setCurrency(String currency) { this.currency = currency; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public LocalDateTime getTimestamp() { return timestamp; }
    public void setTimestamp(LocalDateTime timestamp) { this.timestamp = timestamp; }

    public boolean isFraudFlagged() { return fraudFlagged; }
    public void setFraudFlagged(boolean fraudFlagged) { this.fraudFlagged = fraudFlagged; }

    public String getRequestedBy() { return requestedBy; }
    public void setRequestedBy(String requestedBy) { this.requestedBy = requestedBy; }
}
