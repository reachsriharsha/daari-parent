import 'package:flutter/material.dart';
import 'select_contacts_page.dart';
import 'services/group_service.dart';
import 'group_details_page.dart';
import 'main.dart'; // To access storageService
import 'widgets/status_widget.dart';
import 'screens/log_viewer_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? profId;
  String? backendUrl;
  List<Map<String, dynamic>> groups = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _fetchGroups();
  }

  Future<void> _loadData() async {
    final id = storageService.getProfId();
    final url = storageService.getNgrokUrl(); // Read from Hive instead
    setState(() {
      profId = id;
      backendUrl = url;
    });
  }

  Future<void> _fetchGroups() async {
    final fetchedGroups = await GroupService.getLocalGroups();
    setState(() {
      groups = fetchedGroups;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create Group',
            onPressed: () async {
              await showDialog(
                context: context,
                builder: (context) =>
                    CreateGroupDialog(onGroupCreated: _fetchGroups),
              );
              await _fetchGroups();
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'More options',
            onSelected: (value) {
              if (value == 'debug_logs') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LogViewerScreen(),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'debug_logs',
                child: Row(
                  children: [
                    Icon(Icons.bug_report, size: 20),
                    SizedBox(width: 12),
                    Text('Debug Logs'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: profId == null
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16.0,
                      horizontal: 0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            'Groups',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: groups.isEmpty
                              ? const Center(child: Text("No groups found"))
                              : ListView.builder(
                                  itemCount: groups.length,
                                  itemBuilder: (context, index) {
                                    final group = groups[index];
                                    return Card(
                                      margin: const EdgeInsets.symmetric(
                                        vertical: 8,
                                        horizontal: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 2,
                                      color: Colors.purple[50],
                                      child: ExpansionTile(
                                        leading: CircleAvatar(
                                          backgroundColor: Colors.grey[300],
                                          child: Icon(
                                            Icons.group,
                                            color: Colors.deepPurple,
                                          ),
                                        ),
                                        title: Text(
                                          group["name"] ?? "",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                        subtitle: Text(
                                          'Members: ${group["member_list"] != null ? (group["member_list"] as List).length.toString() : "N/A"}',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16.0,
                                              vertical: 8.0,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    const Text(
                                                      'Group ID: ',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    Text(
                                                      group["id"].toString(),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                if (group["dest_coordinates"] !=
                                                    null)
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      const Text(
                                                        'Destination:',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      if (group["place_name"] !=
                                                          null)
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets.only(
                                                                bottom: 4,
                                                              ),
                                                          child: Text(
                                                            '📍 ${group["place_name"]}',
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 14,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                          ),
                                                        ),
                                                      if (group["address"] !=
                                                          null)
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets.only(
                                                                bottom: 4,
                                                              ),
                                                          child: Text(
                                                            group["address"],
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              color: Colors
                                                                  .grey[700],
                                                            ),
                                                          ),
                                                        ),
                                                      Text(
                                                        'Lat: ${group["dest_coordinates"]["latitude"]?.toStringAsFixed(6) ?? "N/A"}',
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                      Text(
                                                        'Long: ${group["dest_coordinates"]["longitude"]?.toStringAsFixed(6) ?? "N/A"}',
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                              ],
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              // Extract destination coordinates if they exist
                                              double? destLat;
                                              double? destLng;
                                              if (group["dest_coordinates"] !=
                                                  null) {
                                                destLat =
                                                    group["dest_coordinates"]["latitude"];
                                                destLng =
                                                    group["dest_coordinates"]["longitude"];
                                              }

                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      GroupDetailsPage(
                                                        groupName:
                                                            group["name"],
                                                        groupId: group["id"],
                                                        destinationLatitude:
                                                            destLat,
                                                        destinationLongitude:
                                                            destLng,
                                                      ),
                                                ),
                                              );
                                            },
                                            child: const Text('View Details'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
          ),
          const CustomStatusWidget(),
        ],
      ),
    );
  }
}

class CreateGroupDialog extends StatefulWidget {
  final VoidCallback? onGroupCreated;
  const CreateGroupDialog({super.key, this.onGroupCreated});

  @override
  State<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  final TextEditingController groupNameController = TextEditingController();
  final TextEditingController membersController = TextEditingController();
  bool loading = false;

  Future<void> _createGroup() async {
    final groupName = groupNameController.text.trim();
    final membersText = membersController.text.trim();

    if (groupName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Group name is required")));
      return;
    }

    try {
      setState(() => loading = true);

      // Members as list of strings
      List<String> members = [];
      if (membersText.isNotEmpty) {
        members = membersText.split(",").map((m) => m.trim()).toList();
      }

      // Get ngrok_url for backend
      final backendUrl =
          storageService.getNgrokUrl() ?? ""; // Read from Hive instead
      final groupService = GroupService(baseUrl: backendUrl);
      final response = await groupService.createGroup(groupName, members);

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Backend Response: ${response.toString()}"),
            duration: Duration(seconds: 3),
          ),
        );
        widget.onGroupCreated?.call();
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("[ERROR] Exception: $e")));
      }
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Group'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: groupNameController,
              decoration: const InputDecoration(labelText: 'Group Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: membersController,
              decoration: const InputDecoration(
                labelText: 'Members (comma separated)',
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.contacts),
              label: const Text('Pick from Contacts'),
              onPressed: () async {
                // Open contact picker and fill membersController
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => SelectContactsPage(
                      onMembersSelected: (phones) {
                        membersController.text = phones.join(", ");
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: loading ? null : _createGroup,
          child: loading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}
