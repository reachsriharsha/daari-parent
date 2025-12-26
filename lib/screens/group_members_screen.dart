import 'package:flutter/material.dart';

/// Screen to display group members
class GroupMembersScreen extends StatelessWidget {
  final String groupName;
  final List<String> memberPhoneNumbers;
  final bool isAdmin;

  const GroupMembersScreen({
    super.key,
    required this.groupName,
    required this.memberPhoneNumbers,
    this.isAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$groupName Members')),
      body: memberPhoneNumbers.isEmpty
          ? const Center(
              child: Text(
                'No members in this group',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : Column(
              children: [
                // Header with member count
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16.0),
                  color: Colors.purple[50],
                  child: Row(
                    children: [
                      Icon(Icons.group, color: Colors.deepPurple),
                      const SizedBox(width: 12),
                      Text(
                        '${memberPhoneNumbers.length} ${memberPhoneNumbers.length == 1 ? 'Member' : 'Members'}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isAdmin) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'You\'re Admin',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Members list
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: memberPhoneNumbers.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final phoneNumber = memberPhoneNumbers[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.deepPurple[100],
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: Colors.deepPurple[900],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          phoneNumber,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          'Member',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        trailing: Icon(Icons.phone, color: Colors.grey[400]),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
