package com.meridian.payments.fx;

import java.math.BigDecimal;
import java.util.Map;

/**
 * FxRateProvider — supplies live foreign-exchange rates.
 * Returns a map keyed "FROM_TO" (e.g. "USD_EUR") to the conversion rate.
 */
public interface FxRateProvider {

    Map<String, BigDecimal> fetchLatestRates(String baseCurrency);
}
