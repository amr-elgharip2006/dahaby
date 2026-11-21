/// Pure price maths. No I/O, so it is easy to test.
library;

/// Grams in one troy ounce.
const double gramsPerTroyOunce = 31.1035;

/// Purity of each karat relative to 24K.
const Map<int, double> karatPurity = {24: 1.0, 21: 21 / 24, 18: 18 / 24};

/// Price of one gram of pure metal in EGP, from the ounce price in USD.
double gramPriceEgp({required double ounceUsd, required double usdEgp}) =>
    ounceUsd / gramsPerTroyOunce * usdEgp;

/// Price of one gram of [karat] gold in EGP.
double goldGramEgp({
  required double ounceUsd,
  required double usdEgp,
  required int karat,
}) {
  final purity = karatPurity[karat];
  if (purity == null) {
    throw ArgumentError.value(karat, 'karat', 'Unsupported karat');
  }
  return gramPriceEgp(ounceUsd: ounceUsd, usdEgp: usdEgp) * purity;
}

/// Rounds to two decimals so tiny float noise does not count as a change.
double round2(double v) => (v * 100).roundToDouble() / 100;
