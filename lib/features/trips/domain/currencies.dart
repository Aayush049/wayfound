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

/// Currency details model for Wayfound.
class Currency {
  final String code;
  final String symbol;
  final String name;
  final int minorUnitDigits;

  const Currency({
    required this.code,
    required this.symbol,
    required this.name,
    required this.minorUnitDigits,
  });
}

const Map<String, Currency> kCurrencyDetails = {
  'INR': Currency(
    code: 'INR',
    symbol: '₹',
    name: 'Indian Rupee',
    minorUnitDigits: 2,
  ),
  'USD': Currency(
    code: 'USD',
    symbol: '\$',
    name: 'US Dollar',
    minorUnitDigits: 2,
  ),
  'EUR': Currency(code: 'EUR', symbol: '€', name: 'Euro', minorUnitDigits: 2),
  'GBP': Currency(
    code: 'GBP',
    symbol: '£',
    name: 'British Pound',
    minorUnitDigits: 2,
  ),
  'AED': Currency(
    code: 'AED',
    symbol: 'AED',
    name: 'UAE Dirham',
    minorUnitDigits: 2,
  ),
  'AUD': Currency(
    code: 'AUD',
    symbol: 'A\$',
    name: 'Australian Dollar',
    minorUnitDigits: 2,
  ),
  'CAD': Currency(
    code: 'CAD',
    symbol: 'C\$',
    name: 'Canadian Dollar',
    minorUnitDigits: 2,
  ),
  'SGD': Currency(
    code: 'SGD',
    symbol: 'S\$',
    name: 'Singapore Dollar',
    minorUnitDigits: 2,
  ),
  'JPY': Currency(
    code: 'JPY',
    symbol: '¥',
    name: 'Japanese Yen',
    minorUnitDigits: 0,
  ),
  'CHF': Currency(
    code: 'CHF',
    symbol: 'CHF',
    name: 'Swiss Franc',
    minorUnitDigits: 2,
  ),
};

/// Gets the number of minor unit digits for a given currency code.
int getMinorUnitDigits(String currencyCode) {
  final normalized = currencyCode.toUpperCase().trim();
  final details = kCurrencyDetails[normalized];
  if (details != null) return details.minorUnitDigits;
  return 2;
}

/// Checks if a currency string is supported.
bool isSupportedCurrency(String? currency) {
  if (currency == null) return false;
  return kSupportedCurrencies.contains(currency.toUpperCase().trim());
}
