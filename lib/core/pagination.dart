import 'package:flutter/foundation.dart';

class PageResult<T> {
  final List<T> items;
  final int count;
  final int page;
  final int pageSize;
  final int totalPages;
  final bool hasNext;
  final bool hasPrevious;

  const PageResult({
    required this.items,
    required this.count,
    required this.page,
    required this.pageSize,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrevious,
  });

  factory PageResult.fromResponse(
    dynamic response,
    String listKey,
    T Function(Map<String, dynamic>) parser,
  ) {
    if (response is! Map<String, dynamic>) {
      throw const FormatException('استجابة القائمة غير صالحة.');
    }
    final rawItems = response[listKey] ?? response['results'];
    if (rawItems is! List) {
      throw const FormatException('استجابة القائمة لا تحتوي على عناصر.');
    }
    final page = _positiveInt(response['page'], 1);
    final pageSize = _positiveInt(response['page_size'], rawItems.length);
    final count = _nonNegativeInt(response['count'], rawItems.length);
    final totalPages = _positiveInt(
      response['total_pages'],
      pageSize == 0 ? (page > 1 ? page : 1) : ((count + pageSize - 1) / pageSize).ceil(),
    );
    return PageResult<T>(
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(parser)
          .toList(growable: false),
      count: count,
      page: page,
      pageSize: pageSize,
      totalPages: totalPages,
      hasNext: response['has_next'] == true || page < totalPages,
      hasPrevious: response['has_previous'] == true || page > 1,
    );
  }

  static int _positiveInt(dynamic value, int fallback) {
    final parsed = int.tryParse(value?.toString() ?? '');
    return parsed != null && parsed > 0 ? parsed : fallback;
  }

  static int _nonNegativeInt(dynamic value, int fallback) {
    final parsed = int.tryParse(value?.toString() ?? '');
    return parsed != null && parsed >= 0 ? parsed : fallback;
  }
}

typedef PageFetcher<T> = Future<PageResult<T>> Function(
  int page,
  Map<String, dynamic> filters,
);

class PaginationController<T> extends ChangeNotifier {
  PaginationController(this._fetchPage);

  final PageFetcher<T> _fetchPage;
  final List<T> _items = [];
  Map<String, dynamic> _filters = const {};
  List<T> _unmodifiableItems = const [];
  Future<void>? _activeRequest;
  int _generation = 0;
  int _page = 0;
  int _count = 0;
  int _pageSize = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasLoaded = false;
  bool _hasNext = false;
  String? _error;

  List<T> get items => _unmodifiableItems;
  Map<String, dynamic> get filters => Map.unmodifiable(_filters);
  int get page => _page;
  int get count => _count;
  int get pageSize => _pageSize;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasLoaded => _hasLoaded;
  bool get hasNext => _hasNext;
  String? get error => _error;
  bool get hasError => _error != null;

  Future<void> load({bool refresh = false}) {
    if (_activeRequest case final active?) return active;
    final loadingMore = !refresh && _hasLoaded;
    final nextPage = refresh || !_hasLoaded ? 1 : _page + 1;
    return _startLoad(nextPage, _generation, loadingMore);
  }

  Future<void> _startLoad(int nextPage, int generation, bool loadingMore) {
    final operation = _loadPage(nextPage, generation, loadingMore);
    _activeRequest = operation;
    return operation.whenComplete(() {
      if (identical(_activeRequest, operation)) _activeRequest = null;
    });
  }

  Future<void> refresh() => load(refresh: true);

  Future<void> loadMore() {
    if (_isLoading || _isLoadingMore || !_hasNext || !_hasLoaded) {
      return Future<void>.value();
    }
    return load();
  }

  Future<void> replaceFilters(Map<String, dynamic> filters) async {
    final normalized = Map<String, dynamic>.from(filters)
      ..removeWhere((_, value) => value == null || value == '');
    if (mapEquals(_filters, normalized)) return refresh();
    _generation += 1;
    _filters = normalized;
    _items.clear();
    _unmodifiableItems = const [];
    _page = 0;
    _count = 0;
    _hasLoaded = false;
    _hasNext = false;
    _error = null;
    notifyListeners();
    await _startLoad(1, _generation, false);
  }

  Future<void> _loadPage(int nextPage, int generation, bool loadingMore) async {
    if (loadingMore) {
      _isLoadingMore = true;
    } else {
      _isLoading = true;
    }
    _error = null;
    notifyListeners();
    try {
      final result = await _fetchPage(nextPage, Map.from(_filters));
      if (generation != _generation) return;
      if (nextPage <= 1) {
        _items
          ..clear()
          ..addAll(result.items);
      } else {
        _items.addAll(result.items);
      }
      _unmodifiableItems = List<T>.unmodifiable(_items);
      _page = result.page;
      _count = result.count;
      _pageSize = result.pageSize;
      _hasNext = result.hasNext;
      _hasLoaded = true;
    } catch (error) {
      if (generation == _generation) _error = error.toString();
    } finally {
      if (generation == _generation) {
        _isLoading = false;
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _generation += 1;
    super.dispose();
  }
}
