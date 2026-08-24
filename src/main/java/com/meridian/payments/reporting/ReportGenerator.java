package com.meridian.payments.reporting;

import java.time.*;
import java.util.*;
import java.util.logging.*;

/**
 * ReportGenerator — assembles formatted report output for the back-office portal.
 * Peripheral to the lab exercises (context noise).
 */
public class ReportGenerator {

    private static final Logger logger = Logger.getLogger(ReportGenerator.class.getName());

    public String generateCsv(List<Map<String, Object>> rows, List<String> columns) {
        StringBuilder sb = new StringBuilder();
        sb.append(String.join(",", columns)).append("\n");
        for (Map<String, Object> row : rows) {
            List<String> cells = new ArrayList<>();
            for (String col : columns) {
                Object v = row.get(col);
                cells.add(v == null ? "" : v.toString());
            }
            sb.append(String.join(",", cells)).append("\n");
        }
        return sb.toString();
    }

    public Map<String, Object> generateExecutiveSummary(LocalDate from, LocalDate to) {
        Map<String, Object> summary = new LinkedHashMap<>();
        summary.put("periodStart", from.toString());
        summary.put("periodEnd", to.toString());
        summary.put("generatedAt", LocalDateTime.now().toString());
        return summary;
    }
}
