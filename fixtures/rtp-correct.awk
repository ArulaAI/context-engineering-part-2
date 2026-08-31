# FACILITATOR FIXTURE — this file is the correct RTP fee-comparison fix
# used by docs/verify.sh A5 to self-test the verifier. It is NOT part of
# the learner exercise. It replaces the buggy amount-comparison with the
# correct computed-fee comparison at a known anchor line.

$0 == "            if (amount.compareTo(BigDecimal.valueOf(2.00)) >= 0) {" {
  print "            BigDecimal rtpFee = amount.multiply(BigDecimal.valueOf(0.0035)).setScale(2, RoundingMode.HALF_UP);"
  print "            if (rtpFee.compareTo(BigDecimal.valueOf(2.00)) >= 0) {"
  found = 1
  skipnext = 1
  next
}
skipnext == 1 {
  print "                return rtpFee;"
  skipnext = 0
  next
}
{ print }
END { exit (found == 1) ? 0 : 1 }
