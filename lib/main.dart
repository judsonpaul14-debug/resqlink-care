import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

void main() {
  runApp(const ResQLinkApp());
}

class ResQLinkApp extends StatelessWidget {
  const ResQLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ResQLink Care',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF176B87),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F8FA),
      ),
      home: const HomePage(),
    );
  }
}

class HelpRequest {
  final String id;
  final String need;
  final String urgency;
  final String description;
  final String location;
  final bool accessibilityRequired;
  final String status;
  final DateTime createdAt;

  HelpRequest({
    required this.id,
    required this.need,
    required this.urgency,
    required this.description,
    required this.location,
    required this.accessibilityRequired,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'need': need,
      'urgency': urgency,
      'description': description,
      'location': location,
      'accessibilityRequired': accessibilityRequired,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory HelpRequest.fromJson(Map<String, dynamic> json) {
    return HelpRequest(
      id: json['id'] as String,
      need: json['need'] as String,
      urgency: json['urgency'] as String,
      description: json['description'] as String,
      location: json['location'] as String,
      accessibilityRequired: json['accessibilityRequired'] as bool,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  HelpRequest copyWith({
    String? status,
  }) {
    return HelpRequest(
      id: id,
      need: need,
      urgency: urgency,
      description: description,
      location: location,
      accessibilityRequired: accessibilityRequired,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}

class LocalRequestStore {
  static const String storageKey = 'help_requests';

  Future<List<HelpRequest>> loadRequests() async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString(storageKey);

    if (savedData == null) return [];

    final List<dynamic> decoded = jsonDecode(savedData);

    return decoded
        .map(
          (item) => HelpRequest.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<void> saveRequest(HelpRequest request) async {
    final requests = await loadRequests();
    requests.insert(0, request);

    await _saveAll(requests);
  }

  Future<void> updateRequestStatus(
    String requestId,
    String newStatus,
  ) async {
    final requests = await loadRequests();

    final updatedRequests = requests.map((request) {
      if (request.id == requestId) {
        return request.copyWith(status: newStatus);
      }

      return request;
    }).toList();

    await _saveAll(updatedRequests);
  }

  Future<void> _saveAll(List<HelpRequest> requests) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      storageKey,
      jsonEncode(
        requests.map((request) => request.toJson()).toList(),
      ),
    );
  }

  Future<void> clearRequests() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final LocalRequestStore store = LocalRequestStore();

  List<HelpRequest> requests = [];
  bool isLoading = true;
  int selectedIndex = 0;

  final List<Map<String, dynamic>> resources = [
    {
      'name': 'Cape Breton Community Shelter',
      'type': 'Accessible shelter',
      'status': 'Open',
      'distance': '2.4 km',
      'color': Colors.green,
    },
    {
      'name': 'Harbour Pharmacy',
      'type': 'Medication and first aid',
      'status': 'Open',
      'distance': '3.1 km',
      'color': Colors.blue,
    },
    {
      'name': 'North Bridge',
      'type': 'Road',
      'status': 'Blocked',
      'distance': '1.8 km',
      'color': Colors.red,
    },
    {
      'name': 'Community Charging Point',
      'type': 'Power support',
      'status': 'Available',
      'distance': '4.0 km',
      'color': Colors.orange,
    },
  ];

  @override
  void initState() {
    super.initState();
    loadSavedRequests();
  }

  Future<void> loadSavedRequests() async {
    final savedRequests = await store.loadRequests();

    if (!mounted) return;

    setState(() {
      requests = savedRequests;
      isLoading = false;
    });
  }

  Future<void> openRequestForm() async {
    final newRequest = await Navigator.push<HelpRequest>(
      context,
      MaterialPageRoute(
        builder: (_) => const RequestHelpPage(),
      ),
    );

    if (newRequest == null) return;

    await store.saveRequest(newRequest);
    await loadSavedRequests();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Request saved offline. It will sync when connection returns.',
        ),
      ),
    );
  }

  Future<void> showRequestDetails(HelpRequest request) async {
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(request.need),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                detailRow('Status', request.status),
                detailRow('Urgency', request.urgency),
                detailRow('Location', request.location),
                detailRow(
                  'Accessibility',
                  request.accessibilityRequired
                      ? 'Required'
                      : 'Not required',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Description',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(request.description),
              ],
            ),
          ),
          actions: [
            if (request.status != 'Assigned' &&
                request.status != 'Completed')
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, 'Assigned');
                },
                child: const Text('Assign volunteer'),
              ),
            if (request.status == 'Assigned')
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext, 'Completed');
                },
                child: const Text('Mark completed'),
              ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );

    if (result == null) return;

    await store.updateRequestStatus(request.id, result);
    await loadSavedRequests();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Request status updated to $result'),
      ),
    );
  }

  Widget detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ResQLink Care',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Offline status',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Offline mode is active for this prototype.',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.cloud_off),
          ),
        ],
      ),
      body: IndexedStack(
        index: selectedIndex,
        children: [
          buildHomeTab(),
          buildRequestsTab(),
          buildResourcesTab(),
        ],
      ),
      floatingActionButton: selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: openRequestForm,
              icon: const Icon(Icons.add_alert),
              label: const Text('Request help'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Requests',
          ),
          NavigationDestination(
            icon: Icon(Icons.location_on_outlined),
            selectedIcon: Icon(Icons.location_on),
            label: 'Resources',
          ),
        ],
      ),
    );
  }

  Widget buildHomeTab() {
    return RefreshIndicator(
      onRefresh: loadSavedRequests,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          buildEmergencyBanner(),
          const SizedBox(height: 16),
          buildStatusCard(),
          const SizedBox(height: 20),
          const Text(
            'Quick actions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: quickAction(
                  icon: Icons.medical_services,
                  title: 'Medicine',
                  color: Colors.red,
                  onTap: openRequestForm,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: quickAction(
                  icon: Icons.directions_car,
                  title: 'Transport',
                  color: Colors.blue,
                  onTap: openRequestForm,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: quickAction(
                  icon: Icons.accessible,
                  title: 'Accessibility',
                  color: Colors.purple,
                  onTap: openRequestForm,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Emergency overview',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          buildOverviewCard(),
          const SizedBox(height: 24),
          const Text(
            'Recent requests',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else if (requests.isEmpty)
            buildEmptyRequests()
          else
            ...requests.take(3).map(buildRequestCard),
        ],
      ),
    );
  }

  Widget buildEmergencyBanner() {
    return Card(
      color: const Color(0xFFE6F4F1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFF176B87),
              child: Icon(
                Icons.shield,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'You are viewing a prototype area',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Use verified local information during a real emergency.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.warning_amber,
                  color: Colors.orange,
                ),
                SizedBox(width: 8),
                Text(
                  'Community status',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            statusRow('Flood risk', 'Moderate', Colors.orange),
            statusRow('Power', 'Partial outage', Colors.orange),
            statusRow('Main bridge', 'Blocked', Colors.red),
            statusRow('Shelter', 'Open', Colors.green),
          ],
        ),
      ),
    );
  }

  Widget statusRow(String title, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(title)),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildOverviewCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            overviewItem(
              '${requests.length}',
              'Your requests',
              Icons.assignment,
            ),
            overviewItem(
              '4',
              'Open resources',
              Icons.home_work,
            ),
            overviewItem(
              '2',
              'Road warnings',
              Icons.warning,
            ),
          ],
        ),
      ),
    );
  }

  Widget overviewItem(
    String value,
    String label,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          color: const Color(0xFF176B87),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget quickAction({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            children: [
              Icon(
                icon,
                color: color,
                size: 30,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildRequestsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'My help requests',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (requests.isEmpty)
          buildEmptyRequests()
        else
          ...requests.map(buildRequestCard),
      ],
    );
  }

  Widget buildResourcesTab() {
    const mapCenter = LatLng(46.1382, -60.1790);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Emergency resources',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Demo map for the selected emergency area.',
              ),
            ],
          ),
        ),
        Expanded(
          child: FlutterMap(
            options: const MapOptions(
              initialCenter: mapCenter,
              initialZoom: 12,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.resqlink.care',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: const LatLng(46.1382, -60.1790),
                    width: 55,
                    height: 55,
                    child: const Icon(
                      Icons.home_work,
                      color: Colors.green,
                      size: 38,
                    ),
                  ),
                  Marker(
                    point: const LatLng(46.1250, -60.1900),
                    width: 55,
                    height: 55,
                    child: const Icon(
                      Icons.local_pharmacy,
                      color: Colors.blue,
                      size: 38,
                    ),
                  ),
                  Marker(
                    point: const LatLng(46.1480, -60.1650),
                    width: 55,
                    height: 55,
                    child: const Icon(
                      Icons.block,
                      color: Colors.red,
                      size: 38,
                    ),
                  ),
                  Marker(
                    point: const LatLng(46.1300, -60.1600),
                    width: 55,
                    height: 55,
                    child: const Icon(
                      Icons.electric_bolt,
                      color: Colors.orange,
                      size: 38,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildRequestCard(HelpRequest request) {
    final bool isHighUrgency = request.urgency == 'High';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isHighUrgency
              ? Colors.red.shade100
              : Colors.orange.shade100,
          child: Icon(
            Icons.volunteer_activism,
            color: isHighUrgency ? Colors.red : Colors.orange,
          ),
        ),
        title: Text(
          request.need,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${request.location}\n${request.status} • ${request.urgency} urgency',
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => showRequestDetails(request),
      ),
    );
  }

  Widget buildEmptyRequests() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: const [
            Icon(
              Icons.assignment_turned_in,
              size: 50,
              color: Colors.grey,
            ),
            SizedBox(height: 10),
            Text(
              'No requests yet',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 5),
            Text(
              'Create a request when you need community support.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class RequestHelpPage extends StatefulWidget {
  const RequestHelpPage({super.key});

  @override
  State<RequestHelpPage> createState() => _RequestHelpPageState();
}

class _RequestHelpPageState extends State<RequestHelpPage> {
  final formKey = GlobalKey<FormState>();
  final descriptionController = TextEditingController();
  final locationController = TextEditingController(
    text: 'Cape Breton test area',
  );

  String selectedNeed = 'Medication';
  String selectedUrgency = 'High';
  bool accessibilityRequired = false;

  final List<String> needs = [
    'Medication',
    'Food or water',
    'Transport',
    'Welfare check',
    'Accessible shelter',
    'Charging support',
  ];

  @override
  void dispose() {
    descriptionController.dispose();
    locationController.dispose();
    super.dispose();
  }

  void submitRequest() {
    if (!formKey.currentState!.validate()) return;

    final request = HelpRequest(
      id: const Uuid().v4(),
      need: selectedNeed,
      urgency: selectedUrgency,
      description: descriptionController.text.trim(),
      location: locationController.text.trim(),
      accessibilityRequired: accessibilityRequired,
      status: 'Waiting for sync',
      createdAt: DateTime.now(),
    );

    Navigator.pop(context, request);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request help'),
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Tell us what support is needed',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This prototype saves your request on the device first.',
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: selectedNeed,
              decoration: const InputDecoration(
                labelText: 'Type of help',
                border: OutlineInputBorder(),
              ),
              items: needs
                  .map(
                    (need) => DropdownMenuItem(
                      value: need,
                      child: Text(need),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedNeed = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: selectedUrgency,
              decoration: const InputDecoration(
                labelText: 'Urgency',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Low',
                  child: Text('Low'),
                ),
                DropdownMenuItem(
                  value: 'Medium',
                  child: Text('Medium'),
                ),
                DropdownMenuItem(
                  value: 'High',
                  child: Text('High'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedUrgency = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: locationController,
              decoration: const InputDecoration(
                labelText: 'Location or area',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter an area';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Describe the need',
                hintText: 'Example: Insulin needed within two hours',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Describe the need';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Accessibility support required'),
              subtitle: const Text(
                'Wheelchair, mobility, visual, or other support',
              ),
              value: accessibilityRequired,
              onChanged: (value) {
                setState(() {
                  accessibilityRequired = value;
                });
              },
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: submitRequest,
              icon: const Icon(Icons.save),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('Save help request'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}