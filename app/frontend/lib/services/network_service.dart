import 'bluetooth_service.dart';
import 'storage_service.dart';
import 'dart:async';

/// Service for managing S.A.G.E network configuration
class NetworkService {
  static bool _isConfiguring = false;  // Lock to prevent concurrent configuration
  
  /// Send WiFi credentials to paired Glass device and monitor connection status
  /// Returns a stream of connection status updates
  static Stream<NetworkStatus> configureWiFi({
    required String deviceId,
    required String ssid,
    required String password,
  }) async* {
    // Prevent concurrent configuration attempts
    if (_isConfiguring) {
      print('NetworkService: Configuration already in progress, rejecting duplicate request');
      yield NetworkStatus(
        status: ConnectionStatus.failed,
        message: 'Configuration already in progress',
      );
      return;
    }
    
    _isConfiguring = true;
    
    try {
      print('NetworkService: Configuring WiFi for device $deviceId');
      print('  SSID: $ssid');
      
      // Yield initial connecting state
      yield NetworkStatus(
        status: ConnectionStatus.connecting,
        message: 'Sending credentials to S.A.G.E...',
      );
      
      // Send credentials via BLE
      final sent = await BluetoothService.sendCredentials(
        deviceId: deviceId,
        ssid: ssid,
        password: password,
      );
      
      if (!sent) {
        print('NetworkService: Failed to send WiFi configuration');
        _isConfiguring = false;  // Release lock on failure
        yield NetworkStatus(
          status: ConnectionStatus.failed,
          message: 'Failed to send credentials via Bluetooth',
        );
        return;
      }
      
      print('NetworkService: Credentials sent, waiting for connection...');
      yield NetworkStatus(
        status: ConnectionStatus.connecting,
        message: 'S.A.G.E is connecting to $ssid...',
      );
      
      // Poll status characteristic for updates (30 second timeout)
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      int pollCount = 0;
      
      while (DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(seconds: 2));
        pollCount++;
        
        print('NetworkService: Polling status (attempt $pollCount)...');
        
        try {
          final statusData = await BluetoothService.readConnectionStatus(deviceId);
          
          if (statusData != null) {
            final status = statusData['status'] as String?;
            final connectedNetwork = statusData['network'] as String?;
            
            print('NetworkService: Status update - $status, network: $connectedNetwork');
            
            if (status == 'connected') {
              // Check if connected to the right network
              if (connectedNetwork == ssid) {
                // Success!
                await StorageService.saveWiFiCredentials(
                  ssid: ssid,
                  password: password,
                );
                
                _isConfiguring = false;  // Release lock on success
                yield NetworkStatus(
                  status: ConnectionStatus.connected,
                  message: 'Successfully connected to $ssid',
                  connectedNetwork: connectedNetwork,
                );
                print('NetworkService: Connection successful, exiting poll loop');
                return;
              } else {
                // Connected but to wrong network (shouldn't happen)
                print('NetworkService: Connected to wrong network: $connectedNetwork');
                continue; // Keep polling
              }
            } else if (status == 'failed') {
              _isConfiguring = false;  // Release lock on failure
              yield NetworkStatus(
                status: ConnectionStatus.failed,
                message: 'Failed to connect to $ssid. Please check your credentials and try again.',
              );
              print('NetworkService: Connection failed, exiting poll loop');
              return;
            } else if (status == 'timeout') {
              _isConfiguring = false;  // Release lock on timeout
              yield NetworkStatus(
                status: ConnectionStatus.timeout,
                message: 'Connection timeout. The network may be out of range.',
              );
              print('NetworkService: Connection timeout, exiting poll loop');
              return;
            }
            // If status is still 'connecting' or 'waiting', continue polling
          } else {
            print('NetworkService: Status data is null, device may be disconnected');
            // Continue polling, maybe temporary BLE issue
          }
        } catch (e) {
          print('NetworkService: Error reading status: $e');
          // Continue polling, might be temporary
        }
        
        // Maximum 15 polls (30 seconds)
        if (pollCount >= 15) {
          print('NetworkService: Max poll count reached');
          break;
        }
      }
      
      // Timeout - no definitive success or failure
      print('NetworkService: Polling timeout reached');
      _isConfiguring = false;  // Release lock on timeout
      yield NetworkStatus(
        status: ConnectionStatus.timeout,
        message: 'Connection timeout. Check S.A.G.E and try again.',
      );
      
    } catch (e) {
      print('NetworkService: Error configuring WiFi: $e');
      _isConfiguring = false;  // Release lock on error
      yield NetworkStatus(
        status: ConnectionStatus.failed,
        message: 'Error: $e',
      );
    }
  }
  
  /// Get saved WiFi credentials if any
  static Future<WiFiCredentials?> getSavedWiFiCredentials() async {
    try {
      return await StorageService.getWiFiCredentials();
    } catch (e) {
      print('NetworkService: Error getting WiFi credentials: $e');
      return null;
    }
  }
  
  /// Clear saved WiFi credentials
  static Future<void> clearWiFiCredentials() async {
    try {
      await StorageService.clearWiFiCredentials();
      print('NetworkService: WiFi credentials cleared');
    } catch (e) {
      print('NetworkService: Error clearing WiFi credentials: $e');
    }
  }
}

/// Connection status enum
enum ConnectionStatus {
  connecting,
  connected,
  failed,
  timeout,
}

/// Network status data class
class NetworkStatus {
  final ConnectionStatus status;
  final String message;
  final String? connectedNetwork;
  
  NetworkStatus({
    required this.status,
    required this.message,
    this.connectedNetwork,
  });
}

/// WiFi credentials data class
class WiFiCredentials {
  final String ssid;
  final String password;
  final DateTime? savedAt;
  
  WiFiCredentials({
    required this.ssid,
    required this.password,
    this.savedAt,
  });
  
  Map<String, dynamic> toJson() => {
    'ssid': ssid,
    'password': password,
    'savedAt': savedAt?.toIso8601String(),
  };
  
  factory WiFiCredentials.fromJson(Map<String, dynamic> json) {
    return WiFiCredentials(
      ssid: json['ssid'] as String,
      password: json['password'] as String,
      savedAt: json['savedAt'] != null 
          ? DateTime.parse(json['savedAt'] as String)
          : null,
    );
  }
}
