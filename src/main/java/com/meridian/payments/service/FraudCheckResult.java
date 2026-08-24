package com.meridian.payments.service;

/**
 * FraudCheckResult — outcome of a fraud screening.
 */
public class FraudCheckResult {

    private final boolean suspicious;
    private final int score;

    public FraudCheckResult(boolean suspicious, int score) {
        this.suspicious = suspicious;
        this.score = score;
    }

    public boolean isSuspicious() { return suspicious; }
    public int getScore() { return score; }
}
