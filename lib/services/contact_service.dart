import 'package:fast_contacts/fast_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/group_expense.dart';
import '../services/database_service.dart';

class ContactService {
  static List<Contact> _cachedContacts = [];
  static bool _contactsLoaded = false;

  /// Request contacts permission from user
  static Future<bool> requestContactsPermission() async {
    print('📱 ContactService: Checking contacts permission');
    final status = await Permission.contacts.status;
    print('📱 ContactService: Current permission status: $status');

    if (status.isGranted) {
      print('✅ ContactService: Permission already granted');
      return true;
    }

    if (status.isDenied) {
      print('📱 ContactService: Permission denied, requesting...');
      final result = await Permission.contacts.request();
      print('📱 ContactService: Permission request result: $result');
      return result.isGranted;
    }

    if (status.isPermanentlyDenied) {
      print(
        '❌ ContactService: Permission permanently denied, opening settings',
      );
      // Guide user to settings to enable permission
      await openAppSettings();
      return false;
    }

    print('📱 ContactService: Requesting permission for other status: $status');
    final result = await Permission.contacts.request();
    print('📱 ContactService: Permission request result: $result');
    return result.isGranted;
  }

  /// Fetch all contacts from device
  static Future<List<Contact>> fetchContacts() async {
    print('📱 ContactService: fetchContacts called');

    if (_contactsLoaded && _cachedContacts.isNotEmpty) {
      print(
        '📱 ContactService: Using cached contacts (${_cachedContacts.length})',
      );
      return _cachedContacts;
    }

    print('📱 ContactService: Requesting contacts permission');
    final hasPermission = await requestContactsPermission();
    if (!hasPermission) {
      print('❌ ContactService: Contacts permission denied');
      throw Exception('Contacts permission denied');
    }

    print('✅ ContactService: Permission granted, fetching contacts');
    try {
      final contacts = await FastContacts.getAllContacts();
      print('📱 ContactService: Retrieved ${contacts.length} total contacts');

      // Filter contacts that have phone numbers and names
      _cachedContacts = contacts
          .where(
            (contact) =>
                contact.phones.isNotEmpty && contact.displayName.isNotEmpty,
          )
          .toList();

      print(
        '📱 ContactService: Filtered to ${_cachedContacts.length} contacts with phone numbers',
      );

      // Debug: print first few contacts
      for (
        int i = 0;
        i < (_cachedContacts.length > 3 ? 3 : _cachedContacts.length);
        i++
      ) {
        final contact = _cachedContacts[i];
        print(
          '📱 ContactService: Contact ${i + 1}: ${contact.displayName} - ${contact.phones.first.number}',
        );
      }

      _contactsLoaded = true;
      return _cachedContacts;
    } catch (e) {
      print('❌ ContactService: Failed to fetch contacts: $e');
      throw Exception('Failed to fetch contacts: $e');
    }
  }

  /// Find friends who have accounts in the app by matching phone numbers
  static Future<List<ContactMatch>> findFriendsWithAccounts() async {
    final contacts = await fetchContacts();
    final List<ContactMatch> matches = [];

    for (final contact in contacts) {
      if (contact.phones.isEmpty) continue;

      for (final phone in contact.phones) {
        final cleanPhone = _cleanPhoneNumber(phone.number);
        if (cleanPhone.isEmpty) continue;

        try {
          // Check if this phone number has an account
          final userExists = await DatabaseService.checkUserExists(cleanPhone);

          if (userExists) {
            final userInfo = await DatabaseService.getUserByPhone(cleanPhone);
            matches.add(
              ContactMatch(
                contact: contact,
                phoneNumber: cleanPhone,
                userInfo: userInfo,
                isAlreadyFriend: await _isAlreadyFriend(userInfo?['id']),
              ),
            );
            break; // Found a match for this contact, no need to check other numbers
          }
        } catch (e) {
          print('Error checking user existence for $cleanPhone: $e');
        }
      }
    }

    return matches;
  }

  /// Search contacts by name or phone number
  static Future<List<Contact>> searchContacts(String query) async {
    final contacts = await fetchContacts();

    if (query.isEmpty) return contacts;

    final lowerQuery = query.toLowerCase();

    return contacts.where((contact) {
      // Search by display name
      final name = contact.displayName.toLowerCase();
      if (name.contains(lowerQuery)) return true;

      // Search by phone numbers
      for (final phone in contact.phones) {
        final phoneNumber = phone.number;
        if (phoneNumber.contains(query)) return true;
      }

      return false;
    }).toList();
  }

  /// Invite contacts to join the app
  static Future<List<String>> inviteContacts(List<Contact> contacts) async {
    final List<String> inviteLinks = [];

    for (final contact in contacts) {
      if (contact.phones.isEmpty) continue;

      final primaryPhone = _cleanPhoneNumber(contact.phones.first.number);
      if (primaryPhone.isEmpty) continue;

      try {
        final inviteLink = await DatabaseService.inviteFriend(
          contact.displayName,
          primaryPhone,
          contact.emails.isNotEmpty ? contact.emails.first.address : null,
        );
        inviteLinks.add(inviteLink);
      } catch (e) {
        print('Error creating invite for ${contact.displayName}: $e');
      }
    }

    return inviteLinks;
  }

  /// Add found friends to user's friend list
  static Future<void> addContactsAsFriends(
    List<ContactMatch> contactMatches,
  ) async {
    for (final match in contactMatches) {
      if (match.isAlreadyFriend) continue;

      try {
        final friend = Friend(
          id:
              match.userInfo?['id'] ??
              'contact_${DateTime.now().millisecondsSinceEpoch}',
          name: match.contact.displayName,
          phoneNumber: match.phoneNumber,
          email: match.userInfo?['email'],
        );

        await DatabaseService.addFriend(friend);
      } catch (e) {
        print('Error adding friend ${match.contact.displayName}: $e');
      }
    }
  }

  /// Clean and normalize phone number
  static String _cleanPhoneNumber(String phone) {
    // Remove all non-digit characters except +
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');

    // Handle different formats
    if (cleaned.startsWith('0')) {
      // Remove leading 0 and add country code (assuming India +91)
      cleaned = '+91${cleaned.substring(1)}';
    } else if (cleaned.startsWith('+91') && cleaned.length == 13) {
      // Already in correct format
      return cleaned;
    } else if (cleaned.length == 10) {
      // Add country code
      cleaned = '+91$cleaned';
    }

    return cleaned;
  }

  /// Check if user is already in friends list
  static Future<bool> _isAlreadyFriend(String? userId) async {
    if (userId == null) return false;

    try {
      final friends = await DatabaseService.getFriends();
      return friends.any((friend) => friend.id == userId);
    } catch (e) {
      return false;
    }
  }

  /// Get contact suggestions based on recent interactions
  static Future<List<Contact>> getContactSuggestions() async {
    final contacts = await fetchContacts();

    // Sort by display name and return top 20
    contacts.sort((a, b) => a.displayName.compareTo(b.displayName));

    return contacts.take(20).toList();
  }

  /// Add friend by phone number
  static Future<void> addFriendByPhone(
    String phoneNumber,
    String friendName,
  ) async {
    try {
      final cleanPhone = _cleanPhoneNumber(phoneNumber);
      if (cleanPhone.isEmpty) {
        throw Exception('Invalid phone number format');
      }

      // Check if user exists
      final userExists = await DatabaseService.checkUserExists(cleanPhone);

      if (userExists) {
        // User exists, get their info and add as friend
        final userInfo = await DatabaseService.getUserByPhone(cleanPhone);
        if (userInfo != null) {
          final friend = Friend(
            id: userInfo['id'],
            name: userInfo['name'],
            phoneNumber: cleanPhone,
            email: userInfo['email'],
          );
          await DatabaseService.addFriend(friend);
        }
      } else {
        // User doesn't exist, create friend invitation
        await DatabaseService.addFriendByPhone(cleanPhone, friendName);
      }
    } catch (e) {
      throw Exception('Failed to add friend by phone: $e');
    }
  }

  /// Clear cached contacts (useful when contacts are updated)
  static void clearCache() {
    _cachedContacts.clear();
    _contactsLoaded = false;
  }
}

/// Model for contact matches
class ContactMatch {
  final Contact contact;
  final String phoneNumber;
  final Map<String, dynamic>? userInfo;
  final bool isAlreadyFriend;

  ContactMatch({
    required this.contact,
    required this.phoneNumber,
    this.userInfo,
    required this.isAlreadyFriend,
  });

  String get displayName => contact.displayName;
  String get primaryPhone => phoneNumber;
  String? get email => userInfo?['email'];
  bool get hasAccount => userInfo != null;
}
