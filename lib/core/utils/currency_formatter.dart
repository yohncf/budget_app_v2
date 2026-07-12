import 'package:intl/intl.dart';

/// Formats a double amount into standard currency notation with a space: e.g., "$ 1,234,567.89".
/// Handles negative values as "-$ 1,234,567.89".
String formatCurrency(double amount) {
  final isNegative = amount < 0;
  final absAmount = amount.abs();
  final formatter = NumberFormat.currency(locale: 'en_US', symbol: '');
  final formattedStr = formatter.format(absAmount).trim();
  return '${isNegative ? '-' : ''}\$ $formattedStr';
}
