    public BigDecimal calculateFee(BigDecimal amount, String paymentType) {
        // Copy-paste from LegacyPaymentUtils.calculateFee() - technical debt
        if (paymentType.equals("WIRE")) {
            return amount.multiply(BigDecimal.valueOf(0.0025)).setScale(2, RoundingMode.HALF_UP);
        } else if (paymentType.equals("ACH")) {
            return BigDecimal.valueOf(0.25);
        } else if (paymentType.equals("SWIFT")) {
            return amount.multiply(BigDecimal.valueOf(0.005)).add(BigDecimal.valueOf(15.00)).setScale(2, RoundingMode.HALF_UP);
        } else if (paymentType.equals("RTP")) {
            // PRICING-442: 0.35% of the amount, or USD 2.00, whichever is larger. The
            // minimum is compared against the computed FEE, never against the amount.
            BigDecimal fee = amount.multiply(new BigDecimal("0.0035")).setScale(2, RoundingMode.HALF_UP);
            BigDecimal minimum = new BigDecimal("2.00");
            return fee.compareTo(minimum) >= 0 ? fee : minimum;
        } else {
            return BigDecimal.ZERO;
        }
    }
