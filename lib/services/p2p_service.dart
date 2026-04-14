import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../models/contact.dart';
import 'storage_service.dart';
import 'encryption_service.dart';
import 'notification_service.dart';

class P2PService {
  static final P2PService instance = P2PService._internal();
  P2PService._internal();

  static const int _port = 8888;
  ServerSocket? _serverSocket;
  final Map<String, Socket> _activeSockets = {};
  final StreamController<Message> _messageController = StreamController.broadcast();
  final StreamController<Map<String, String>> _contactRequestController = StreamController.broadcast();
  final Map<String, Completer<bool>> _pingCompleters = {};
  final Map<String, Completer<void>> _handshakeCompleters = {};
  final ValueNotifier<String?> myIpv6AddressNotifier = ValueNotifier(null);

  Stream<Message> get messageStream => _messageController.stream;
  Stream<Map<String, String>> get contactRequestStream => _contactRequestController.stream;
  String? get myIpv6Address => myIpv6AddressNotifier.value;

  Future<void> init() async {
    try {
      await _startTcpListener();
      // Start IPv6 discovery unconditionally in the background
      _discoverIpv6Address();
      Connectivity().onConnectivityChanged.listen((_) => _handleNetworkChange());
    } catch (e) {
      debugPrint('Error during P2PService initialization: $e');
    }
  }

  Future<void> _handleNetworkChange() async {
    debugPrint('Network change detected, re-initializing TCP connections...');
    _closeAllConnections();
    await _discoverIpv6Address();
    final contacts = StorageService.getAllContacts();
    for (final contact in contacts) {
      // Invalidate old session on network change to force KEM renegotiation
      contact.sharedSecret = null;
      await StorageService.updateContact(contact);
      await initiateHandshake(contact);
    }
  }

  void _closeAllConnections() {
    for (var socket in _activeSockets.values) {
      try {
        socket.destroy();
      } catch (_) {}
    }
    _activeSockets.clear();
  }

  Future<void> _discoverIpv6Address() async {
    const maxRetries = 5;
    for (int i = 0; i < maxRetries; i++) {
      try {
        final ip = await _getPublicIpv6WithBinding();
        InternetAddress(ip, type: InternetAddressType.IPv6);
        
        var finalIp = ip;
        final zoneIndex = ip.indexOf('%');
        if (zoneIndex != -1) {
          finalIp = ip.substring(0, zoneIndex);
        }
        
        myIpv6AddressNotifier.value = finalIp;
        debugPrint('Found IPv6 address via bound socket: $finalIp');
        return;
      } catch (e) {
        debugPrint('Attempt ${i + 1} failed: Error discovering IPv6 address: $e');
        if (i < maxRetries - 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    }
    debugPrint('All attempts to fetch IPv6 address failed. Falling back.');
    myIpv6AddressNotifier.value = '::1';
  }

  Future<InternetAddress> _getLocalIpv6Address() async {
    InternetAddress? sourceAddress;
    final interfaces = await NetworkInterface.list(
        includeLoopback: false, type: InternetAddressType.any);
    for (final interface in interfaces) {
      for (final addr in interface.addresses) {
        if (addr.type == InternetAddressType.IPv6 &&
            !addr.isLinkLocal &&
            !addr.isLoopback) {
          sourceAddress = addr;
          break;
        }
      }
      if (sourceAddress != null) break;
    }

    if (sourceAddress == null) {
      throw Exception('No local non-link-local IPv6 found.');
    }
    return sourceAddress;
  }

  Future<String> _getPublicIpv6WithBinding() async {
    final sourceAddress = await _getLocalIpv6Address();
    return sourceAddress.address;
  }

  void manualIpUpdate(String newIp) {
    myIpv6AddressNotifier.value = newIp;
    debugPrint('IP manually updated to: $newIp');
  }

  Future<void> _startTcpListener() async {
    try {
      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv6, _port, shared: true);
      debugPrint('P2P TCP Server listening on [::]:$_port');
      
      _serverSocket!.listen((Socket clientSocket) {
        final remoteAddress = clientSocket.remoteAddress.address;
        debugPrint('Incoming TCP connection from [$remoteAddress]');
        _handleNewConnection(clientSocket, remoteAddress);
      });
    } catch (e) {
      debugPrint('Error starting TCP server: $e');
    }
  }

  void _handleNewConnection(Socket socket, String remoteAddress) {
    // Drop existing duplicate connection
    if (_activeSockets.containsKey(remoteAddress)) {
      _activeSockets[remoteAddress]?.destroy();
    }
    
    _activeSockets[remoteAddress] = socket;

    // Use a LineSplitter to safely map arbitrary payloads in TCP streams
    socket.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()).listen(
      (String line) {
        try {
          final payload = jsonDecode(line);
          debugPrint('Received ${payload['type']} from [$remoteAddress]');
          _handlePayload(payload, remoteAddress);
        } catch (e) {
          debugPrint('Failed to parse incoming TCP line: $e');
        }
      },
      onError: (e) {
        debugPrint('Connection error with [$remoteAddress]: $e');
        _activeSockets.remove(remoteAddress);
        socket.destroy();
      },
      onDone: () {
        debugPrint('Connection closed by [$remoteAddress]');
        _activeSockets.remove(remoteAddress);
        socket.destroy();
      },
    );
  }

  Future<Socket?> _getOrCreateConnection(String targetIp) async {
    if (_activeSockets.containsKey(targetIp)) {
      return _activeSockets[targetIp];
    }
    try {
      debugPrint('Connecting via TCP to [$targetIp]:$_port...');
      final socket = await Socket.connect(
        InternetAddress(targetIp, type: InternetAddressType.IPv6), 
        _port, 
        timeout: const Duration(seconds: 10)
      );
      _handleNewConnection(socket, targetIp);
      return socket;
    } catch (e) {
      debugPrint('✗ TCP connect failed to [$targetIp]: $e');
      return null;
    }
  }

  void _handlePayload(Map<String, dynamic> payload, String remoteAddress) {
    switch (payload['type']) {
      case 'ping': _handlePing(payload, remoteAddress); break;
      case 'pong': _handlePong(payload); break;
      case 'message': _handleIncomingMessage(payload, remoteAddress); break;
      case 'handshake': _handleHandshake(payload, remoteAddress); break;
      case 'handshake_response': _handleHandshakeResponse(payload); break;
   
      case 'delivery_ack': _handleDeliveryAck(payload); break;
      case 'read_ack': _handleReadAck(payload); break;
      default: debugPrint('Unknown payload type: ${payload['type']}');
    }
  }

  Future<void> _handlePing(Map<String, dynamic> payload, String remoteAddress) async {
    final senderPublicKey = payload['publicKey'] as String;
    final contact = _findContactByPublicKey(senderPublicKey);
    
    if (contact != null) {
      if (contact.ipAddress != remoteAddress) {
        contact.ipAddress = remoteAddress;
        await StorageService.updateContact(contact);
      }
      final profile = StorageService.getProfile();
      if (profile == null) return;
      _sendJson({'type': 'pong', 'publicKey': profile.publicKey}, contact.ipAddress);
    }
  }

  void _handlePong(Map<String, dynamic> payload) {
    final publicKey = payload['publicKey'] as String;
    final completer = _pingCompleters[publicKey];
    if (completer != null && !completer.isCompleted) {
      completer.complete(true);
      _pingCompleters.remove(publicKey);
    }
  }

  Future<void> _handleIncomingMessage(Map<String, dynamic> payload, String remoteAddress) async {
    final senderPublicKey = payload['senderId'] as String;
    final encryptedContent = payload['content'] as String;
    final messageId = payload['messageId'] as String;

    final contact = _findContactByPublicKey(senderPublicKey);
    if (contact == null) return;

    if (contact.ipAddress != remoteAddress) {
      contact.ipAddress = remoteAddress;
      await StorageService.updateContact(contact);
    }

    if (contact.sharedSecret == null) return;

    final decryptedContent = await EncryptionService.decryptMessage(encryptedContent, contact.sharedSecret!);
    final message = Message(
      id: messageId,
      contactId: contact.id,
      content: decryptedContent,
      timestamp: DateTime.now(),
      isSent: false,
      status: MessageStatus.delivered,
    );

    await StorageService.saveMessage(message);
    _messageController.add(message);

    await NotificationService().showNotification('New message from ${contact.name}', decryptedContent);
    await _sendDeliveryAck(contact, messageId);
  }

  Contact? _findContactByPublicKey(String publicKey) {
    for (var contact in StorageService.getAllContacts()) {
      if (contact.publicKey == publicKey) return contact;
    }
    return null;
  }

  Future<void> _handleHandshake(Map<String, dynamic> payload, String remoteAddress) async {
    final senderPublicKey = payload['publicKey'] as String;
    final ciphertext = payload['ciphertext'] as String?;

    Contact? contact = _findContactByPublicKey(senderPublicKey);
    if (contact != null && contact.ipAddress != remoteAddress) {
      contact.ipAddress = remoteAddress;
      await StorageService.updateContact(contact);
    }

    // Trigger stranger flow for unknown contacts
    if (contact == null) {
      _contactRequestController.add({'publicKey': senderPublicKey, 'ipAddress': remoteAddress});
      return;
    }

    final profile = StorageService.getProfile();
    if (profile == null) return;

    // Case 1: Active KEM received
    if (ciphertext != null) {
      if (contact.sharedSecret == null) {
        try {
          contact.sharedSecret = await EncryptionService.decapsulate(ciphertext, profile.privateKey);
          await StorageService.updateContact(contact);
          _handshakeCompleters[senderPublicKey]?.complete();
          _sendJson({'type': 'handshake_response', 'publicKey': profile.publicKey}, contact.ipAddress);
        } catch (e) {
          _handshakeCompleters[senderPublicKey]?.completeError(e);
        }
      }
    } 
    // Case 2: Plain handshake received
    else {
      if (contact.sharedSecret != null) {
        contact.sharedSecret = null;
        await StorageService.updateContact(contact);
      }
      // Lexicographically larger public key initiates KEM tie-breaker
      if (profile.publicKey.compareTo(contact.publicKey) > 0) {
        try {
          final kemResult = await EncryptionService.encapsulate(contact.publicKey);
          contact.sharedSecret = kemResult['sharedSecret']!;
          await StorageService.updateContact(contact);
          _sendJson({
            'type': 'handshake',
            'publicKey': profile.publicKey,
            'ciphertext': kemResult['ciphertext']!,
          }, contact.ipAddress);
        } catch (e) {
          debugPrint('✗ KEM encapsulation failed: $e');
        }
      }
    }
  }

  Future<void> _handleHandshakeResponse(Map<String, dynamic> payload) async {
    final publicKey = payload['publicKey'] as String;
    final contact = _findContactByPublicKey(publicKey);
    if (contact != null) {
      _handshakeCompleters[publicKey]?.complete();
    }
  }

  Future<void> _handleDeliveryAck(Map<String, dynamic> payload) async {
    final messageId = payload['messageId'] as String;
    final message = StorageService.messagesBox.get(messageId);
    if (message != null) {
      message.status = MessageStatus.delivered;
      await StorageService.updateMessage(message);
    }
  }

  Future<void> _handleReadAck(Map<String, dynamic> payload) async {
    final messageId = payload['messageId'] as String;
    final message = StorageService.messagesBox.get(messageId);
    if (message != null) {
      message.status = MessageStatus.read;
      await StorageService.updateMessage(message);
    }
  }

  Future<bool> sendPing(Contact contact) async {
    try {
      final profile = StorageService.getProfile();
      if (profile == null) return false;

      final completer = Completer<bool>();
      _pingCompleters[contact.publicKey] = completer;
      
      await _sendJson({'type': 'ping', 'publicKey': profile.publicKey}, contact.ipAddress);
      
      Future.delayed(const Duration(seconds: 10), () {
        if (!completer.isCompleted) {
          completer.complete(false);
          _pingCompleters.remove(contact.publicKey);
        }
      });
      return await completer.future;
    } catch (e) {
      return false;
    }
  }

  Future<void> initiateHandshake(Contact contact) async {
    try {
      final profile = StorageService.getProfile();
      if (profile == null) return;

      Map<String, dynamic> handshake;
      // Evaluate if we are the connection initiator based on PK lexicography
      if (contact.sharedSecret == null) {
        if (profile.publicKey.compareTo(contact.publicKey) > 0) {
          final kemResult = await EncryptionService.encapsulate(contact.publicKey);
          contact.sharedSecret = kemResult['sharedSecret']!;
          await StorageService.updateContact(contact);
          handshake = {
            'type': 'handshake', 
            'publicKey': profile.publicKey, 
            'ciphertext': kemResult['ciphertext']!
          };
        } else {
          handshake = {'type': 'handshake', 'publicKey': profile.publicKey};
        }
      } else {
        handshake = {'type': 'handshake', 'publicKey': profile.publicKey};
      }
      
      await _sendJson(handshake, contact.ipAddress);
    } catch (e) {
      debugPrint('✗ Handshake failed: $e');
    }
  }

  Future<bool> sendMessage(Message message, Contact contact) async {
    try {
      if (contact.sharedSecret == null) {
        final completer = _handshakeCompleters.putIfAbsent(contact.publicKey, () => Completer<void>());
        initiateHandshake(contact);
        try {
          await completer.future.timeout(const Duration(seconds: 10));
        } catch (e) {
          _handshakeCompleters.remove(contact.publicKey);
          throw Exception('Handshake failed during message initiation');
        } finally {
          _handshakeCompleters.remove(contact.publicKey);
        }
        
        if (contact.sharedSecret == null) throw Exception('No shared secret after handshake');
      }

      final encryptedContent = await EncryptionService.encryptMessage(message.content, contact.sharedSecret!);
      final profile = StorageService.getProfile();
      if (profile == null) return false;

      final payload = {
        'type': 'message',
        'senderId': profile.publicKey,
        'messageId': message.id,
        'content': encryptedContent,
        'timestamp': message.timestamp.toIso8601String(),
      };

      await _sendJson(payload, contact.ipAddress);
      return true;
    } catch (e) {
      message.status = MessageStatus.failed;
      await StorageService.updateMessage(message);
      return false;
    }
  }

  Future<void> _sendDeliveryAck(Contact contact, String messageId) async {
    await _sendJson({'type': 'delivery_ack', 'messageId': messageId}, contact.ipAddress);
  }

  Future<void> sendReadAck(Contact contact, String messageId) async {
    await _sendJson({'type': 'read_ack', 'messageId': messageId}, contact.ipAddress);
  }

  Future<void> _sendJson(Map<String, dynamic> payload, String targetIp) async {
    try {
      final socket = await _getOrCreateConnection(targetIp);
      if (socket != null) {
        final line = jsonEncode(payload) + '\n'; // newline framed json over tcp stream
        socket.write(line);
        await socket.flush();
      } else {
        debugPrint('✗ Could not establish TCP connection to $targetIp');
      }
    } catch (e) {
      debugPrint('✗ Failed to send JSON payload to [$targetIp]: $e');
    }
  }

  void dispose() {
    _serverSocket?.close();
    _closeAllConnections();
    _messageController.close();
    _contactRequestController.close();
  }
}
