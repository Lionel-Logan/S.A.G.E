import 'package:flutter/material.dart';
import '../theme/app-theme.dart';
import '../widgets/sidebar.dart';
import '../models/person_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../config/backend_config.dart';

class FacialRecognitionSettingsScreen extends StatefulWidget {
  final Function(String) onNavigate;
  final String currentRoute;

  const FacialRecognitionSettingsScreen({
    super.key,
    required this.onNavigate,
    required this.currentRoute,
  });

  @override
  State<FacialRecognitionSettingsScreen> createState() => _FacialRecognitionSettingsScreenState();
}

class _FacialRecognitionSettingsScreenState extends State<FacialRecognitionSettingsScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _urlController = TextEditingController();

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  bool _isLoading = true;
  bool _isSavingUrl = false;
  List<PersonModel> _people = [];
  int? _expandedPersonId;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOut,
      ),
    );

    _loadData();
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _scrollController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Load custom URL
      final savedUrl = await StorageService.getFacialRecognitionUrl();
      if (savedUrl != null && savedUrl.isNotEmpty) {
        _urlController.text = savedUrl;
      } else {
        _urlController.text = BackendConfig.getFacialRecognitionUrl();
      }

      // Fetch folks
      await _fetchPeople();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchPeople() async {
    try {
      final response = await ApiService.fetchPeople();
      final peopleData = response['people'] as List;
      
      setState(() {
        _people = peopleData.map((p) => PersonModel.fromJson(p)).toList();
      });
    } catch (e) {
      print('Fetch people error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not load database. Check URL.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _saveUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty || !url.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a valid HTTP/HTTPS URL'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSavingUrl = true);
    
    try {
      await StorageService.saveFacialRecognitionUrl(url);
      BackendConfig.customFacialRecognitionUrl = url;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('URL Saved Successfully'),
          backgroundColor: Colors.greenAccent,
        ),
      );

      // Refresh database using new URL
      await _fetchPeople();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save URL: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingUrl = false);
      }
    }
  }

  Future<void> _handleDelete(PersonModel person) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
        ),
        title: Text(
          'Delete Person',
          style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete "${person.name}" from the database?',
          style: TextStyle(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('CANCEL', style: TextStyle(color: AppTheme.gray500)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('DELETE', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await ApiService.deletePerson(person.id);
        setState(() {
          _people.removeWhere((p) => p.id == person.id);
          if (_expandedPersonId == person.id) {
            _expandedPersonId = null;
          }
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted "${person.name}"'),
              backgroundColor: Colors.greenAccent,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _handleEdit(PersonModel person) async {
    final nameController = TextEditingController(text: person.name);
    final descController = TextEditingController(text: person.description);

    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.cyan.withOpacity(0.5)),
        ),
        title: Text(
          'Edit Person',
          style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: TextStyle(color: AppTheme.white),
                decoration: InputDecoration(
                  labelText: 'Name',
                  labelStyle: TextStyle(color: AppTheme.cyan),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.gray500),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.cyan),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                style: TextStyle(color: AppTheme.white),
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description',
                  labelStyle: TextStyle(color: AppTheme.cyan),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.gray500),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.cyan),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text('CANCEL', style: TextStyle(color: AppTheme.gray500)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, {
                'name': nameController.text.trim(),
                'description': descController.text.trim(),
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.cyan,
              foregroundColor: AppTheme.black,
            ),
            child: const Text('SAVE'),
          ),
        ],
      ),
    );

    if (result != null) {
      final newName = result['name'] ?? person.name;
      final newDesc = result['description'] ?? person.description;

      if (newName.isEmpty) return;

      setState(() => _isLoading = true);
      try {
        await ApiService.updatePerson(
          id: person.id,
          name: newName,
          description: newDesc,
        );
        
        // Update locally without full refetch
        setState(() {
          final idx = _people.indexWhere((p) => p.id == person.id);
          if (idx != -1) {
            _people[idx] = PersonModel(
              id: person.id,
              name: newName,
              description: newDesc,
            );
          }
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Update successful'),
              backgroundColor: Colors.greenAccent,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Widget _buildDatabaseRow(PersonModel person) {
    final isExpanded = _expandedPersonId == person.id;

    return Card(
      color: AppTheme.black,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isExpanded ? AppTheme.cyan : AppTheme.gray800,
          width: isExpanded ? 2.0 : 1.0,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            onTap: () {
              setState(() {
                _expandedPersonId = isExpanded ? null : person.id;
              });
            },
            title: Text(
              person.name,
              style: TextStyle(
                color: AppTheme.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: AppTheme.cyan, size: 20),
                  onPressed: () => _handleEdit(person),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  onPressed: () => _handleDelete(person),
                ),
                Icon(
                  isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: AppTheme.gray500,
                ),
              ],
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  person.description,
                  style: TextStyle(
                    color: Colors.grey[300],
                    height: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new, color: AppTheme.cyan),
                    onPressed: () => widget.onNavigate('settings'),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Facial Recognition',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _isLoading && _people.isEmpty
                  ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.cyan),
                      ),
                    )
                  : FadeTransition(
                      opacity: _fadeAnimation,
                      child: ListView(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        children: [
                          // Network Settings Section
                          Text(
                            'SERVER CONNECTION',
                            style: TextStyle(
                              color: AppTheme.gray500,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.gray900,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.gray800),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: _urlController,
                                  style: TextStyle(color: AppTheme.white),
                                  decoration: InputDecoration(
                                    labelText: 'Facial Recognition URL',
                                    labelStyle: TextStyle(color: AppTheme.cyan),
                                    enabledBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(color: AppTheme.gray500),
                                    ),
                                    focusedBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(color: AppTheme.cyan),
                                    ),
                                    suffixIcon: Icon(Icons.link, color: AppTheme.gray500),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _isSavingUrl ? null : _saveUrl,
                                    icon: _isSavingUrl
                                        ? SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppTheme.black,
                                            ),
                                          )
                                        : const Icon(Icons.save),
                                    label: const Text('SAVE & CONNECT'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.cyan,
                                      foregroundColor: AppTheme.black,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 32),

                          // Database Management Section
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'MANAGE DATABASE',
                                style: TextStyle(
                                  color: AppTheme.gray500,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                              if (_isLoading)
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.cyan,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          if (_people.isEmpty && !_isLoading)
                            Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppTheme.gray800, style: BorderStyle.solid),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: Text(
                                  'Database is empty or connection failed.',
                                  style: TextStyle(color: AppTheme.gray500),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          else
                            ..._people.map((p) => _buildDatabaseRow(p)),

                          const SizedBox(height: 48),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
