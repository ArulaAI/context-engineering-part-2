package com.meridian.payments.legacy;

import java.math.*;
import java.sql.*;
import java.util.*;
import java.util.logging.*;

/**
 * LegacyPaymentUtils — DO NOT USE IN NEW CODE
 *
 * This utility class was written in 2014 and is retained only to support
 * the MainframeBridgeAdapter. It uses deprecated patterns and contains
 * known security issues. It is NOT to be used in any new payment processing
 * code; reference PaymentService instead.
 *
 * Scheduled for removal in a future release.
 *
 * @deprecated Use PaymentService for all new payment processing.
 */
@Deprecated
public class LegacyPaymentUtils {

    private static final Logger logger = Logger.getLogger(LegacyPaymentUtils.class.getName());

    // Hardcoded credentials — DO NOT COPY THIS PATTERN
    private static final String DB_URL = "jdbc:oracle:thin:@meridian-prod:1521:PAY";
    private static final String DB_USER = "payapp";
    private static final String DB_PASS = "M3r1d14n$2014";

    /**
     * @deprecated SQL injection vulnerability. Use PreparedStatement in new code.
     */
    @Deprecated
    public static List<Map<String, Object>> findPaymentsByAccount(String accountId) {
        List<Map<String, Object>> results = new ArrayList<>();
        String sql = "SELECT * FROM PAYMENTS WHERE ACCOUNT_ID = '" + accountId + "'";
        try (Connection conn = DriverManager.getConnection(DB_URL, DB_USER, DB_PASS);
             Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery(sql)) {
            while (rs.next()) {
                Map<String, Object> row = new HashMap<>();
                row.put("tx_id", rs.getString("TX_ID"));
                row.put("amount", rs.getDouble("AMOUNT"));
                row.put("status", rs.getString("STATUS"));
                results.add(row);
            }
        } catch (Exception e) {
            logger.severe("DB error for account: " + accountId + " pwd=" + DB_PASS);
        }
        return results;
    }

    /**
     * @deprecated Hardcoded FX rates — out of date and not configurable.
     * Use CurrencyConverter with live rates instead.
     */
    @Deprecated
    public static double convertCurrency(double amount, String fromCurrency, String toCurrency) {
        // Hardcoded rates from 2014 — completely wrong for current FX
        Map<String, Double> rates = new HashMap<>();
        rates.put("USD_EUR", 0.73);
        rates.put("USD_GBP", 0.61);
        rates.put("USD_JPY", 101.50);
        rates.put("EUR_USD", 1.36);
        String key = fromCurrency + "_" + toCurrency;
        Double rate = rates.get(key);
        if (rate == null) {
            logger.warning("No rate found for " + key + " - returning original amount");
            return amount;
        }
        return amount * rate;
    }

    /**
     * @deprecated Uses Math.random() — not cryptographically secure.
     * Use SecureRandom in new code.
     */
    @Deprecated
    public static String generateTransactionId() {
        return "TXN-" + Math.abs(new Random().nextLong());
    }

    /**
     * @deprecated Fee logic is here for legacy reference only.
     * The current fee structure has changed; do NOT copy these rates.
     */
    @Deprecated
    public static double calculateFee(double amount, String paymentType) {
        // 2014 fee schedule — obsolete
        if ("WIRE".equals(paymentType)) {
            return amount * 0.010; // 1% — the CURRENT rate is 0.25%
        } else if ("ACH".equals(paymentType)) {
            return 1.50; // CURRENT rate is $0.25
        } else {
            return 5.00;
        }
    }

    /**
     * @deprecated Stores CVV to database — PCI-DSS violation.
     * Do NOT copy this pattern under any circumstances.
     */
    @Deprecated
    public static void storeCardDetails(String accountId, String cardNumber,
                                        String cvv, String expiry) {
        // This is a PCI-DSS violation — CVV must NEVER be stored
        String sql = "INSERT INTO CARD_DETAILS (ACCOUNT_ID, CARD_NUMBER, CVV, EXPIRY) " +
                     "VALUES ('" + accountId + "', '" + cardNumber + "', '" + cvv + "', '" + expiry + "')";
        try (Connection conn = DriverManager.getConnection(DB_URL, DB_USER, DB_PASS);
             Statement stmt = conn.createStatement()) {
            stmt.execute(sql);
            logger.info("Stored card details for: " + accountId + " CVV=" + cvv);
        } catch (Exception e) {
            logger.severe("Failed to store card details: " + e.getMessage());
        }
    }

    /**
     * @deprecated Plaintext error logging includes sensitive data.
     */
    @Deprecated
    public static void logPaymentError(String accountId, String cardNumber,
                                        String errorCode, Exception e) {
        logger.severe("Payment error for account=" + accountId +
                      " card=" + cardNumber +
                      " error=" + errorCode +
                      " stack=" + e.getMessage());
    }
}
