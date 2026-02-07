/// Example Usage of Location Tracking System
/// 
/// This file demonstrates how to use the location tracking system
/// in your Flutter application for real-time navigation.

import 'package:flutter/material.dart';
import '../services/location_manager.dart';
import '../services/location_websocket_service.dart';
import '../models/location_data.dart';

/// Example: Start location tracking when user starts navigation
Future<void> startNavigation() async {
  // Start location tracking in navigation mode (high accuracy, frequent updates)
  final started = await LocationManager.startNavigationMode();
  
  if (started) {
    print('Navigation started successfully');
    
    // Listen for navigation updates from backend
    LocationWebSocketService.navigationUpdates.listen((update) {
      print('Turn instruction: ${update.instruction}');
      print('Distance to next turn: ${update.distanceToNextTurn}m');
      print('ETA: ${update.etaSeconds}s');
      
      // Update UI with navigation instructions
      // showNavigationInstruction(update.instruction);
    });
    
    // Listen for connection status changes
    LocationWebSocketService.connectionStatus.listen((isConnected) {
      if (isConnected) {
        print('Backend connected');
      } else {
        print('Backend disconnected - using HTTP fallback');
      }
    });
  } else {
    print('Failed to start navigation - check permissions');
  }
}

/// Example: Stop navigation
Future<void> stopNavigation() async {
  await LocationManager.stop();
  print('Navigation stopped');
  
  // Show statistics
  final stats = LocationManager.statistics;
  print('Total updates sent: ${stats['total_updates_sent']}');
  print('Updates failed: ${stats['updates_failed']}');
  print('Duration: ${stats['tracking_duration_seconds']}s');
}

/// Example: Get current location once (without continuous tracking)
Future<void> getCurrentLocationExample() async {
  final location = await LocationManager.getCurrentLocation();
  
  if (location != null) {
    print('Current location: ${location.latitude}, ${location.longitude}');
    print('Accuracy: ${location.accuracy}m');
  } else {
    print('Unable to get location');
  }
}

/// Example: Simple Flutter widget with location tracking
class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  bool _isTracking = false;
  String _navigationInstruction = 'Waiting for navigation...';
  LocationData? _currentLocation;
  bool _isBackendConnected = false;

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  void _setupListeners() {
    // Listen for navigation updates
    LocationWebSocketService.navigationUpdates.listen((update) {
      setState(() {
        _navigationInstruction = update.instruction ?? 'Continue straight';
      });
    });

    // Listen for connection status
    LocationWebSocketService.connectionStatus.listen((isConnected) {
      setState(() {
        _isBackendConnected = isConnected;
      });
    });
  }

  Future<void> _toggleTracking() async {
    if (_isTracking) {
      await LocationManager.stop();
      setState(() {
        _isTracking = false;
      });
    } else {
      final started = await LocationManager.startNavigationMode();
      setState(() {
        _isTracking = started;
      });
    }
  }

  @override
  void dispose() {
    LocationManager.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Navigation'),
        actions: [
          // Connection status indicator
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Icon(
              _isBackendConnected ? Icons.cloud_done : Icons.cloud_off,
              color: _isBackendConnected ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Navigation instruction
            Text(
              _navigationInstruction,
              style: const TextStyle(fontSize: 24),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            
            // Start/Stop button
            ElevatedButton.icon(
              onPressed: _toggleTracking,
              icon: Icon(_isTracking ? Icons.stop : Icons.navigation),
              label: Text(_isTracking ? 'Stop Navigation' : 'Start Navigation'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
            const SizedBox(height: 20),
            
            // Status
            Text(
              _isTracking ? 'Tracking active' : 'Not tracking',
              style: TextStyle(
                color: _isTracking ? Colors.green : Colors.grey,
              ),
            ),
            
            // Statistics
            if (_isTracking) ...[
              const SizedBox(height: 40),
              Text('Updates sent: ${LocationManager.statistics['total_updates_sent']}'),
              Text('Failed: ${LocationManager.statistics['updates_failed']}'),
              Text('Using: ${LocationManager.statistics['using_websocket'] ? 'WebSocket' : 'HTTP'}'),
            ],
          ],
        ),
      ),
    );
  }
}

/// Example: Quick start in your main.dart or dashboard
/// 
/// ```dart
/// // In your dashboard or main screen
/// ElevatedButton(
///   onPressed: () async {
///     await LocationManager.startNavigationMode();
///   },
///   child: Text('Start Navigation'),
/// ),
/// 
/// ElevatedButton(
///   onPressed: () async {
///     await LocationManager.stop();
///   },
///   child: Text('Stop Navigation'),
/// ),
/// ```
