// ===== Proximity Announcement Thresholds =====
/// Distance threshold for first proximity announcement (meters)
const double PROXIMITY_THRESHOLD_1KM = 1000.0;

/// Distance threshold for second proximity announcement (meters)
const double PROXIMITY_THRESHOLD_500M = 500.0;

/// Distance threshold for third proximity announcement (meters)
const double PROXIMITY_THRESHOLD_200M = 200.0;

/// Distance threshold for fourth proximity announcement (meters)
const double PROXIMITY_THRESHOLD_100M = 100.0;

/// Distance threshold for destination reached announcement (meters)
const double PROXIMITY_THRESHOLD_50M = 50.0;

// ===== Trip Cache Configuration (DES-TRP001) =====
/// Cache freshness threshold in minutes
/// If Hive cache is older than this, backend sync will be triggered
const int tripCacheFreshnessMinutes = 2;

/// Force backend refresh on every load (for testing)
/// When true, always contacts backend regardless of cache state
const bool alwaysRefreshFromBackend = false;

// ===== Trip Source Identifiers (DES-TRP001) =====
/// Trip data loaded from in-memory controller state
const String tripSourceInMemory = 'in_memory';

/// Trip data loaded from Hive local cache
const String tripSourceHiveCache = 'hive_cache';

/// Trip data loaded from backend API
const String tripSourceBackend = 'backend_api';

/// No active trip found
const String tripSourceNone = 'none';
