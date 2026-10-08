/// Fixed list of supported trip currencies for Wayfound V1.
/// Must match the security rules allowed currency list.
const List<String> kSupportedCurrencies = [
  'INR',
  'USD',
  'EUR',
  'GBP',
  'AED',
  'AUD',
  'CAD',
  'SGD',
  'JPY',
  'CHF',
];

/// Checks if a currency string is supported.
bool isSupportedCurrency(String? currency) {
  if (currency == null) return false;
  return kSupportedCurrencies.contains(currency.toUpperCase().trim());
}
