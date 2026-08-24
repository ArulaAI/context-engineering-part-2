package com.meridian.payments.account;

import java.math.BigDecimal;
import java.util.*;
import java.util.logging.*;

/**
 * AccountService — balance and limit management for Meridian accounts.
 * Peripheral to the lab exercises (context noise).
 */
public class AccountService {

    private static final Logger logger = Logger.getLogger(AccountService.class.getName());
    private static final BigDecimal DEFAULT_DAILY_LIMIT = new BigDecimal("50000.00");

    public BigDecimal getDailyLimit(String accountId, String tier) {
        switch (tier) {
            case "PREMIUM": return new BigDecimal("250000.00");
            case "PRIVATE": return new BigDecimal("1000000.00");
            default: return DEFAULT_DAILY_LIMIT;
        }
    }

    public boolean withinDailyLimit(String accountId, BigDecimal amount, BigDecimal spentToday) {
        return spentToday.add(amount).compareTo(getDailyLimit(accountId, "STANDARD")) <= 0;
    }

    public Map<String, Object> getAccountMetrics(String accountId) {
        Map<String, Object> metrics = new HashMap<>();
        metrics.put("accountId", accountId);
        metrics.put("transactionsToday", 0);
        metrics.put("volumeToday", BigDecimal.ZERO);
        return metrics;
    }
}
