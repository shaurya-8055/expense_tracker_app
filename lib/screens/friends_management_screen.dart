import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/synced_group_expense_provider.dart';
import '../models/group_expense.dart';
import '../utils/constants.dart';
import '../screens/contact_picker_screen.dart';
import '../services/contact_service.dart';
import '../widgets/connection_status_widgets.dart';

class FriendsManagementScreen extends StatefulWidget {
  const FriendsManagementScreen({super.key});

  @override
  State<FriendsManagementScreen> createState() =>
      _FriendsManagementScreenState();
}

class _FriendsManagementScreenState extends State<FriendsManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  Future<void> _addFriendsFromContacts() async {
    try {
      final result = await Navigator.push<List<ContactMatch>>(
        context,
        MaterialPageRoute(
          builder: (context) => const ContactPickerScreen(isForInvite: false),
        ),
      );

      if (result != null && result.isNotEmpty) {
        setState(() {
          _isLoading = true;
        });

        // Refresh the friends list after adding
        // The provider will handle the actual addition through the ContactPickerScreen
        await Future.delayed(
          const Duration(milliseconds: 500),
        ); // Small delay for UX

        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added ${result.length} friends!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _inviteFriendsFromContacts() async {
    try {
      final result = await Navigator.push<List<ContactMatch>>(
        context,
        MaterialPageRoute(
          builder: (context) => const ContactPickerScreen(isForInvite: true),
        ),
      );

      if (result != null && result.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invited ${result.length} friends!'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _addManualFriend() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Friend Manually'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name *',
                hintText: 'Enter friend\'s name',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: '+91XXXXXXXXXX',
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'friend@example.com',
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      try {
        final provider = Provider.of<SyncedGroupExpenseProvider>(
          context,
          listen: false,
        );
        final friend = Friend(
          id: 'manual_${DateTime.now().millisecondsSinceEpoch}',
          name: nameController.text.trim(),
          phoneNumber: phoneController.text.trim().isNotEmpty
              ? phoneController.text.trim()
              : null,
          email: emailController.text.trim().isNotEmpty
              ? emailController.text.trim()
              : null,
        );

        await provider.addFriend(friend);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Friend added successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error adding friend: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Friends'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'add_from_contacts':
                  _addFriendsFromContacts();
                  break;
                case 'invite_contacts':
                  _inviteFriendsFromContacts();
                  break;
                case 'add_manual':
                  _addManualFriend();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'add_from_contacts',
                child: ListTile(
                  leading: Icon(Icons.person_add),
                  title: Text('Add from Contacts'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'invite_contacts',
                child: ListTile(
                  leading: Icon(Icons.share),
                  title: Text('Invite Friends'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'add_manual',
                child: ListTile(
                  leading: Icon(Icons.person_add_alt),
                  title: Text('Add Manually'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          const SyncStatusBanner(),
          const OnlineUsersWidget(),
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildFriendsList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addFriendsFromContacts,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search friends...',
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

  Widget _buildFriendsList() {
    return Consumer<SyncedGroupExpenseProvider>(
      builder: (context, provider, child) {
        List<Friend> filteredFriends = provider.friends;

        if (_searchQuery.isNotEmpty) {
          filteredFriends = provider.friends.where((friend) {
            return friend.name.toLowerCase().contains(_searchQuery) ||
                (friend.phoneNumber?.contains(_searchQuery) ?? false) ||
                (friend.email?.toLowerCase().contains(_searchQuery) ?? false);
          }).toList();
        }

        if (filteredFriends.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          itemCount: filteredFriends.length,
          itemBuilder: (context, index) {
            final friend = filteredFriends[index];
            return _buildFriendTile(friend, provider);
          },
        );
      },
    );
  }

  Widget _buildFriendTile(Friend friend, SyncedGroupExpenseProvider provider) {
    final balances = provider.getBalances();
    final balance = balances[friend.id] ?? 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: balance > 0
              ? Colors.green.shade100
              : balance < 0
              ? Colors.red.shade100
              : AppColors.primary.withOpacity(0.1),
          child: Text(
            friend.name.isNotEmpty ? friend.name[0].toUpperCase() : '?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: balance > 0
                  ? Colors.green.shade700
                  : balance < 0
                  ? Colors.red.shade700
                  : AppColors.primary,
            ),
          ),
        ),
        title: Text(
          friend.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (friend.phoneNumber != null)
              Text(
                friend.phoneNumber!,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            if (friend.email != null)
              Text(
                friend.email!,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            if (balance != 0)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: balance > 0
                      ? Colors.green.shade100
                      : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  balance > 0
                      ? 'Owes you ₹${balance.abs().toStringAsFixed(2)}'
                      : 'You owe ₹${balance.abs().toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: balance > 0
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            switch (value) {
              case 'view_expenses':
                _viewExpensesWithFriend(friend, provider);
                break;
              case 'settle':
                _settleBill(friend, provider);
                break;
              case 'delete':
                _deleteFriend(friend, provider);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'view_expenses',
              child: Text('View Expenses'),
            ),
            if (balance != 0)
              const PopupMenuItem(value: 'settle', child: Text('Settle Bill')),
            const PopupMenuItem(value: 'delete', child: Text('Remove Friend')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 24),
            Text(
              _searchQuery.isEmpty ? 'No Friends Yet' : 'No Results Found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? 'Add friends to start splitting expenses!\nTap the + button to get started.'
                  : 'No friends match your search.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _addFriendsFromContacts,
                icon: const Icon(Icons.contact_phone),
                label: const Text('Add from Contacts'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _viewExpensesWithFriend(
    Friend friend,
    SyncedGroupExpenseProvider provider,
  ) {
    final expenses = provider.getExpensesWithFriend(friend.id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Expenses with ${friend.name}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: expenses.isEmpty
                    ? const Center(child: Text('No shared expenses'))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: expenses.length,
                        itemBuilder: (context, index) {
                          final expense = expenses[index];
                          return Card(
                            child: ListTile(
                              title: Text(expense.title),
                              subtitle: Text(expense.formattedDate),
                              trailing: Text(expense.formattedAmount),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _settleBill(Friend friend, SyncedGroupExpenseProvider provider) {
    // Implement settle bill functionality
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Settle with ${friend.name}'),
        content: const Text('Bill settlement functionality coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _deleteFriend(Friend friend, SyncedGroupExpenseProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${friend.name}?'),
        content: const Text(
          'This will remove them from your friends list. Shared expense history will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await provider.deleteFriend(friend.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Friend removed'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error removing friend: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
