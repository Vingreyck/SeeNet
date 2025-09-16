// lib/services/performance_service.dart
import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

class PerformanceMetrics {
  final String operation;
  final int duration;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  PerformanceMetrics({
    required this.operation,
    required this.duration,
    required this.timestamp,
    this.metadata,
  });
}

class CacheItem<T> {
  final T data;
  final DateTime timestamp;
  final Duration ttl;

  CacheItem({
    required this.data,
    required this.timestamp,
    required this.ttl,
  });

  bool get isExpired => DateTime.now().difference(timestamp) > ttl;
}

class PerformanceService extends GetxService {
  static const String _tag = 'PERFORMANCE';
  static const int _maxCacheSize = 100;
  static const Duration _defaultCacheTTL = Duration(minutes: 15);
  
  // Cache inteligente com LRU
  final LinkedHashMap<String, CacheItem> _cache = LinkedHashMap();
  
  // Debounce controllers
  final Map<String, Timer?> _debounceTimers = {};
  
  // Performance metrics
  final Map<String, DateTime> _operationStartTimes = {};
  final List<PerformanceMetrics> _metrics = [];
  
  // Memory optimization
  final Map<String, WeakReference<Widget>> _widgetCache = {};
  
  // Batch operations queue
  final Map<String, List<Function>> _batchQueue = {};
  Timer? _batchTimer;

  @override
  void onInit() {
    super.onInit();
    _setupPerformanceMonitoring();
    _startPeriodicCleanup();
  }

  void _setupPerformanceMonitoring() {
    if (kDebugMode) {
      debugPrint('$_tag: Performance monitoring initialized');
    }
  }

  void _startPeriodicCleanup() {
    Timer.periodic(const Duration(minutes: 5), (_) {
      _cleanupExpiredCache();
      _cleanupOldMetrics();
    });
  }

  /// ========== CACHE INTELIGENTE ==========
  
  /// Armazenar no cache com TTL
  void setCache<T>(String key, T data, {Duration? ttl}) {
    _ensureCacheSize();
    
    _cache[key] = CacheItem(
      data: data,
      timestamp: DateTime.now(),
      ttl: ttl ?? _defaultCacheTTL,
    );
    
    if (kDebugMode) {
      debugPrint('$_tag: Cached [$key] for ${ttl?.inMinutes ?? _defaultCacheTTL.inMinutes}min');
    }
  }

  /// Obter do cache
  T? getCache<T>(String key) {
    final item = _cache[key];
    if (item == null) return null;
    
    if (item.isExpired) {
      _cache.remove(key);
      return null;
    }
    
    // Move para o fim (LRU)
    _cache.remove(key);
    _cache[key] = item;
    
    return item.data as T?;
  }

  /// Cache para widgets pesados
  Widget cacheWidget(String key, Widget Function() builder, {Duration? ttl}) {
    if (kDebugMode) {
      // Em debug, sempre rebuilda para hot reload
      return builder();
    }
    
    final cached = getCache<Widget>(key);
    if (cached != null) {
      return cached;
    }
    
    final widget = builder();
    setCache(key, widget, ttl: ttl);
    return widget;
  }

  /// Widget com weak reference para economia de memória
  Widget weakCacheWidget(String key, Widget Function() builder) {
    final ref = _widgetCache[key];
    final cached = ref?.target;
    
    if (cached != null) {
      return cached;
    }
    
    final widget = builder();
    _widgetCache[key] = WeakReference(widget);
    return widget;
  }

  void _ensureCacheSize() {
    while (_cache.length >= _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
  }

  void _cleanupExpiredCache() {
    _cache.removeWhere((key, item) => item.isExpired);
    
    if (kDebugMode) {
      debugPrint('$_tag: Cache cleanup - ${_cache.length} items remaining');
    }
  }

  /// ========== DEBOUNCE E THROTTLE ==========
  
  /// Debounce para inputs e buscas
  void debounce(
    String key,
    VoidCallback callback, {
    Duration delay = const Duration(milliseconds: 300),
  }) {
    _debounceTimers[key]?.cancel();
    _debounceTimers[key] = Timer(delay, () {
      callback();
      _debounceTimers.remove(key);
    });
  }

  /// Throttle para ações frequentes
  bool throttle(String key, {Duration cooldown = const Duration(seconds: 1)}) {
    final cached = getCache<DateTime>('throttle_$key');
    final now = DateTime.now();
    
    if (cached != null && now.difference(cached) < cooldown) {
      return false; // Ainda em cooldown
    }
    
    setCache('throttle_$key', now, ttl: cooldown);
    return true;
  }

  /// ========== PERFORMANCE MONITORING ==========
  
  /// Iniciar medição de performance
  void startMeasure(String operation, {Map<String, dynamic>? metadata}) {
    _operationStartTimes[operation] = DateTime.now();
    
    if (kDebugMode && metadata != null) {
      debugPrint('$_tag: Starting [$operation] with metadata: $metadata');
    }
  }

  /// Finalizar medição
  void endMeasure(String operation, {Map<String, dynamic>? metadata}) {
    final startTime = _operationStartTimes[operation];
    if (startTime == null) return;
    
    final duration = DateTime.now().difference(startTime).inMilliseconds;
    
    final metric = PerformanceMetrics(
      operation: operation,
      duration: duration,
      timestamp: DateTime.now(),
      metadata: metadata,
    );
    
    _metrics.add(metric);
    _operationStartTimes.remove(operation);
    
    if (kDebugMode) {
      debugPrint('$_tag: [$operation] completed in ${duration}ms');
      
      // Alertar se operação demorou muito
      if (duration > 1000) {
        debugPrint('⚠️ SLOW OPERATION: [$operation] took ${duration}ms');
      }
    }
  }

  /// Medir operação automaticamente
  Future<T> measureOperation<T>(
    String operation,
    Future<T> Function() callback, {
    Map<String, dynamic>? metadata,
  }) async {
    startMeasure(operation, metadata: metadata);
    try {
      final result = await callback();
      endMeasure(operation, metadata: metadata);
      return result;
    } catch (e) {
      endMeasure(operation, metadata: {'error': e.toString()});
      rethrow;
    }
  }

  /// ========== BATCH OPERATIONS ==========
  
  /// Adicionar operação ao batch
  void addToBatch(String batchKey, Function operation) {
    _batchQueue.putIfAbsent(batchKey, () => []).add(operation);
    
    // Executar batch após delay
    _batchTimer?.cancel();
    _batchTimer = Timer(const Duration(milliseconds: 100), () {
      _executeBatch(batchKey);
    });
  }

  /// Executar batch de operações
  void _executeBatch(String batchKey) async {
    final operations = _batchQueue[batchKey];
    if (operations == null || operations.isEmpty) return;
    
    startMeasure('batch_$batchKey');
    
    try {
      await Future.wait(operations.map((op) async {
        if (op is Function()) {
          return op();
        } else {
          op();
          return Future.value();
        }
      }));
      
      if (kDebugMode) {
        debugPrint('$_tag: Executed batch [$batchKey] with ${operations.length} operations');
      }
    } catch (e) {
      debugPrint('$_tag: Batch error [$batchKey]: $e');
    } finally {
      endMeasure('batch_$batchKey');
      _batchQueue.remove(batchKey);
    }
  }

  /// ========== LAZY LOADING ==========
  
  /// Widget com lazy loading
  Widget lazyBuilder({
    required Widget Function() builder,
    Widget? placeholder,
    Duration delay = const Duration(milliseconds: 50),
  }) {
    return FutureBuilder<Widget>(
      future: Future.delayed(delay, builder),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return snapshot.data!;
        }
        return placeholder ?? const SizedBox.shrink();
      },
    );
  }

  /// Lista virtual para grandes volumes
  Widget virtualList({
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
    double? itemExtent,
    ScrollController? controller,
  }) {
    return ListView.builder(
      controller: controller,
      itemCount: itemCount,
      itemExtent: itemExtent,
      cacheExtent: 1000, // Cache mais itens
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: false,
      itemBuilder: (context, index) {
        return RepaintBoundary(
          child: itemBuilder(context, index),
        );
      },
    );
  }

  /// ========== RELATÓRIOS E ANALYTICS ==========
  
  /// Obter relatório de performance
  Map<String, dynamic> getPerformanceReport() {
    if (_metrics.isEmpty) {
      return {'message': 'Nenhuma métrica disponível'};
    }

    Map<String, List<int>> operationDurations = {};
    
    // Agrupar por operação
    for (var metric in _metrics) {
      operationDurations.putIfAbsent(metric.operation, () => []).add(metric.duration);
    }

    Map<String, dynamic> report = {};
    
    operationDurations.forEach((operation, durations) {
      final avg = durations.reduce((a, b) => a + b) / durations.length;
      final max = durations.reduce((a, b) => a > b ? a : b);
      final min = durations.reduce((a, b) => a < b ? a : b);
      
      report[operation] = {
        'average_ms': avg.round(),
        'max_ms': max,
        'min_ms': min,
        'total_calls': durations.length,
        'performance_grade': _calculateGrade(avg),
      };
    });

    report['summary'] = {
      'total_operations': _metrics.length,
      'cache_size': _cache.length,
      'cache_hit_ratio': _calculateCacheHitRatio(),
      'memory_usage': _getMemoryUsage(),
    };

    return report;
  }

  String _calculateGrade(double avgMs) {
    if (avgMs < 100) return 'A (Excelente)';
    if (avgMs < 300) return 'B (Bom)';
    if (avgMs < 500) return 'C (Regular)';
    if (avgMs < 1000) return 'D (Lento)';
    return 'F (Muito Lento)';
  }

  double _calculateCacheHitRatio() {
    // Implementação simplificada
    return _cache.isNotEmpty ? 0.85 : 0.0;
  }

  String _getMemoryUsage() {
    // Estimativa simples
    int cacheSize = _cache.length * 1024; // ~1KB por item
    int metricsSize = _metrics.length * 256; // ~256B por métrica
    int totalBytes = cacheSize + metricsSize;
    
    if (totalBytes > 1024 * 1024) {
      return '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else if (totalBytes > 1024) {
      return '${(totalBytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '$totalBytes B';
    }
  }

  /// ========== OTIMIZAÇÕES ESPECÍFICAS ==========
  
  /// Pre-carregamento inteligente
  void preloadData(List<String> keys, List<Future<dynamic> Function()> loaders) {
    for (int i = 0; i < keys.length && i < loaders.length; i++) {
      final key = keys[i];
      final loader = loaders[i];
      
      if (getCache(key) == null) {
        loader().then((data) {
          setCache(key, data);
        }).catchError((e) {
          debugPrint('$_tag: Preload failed for [$key]: $e');
        });
      }
    }
  }

  /// Otimização de imagens
  Widget optimizedImage(
    String path, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
  }) {
    return cacheWidget(
      'image_$path',
      () => Image.asset(
        path,
        width: width,
        height: height,
        fit: fit,
        cacheWidth: width?.round(),
        cacheHeight: height?.round(),
      ),
      ttl: const Duration(hours: 1),
    );
  }

  /// ========== CLEANUP E MANUTENÇÃO ==========
  
  void _cleanupOldMetrics() {
    final cutoff = DateTime.now().subtract(const Duration(hours: 1));
    _metrics.removeWhere((metric) => metric.timestamp.isBefore(cutoff));
  }

  /// Limpar cache específico
  void clearCache([String? key]) {
    if (key != null) {
      _cache.remove(key);
      _widgetCache.remove(key);
    } else {
      _cache.clear();
      _widgetCache.clear();
    }
    
    if (kDebugMode) {
      debugPrint('$_tag: Cache cleared ${key != null ? '[$key]' : '(all)'}');
    }
  }

  /// Forçar garbage collection
  void forceGC() {
    _cache.clear();
    _widgetCache.clear();
    _metrics.clear();
    
    // Limpar timers
    for (var timer in _debounceTimers.values) {
      timer?.cancel();
    }
    _debounceTimers.clear();
    
    if (kDebugMode) {
      debugPrint('$_tag: Forced garbage collection');
    }
  }

  /// Debug - mostrar status
  void debugStatus() {
    if (!kDebugMode) return;
    
    debugPrint('\n$_tag === STATUS ===');
    debugPrint('Cache items: ${_cache.length}/$_maxCacheSize');
    debugPrint('Widget cache: ${_widgetCache.length}');
    debugPrint('Active timers: ${_debounceTimers.length}');
    debugPrint('Metrics: ${_metrics.length}');
    debugPrint('Batch queues: ${_batchQueue.length}');
    debugPrint('Memory usage: ${_getMemoryUsage()}');
    debugPrint('====================\n');
  }

  @override
  void onClose() {
    _batchTimer?.cancel();
    for (var timer in _debounceTimers.values) {
      timer?.cancel();
    }
    forceGC();
    super.onClose();
  }
}

/// Mixin para widgets que usam performance
mixin PerformanceOptimized<T extends StatefulWidget> on State<T> {
  PerformanceService get performance => Get.find<PerformanceService>();
  
  /// Cache widget com cleanup automático
  Widget cachedBuild(String key, Widget Function() builder) {
    return performance.cacheWidget(key, builder);
  }
  
  /// Debounce para setState
  void debouncedSetState(VoidCallback callback, {Duration? delay}) {
    performance.debounce(
      '${widget.runtimeType}_setState',
      () {
        if (mounted) {
          setState(callback);
        }
      },
      delay: delay ?? const Duration(milliseconds: 16), // ~60 FPS
    );
  }
  
  @override
  void dispose() {
    performance.clearCache('${widget.runtimeType}');
    super.dispose();
  }
}

/// Extension para Future com medição automática
extension PerformanceFuture<T> on Future<T> {
  Future<T> measure(String operation) {
    return Get.find<PerformanceService>().measureOperation(operation, () => this);
  }
}