import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../models/websocket_command.dart';
import '../config/backend_config.dart';

/// WebSocket service for real-time communication with backend
/// Handles connection lifecycle, reconnection, and message routing
class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  // WebSocket channel
  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;

  // Connection state
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _shouldReconnect = true;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  DateTime? _lastMessageTime;

  // Stream controllers
  final _commandStreamController = StreamController<WebSocketCommand>.broadcast();
  final _connectionStateController = StreamController<WebSocketConnectionState>.broadcast();

  // Device ID (from pairing)
  String? _deviceId;

  // Getters
  Stream<WebSocketCommand> get commandStream => _commandStreamController.stream;
  Stream<WebSocketConnectionState> get connectionStateStream => _connectionStateController.stream;
  bool get isConnected => _isConnected;
  WebSocketConnectionState get connectionState => _isConnected 
      ? WebSocketConnectionState.connected 
      : _isConnecting 
          ? WebSocketConnectionState.connecting 
          : WebSocketConnectionState.disconnected;

  /// Initialize WebSocket connection
  /// Call this after successful pairing with device ID
  Future<void> connect(String deviceId) async {
    if (_isConnected || _isConnecting) {
      print('⚠️ [WebSocketService] Already connected or connecting');
      return;
    }

    _deviceId = deviceId;
    _shouldReconnect = true;
    _reconnectAttempts = 0;

    await _establishConnection();
  }

  /// Establish WebSocket connection
  Future<void> _establishConnection() async {
    if (_deviceId == null) {
      print('❌ [WebSocketService] Cannot connect: Device ID not set');
      return;
    }

    try {
      _isConnecting = true;
      _updateConnectionState(WebSocketConnectionState.connecting);

      final wsUrl = BackendConfig.getDeviceWebSocketUrl(_deviceId!);
      print('🔌 [WebSocketService] Connecting to: $wsUrl');

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      // Listen to the stream
      _channelSubscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDisconnected,
        cancelOnError: false,
      );

      // Wait a moment to see if connection succeeds
      await Future.delayed(const Duration(milliseconds: 500));

      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0;
      _lastMessageTime = DateTime.now();

      _updateConnectionState(WebSocketConnectionState.connected);
      print('✅ [WebSocketService] Connected successfully');

      // Start ping timer to keep connection alive
      _startPingTimer();

    } catch (e) {
      print('❌ [WebSocketService] Connection error: $e');
      _isConnecting = false;
      _handleConnectionFailure();
    }
  }

  /// Handle incoming WebSocket messages
  void _onMessage(dynamic message) {
    _lastMessageTime = DateTime.now();

    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      print('📩 [WebSocketService] Received: ${data['command'] ?? data['type']}');

      // Parse as command
      final command = WebSocketCommand.fromJson(data);
      
      // Handle ping specially
      if (command.command == WebSocketCommandType.ping) {
        _sendPong(command.requestId);
        return;
      }

      // Emit command to listeners
      _commandStreamController.add(command);

    } catch (e) {
      print('❌ [WebSocketService] Error parsing message: $e');
    }
  }

  /// Handle WebSocket errors
  void _onError(dynamic error) {
    print('❌ [WebSocketService] WebSocket error: $error');
    _handleConnectionFailure();
  }

  /// Handle WebSocket disconnection
  void _onDisconnected() {
    print('🔌 [WebSocketService] WebSocket disconnected');
    _isConnected = false;
    _stopPingTimer();
    _updateConnectionState(WebSocketConnectionState.disconnected);

    if (_shouldReconnect) {
      _scheduleReconnection();
    }
  }

  /// Handle connection failure and schedule reconnection
  void _handleConnectionFailure() {
    _isConnected = false;
    _isConnecting = false;
    _stopPingTimer();
    _updateConnectionState(WebSocketConnectionState.disconnected);

    if (_shouldReconnect) {
      _scheduleReconnection();
    }
  }

  /// Schedule automatic reconnection with exponential backoff
  void _scheduleReconnection() {
    _reconnectTimer?.cancel();

    _reconnectAttempts++;

    // Calculate delay with exponential backoff
    int delay = BackendConfig.websocketReconnectDelaySeconds * _reconnectAttempts;
    delay = delay.clamp(
      BackendConfig.websocketReconnectDelaySeconds,
      BackendConfig.websocketReconnectMaxDelaySeconds,
    );

    print('🔄 [WebSocketService] Reconnecting in $delay seconds (attempt $_reconnectAttempts)...');
    _updateConnectionState(WebSocketConnectionState.reconnecting);

    _reconnectTimer = Timer(Duration(seconds: delay), () {
      if (_shouldReconnect && !_isConnected && !_isConnecting) {
        _establishConnection();
      }
    });
  }

  /// Start ping timer to keep connection alive
  void _startPingTimer() {
    _stopPingTimer();
    
    _pingTimer = Timer.periodic(
      Duration(seconds: BackendConfig.websocketPingIntervalSeconds),
      (_) => _sendPing(),
    );
  }

  /// Stop ping timer
  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  /// Send ping to backend
  void _sendPing() {
    if (!_isConnected) return;

    // Check if backend is still responding
    final timeSinceLastMessage = DateTime.now().difference(_lastMessageTime ?? DateTime.now());
    if (timeSinceLastMessage.inSeconds > BackendConfig.websocketTimeoutSeconds) {
      print('⚠️ [WebSocketService] Backend not responding, reconnecting...');
      _handleConnectionFailure();
      return;
    }

    final message = WebSocketMessage.pong(null);
    send(message);
  }

  /// Send pong response to ping
  void _sendPong(String? requestId) {
    final message = WebSocketMessage.pong(requestId);
    send(message);
  }

  /// Send a message to backend
  void send(WebSocketMessage message) {
    // Debug logging - always log in debug mode
    if (BackendConfig.debugMode) {
      final json = message.toJson();
      print('═══════════════════════════════════════════════════════════');
      print('📤 [WebSocketService] OUTGOING MESSAGE:');
      print('   Type: ${message.type.name}');
      print('   JSON: ${jsonEncode(json)}');
      if (message.type == WebSocketMessageType.locationUpdate) {
        print('   Location Data:');
        if (json['data'] != null) {
          final data = json['data'] as Map<String, dynamic>;
          print('      Latitude:  ${data['latitude']}');
          print('      Longitude: ${data['longitude']}');
          print('      Accuracy:  ${data['accuracy']}m');
          print('      Speed:     ${data['speed']}m/s');
          print('      Timestamp: ${data['timestamp']}');
        }
      }
      print('═══════════════════════════════════════════════════════════');
    }
    
    if (!_isConnected || _channel == null) {
      if (BackendConfig.debugMode) {
        print('⚠️ [WebSocketService] Not connected - message would be sent when connected');
      } else {
        print('⚠️ [WebSocketService] Cannot send message: Not connected');
      }
      return;
    }

    try {
      final json = jsonEncode(message.toJson());
      _channel!.sink.add(json);
      
      // Don't log pong messages to reduce noise
      if (message.type != WebSocketMessageType.pong && !BackendConfig.debugMode) {
        print('📤 [WebSocketService] Sent: ${message.type.name}');
      }
    } catch (e) {
      print('❌ [WebSocketService] Error sending message: $e');
    }
  }

  /// Send status response
  void sendStatusResponse({
    required bool isSharing,
    required String status,
    String? requestId,
  }) {
    final message = WebSocketMessage.statusResponse(
      isSharing: isSharing,
      status: status,
      requestId: requestId,
    );
    send(message);
  }

  /// Disconnect WebSocket
  Future<void> disconnect() async {
    print('🔌 [WebSocketService] Disconnecting...');
    
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _stopPingTimer();

    await _channelSubscription?.cancel();
    await _channel?.sink.close(status.goingAway);
    
    _channel = null;
    _channelSubscription = null;
    _isConnected = false;
    _isConnecting = false;

    _updateConnectionState(WebSocketConnectionState.disconnected);
    print('✅ [WebSocketService] Disconnected');
  }

  /// Update connection state and notify listeners
  void _updateConnectionState(WebSocketConnectionState state) {
    _connectionStateController.add(state);
  }

  /// Check if backend is reachable (based on last message time)
  bool isBackendReachable() {
    if (!_isConnected || _lastMessageTime == null) {
      return false;
    }

    final timeSinceLastMessage = DateTime.now().difference(_lastMessageTime!);
    return timeSinceLastMessage.inSeconds < BackendConfig.websocketTimeoutSeconds;
  }

  /// Dispose resources
  void dispose() {
    disconnect();
    _commandStreamController.close();
    _connectionStateController.close();
  }
}

/// WebSocket connection states
enum WebSocketConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}
