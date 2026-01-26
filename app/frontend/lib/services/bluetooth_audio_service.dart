import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/bluetooth_audio_device.dart';
import '../models/bluetooth_pairing_status.dart';

/// Service for managing Bluetooth audio devices via Pi server
class BluetoothAudioService {
  static const String defaultPiHost = 'sage-pi.local';
  static const int piPort = 8001;
  static const Duration timeout = Duration(seconds: 70); // Increased for pairing
  
  static StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  static String? _lastNetworkId;
  static bool _isDiscovering = false;
  static String? _cachedPiServerUrl;
  static DateTime? _cacheTimestamp;

  /// Initialize network monitoring for auto-discovery
  static void startNetworkMonitoring() {
    _connectivitySubscription?.cancel();
    
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) async {
      // Only trigger on WiFi connections
      if (result.contains(ConnectivityResult.wifi)) {
        // Get current network identifier (SSID or IP subnet)
        final networkInfo = NetworkInfo();
        final wifiIP = await networkInfo.getWifiIP();
        
        if (wifiIP != null) {
          final parts = wifiIP.split('.');
          final networkId = parts.length >= 3 ? '${parts[0]}.${parts[1]}.${parts[2]}' : wifiIP;
          
          // Check if network changed
          if (_lastNetworkId != networkId && !_isDiscovering) {
            print('Network changed to: $networkId - triggering auto-discovery');
            _lastNetworkId = networkId;
            
            // Trigger discovery in background
            _isDiscovering = true;
            final discovered = await discoverPiServer();
            _isDiscovering = false;
            
            if (discovered != null) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('pi_server_host', discovered);
              print('Auto-discovered Pi on new network: $discovered');
            }
          }
        }
      }
    });
    
    // Initialize last network
    _initializeLastNetwork();
  }
  
  /// Stop network monitoring
  static void stopNetworkMonitoring() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }
  
  static Future<void> _initializeLastNetwork() async {
    final networkInfo = NetworkInfo();
    final wifiIP = await networkInfo.getWifiIP();
    if (wifiIP != null) {
      final parts = wifiIP.split('.');
      _lastNetworkId = parts.length >= 3 ? '${parts[0]}.${parts[1]}.${parts[2]}' : wifiIP;
    }
  }

  /// Discover Pi server on local network
  static Future<String?> discoverPiServer() async {
    try {
      // Get WiFi IP address
      final networkInfo = NetworkInfo();
      final wifiIP = await networkInfo.getWifiIP();
      
      if (wifiIP == null) return null;
      
      // Extract network prefix (e.g., "192.168.1" from "192.168.1.105")
      final parts = wifiIP.split('.');
      if (parts.length != 4) return null;
      
      final networkPrefix = '${parts[0]}.${parts[1]}.${parts[2]}';
      
      print('Scanning network $networkPrefix.0/24 for Pi server...');
      
      // Try common addresses first (router typically assigns low IPs to static devices)
      final priorityHosts = [
        '$networkPrefix.110', // Common Pi address
        '$networkPrefix.100',
        '$networkPrefix.2',
        '$networkPrefix.10',
      ];
      
      for (final host in priorityHosts) {
        if (await _checkPiServer(host)) {
          print('Found Pi server at: $host');
          return host;
        }
      }
      
      // If not found in priority list, scan range 1-254 (in parallel batches)
      final futures = <Future<String?>>[];
      for (int i = 1; i <= 254; i++) {
        final host = '$networkPrefix.$i';
        if (!priorityHosts.contains(host)) {
          futures.add(_checkPiServer(host).then((found) => found ? host : null));
        }
        
        // Process in batches of 50 to avoid overwhelming
        if (futures.length >= 50) {
          final results = await Future.wait(futures);
          final found = results.firstWhere((h) => h != null, orElse: () => null);
          if (found != null) {
            print('Found Pi server at: $found');
            return found;
          }
          futures.clear();
        }
      }
      
      // Check remaining
      if (futures.isNotEmpty) {
        final results = await Future.wait(futures);
        final found = results.firstWhere((h) => h != null, orElse: () => null);
        if (found != null) {
          print('Found Pi server at: $found');
          return found;
        }
      }
      
      return null;
    } catch (e) {
      print('Error discovering Pi server: $e');
      return null;
    }
  }
  
  /// Check if a host is the Pi server
  static Future<bool> _checkPiServer(String host) async {
    try {
      final socket = await Socket.connect(
        host,
        piPort,
        timeout: const Duration(milliseconds: 500),
      );
      socket.destroy();
      
      // Verify it's our server by checking /ping
      try {
        final response = await http.get(
          Uri.parse('http://$host:$piPort/ping'),
        ).timeout(const Duration(seconds: 1));
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return data['service']?.toString().contains('SAGE') ?? false;
        }
      } catch (_) {}
      
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Get the configured Pi server URL (with auto-discovery)
  static Future<String> _getPiServerUrl() async {
    // Use cached URL if recent (within 5 minutes)
    if (_cachedPiServerUrl != null && _cacheTimestamp != null) {
      final age = DateTime.now().difference(_cacheTimestamp!);
      if (age.inMinutes < 5) {
        return _cachedPiServerUrl!;
      }
    }
    
    final prefs = await SharedPreferences.getInstance();
    String? host = prefs.getString('pi_server_host');
    
    // If no custom host set, use saved or default
    if (host == null || host.isEmpty) {
      host = defaultPiHost;
    }
    
    final url = 'http://$host:$piPort';
    _cachedPiServerUrl = url;
    _cacheTimestamp = DateTime.now();
    
    return url;
  }
  
  /// Clear cached Pi server URL (forces re-discovery on next call)
  static void clearCache() {
    _cachedPiServerUrl = null;
    _cacheTimestamp = null;
  }
  
  /// Check if Pi server is reachable
  static Future<bool> isPiServerReachable() async {
    try {
      final piServerUrl = await _getPiServerUrl();
      final response = await http.get(
        Uri.parse('$piServerUrl/ping'),
      ).timeout(const Duration(seconds: 3));
      
      return response.statusCode == 200;
    } catch (e) {
      print('Pi server not reachable: $e');
      return false;
    }
  }
  
  /// Set custom Pi server host (IP address or hostname)
  static Future<void> setPiServerHost(String host) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pi_server_host', host);
    clearCache(); // Force using new host
  }
  
  /// Get current Pi server host
  static Future<String> getPiServerHost() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('pi_server_host') ?? defaultPiHost;
  }
  
  /// Reset to default host
  static Future<void> resetPiServerHost() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pi_server_host');
    clearCache();
  }

  /// Scan for Bluetooth devices (SSE stream - continuous until stopped)
  static Stream<BluetoothAudioDevice> scanDevices() async* {
    // Check connectivity first
    final connectivity = await Connectivity().checkConnectivity();
    if (!connectivity.contains(ConnectivityResult.wifi)) {
      throw Exception('No WiFi connection. Please connect to WiFi.');
    }
    
    // Check if Pi server is reachable
    final reachable = await isPiServerReachable();
    if (!reachable) {
      throw Exception('Cannot reach Pi server. Check Pi server address in settings.');
    }
    
    try {
      final piServerUrl = await _getPiServerUrl();
      final url = Uri.parse('$piServerUrl/bluetooth/scan');
      final request = http.Request('GET', url);

      final response = await request.send();

      if (response.statusCode != 200) {
        throw Exception('Scan failed with status: ${response.statusCode}');
      }

      // Parse SSE stream
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        final lines = chunk.split('\n');
        
        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final jsonStr = line.substring(6); // Remove 'data: ' prefix
            try {
              final data = json.decode(jsonStr);
              
              // Check for error
              if (data.containsKey('error')) {
                throw Exception(data['error']);
              }
              
              yield BluetoothAudioDevice.fromJson(data);
            } catch (e) {
              print('Error parsing device data: $e');
            }
          }
        }
      }
    } catch (e) {
      print('Scan error: $e');
      rethrow;
    }
  }

  /// Stop the current Bluetooth scan
  static Future<bool> stopScan() async {
    try {
      final piServerUrl = await _getPiServerUrl();
      final response = await http.post(
        Uri.parse('$piServerUrl/bluetooth/scan/stop'),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] ?? false;
      }
      return false;
    } catch (e) {
      print('Stop scan error: $e');
      return false;
    }
  }

  /// Pair with a Bluetooth device (SSE stream of progress)
  static Stream<BluetoothPairingState> pairDevice({
    required String mac,
    required String name,
  }) async* {
    // Check connectivity first
    final connectivity = await Connectivity().checkConnectivity();
    if (!connectivity.contains(ConnectivityResult.wifi)) {
      yield BluetoothPairingState(
        status: BluetoothPairingStatus.failed,
        progress: 0,
        message: 'No WiFi connection. Please connect to WiFi.',
        timestamp: DateTime.now().toIso8601String(),
      );
      return;
    }
    
    // Check if Pi server is reachable
    final reachable = await isPiServerReachable();
    if (!reachable) {
      yield BluetoothPairingState(
        status: BluetoothPairingStatus.failed,
        progress: 0,
        message: 'Cannot reach Pi server. Check Pi server address in settings.',
        timestamp: DateTime.now().toIso8601String(),
      );
      return;
    }
    
    try {
      final piServerUrl = await _getPiServerUrl();
      final url = Uri.parse('$piServerUrl/bluetooth/pair');
      final client = http.Client();

      final request = http.Request('POST', url)
        ..headers['Content-Type'] = 'application/json'
        ..body = json.encode({
          'mac': mac,
          'name': name,
        });

      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Pairing failed with status: ${response.statusCode}');
      }

      // Parse SSE stream
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        final lines = chunk.split('\n');
        
        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final jsonStr = line.substring(6);
            try {
              final data = json.decode(jsonStr);
              yield BluetoothPairingState.fromJson(data);
            } catch (e) {
              print('Error parsing pairing status: $e');
            }
          }
        }
      }

      client.close();
    } catch (e) {
      print('Pairing error: $e');
      // Yield failed status
      yield BluetoothPairingState(
        status: BluetoothPairingStatus.failed,
        progress: 0,
        message: 'Error: $e',
        timestamp: DateTime.now().toIso8601String(),
      );
    }
  }

  /// Disconnect a Bluetooth device
  static Future<Map<String, dynamic>> disconnectDevice(String mac) async {
    try {
      final piServerUrl = await _getPiServerUrl();
      final response = await http.post(
        Uri.parse('$piServerUrl/bluetooth/disconnect'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'mac': mac}),
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Disconnect failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error disconnecting device: $e');
    }
  }

  /// Get current Bluetooth status
  static Future<Map<String, dynamic>> getStatus() async {
    try {
      final piServerUrl = await _getPiServerUrl();
      final response = await http.get(
        Uri.parse('$piServerUrl/bluetooth/status'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Status check failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting status: $e');
    }
  }
}
