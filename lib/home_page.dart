import 'package:flutter/material.dart';
import 'select_contacts_page.dart';
import 'services/group_service.dart';
import 'services/backend_com_service.dart';
import 'services/diagnostic_service.dart';
import 'group_details_page.dart';
import 'main.dart'; // To access storageService
import 'models/group_member_input.dart';
import 'widgets/status_widget.dart';
import 'screens/log_viewer_screen.dart';
import 'login_page.dart';

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

  /// Handle diagnostic upload
  Future<void> _handleDiagnosticsUpload() async {
    try {
      // Show loading dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Preparing diagnostics...'),
              ],
            ),
          ),
        );
      }

      // Create diagnostics ZIP
      final zipFile = await DiagnosticService.createDiagnosticsZip();

      // Update loading message
      if (mounted) {
        Navigator.pop(context);
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Uploading diagnostics...'),
              ],
            ),
          ),
        );
      }

      try {
        // Upload to backend
        await BackendComService.instance.uploadDiagnostics(zipFile);

        // Close loading dialog
        if (mounted) {
          Navigator.pop(context);
        }
      } finally {
        // Always delete the temporary ZIP file (even on upload failure)
        try {
          await zipFile.delete();
        } catch (e) {
          // Ignore deletion errors
        }
      }
    } catch (e) {
      // Close loading dialog on error
      if (mounted) {
        Navigator.pop(context);
      }
      showMessageInStatus("error", "Failed to upload diagnostics: $e");
    }
  }

  /// Handle logout action
  Future<void> _handleLogout() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Clear session data
      await storageService.clearSession();

      showMessageInStatus("success", "Logged out successfully");

      // Navigate to login page and clear navigation stack
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false, // Remove all previous routes
        );
      }
    }
  }

  void _showSettingsDialog() {
    final TextEditingController urlController = TextEditingController(
      text: storageService.getNgrokUrl() ?? "",
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'Backend URL',
                hintText: 'http://... or https://...',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _handleDiagnosticsUpload();
                },
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload Diagnostics'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final url = urlController.text.trim();
              if (url.isEmpty) {
                showMessageInStatus("error", "URL cannot be empty");
                return;
              }
              if (!url.startsWith('http://') && !url.startsWith('https://')) {
                showMessageInStatus(
                  "error",
                  "URL must start with http:// or https://",
                );
                return;
              }

              await storageService.saveNgrokUrl(url);
              BackendComService.instance.setBaseUrl(url);

              // Update local state if needed
              setState(() {
                backendUrl = url;
              });

              if (context.mounted) {
                Navigator.pop(context);
                showMessageInStatus("success", "Settings saved successfully");
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
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
              } else if (value == 'settings') {
                _showSettingsDialog();
              } else if (value == 'logout') {
                _handleLogout();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 20),
                    SizedBox(width: 12),
                    Text('Settings'),
                  ],
                ),
              ),
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
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 12),
                    Text('Logout'),
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
                              : Scrollbar(
                                  thumbVisibility: true,
                                  child: ListView.builder(
                                    itemCount: groups.length,
                                    itemBuilder: (context, index) {
                                      final group = groups[index];

                                      // Extract destination coordinates if they exist
                                      double? destLat;
                                      double? destLng;
                                      if (group["dest_coordinates"] != null) {
                                        destLat =
                                            group["dest_coordinates"]["latitude"];
                                        destLng =
                                            group["dest_coordinates"]["longitude"];
                                      }

                                      // Extract member phone numbers
                                      List<String> members = [];
                                      if (group["member_phone_numbers"] !=
                                          null) {
                                        members = List<String>.from(
                                          group["member_phone_numbers"],
                                        );
                                      }

                                      // Extract admin and driver phone numbers
                                      final adminPhone =
                                          group["admin_phone_number"]
                                              as String?;
                                      final driverPhone =
                                          group["driver_phone_number"]
                                              as String?;

                                      return Card(
                                        margin: const EdgeInsets.symmetric(
                                          vertical: 8,
                                          horizontal: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        elevation: 2,
                                        color: Colors.purple[50],
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    GroupDetailsPage(
                                                      groupName: group["name"],
                                                      groupId: group["id"],
                                                      destinationLatitude:
                                                          destLat,
                                                      destinationLongitude:
                                                          destLng,
                                                      placeName:
                                                          group["place_name"],
                                                      address: group["address"],
                                                      isAdmin:
                                                          group["is_admin"] ??
                                                          false,
                                                      memberPhoneNumbers:
                                                          members,
                                                      adminPhoneNumber:
                                                          adminPhone,
                                                      driverPhoneNumber:
                                                          driverPhone,
                                                    ),
                                              ),
                                            );
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Row(
                                              children: [
                                                CircleAvatar(
                                                  backgroundColor:
                                                      Colors.grey[300],
                                                  child: const Icon(
                                                    Icons.group,
                                                    color: Colors.deepPurple,
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                Expanded(
                                                  child: Text(
                                                    group["name"] ?? "",
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 18,
                                                    ),
                                                  ),
                                                ),
                                                const Icon(
                                                  Icons.arrow_forward_ios,
                                                  size: 16,
                                                  color: Colors.grey,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
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
  List<GroupMemberInput> selectedMembers = [];
  bool loading = false;

  Future<void> _createGroup() async {
    final groupName = groupNameController.text.trim();

    if (groupName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Group name is required")));
      return;
    }

    try {
      setState(() => loading = true);

      // Get ngrok_url for backend
      final backendUrl =
          storageService.getNgrokUrl() ?? ""; // Read from Hive instead
      final groupService = GroupService(baseUrl: backendUrl);
      final response = await groupService.createGroup(
        groupName,
        selectedMembers,
      );

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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: groupNameController,
              decoration: const InputDecoration(labelText: 'Group Name'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.contacts),
              label: const Text('Select Members from Contacts'),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => SelectContactsPage(
                      onMembersSelected: (members) {
                        setState(() {
                          selectedMembers = members;
                        });
                      },
                    ),
                  ),
                );
              },
            ),
            if (selectedMembers.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Selected Members (${selectedMembers.length}):',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...selectedMembers.asMap().entries.map((entry) {
                final index = entry.key;
                final member = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      backgroundColor: Colors.purple[100],
                      child: const Icon(Icons.person, size: 20),
                    ),
                    title: Text(
                      member.getDisplayName(),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(member.phoneNumber),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () {
                        setState(() {
                          selectedMembers.removeAt(index);
                        });
                      },
                    ),
                  ),
                );
              }).toList(),
            ],
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
