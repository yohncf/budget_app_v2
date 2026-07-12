import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import './database_service.dart';

class CurrencyService {
  static final CurrencyService _instance = CurrencyService._internal();
  factory CurrencyService() => _instance;
  CurrencyService._internal();

  // Keys for SharedPreferences
  static const String _keyActiveCurrencies = 'currency_active_list';
  static const String _keyCachedRates = 'currency_cached_rates';
  static const String _keyLastFetchTime = 'currency_last_fetch_time';
  static const String _keyFetchCountToday = 'currency_fetch_count_today';
  static const String _keyLastFetchDate = 'currency_last_fetch_date';
  static const String _keyDiagnosticsLog = 'currency_diagnostics_log';

  // Default values
  static const List<String> _defaultCurrencies = ['USD', 'MXN', 'SOL', 'KMNO'];
  static const Map<String, double> _defaultRates = {
    'USD': 1.0,
    'MXN': 0.053,
    'SOL': 142.50,
    'KMNO': 0.040,
  };

  // Memory cache
  List<String> _activeCurrencies = [];
  Map<String, double> _cachedRates = {};
  DateTime? _lastFetchTime;
  int _fetchCountToday = 0;
  String _lastFetchDate = '';
  List<String> _diagnosticsLog = [];

  bool _isInitialized = false;

  /// Initializes the service by loading cached data from SharedPreferences.
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load active currencies
      _activeCurrencies = prefs.getStringList(_keyActiveCurrencies) ?? List.from(_defaultCurrencies);

      // Load cached rates
      final ratesJson = prefs.getString(_keyCachedRates);
      if (ratesJson != null) {
        final Map<String, dynamic> decoded = json.decode(ratesJson);
        _cachedRates = decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
      } else {
        _cachedRates = Map.from(_defaultRates);
      }

      // Load fetch metadata
      final fetchTimeStr = prefs.getString(_keyLastFetchTime);
      if (fetchTimeStr != null) {
        _lastFetchTime = DateTime.tryParse(fetchTimeStr);
      }
      _fetchCountToday = prefs.getInt(_keyFetchCountToday) ?? 0;
      _lastFetchDate = prefs.getString(_keyLastFetchDate) ?? '';

      // Load logs
      _diagnosticsLog = prefs.getStringList(_keyDiagnosticsLog) ?? ['Service initialized.'];

      _isInitialized = true;
    } catch (e) {
      _log('Initialization error: $e');
    }
  }

  // Getters
  List<String> get activeCurrencies => _activeCurrencies;
  Map<String, double> get cachedRates => _cachedRates;
  DateTime? get lastFetchTime => _lastFetchTime;
  int get fetchCountToday => _fetchCountToday;
  String get lastFetchDate => _lastFetchDate;
  List<String> get diagnosticsLog => _diagnosticsLog;

  /// Returns the cached price of a symbol in USD. Returns null if not in cache.
  double? getPrice(String symbol) {
    final sym = symbol.trim().toUpperCase();
    if (sym == 'USD') return 1.0;
    return _cachedRates[sym];
  }

  /// Appends a message to the diagnostics logs and persists it.
  Future<void> _log(String message) async {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    final logMessage = '[$timestamp] $message';
    _diagnosticsLog.insert(0, logMessage); // Prepend so latest is first
    if (_diagnosticsLog.length > 50) {
      _diagnosticsLog = _diagnosticsLog.sublist(0, 50);
    }
    print(logMessage);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyDiagnosticsLog, _diagnosticsLog);
    } catch (e) {
      print('Failed to save logs: $e');
    }
  }

  /// Saves the active currencies list and persists it.
  Future<void> saveActiveCurrencies(List<String> currencies) async {
    _activeCurrencies = currencies.map((c) => c.toUpperCase().trim()).toList();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyActiveCurrencies, _activeCurrencies);
      await _log('Saved active currencies: $_activeCurrencies');
    } catch (e) {
      await _log('Error saving active currencies: $e');
    }
  }

  /// Adds a currency to the active currencies list.
  Future<bool> addCurrency(String currency) async {
    final cur = currency.toUpperCase().trim();
    if (cur.isEmpty) return false;
    if (_activeCurrencies.contains(cur)) return false;
    _activeCurrencies.add(cur);
    await saveActiveCurrencies(_activeCurrencies);
    return true;
  }

  /// Removes a currency from the active currencies list.
  Future<bool> removeCurrency(String currency) async {
    final cur = currency.toUpperCase().trim();
    if (cur == 'USD') return false; // Prevent removing primary base currency USD
    if (!_activeCurrencies.contains(cur)) return false;
    _activeCurrencies.remove(cur);
    await saveActiveCurrencies(_activeCurrencies);
    return true;
  }

  /// Check-fetch routine triggered automatically on login / startup.
  /// Respects the rate limit of maximum twice per day, separated by at least 8 hours.
  Future<void> checkAndFetchRatesOnLogin() async {
    await initialize();
    final now = DateTime.now();
    final todayStr = now.toIso8601String().substring(0, 10); // YYYY-MM-DD

    // Reset daily counter if calendar day changes
    if (_lastFetchDate != todayStr) {
      _fetchCountToday = 0;
      _lastFetchDate = todayStr;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyFetchCountToday, 0);
      await prefs.setString(_keyLastFetchDate, todayStr);
      await _log('New calendar day detected ($todayStr). Reset fetch counter.');
    }

    bool shouldFetch = false;
    if (_lastFetchTime == null) {
      shouldFetch = true;
      await _log('No previous fetch timestamp. Initializing first fetch.');
    } else if (_fetchCountToday == 0) {
      shouldFetch = true;
      await _log('First fetch of the day.');
    } else if (_fetchCountToday == 1) {
      final timeDifference = now.difference(_lastFetchTime!);
      if (timeDifference >= const Duration(hours: 8)) {
        shouldFetch = true;
        await _log('Second fetch of the day (8+ hours since first fetch: ${timeDifference.inHours} hrs).');
      } else {
        await _log('Fetch skipped: already fetched once today. Next session allowed in ${8 - timeDifference.inHours} hrs.');
      }
    } else {
      await _log('Fetch skipped: reached daily limit of 2 fetches.');
    }

    if (shouldFetch) {
      await fetchAllRates();
    }
  }

  /// Forces a rate fetch (bypassing limits, used for diagnostics/manual updates).
  Future<void> forceFetchRates() async {
    await initialize();
    await _log('Force fetch initiated by user.');
    await fetchAllRates(isForced: true);
  }

  /// Internal executor to run the queries.
  Future<void> fetchAllRates({bool isForced = false}) async {
    final apiKey = ApiConfig.alphaVantageApiKey;
    if (apiKey.isEmpty || apiKey == 'RYN05MCEKCR4F107' && ApiConfig.alphaVantageApiKey == '') {
      await _log('Fetch aborted: API Key is empty.');
      return;
    }

    // Step 1: Gather active currencies (e.g. USD, MXN, SOL, KMNO)
    final currenciesToFetch = List<String>.from(_activeCurrencies);

    // Step 2: Gather active Stocks & ETFs symbols (holdings > 0)
    List<String> assetsToFetch = [];
    try {
      final dbService = DatabaseService();
      final holdings = await dbService.fetchHoldings();
      for (var h in holdings) {
        if (h.quantity > 0 && h.asset != null) {
          final type = h.asset!.type.toLowerCase();
          if (type == 'stock' || type == 'etf') {
            final sym = h.asset!.symbol.toUpperCase().trim();
            if (!assetsToFetch.contains(sym)) {
              assetsToFetch.add(sym);
            }
          }
        }
      }
      await _log('Found active holdings in database: $assetsToFetch');
    } catch (e) {
      await _log('Warning: could not fetch holdings from database: $e');
    }

    await _log('Beginning fetch batch. Currencies: $currenciesToFetch, Assets: $assetsToFetch');

    // Fetch Rates Sequentially with 1 second delay to prevent minute rate limit blocks
    final Map<String, double> newRates = Map.from(_cachedRates);

    // Fetch currencies
    for (var symbol in currenciesToFetch) {
      if (symbol == 'USD') {
        newRates['USD'] = 1.0;
        continue;
      }
      await _log('Fetching rate for currency: $symbol...');
      await Future.delayed(const Duration(milliseconds: 1000));
      try {
        double? rate;
        if (symbol == 'KMNO') {
          rate = await _fetchKmnoPrice();
        } else {
          rate = await _fetchCurrencyExchangeRate(symbol, apiKey);
        }
        
        if (rate != null) {
          newRates[symbol] = rate;
          await _log('Success: 1 $symbol = $rate USD');
        } else {
          await _log('Failed to fetch rate for $symbol (retaining cached/default value).');
        }
      } catch (e) {
        await _log('Error fetching $symbol: $e');
      }
    }

    // Fetch Stocks & ETFs
    for (var symbol in assetsToFetch) {
      await _log('Fetching price for asset: $symbol...');
      await Future.delayed(const Duration(milliseconds: 1000));
      try {
        final price = await _fetchStockPrice(symbol, apiKey);
        if (price != null) {
          newRates[symbol] = price;
          await _log('Success: $symbol = $price USD');
        } else {
          await _log('Failed to fetch price for $symbol (retaining cached value).');
        }
      } catch (e) {
        await _log('Error fetching stock $symbol: $e');
      }
    }

    // Update state and save
    _cachedRates = newRates;
    _lastFetchTime = DateTime.now();
    if (!isForced) {
      _fetchCountToday++;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyCachedRates, json.encode(_cachedRates));
      await prefs.setString(_keyLastFetchTime, _lastFetchTime!.toIso8601String());
      await prefs.setInt(_keyFetchCountToday, _fetchCountToday);
      await _log('Fetch batch completed successfully. Daily count: $_fetchCountToday/2.');
    } catch (e) {
      await _log('Error saving fetch metadata: $e');
    }
  }

  /// Fetch rate for physical/digital currency from AlphaVantage API.
  Future<double?> _fetchCurrencyExchangeRate(String fromSymbol, String apiKey) async {
    final url = 'https://www.alphavantage.co/query?function=CURRENCY_EXCHANGE_RATE&from_currency=$fromSymbol&to_currency=USD&apikey=$apiKey';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) return null;

    final data = json.decode(response.body);
    if (data.containsKey('Realtime Currency Exchange Rate')) {
      final rateStr = data['Realtime Currency Exchange Rate']['5. Exchange Rate'];
      return double.tryParse(rateStr ?? '');
    } else if (data.containsKey('Note')) {
      await _log('API Throttling Note: ${data['Note']}');
    } else if (data.containsKey('Error Message')) {
      await _log('API Error: ${data['Error Message']}');
    } else if (data.containsKey('Information')) {
      await _log('API Info: ${data['Information']}');
    }
    return null;
  }

  /// Fetch stock / ETF price from AlphaVantage API.
  Future<double?> _fetchStockPrice(String symbol, String apiKey) async {
    final url = 'https://www.alphavantage.co/query?function=GLOBAL_QUOTE&symbol=$symbol&apikey=$apiKey';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) return null;

    final data = json.decode(response.body);
    if (data.containsKey('Global Quote') && data['Global Quote'].containsKey('05. price')) {
      final priceStr = data['Global Quote']['05. price'];
      return double.tryParse(priceStr ?? '');
    } else if (data.containsKey('Note')) {
      await _log('API Throttling Note: ${data['Note']}');
    } else if (data.containsKey('Error Message')) {
      await _log('API Error: ${data['Error Message']}');
    } else if (data.containsKey('Information')) {
      await _log('API Info: ${data['Information']}');
    }
    return null;
  }

  /// Fetch KMNO price from CoinMarketCap simple price API
  Future<double?> _fetchKmnoPrice() async {
    const url = 'https://pro-api.coinmarketcap.com/public-api/v1/simple/price?ids=30986&convert=USD';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        await _log('CMC API status: ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body);
      if (data != null && data['data'] != null && data['data']['30986'] != null) {
        final entry = data['data']['30986'];
        
        // Try direct price
        if (entry['price'] != null) {
          return double.tryParse(entry['price'].toString());
        }
        
        // Try quote -> USD -> price
        if (entry['quote'] != null && entry['quote']['USD'] != null && entry['quote']['USD']['price'] != null) {
          return double.tryParse(entry['quote']['USD']['price'].toString());
        }
      }
      await _log('Failed to parse price field from CMC response.');
    } catch (e) {
      await _log('Error during CMC API call: $e');
    }
    return null;
  }
}
