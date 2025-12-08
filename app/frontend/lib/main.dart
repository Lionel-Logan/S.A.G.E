import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // add http in pubspec if you want network demo

void main() => runApp(const SageApp());

class SageApp extends StatelessWidget {
  const SageApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'S.A.G.E. Frontend',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _counter = 0;
  String _networkResult = 'No result yet';

  void _increment() => setState(() => _counter++);

  Future<void> _fetchSample() async {
    setState(() => _networkResult = 'Loading...');
    try {
      // a tiny public API for testing
      final res = await http.get(Uri.parse('https://api.github.com/zen')).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        setState(() => _networkResult = res.body);
      } else {
        setState(() => _networkResult = 'Status ${res.statusCode}');
      }
    } catch (e) {
      setState(() => _networkResult = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('S.A.G.E. — Demo UI')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Counter', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            Text('$_counter', style: Theme.of(context).textTheme.headlineMedium),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _increment,
                              icon: const Icon(Icons.plus_one),
                              label: const Text('Increment'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.network_wifi),
                        title: const Text('Network test (GitHub Zen)'),
                        subtitle: Text(_networkResult),
                        trailing: ElevatedButton(
                          onPressed: _fetchSample,
                          child: const Text('Fetch'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.navigate_next),
                        title: const Text('Open demo page'),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SecondPage())),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Screen size: ${mq.size.width.toStringAsFixed(0)} × ${mq.size.height.toStringAsFixed(0)}'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SecondPage extends StatelessWidget {
  const SecondPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Details')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 72, color: Colors.green),
            const SizedBox(height: 12),
            Text('Navigation works!', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go back'),
            )
          ],
        ),
      ),
    );
  }
}
