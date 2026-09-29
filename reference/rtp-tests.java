    // --- MFIN-2088: the approved RTP rule (PRICING-442), permanently guarded ---

    @Test
    void calculateFee_rtpMinimumAppliesBelowThreshold() {
        // 0.35% of 100.00 is 0.35, which is under the approved USD 2.00 minimum,
        // so the minimum is what gets charged. This is the assertion the injected
        // fault breaks: comparing 2.00 against the amount would return 0.35 here.
        BigDecimal fee = service.calculateFee(new BigDecimal("100.00"), "RTP");
        assertEquals(new BigDecimal("2.00"), fee);
    }

    @Test
    void calculateFee_rtpPercentageAppliesAboveThreshold() {
        // 0.35% of 10000.00 is 35.00, comfortably above the minimum, so the
        // percentage governs.
        BigDecimal fee = service.calculateFee(new BigDecimal("10000.00"), "RTP");
        assertEquals(new BigDecimal("35.00"), fee);
    }
