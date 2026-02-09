import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import '../theme/app-theme.dart';
import '../services/location_stream_manager.dart';
import '../services/location_service.dart';
import '../services/websocket_service.dart';
import '../models/location_update.dart';

/// Debug screen for testing location sharing without backend
class LocationDebugScreen extends StatefulWidget {
  final Function(String) onNavigate;
  final String currentRoute;

  const LocationDebugScreen({
    super.key,
    required this.onNavigate,
    required this.currentRoute,
  });

  @override
  State<LocationDebugScreen> createState() => _LocationDebugScreenState();
}

class _LocationDebugScreenState extends State<LocationDebugScreen> {
  final _manager = LocationStreamManager();
  final _locationService = LocationService();
  final _wsService = WebSocketService();
  
  LocationUpdate? _latestLocation;
  final List<String> _locationLog = [];
  StreamSubscription<LocationUpdate>? _locationSubscription;
  
  bool _isTracking = false;
  int _totalUpdates = 0;
  String _status = 'Ready to test';

  @override
  void initState() {
    super.initState();
    _listenToLocationUpdates();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  void _listenToLocationUpdates() {
    _locationSubscription = _locationService.locationStream.listen((location) {
      setState(() {
        _latestLocation = location;
        _totalUpdates++;
        
        // Add to log (keep last 10)
        final logEntry = '${DateTime.now().toString().substring(11, 19)} | '
            'Lat: ${location.latitude.toStringAsFixed(6)}, '
            'Lng: ${location.longitude.toStringAsFixed(6)}, '
            'Acc: ${location.accuracy?.toStringAsFixed(1)}m';
        
        _locationLog.insert(0, logEntry);
        if (_locationLog.length > 10) {
          _locationLog.removeLast();
        }
      });
    });
  }

  Future<void> _startTracking() async {
    try {
      setState(() {
        _status = 'Starting location tracking...';
      });

      // Request permissions
      await _locationService.requestLocationPermission();
      await _locationService.requestBackgroundLocationPermission();

      // Start tracking
      await _locationService.startTracking();

      setState(() {
        _isTracking = true;
        _status = 'Tracking active - GPS updates every 3s or 5m';
        _totalUpdates = 0;
        _locationLog.clear();
      });

      _showSnackBar('✅ Location tracking started', Colors.green);
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
      _showSnackBar('❌ Error: $e', Colors.red);
    }
  }

  Future<void> _stopTracking() async {
    await _locationService.stopTracking();
    
    setState(() {
      _isTracking = false;
      _status = 'Tracking stopped';
    });

    _showSnackBar('⏹️ Location tracking stopped', Colors.orange);
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _copyLocationJson() {
    if (_latestLocation == null) {
      _showSnackBar('No location data available', Colors.orange);
      return;
    }

    final json = jsonEncode(_latestLocation!.toJson());
    Clipboard.setData(ClipboardData(text: json));
    _showSnackBar('📋 JSON copied to clipboard', Colors.blue);
  }

  void _getCurrentLocation() async {
    setState(() {
      _status = 'Getting current location...';
    });

    final location = await _locationService.getCurrentPosition();
    
    if (location != null) {
      setState(() {
        _latestLocation = location;
        _status = 'Got current location';
      });
      _showSnackBar('✅ Location acquired', Colors.green);
    } else {
      setState(() {
        _status = 'Failed to get location';
      });
      _showSnackBar('❌ Failed to get location', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        backgroundColor: AppTheme.gray900,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.cyan),
          onPressed: () => widget.onNavigate('settings'),
        ),
        title: const Text(
          'Location Debug & Testing',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            _buildStatusCard(),
            
            const SizedBox(height: 16),
            
            // Control Buttons
            _buildControlButtons(),
            
            const SizedBox(height: 24),
            
            // Latest Location Data
            _buildLocationDataCard(),
            
            const SizedBox(height: 24),
            
            // Location Updates Log
            _buildLocationLog(),
            
            const SizedBox(height: 24),
            
            // WebSocket Status
            _buildWebSocketStatus(),
            
            const SizedBox(height: 24),
            
            // Instructions
            _buildInstructions(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.gray900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isTracking ? Colors.green : AppTheme.cyan.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isTracking ? Icons.location_on : Icons.location_off,
                color: _isTracking ? Colors.green : Colors.grey,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isTracking ? 'TRACKING ACTIVE' : 'TRACKING STOPPED',
                      style: TextStyle(
                        color: _isTracking ? Colors.green : Colors.grey,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _status,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          const Divider(color: Colors.white24),
          const SizedBox(height: 8),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Total Updates', _totalUpdates.toString()),
              _buildStatItem('Mode', _locationService.currentMode.name.toUpperCase()),
              _buildStatItem('Queue', _manager.queuedLocationsCount.toString()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.cyan,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildControlButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isTracking ? null : _startTracking,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Tracking'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  disabledBackgroundColor: Colors.green.withOpacity(0.3),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isTracking ? _stopTracking : null,
                icon: const Icon(Icons.stop),
                label: const Text('Stop Tracking'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  disabledBackgroundColor: Colors.red.withOpacity(0.3),
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _getCurrentLocation,
            icon: const Icon(Icons.my_location),
            label: const Text('Get Current Location (One-Time)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.cyan,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationDataCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.gray900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cyan.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Latest Location Data',
                style: TextStyle(
                  color: AppTheme.cyan,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_latestLocation != null)
                IconButton(
                  icon: const Icon(Icons.copy, color: AppTheme.cyan, size: 20),
                  onPressed: _copyLocationJson,
                  tooltip: 'Copy JSON',
                ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          if (_latestLocation == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No location data yet\nStart tracking to see updates',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.gray900),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    jsonEncode(_latestLocation!.toJson()),
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 8),
                  
                  _buildDataRow('Latitude', _latestLocation!.latitude.toStringAsFixed(8)),
                  _buildDataRow('Longitude', _latestLocation!.longitude.toStringAsFixed(8)),
                  _buildDataRow('Accuracy', '${_latestLocation!.accuracy?.toStringAsFixed(1) ?? 'N/A'}m'),
                  _buildDataRow('Speed', '${_latestLocation!.speed?.toStringAsFixed(1) ?? 'N/A'} m/s'),
                  _buildDataRow('Heading', '${_latestLocation!.heading?.toStringAsFixed(1) ?? 'N/A'}°'),
                  _buildDataRow('Altitude', '${_latestLocation!.altitude?.toStringAsFixed(1) ?? 'N/A'}m'),
                  _buildDataRow('Timestamp', _latestLocation!.timestamp.toString().substring(11, 19)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.cyan,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationLog() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.gray900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cyan.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Location Updates Log (Last 10)',
            style: TextStyle(
              color: AppTheme.cyan,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 12),
          
          if (_locationLog.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No updates logged yet',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _locationLog.map((log) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    log,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                )).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWebSocketStatus() {
    final isConnected = _wsService.isConnected;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.gray900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConnected ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isConnected ? Icons.cloud_done : Icons.cloud_off,
            color: isConnected ? Colors.green : Colors.orange,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WebSocket: ${isConnected ? 'CONNECTED' : 'DISCONNECTED'}',
                  style: TextStyle(
                    color: isConnected ? Colors.green : Colors.orange,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isConnected 
                      ? 'Backend receiving location updates'
                      : 'Check console logs - data being captured locally',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.info_outline, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Text(
                'Testing Instructions',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          const Text(
            '1. Click "Start Tracking" to begin GPS updates\n'
            '2. Move around to see location changes\n'
            '3. Check console logs (debug mode enabled)\n'
            '4. Copy JSON to verify format\n'
            '5. Watch mode switch (moving ↔ stationary)\n\n'
            '💡 All location data is logged to console in the exact format that will be sent to backend',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
