import 'package:flutter/material.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:provider/provider.dart';
import '../services/contact_service.dart';
import '../providers/synced_group_expense_provider.dart';
import '../utils/constants.dart';
import '../widgets/connection_status_widgets.dart';

class ContactPickerScreen extends StatefulWidget {
  final bool isForInvite;
  final Function(List<ContactMatch>)? onContactsSelected;

  const ContactPickerScreen({
    super.key,
    this.isForInvite = false,
    this.onContactsSelected,
  });

  @override
  State<ContactPickerScreen> createState() => _ContactPickerScreenState();
}

class _ContactPickerScreenState extends State<ContactPickerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<ContactMatch> _friendsWithAccounts = [];
  List<Contact> _allContacts = [];
  List<Contact> _filteredContacts = [];
  List<ContactMatch> _selectedContacts = [];

  bool _isLoading = true;
  bool _hasPermission = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadContacts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Request permission
      _hasPermission = await ContactService.requestContactsPermission();

      if (!_hasPermission) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Load contacts and find friends with accounts
      final contacts = await ContactService.fetchContacts();
      final friendsWithAccounts =
          await ContactService.findFriendsWithAccounts();

      setState(() {
        _allContacts = contacts;
        _filteredContacts = contacts;
        _friendsWithAccounts = friendsWithAccounts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading contacts: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filterContacts(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredContacts = _allContacts;
      } else {
        _filteredContacts = _allContacts.where((contact) {
          final name = contact.displayName?.toLowerCase() ?? '';
          final phones =
              contact.phones?.map((p) => p.value ?? '').join(' ') ?? '';
          return name.contains(query.toLowerCase()) || phones.contains(query);
        }).toList();
      }
    });
  }

  void _toggleContactSelection(ContactMatch contactMatch) {
    setState(() {
      if (_selectedContacts.any(
        (c) => c.contact.identifier == contactMatch.contact.identifier,
      )) {
        _selectedContacts.removeWhere(
          (c) => c.contact.identifier == contactMatch.contact.identifier,
        );
      } else {
        _selectedContacts.add(contactMatch);
      }
    });
  }

  Future<void> _addSelectedFriends() async {
    if (_selectedContacts.isEmpty) return;

    try {
      final provider = Provider.of<SyncedGroupExpenseProvider>(
        context,
        listen: false,
      );

      setState(() {
        _isLoading = true;
      });

      // Add contacts as friends
      await ContactService.addContactsAsFriends(_selectedContacts);

      // Refresh provider data
      // This would trigger a refresh of the friends list

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added ${_selectedContacts.length} friends successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, _selectedContacts);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding friends: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _inviteSelectedContacts() async {
    if (_selectedContacts.isEmpty) return;

    try {
      setState(() {
        _isLoading = true;
      });

      final inviteLinks = await ContactService.inviteContacts(
        _selectedContacts.map((cm) => cm.contact).toList(),
      );

      if (mounted) {
        // Show share dialog with invite links
        _showInviteDialog(inviteLinks);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating invites: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showInviteDialog(List<String> inviteLinks) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite Links Created'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${inviteLinks.length} invite links created successfully!'),
            const SizedBox(height: 16),
            const Text('Share these links with your friends:'),
            const SizedBox(height: 8),
            ...inviteLinks
                .take(3)
                .map(
                  (link) => SelectableText(
                    link,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            if (inviteLinks.length > 3)
              Text('... and ${inviteLinks.length - 3} more'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement sharing functionality
              Navigator.pop(context);
            },
            child: const Text('Share All'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.isForInvite ? 'Invite Friends' : 'Add Friends'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Friends with App'),
            Tab(text: 'All Contacts'),
          ],
        ),
        actions: [
          if (_selectedContacts.isNotEmpty)
            TextButton(
              onPressed: _isLoading
                  ? null
                  : (widget.isForInvite
                        ? _inviteSelectedContacts
                        : _addSelectedFriends),
              child: Text(
                widget.isForInvite
                    ? 'INVITE (${_selectedContacts.length})'
                    : 'ADD (${_selectedContacts.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          const ConnectionStatusWidget(),
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : !_hasPermission
                ? _buildPermissionDenied()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildFriendsWithAppTab(),
                      _buildAllContactsTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: TextField(
        controller: _searchController,
        onChanged: _filterContacts,
        decoration: InputDecoration(
          hintText: 'Search contacts...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey.shade100,
        ),
      ),
    );
  }

  Widget _buildPermissionDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.contacts, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 24),
            Text(
              'Contacts Permission Required',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'To find your friends who already use the app, we need access to your contacts.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _loadContacts,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
              child: const Text('Grant Permission'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsWithAppTab() {
    if (_friendsWithAccounts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.person_search,
        title: 'No Friends Found',
        subtitle:
            'None of your contacts have the app yet.\nInvite them to join!',
      );
    }

    return ListView.builder(
      itemCount: _friendsWithAccounts.length,
      itemBuilder: (context, index) {
        final contactMatch = _friendsWithAccounts[index];
        final isSelected = _selectedContacts.any(
          (c) => c.contact.identifier == contactMatch.contact.identifier,
        );

        return _buildContactMatchTile(contactMatch, isSelected);
      },
    );
  }

  Widget _buildAllContactsTab() {
    if (_filteredContacts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.contact_phone,
        title: _searchQuery.isEmpty ? 'No Contacts' : 'No Results',
        subtitle: _searchQuery.isEmpty
            ? 'No contacts found on your device.'
            : 'No contacts match your search.',
      );
    }

    return ListView.builder(
      itemCount: _filteredContacts.length,
      itemBuilder: (context, index) {
        final contact = _filteredContacts[index];
        final contactMatch = ContactMatch(
          contact: contact,
          phoneNumber: contact.phones?.first.value ?? '',
          isAlreadyFriend: false,
        );

        final isSelected = _selectedContacts.any(
          (c) => c.contact.identifier == contact.identifier,
        );

        return _buildContactTile(contactMatch, isSelected);
      },
    );
  }

  Widget _buildContactMatchTile(ContactMatch contactMatch, bool isSelected) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: contactMatch.hasAccount ? Colors.green : Colors.grey,
          child: Text(
            contactMatch.displayName.isNotEmpty
                ? contactMatch.displayName[0].toUpperCase()
                : '?',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          contactMatch.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(contactMatch.primaryPhone),
            if (contactMatch.email != null)
              Text(
                contactMatch.email!,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: contactMatch.hasAccount
                    ? Colors.green.shade100
                    : Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                contactMatch.hasAccount ? 'Has App' : 'Needs Invite',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: contactMatch.hasAccount
                      ? Colors.green.shade700
                      : Colors.orange.shade700,
                ),
              ),
            ),
          ],
        ),
        trailing: isSelected
            ? const Icon(Icons.check_circle, color: AppColors.primary)
            : const Icon(Icons.circle_outlined, color: Colors.grey),
        onTap: contactMatch.isAlreadyFriend
            ? null
            : () => _toggleContactSelection(contactMatch),
        enabled: !contactMatch.isAlreadyFriend,
      ),
    );
  }

  Widget _buildContactTile(ContactMatch contactMatch, bool isSelected) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: Text(
            contactMatch.displayName.isNotEmpty
                ? contactMatch.displayName[0].toUpperCase()
                : '?',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          contactMatch.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(contactMatch.primaryPhone),
        trailing: isSelected
            ? const Icon(Icons.check_circle, color: AppColors.primary)
            : const Icon(Icons.circle_outlined, color: Colors.grey),
        onTap: () => _toggleContactSelection(contactMatch),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
