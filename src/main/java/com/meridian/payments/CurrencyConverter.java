package com.meridian.payments;

import com.meridian.payments.fx.FxRateProvider;
import java.math.*;
import java.time.*;
import java.util.*;
import java.util.logging.*;

/**
 * CurrencyConverter — Live FX rate conversion for Meridian payment processing.
 * Uses externally-sourced rates refreshed hourly.
 * This is the canonical conversion class — use this, not LegacyPaymentUtils.convertCurrency().
 */
public class CurrencyConverter {

    private static final Logger logger = Logger.getLogger(CurrencyConverter.class.getName());

    private final FxRateProvider fxRateProvider;
    private final Map<String, BigDecimal> rateCache = new HashMap<>();
    private Instant cacheExpiry = Instant.EPOCH;

    private static final Set<String> SUPPORTED_CURRENCIES =
        Set.of("USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "SGD");

    public CurrencyConverter(FxRateProvider fxRateProvider) {
        this.fxRateProvider = fxRateProvider;
    }

    public BigDecimal convert(BigDecimal amount, String fromCurrency, String toCurrency) {
        if (amount == null || amount.compareTo(BigDecimal.ZERO) < 0) {
            throw new IllegalArgumentException("Amount must be positive");
        }
        if (!SUPPORTED_CURRENCIES.contains(fromCurrency)) {
            throw new UnsupportedOperationException("Unsupported currency: " + fromCurrency);
        }
        if (!SUPPORTED_CURRENCIES.contains(toCurrency)) {
            throw new UnsupportedOperationException("Unsupported currency: " + toCurrency);
        }
        if (fromCurrency.equals(toCurrency)) {
            return amount;
        }
        refreshRatesIfStale();
        BigDecimal rate = getRate(fromCurrency, toCurrency);
        return amount.multiply(rate).setScale(2, RoundingMode.HALF_UP);
    }

    public boolean isSupported(String currency) {
        return SUPPORTED_CURRENCIES.contains(currency);
    }

    private BigDecimal getRate(String from, String to) {
        String key = from + "_" + to;
        if (!rateCache.containsKey(key)) {
            String reverseKey = to + "_" + from;
            if (rateCache.containsKey(reverseKey)) {
                return BigDecimal.ONE.divide(rateCache.get(reverseKey), 6, RoundingMode.HALF_UP);
            }
            throw new IllegalStateException("No FX rate available for " + key);
        }
        return rateCache.get(key);
    }

    private void refreshRatesIfStale() {
        if (Instant.now().isBefore(cacheExpiry)) return;
        try {
            Map<String, BigDecimal> freshRates = fxRateProvider.fetchLatestRates("USD");
            rateCache.clear();
            rateCache.putAll(freshRates);
            cacheExpiry = Instant.now().plusSeconds(3600);
            logger.info("FX rates refreshed successfully");
        } catch (Exception e) {
            logger.severe("FX rate refresh failed: " + e.getMessage());
            if (rateCache.isEmpty()) throw new IllegalStateException("No FX rates available");
        }
    }
}
