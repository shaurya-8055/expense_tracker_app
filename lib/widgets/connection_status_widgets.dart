import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/synced_group_expense_provider.dart';

class ConnectionStatusBadge extends StatelessWidget {
  const ConnectionStatusBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncedGroupExpenseProvider>(
      builder: (context, provider, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: provider.isOnline
                ? Colors.green.withOpacity(0.2)
                : Colors.red.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                provider.isOnline ? Icons.wifi : Icons.wifi_off,
                size: 12,
                color: provider.isOnline ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 4),
              Text(
                provider.isOnline ? 'Online' : 'Offline',
                style: TextStyle(
                  color: provider.isOnline ? Colors.green : Colors.red,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ConnectionStatusWidget extends StatelessWidget {
  const ConnectionStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncedGroupExpenseProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.orange.shade600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Syncing...',
                  style: TextStyle(
                    color: Colors.orange.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: provider.isOnline
                ? Colors.green.shade100
                : Colors.red.shade100,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                provider.isOnline ? Icons.cloud_done : Icons.cloud_off,
                size: 14,
                color: provider.isOnline
                    ? Colors.green.shade600
                    : Colors.red.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                provider.isOnline ? 'Online' : 'Offline',
                style: TextStyle(
                  color: provider.isOnline
                      ? Colors.green.shade600
                      : Colors.red.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncedGroupExpenseProvider>(
      builder: (context, provider, child) {
        if (provider.isOnline) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: Colors.orange.shade100,
          child: Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.orange.shade700, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You\'re offline',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Changes will sync when you reconnect',
                      style: TextStyle(
                        color: Colors.orange.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class RealTimeUpdateBanner extends StatefulWidget {
  const RealTimeUpdateBanner({super.key});

  @override
  State<RealTimeUpdateBanner> createState() => _RealTimeUpdateBannerState();
}

class _RealTimeUpdateBannerState extends State<RealTimeUpdateBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  void _showUpdateBanner() {
    if (!_isVisible) {
      setState(() {
        _isVisible = true;
      });
      _animationController.forward();

      // Hide after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          _animationController.reverse().then((_) {
            if (mounted) {
              setState(() {
                _isVisible = false;
              });
            }
          });
        }
      });
    }
  }

  // Method to manually trigger the banner (can be called by provider)
  void showUpdate() {
    _showUpdateBanner();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncedGroupExpenseProvider>(
      builder: (context, provider, child) {
        // This would be triggered by the provider when real-time updates arrive
        // For now, we'll show it when the provider state changes

        if (!_isVisible) {
          return const SizedBox.shrink();
        }

        return FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.blue.shade100,
            child: Row(
              children: [
                Icon(Icons.update, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'New updates from friends received!',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(Icons.check_circle, color: Colors.blue.shade700, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}

class OnlineUsersWidget extends StatelessWidget {
  const OnlineUsersWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncedGroupExpenseProvider>(
      builder: (context, provider, child) {
        if (!provider.isOnline) {
          return const SizedBox.shrink();
        }

        // This would show online friends - for now we'll show a placeholder
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.people, size: 16, color: Colors.green.shade600),
              const SizedBox(width: 8),
              Text(
                '${provider.friends.length} friends connected',
                style: TextStyle(
                  color: Colors.green.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              // Show online indicator dots for friends
              ...provider.friends
                  .take(3)
                  .map(
                    (friend) => Container(
                      margin: const EdgeInsets.only(right: 4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.green.shade500,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              if (provider.friends.length > 3)
                Text(
                  '+${provider.friends.length - 3}',
                  style: TextStyle(
                    color: Colors.green.shade600,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
