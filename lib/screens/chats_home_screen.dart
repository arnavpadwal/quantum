import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/contact.dart';
import '../models/message.dart';
import '../services/storage_service.dart';
import '../services/encryption_service.dart';
import '../services/p2p_service.dart';
import 'chat_room_screen.dart';
import 'add_contact_screen.dart';
import 'share_contact_screen.dart';
import '../services/update_service.dart';

class ChatsHomeScreen extends StatefulWidget {
  const ChatsHomeScreen({super.key});

  @override
  State<ChatsHomeScreen> createState() => _ChatsHomeScreenState();
}

class _ChatsHomeScreenState extends State<ChatsHomeScreen> {
  List<Contact> _contacts = [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _listenToMessages();
    P2PService.instance.myIpv6AddressNotifier.addListener(_onIpv6AddressChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.checkForUpdate(context);
    });
  }

  @override
  void dispose() {
    P2PService.instance.myIpv6AddressNotifier.removeListener(_onIpv6AddressChanged);
    super.dispose();
  }

  void _onIpv6AddressChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _loadContacts() {
    setState(() {
      _contacts = StorageService.getAllContacts();
    });
  }

  void _listenToMessages() {
    P2PService.instance.messageStream.listen((message) {
      if (mounted) {
        _loadContacts();
      }
    });

    P2PService.instance.contactRequestStream.listen((request) {
      if (mounted) {
        _showContactRequestDialog(request);
      }
    });
  }

  void _showContactRequestDialog(Map<String, String> request) {
    final publicKey = request['publicKey']!;
    final ipAddress = request['ipAddress']!;
    final nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Connection Request', style: TextStyle(fontWeight: FontWeight.w600)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('An unknown device is attempting to connect.', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('IP: $ipAddress', style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                    const SizedBox(height: 8),
                    Text('Key: ${publicKey.substring(0, 16)}...', style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Save as...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Decline', style: TextStyle(color: Colors.red)),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a name')),
                );
                return;
              }

              final newContact = Contact(
                id: EncryptionService.generateId(),
                name: name,
                ipAddress: ipAddress,
                publicKey: publicKey,
              );

              await StorageService.saveContact(newContact);
              await P2PService.instance.initiateHandshake(newContact);

              Navigator.pop(context);
              _loadContacts();
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  void _showMyInfoDialog() {
    final profile = StorageService.getProfile();
    if (profile == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('My Identity', style: TextStyle(fontWeight: FontWeight.w600)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Name: ${profile.displayName}', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('IPv6 Address', style: TextStyle(fontWeight: FontWeight.w500)),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 20),
                        onPressed: () async {
                          await P2PService.instance.init();
                          if (mounted) setState(() {});
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _showEditIpDialog(),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  P2PService.instance.myIpv6Address ?? 'Discovering...',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Public Key', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  profile.publicKey,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(
                      text: 'IP Address: ${P2PService.instance.myIpv6Address}\nPublic Key: ${profile.publicKey}',
                    ));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Identity copied to clipboard')),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy All Details'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditIpDialog() {
    final ipController = TextEditingController(text: P2PService.instance.myIpv6Address);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit IP Address', style: TextStyle(fontWeight: FontWeight.w600)),
        content: TextField(
          controller: ipController,
          decoration: InputDecoration(
            labelText: 'IPv6 Address',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () {
              final newIp = ipController.text.trim();
              if (newIp.isNotEmpty) {
                P2PService.instance.manualIpUpdate(newIp);
                Navigator.pop(context);
                if (mounted) setState(() {});
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return '';
    
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(timestamp);
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE').format(timestamp);
    } else {
      return DateFormat('dd/MM/yy').format(timestamp);
    }
  }

  Widget _buildMessageStatus(MessageStatus status) {
    switch (status) {
      case MessageStatus.sent:
        return const Icon(Icons.check, size: 14, color: Colors.grey);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all, size: 14, color: Colors.grey);
      case MessageStatus.read:
        return Icon(Icons.done_all, size: 14, color: Theme.of(context).colorScheme.primary);
      case MessageStatus.failed:
        return const Icon(Icons.error_outline, size: 14, color: Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: _showMyInfoDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: _contacts.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.primaryContainer,
                      ),
                      child: Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No Conversations Yet',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the + button to add a contact',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _contacts.length,
                itemBuilder: (context, index) {
                  final contact = _contacts[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    leading: CircleAvatar(
                      radius: 26,
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        contact.name[0].toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    title: Text(
                      contact.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                    subtitle: contact.lastMessage != null
                        ? Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Row(
                              children: [
                                if (contact.lastMessage != null)
                                  _buildMessageStatus(MessageStatus.delivered),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    contact.lastMessage!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : null,
                    trailing: contact.lastMessageTime != null
                        ? Text(
                            _formatTimestamp(contact.lastMessageTime),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          )
                        : null,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatRoomScreen(contact: contact),
                        ),
                      ).then((_) => _loadContacts());
                    },
                    onLongPress: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Contact'),
                          content: Text('Are you sure you want to delete ${contact.name}?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () async {
                                await StorageService.deleteContact(contact.id);
                                Navigator.pop(context);
                                _loadContacts();
                              },
                              child: const Text('Delete', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (BuildContext context) {
              return SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const SizedBox(height: 16),
                    ListTile(
                      leading: Icon(Icons.qr_code_scanner, color: Theme.of(context).colorScheme.primary),
                      title: const Text('Scan QR Code', style: TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: const Text('Add a new contact by scanning their QR'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AddContactScreen()),
                        ).then((_) => _loadContacts());
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.qr_code, color: Theme.of(context).colorScheme.primary),
                      title: const Text('Show My QR Code', style: TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: const Text('Let others scan your QR to connect'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ShareContactScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
