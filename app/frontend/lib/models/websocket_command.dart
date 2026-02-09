/// Model for WebSocket commands sent from backend to Flutter app
/// Represents commands to control location sharing

enum WebSocketCommandType {
  startLocationSharing,
  stopLocationSharing,
  getStatus,
  ping,
  unknown,
}

class WebSocketCommand {
  final WebSocketCommandType command;
  final String? requestId;
  final Map<String, dynamic>? params;

  WebSocketCommand({
    required this.command,
    this.requestId,
    this.params,
  });

  /// Parse command from JSON received via WebSocket
  factory WebSocketCommand.fromJson(Map<String, dynamic> json) {
    final commandStr = json['command'] as String?;
    
    WebSocketCommandType commandType;
    switch (commandStr?.toUpperCase()) {
      case 'START_LOCATION_SHARING':
        commandType = WebSocketCommandType.startLocationSharing;
        break;
      case 'STOP_LOCATION_SHARING':
        commandType = WebSocketCommandType.stopLocationSharing;
        break;
      case 'GET_STATUS':
        commandType = WebSocketCommandType.getStatus;
        break;
      case 'PING':
        commandType = WebSocketCommandType.ping;
        break;
      default:
        commandType = WebSocketCommandType.unknown;
    }

    return WebSocketCommand(
      command: commandType,
      requestId: json['request_id'] as String?,
      params: json['params'] as Map<String, dynamic>?,
    );
  }

  /// Convert to JSON for debugging
  Map<String, dynamic> toJson() {
    return {
      'command': command.name.toUpperCase(),
      'request_id': requestId,
      'params': params,
    };
  }

  @override
  String toString() {
    return 'WebSocketCommand(${command.name}, requestId: $requestId, params: $params)';
  }
}

/// Model for WebSocket messages sent from Flutter to backend
enum WebSocketMessageType {
  locationUpdate,
  statusResponse,
  pong,
  error,
}

class WebSocketMessage {
  final WebSocketMessageType type;
  final Map<String, dynamic>? data;
  final String? requestId;  // To match responses with requests
  final String? error;

  WebSocketMessage({
    required this.type,
    this.data,
    this.requestId,
    this.error,
  });

  /// Convert to JSON for WebSocket transmission
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'type': _typeToString(type),
    };

    if (data != null) json['data'] = data;
    if (requestId != null) json['request_id'] = requestId;
    if (error != null) json['error'] = error;

    return json;
  }

  String _typeToString(WebSocketMessageType type) {
    switch (type) {
      case WebSocketMessageType.locationUpdate:
        return 'LOCATION_UPDATE';
      case WebSocketMessageType.statusResponse:
        return 'STATUS_RESPONSE';
      case WebSocketMessageType.pong:
        return 'PONG';
      case WebSocketMessageType.error:
        return 'ERROR';
    }
  }

  @override
  String toString() {
    return 'WebSocketMessage(${_typeToString(type)}, requestId: $requestId)';
  }

  /// Create a location update message
  factory WebSocketMessage.locationUpdate(Map<String, dynamic> locationData) {
    return WebSocketMessage(
      type: WebSocketMessageType.locationUpdate,
      data: locationData,
    );
  }

  /// Create a status response message
  factory WebSocketMessage.statusResponse({
    required bool isSharing,
    required String status,
    String? requestId,
  }) {
    return WebSocketMessage(
      type: WebSocketMessageType.statusResponse,
      data: {
        'is_sharing': isSharing,
        'status': status,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      },
      requestId: requestId,
    );
  }

  /// Create a pong response
  factory WebSocketMessage.pong(String? requestId) {
    return WebSocketMessage(
      type: WebSocketMessageType.pong,
      requestId: requestId,
    );
  }

  /// Create an error message
  factory WebSocketMessage.error(String errorMessage, {String? requestId}) {
    return WebSocketMessage(
      type: WebSocketMessageType.error,
      error: errorMessage,
      requestId: requestId,
    );
  }
}
