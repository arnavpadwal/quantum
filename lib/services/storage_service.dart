import 'package:hive_flutter/hive_flutter.dart';
import '../models/profile.dart';
import '../models/contact.dart';
import '../models/message.dart';

class StorageService {
  static const String _profileBox = 'profile';
  static const String _contactsBox = 'contacts';
  static const String _messagesBox = 'messages';

  static const String _settingsBox = 'settings';

  static late Box<Profile> _profile;
  static late Box<Contact> _contacts;
  static late Box<Message> _messages;
  static late Box _settings;

  static Future<void> init() async {
    _profile = await Hive.openBox<Profile>(_profileBox);
    _contacts = await Hive.openBox<Contact>(_contactsBox);
    _messages = await Hive.openBox<Message>(_messagesBox);
    _settings = await Hive.openBox(_settingsBox);
  }

  // Settings operations
  static bool hasSeenOnboarding() {
    return _settings.get('hasSeenOnboarding', defaultValue: false);
  }

  static Future<void> setHasSeenOnboarding(bool value) async {
    await _settings.put('hasSeenOnboarding', value);
  }

  // Profile operations
  static Future<void> saveProfile(Profile profile) async {
    await _profile.put('user', profile);
  }

  static Profile? getProfile() {
    return _profile.get('user');
  }

  static Future<bool> hasProfile() async {
    return _profile.isNotEmpty;
  }

  // Contact operations
  static Future<void> saveContact(Contact contact) async {
    await _contacts.put(contact.id, contact);
  }

  static Contact? getContact(String id) {
    return _contacts.get(id);
  }

  static List<Contact> getAllContacts() {
    return _contacts.values.toList()
      ..sort((a, b) {
        if (a.lastMessageTime == null && b.lastMessageTime == null) return 0;
        if (a.lastMessageTime == null) return 1;
        if (b.lastMessageTime == null) return -1;
        return b.lastMessageTime!.compareTo(a.lastMessageTime!);
      });
  }

  static Future<void> updateContact(Contact contact) async {
    await contact.save();
  }

  static Future<void> addContact(Contact contact) async {
    await _contacts.put(contact.id, contact);
  }

  static Future<void> deleteContact(String id) async {
    await _contacts.delete(id);
    final messages = getMessagesForContact(id);
    for (var msg in messages) {
      await msg.delete();
    }
  }

  // Message operations
  static Future<void> saveMessage(Message message) async {
    await _messages.put(message.id, message);
    
    final contact = getContact(message.contactId);
    if (contact != null) {
      contact.lastMessage = message.content;
      contact.lastMessageTime = message.timestamp;
      await updateContact(contact);
    }
  }

  static List<Message> getMessagesForContact(String contactId) {
    return _messages.values
        .where((msg) => msg.contactId == contactId)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  static Future<void> updateMessage(Message message) async {
    await message.save();
  }

  static Box<Contact> get contactsBox => _contacts;
  static Box<Message> get messagesBox => _messages;
}
