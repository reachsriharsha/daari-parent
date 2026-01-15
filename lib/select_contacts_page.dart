import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

class SelectContactsPage extends StatefulWidget {
  final Function(List<String>) onMembersSelected;
  const SelectContactsPage({super.key, required this.onMembersSelected});

  @override
  State<SelectContactsPage> createState() => _SelectContactsPageState();
}

class _SelectContactsPageState extends State<SelectContactsPage> {
  List<Contact> contacts = [];
  List<Contact> selectedContacts = [];
  bool loading = true;
  String? errorMessage;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchContacts();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchContacts() async {
    // Check and request contact permission using permission_handler.
    PermissionStatus permissionStatus = await Permission.contacts.status;
    if (!permissionStatus.isGranted) {
      permissionStatus = await Permission.contacts.request();
    }

    if (permissionStatus.isGranted) {
      try {
        final allContacts = await FlutterContacts.getContacts(
          withProperties: true,
        );
        setState(() {
          contacts = allContacts;
          loading = false;
        });
      } catch (e) {
        setState(() {
          errorMessage = 'Failed to fetch contacts: $e';
          loading = false;
        });
      }
    } else {
      // Handle permission denial.
      setState(() {
        errorMessage =
            'Permission to access contacts was denied. Please grant contacts permission in app settings.';
        loading = false;
      });
      // Show a dialog to guide the user to app settings
      _showPermissionSettingsDialog();
    }
  }

  void _toggleContact(Contact contact) {
    setState(() {
      if (selectedContacts.contains(contact)) {
        selectedContacts.remove(contact);
      } else {
        selectedContacts.add(contact);
      }
    });
  }

  // Show dialog to guide user to app settings
  Future<void> _showPermissionSettingsDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Contacts Permission Required'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  'This app needs access to your contacts to function properly.',
                ),
                Text('\nPlease grant contacts permission in app settings.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Open Settings'),
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
            ),
          ],
        );
      },
    );
  }

  // Retry fetching contacts
  Future<void> _retryFetchContacts() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });
    await _fetchContacts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Members')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _retryFetchContacts,
                    child: const Text('Retry'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => openAppSettings(),
                    child: const Text('Open Settings'),
                  ),
                ],
              ),
            )
          : contacts.isEmpty
          ? const Center(child: Text('No contacts found.'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search by name or number',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final contactsWithPhones = contacts
                          .where(
                            (c) =>
                                c.phones.isNotEmpty &&
                                c.phones.first.number.isNotEmpty,
                          )
                          .toList();

                      if (contactsWithPhones.isEmpty) {
                        return const Center(
                          child: Text('No contacts with phone numbers found.'),
                        );
                      }

                      final filteredContacts = contactsWithPhones.where((
                        contact,
                      ) {
                        final name = contact.displayName.toLowerCase();
                        final phone = contact.phones.first.number.replaceAll(
                          RegExp(r'[^\d+]'),
                          '',
                        );
                        final query = _searchQuery.toLowerCase();
                        return name.contains(query) || phone.contains(query);
                      }).toList();

                      if (filteredContacts.isEmpty && _searchQuery.isNotEmpty) {
                        return const Center(
                          child: Text('No matching contacts found.'),
                        );
                      }

                      return ListView.builder(
                        itemCount: filteredContacts.length,
                        itemBuilder: (context, index) {
                          final contact = filteredContacts[index];
                          final isSelected = selectedContacts.contains(contact);
                          final phone = contact.phones.first.number;
                          return ListTile(
                            title: Text(contact.displayName),
                            subtitle: Text(phone),
                            trailing: isSelected
                                ? const Icon(Icons.check_box)
                                : const Icon(Icons.check_box_outline_blank),
                            onTap: () => _toggleContact(contact),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: selectedContacts.isEmpty
            ? null
            : () {
                final memberPhones = selectedContacts
                    .map(
                      (c) => c.phones.isNotEmpty ? c.phones.first.number : '',
                    )
                    .where((phone) => phone.isNotEmpty)
                    .toList();
                widget.onMembersSelected(memberPhones);
                Navigator.pop(context);
              },
        child: const Icon(Icons.done),
      ),
    );
  }
}
