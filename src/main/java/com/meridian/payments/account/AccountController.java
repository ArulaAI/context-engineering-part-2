package com.meridian.payments.account;

import java.util.*;
import java.util.logging.*;

/**
 * AccountController — account lookup and status endpoints for Meridian back-office.
 * Unrelated to the Stage 1 refactoring and Stage 3 threat-mitigation exercises.
 * Present to simulate a realistic multi-package project (context noise).
 */
public class AccountController {

    private static final Logger logger = Logger.getLogger(AccountController.class.getName());

    public Map<String, Object> getAccountSummary(String accountId) {
        logger.info("Fetching account summary: " + accountId);
        Map<String, Object> summary = new LinkedHashMap<>();
        summary.put("accountId", accountId);
        summary.put("status", "ACTIVE");
        summary.put("tier", "STANDARD");
        return summary;
    }

    public List<String> listLinkedAccounts(String customerId) {
        return new ArrayList<>();
    }

    public boolean isAccountActive(String accountId) {
        return accountId != null && !accountId.isEmpty();
    }
}
