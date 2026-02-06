import 'package:flutter_contacts/flutter_contacts.dart' hide Group;
import 'package:hive/hive.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/group.dart';
import '../models/group_member_name.dart';
import '../utils/app_logger.dart';
import '../utils/phone_number_utils.dart';

/// Singleton service for synchronizing contact names with group member phone numbers
///
/// This service manages the mapping between phone numbers from group members
/// and contact names from the device's contact list. It uses smart permission
/// checking to reuse existing grants (e.g., from SelectContactsPage) and avoids
/// duplicate permission dialogs.
class ContactSyncService {
  static final ContactSyncService _instance = ContactSyncService._internal();
  factory ContactSyncService() => _instance;
  ContactSyncService._internal();

  Box<GroupMemberName>? _namesBox;
  bool _initialized = false;

  static const String _boxName = 'group_member_names';

  /// Initialize the service by opening the Hive box
  Future<void> initialize() async {
    if (_initialized) {
      logger.debug('[CONTACTS] Already initialized');
      return;
    }

    try {
      _namesBox = await Hive.openBox<GroupMemberName>(_boxName);
      _initialized = true;
      logger.info('[CONTACTS] Contact sync service initialized');
    } catch (e) {
      logger.error('[CONTACTS ERROR] Failed to initialize: $e');
      rethrow;
    }
  }

  /// Request contacts permission (reuses if already granted)
  /// This checks if permission was previously granted (e.g., via SelectContactsPage)
  /// and only requests if not yet granted - preventing duplicate permission dialogs
  Future<bool> requestPermission() async {
    try {
      PermissionStatus status = await Permission.contacts.status;

      if (status.isGranted) {
        logger.info('[CONTACTS] Permission already granted (reusing existing)');
        return true; // ✅ No dialog shown - already granted!
      }

      if (status.isDenied) {
        logger.info('[CONTACTS] Requesting permission for first time');
        status = await Permission.contacts.request();
        logger.info('[CONTACTS] Permission request result: $status');
      }

      if (status.isPermanentlyDenied) {
        logger.warning('[CONTACTS] Permission permanently denied');
        // Gracefully continue without contacts - show phone numbers
      }

      return status.isGranted;
    } catch (e) {
      logger.error('[CONTACTS ERROR] Permission request failed: $e');
      return false;
    }
  }

  /// Sync contact names for all members in the given groups
  ///
  /// Returns a map with 'matched' and 'total' counts
  Future<Map<String, int>> syncContactsForGroups(List<Group> groups) async {
    if (!_initialized) {
      await initialize();
    }

    int totalMembers = 0;
    int matchedMembers = 0;

    try {
      // Step 1: Check/request permission
      final hasPermission = await requestPermission();
      if (!hasPermission) {
        logger.warning('[CONTACTS] Permission not granted, skipping sync');
        return {'matched': 0, 'total': 0};
      }

      // Step 2: Read all contacts
      logger.info('[CONTACTS] Reading device contacts...');
      final contacts = await FlutterContacts.getContacts(
        withProperties: true, // Include phone numbers
        withThumbnail: false, // We don't need photos
        withPhoto: false,
      );
      logger.info('[CONTACTS] Found ${contacts.length} contacts');

      // Step 3: Build phone-to-name lookup map
      final phoneToNameMap = _buildPhoneToNameMap(contacts);
      logger.debug(
        '[CONTACTS] Built map with ${phoneToNameMap.length} phone entries',
      );

      // Step 4: Process each group's members
      for (var group in groups) {
        final members = group.memberPhoneNumbers ?? [];
        totalMembers += members.length;

        for (var phoneNumber in members) {
          // Normalize phone number
          final normalized = PhoneNumberUtils.tryNormalizePhoneNumber(
            phoneNumber,
          );
          if (normalized == null) {
            logger.warning('[CONTACTS] Cannot normalize phone: $phoneNumber');
            continue;
          }

          // Check if we have a contact name for this number
          final contactName = phoneToNameMap[normalized];
          if (contactName != null) {
            // Save to Hive
            await _saveContactName(group.groupId, normalized, contactName);
            matchedMembers++;
            logger.debug('[CONTACTS] Matched: $normalized → $contactName');
          }
        }
      }

      logger.info(
        '[CONTACTS] Sync complete: Matched $matchedMembers/$totalMembers members',
      );

      return {'matched': matchedMembers, 'total': totalMembers};
    } catch (e) {
      logger.error('[CONTACTS ERROR] Sync failed: $e');
      return {'matched': matchedMembers, 'total': totalMembers};
    }
  }

  /// Build a phone-to-name lookup map from contacts
  Map<String, String> _buildPhoneToNameMap(List<Contact> contacts) {
    final phoneToNameMap = <String, String>{};

    for (var contact in contacts) {
      // Get display name
      final displayName = contact.displayName;
      if (displayName.isEmpty) continue;

      // Process all phone numbers for this contact
      for (var phone in contact.phones) {
        final phoneNumber = phone.number;
        final normalized = PhoneNumberUtils.tryNormalizePhoneNumber(
          phoneNumber,
        );

        if (normalized != null) {
          // Store in map (later numbers overwrite earlier ones)
          phoneToNameMap[normalized] = displayName;
        }
      }
    }

    return phoneToNameMap;
  }

  /// Save a contact name to Hive
  Future<void> _saveContactName(
    int groupId,
    String phoneNumber,
    String contactName,
  ) async {
    if (_namesBox == null) {
      logger.error('[CONTACTS ERROR] Names box not initialized');
      return;
    }

    try {
      final key = '${groupId}_$phoneNumber';
      final memberName = GroupMemberName(
        groupId: groupId,
        phoneNumber: phoneNumber,
        contactName: contactName,
        lastSynced: DateTime.now(),
      );

      await _namesBox!.put(key, memberName);
    } catch (e) {
      logger.error('[CONTACTS ERROR] Failed to save name for $phoneNumber: $e');
    }
  }

  /// Get contact name for a specific group member
  ///
  /// Returns the contact name if found, null otherwise
  String? getContactName(int groupId, String phoneNumber) {
    if (_namesBox == null) return null;

    try {
      // Normalize the phone number for lookup
      final normalized = PhoneNumberUtils.tryNormalizePhoneNumber(phoneNumber);
      if (normalized == null) return null;

      final key = '${groupId}_$normalized';
      final memberName = _namesBox!.get(key);
      return memberName?.contactName;
    } catch (e) {
      logger.error('[CONTACTS ERROR] Failed to get name for $phoneNumber: $e');
      return null;
    }
  }

  /// Get all contact names for a specific group
  ///
  /// Returns a map of phoneNumber -> contactName
  Map<String, String> getContactNamesForGroup(int groupId) {
    if (_namesBox == null) return {};

    try {
      final result = <String, String>{};

      for (var entry in _namesBox!.values) {
        if (entry.groupId == groupId) {
          result[entry.phoneNumber] = entry.contactName;
        }
      }

      return result;
    } catch (e) {
      logger.error(
        '[CONTACTS ERROR] Failed to get names for group $groupId: $e',
      );
      return {};
    }
  }

  /// Clear all contact data
  Future<void> clearContactData() async {
    if (_namesBox == null) return;

    try {
      await _namesBox!.clear();
      logger.info('[CONTACTS] Cleared all contact data');
    } catch (e) {
      logger.error('[CONTACTS ERROR] Failed to clear data: $e');
    }
  }

  /// Clear contact data for a specific group
  Future<void> clearGroupContactData(int groupId) async {
    if (_namesBox == null) return;

    try {
      final keysToDelete = <String>[];

      for (var entry in _namesBox!.toMap().entries) {
        if (entry.value.groupId == groupId) {
          keysToDelete.add(entry.key);
        }
      }

      for (var key in keysToDelete) {
        await _namesBox!.delete(key);
      }

      logger.info(
        '[CONTACTS] Cleared contact data for group $groupId (${keysToDelete.length} entries)',
      );
    } catch (e) {
      logger.error(
        '[CONTACTS ERROR] Failed to clear data for group $groupId: $e',
      );
    }
  }
}
