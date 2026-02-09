import 'dart:async';
import 'dart:collection';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/location_update.dart';
import '../models/websocket_command.dart';
import '../config/backend_config.dart';
import 'location_service.dart';
import 'websocket_service.dart';

/// Coordinates location tracking and WebSocket streaming
/// Manages the entire location sharing lifecycle
class LocationStreamManager {
  static final LocationStreamManager _instance = LocationStreamManager._internal();
  factory LocationStreamManager() => _instance;
  LocationStreamManager._internal();

  // Services
  final _locationService = LocationService();
  final _webSocketService = WebSocketService();

  // State
  bool _isSharing = false;
  final Queue<LocationUpdate> _locationQueue = Queue();
  StreamSubscription<LocationUpdate>? _locationSubscription;
  StreamSubscription<WebSocketCommand>? _commandSubscription;
  Timer? _watchdogTimer;

  // Status tracking
  DateTime? _sharingStartedAt;
  int _locationsSent = 0;
  int _locationsQueued = 0;

  // Getters
  bool get isSharing => _isSharing;
  int get queuedLocationsCount => _locationQueue.length;
  LocationService get locationService => _locationService;
  WebSocketService get webSocketService => _webSocketService;

  /// Initialize the manager
  /// Call this after successful pairing, passing the device ID
  Future<void> initialize(String deviceId) async {
    print('🚀 [LocationStreamManager] Initializing...');

    // Connect WebSocket
    await _webSocketService.connect(deviceId);

    // Listen to WebSocket commands
    _commandSubscription = _webSocketService.commandStream.listen(_handleCommand);

    // Restore sharing state if app was killed
    await _restoreSharingState();

    // Start watchdog timer to detect backend unavailability
    _startWatchdog();

    print('✅ [LocationStreamManager] Initialized');
  }

  /// Handle commands from backend
  void _handleCommand(WebSocketCommand command) {
    print('📨 [LocationStreamManager] Received command: ${command.command.name}');

    switch (command.command) {
      case WebSocketCommandType.startLocationSharing:
        _handleStartCommand(command);
        break;

      case WebSocketCommandType.stopLocationSharing:
        _handleStopCommand(command);
        break;

      case WebSocketCommandType.getStatus:
        _handleStatusRequest(command);
        break;

      case WebSocketCommandType.ping:
        // Already handled by WebSocketService
        break;

      case WebSocketCommandType.unknown:
        print('⚠️ [LocationStreamManager] Unknown command received');
        break;
    }
  }

  /// Handle START_LOCATION_SHARING command
  Future<void> _handleStartCommand(WebSocketCommand command) async {
    if (_isSharing) {
      print('⚠️ [LocationStreamManager] Already sharing location');
      _sendStatusResponse(command.requestId);
      return;
    }

    print('▶️ [LocationStreamManager] Starting location sharing...');

    try {
      // Request background location permission
      await _locationService.requestBackgroundLocationPermission();

      // Start location tracking
      await _locationService.startTracking(
        initialMode: LocationTrackingMode.moving,
      );

      // Listen to location updates
      _locationSubscription = _locationService.locationStream.listen(_handleLocationUpdate);

      _isSharing = true;
      _sharingStartedAt = DateTime.now();
      _locationsSent = 0;
      _locationsQueued = 0;

      // Save state
      await _saveSharingState(true);

      print('✅ [LocationStreamManager] Location sharing started');

      // Send status response
      _sendStatusResponse(command.requestId);

    } catch (e) {
      print('❌ [LocationStreamManager] Failed to start sharing: $e');
      _webSocketService.send(
        WebSocketMessage.error('Failed to start location sharing: $e', requestId: command.requestId),
      );
    }
  }

  /// Handle STOP_LOCATION_SHARING command
  Future<void> _handleStopCommand(WebSocketCommand command) async {
    if (!_isSharing) {
      print('⚠️ [LocationStreamManager] Not currently sharing location');
      _sendStatusResponse(command.requestId);
      return;
    }

    print('⏹️ [LocationStreamManager] Stopping location sharing...');

    await _stopSharing();

    print('✅ [LocationStreamManager] Location sharing stopped');

    // Send status response
    _sendStatusResponse(command.requestId);
  }

  /// Handle GET_STATUS request
  void _handleStatusRequest(WebSocketCommand command) {
    print('ℹ️ [LocationStreamManager] Status requested');
    _sendStatusResponse(command.requestId);
  }

  /// Handle location updates from LocationService
  void _handleLocationUpdate(LocationUpdate location) {
    if (!_isSharing) return;

    print('📍 [LocationStreamManager] Location update received');

    // If WebSocket is connected, send immediately
    if (_webSocketService.isConnected) {
      _sendLocation(location);
      
      // Also send any queued locations
      _flushLocationQueue();
    } else {
      // Queue location for later
      _queueLocation(location);
    }
  }

  /// Send location to backend via WebSocket
  void _sendLocation(LocationUpdate location) {
    final message = WebSocketMessage.locationUpdate(location.toJson());
    _webSocketService.send(message);
    _locationsSent++;
    
    print('✅ [LocationStreamManager] Location sent (total: $_locationsSent)');
  }

  /// Queue location update when WebSocket is disconnected
  void _queueLocation(LocationUpdate location) {
    // Prevent queue overflow
    if (_locationQueue.length >= BackendConfig.maxQueuedLocationUpdates) {
      // Remove oldest location
      _locationQueue.removeFirst();
      print('⚠️ [LocationStreamManager] Queue full, dropping oldest location');
    }

    _locationQueue.add(location);
    _locationsQueued++;
    
    print('📦 [LocationStreamManager] Location queued (queue size: ${_locationQueue.length})');
  }

  /// Flush queued locations when WebSocket reconnects
  void _flushLocationQueue() {
    if (_locationQueue.isEmpty || !_webSocketService.isConnected) {
      return;
    }

    print('📤 [LocationStreamManager] Flushing ${_locationQueue.length} queued locations...');

    if (BackendConfig.batchSendQueuedUpdates) {
      // Send in batches
      while (_locationQueue.isNotEmpty) {
        final batch = <LocationUpdate>[];
        final batchSize = BackendConfig.queuedUpdatesBatchSize;
        
        for (int i = 0; i < batchSize && _locationQueue.isNotEmpty; i++) {
          batch.add(_locationQueue.removeFirst());
        }

        // Send batch (for now, send one by one; backend team can implement batch endpoint)
        for (final location in batch) {
          _sendLocation(location);
        }
      }
    } else {
      // Send one by one
      while (_locationQueue.isNotEmpty) {
        final location = _locationQueue.removeFirst();
        _sendLocation(location);
      }
    }

    print('✅ [LocationStreamManager] Queue flushed');
  }

  /// Start watchdog timer to detect backend unavailability
  void _startWatchdog() {
    _watchdogTimer?.cancel();
    
    _watchdogTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_isSharing) return;

      // Check if backend is still reachable
      if (!_webSocketService.isBackendReachable()) {
        print('⚠️ [LocationStreamManager] Backend unreachable for extended period, stopping...');
        _stopSharing();
      }
    });
  }

  /// Stop location sharing
  Future<void> _stopSharing() async {
    // Stop location tracking
    await _locationService.stopTracking();

    // Cancel location subscription
    await _locationSubscription?.cancel();
    _locationSubscription = null;

    // Clear queue
    _locationQueue.clear();

    _isSharing = false;
    _sharingStartedAt = null;

    // Save state
    await _saveSharingState(false);

    print('✅ [LocationStreamManager] Sharing stopped');
  }

  /// Send status response to backend
  void _sendStatusResponse(String? requestId) {
    final duration = _sharingStartedAt != null
        ? DateTime.now().difference(_sharingStartedAt!).inSeconds
        : 0;

    final statusMessage = _isSharing
        ? 'Sharing location (${_locationsSent} sent, ${_locationQueue.length} queued, ${duration}s active)'
        : 'Not sharing location';

    _webSocketService.sendStatusResponse(
      isSharing: _isSharing,
      status: statusMessage,
      requestId: requestId,
    );
  }

  /// Save sharing state to persistent storage
  Future<void> _saveSharingState(bool isSharing) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('location_sharing_active', isSharing);
    
    if (isSharing) {
      await prefs.setString('location_sharing_started_at', DateTime.now().toIso8601String());
    } else {
      await prefs.remove('location_sharing_started_at');
    }
  }

  /// Restore sharing state after app restart
  Future<void> _restoreSharingState() async {
    final prefs = await SharedPreferences.getInstance();
    final wasSharing = prefs.getBool('location_sharing_active') ?? false;

    if (wasSharing) {
      print('🔄 [LocationStreamManager] Restoring previous sharing state...');
      
      // Auto-start sharing (backend should send command anyway)
      // This is just for resilience in case app was killed
      final startedAtStr = prefs.getString('location_sharing_started_at');
      if (startedAtStr != null) {
        final startedAt = DateTime.parse(startedAtStr);
        final elapsed = DateTime.now().difference(startedAt);
        
        // Only restore if less than 10 minutes elapsed
        if (elapsed.inMinutes < 10) {
          print('ℹ️ [LocationStreamManager] Waiting for backend START command...');
          // Don't auto-start; wait for backend command
        } else {
          print('⚠️ [LocationStreamManager] Previous session too old, not restoring');
          await _saveSharingState(false);
        }
      }
    }
  }

  /// Manually start sharing (for testing/debugging)
  Future<void> manualStart() async {
    final fakeCommand = WebSocketCommand(
      command: WebSocketCommandType.startLocationSharing,
      requestId: 'manual_start',
    );
    await _handleStartCommand(fakeCommand);
  }

  /// Manually stop sharing (for testing/debugging)
  Future<void> manualStop() async {
    final fakeCommand = WebSocketCommand(
      command: WebSocketCommandType.stopLocationSharing,
      requestId: 'manual_stop',
    );
    await _handleStopCommand(fakeCommand);
  }

  /// Dispose resources
  Future<void> dispose() async {
    _watchdogTimer?.cancel();
    await _stopSharing();
    await _commandSubscription?.cancel();
    await _webSocketService.disconnect();
  }
}
