import 'package:hive/hive.dart';

part 'contact.g.dart';

@HiveType(typeId: 1)
class Contact extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String ipAddress;

  @HiveField(3)
  String publicKey;

  @HiveField(4)
  String? lastMessage;

  @HiveField(5)
  DateTime? lastMessageTime;

  @HiveField(6)
  String? sharedSecret;

  Contact({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.publicKey,
    this.lastMessage,
    this.lastMessageTime,
    this.sharedSecret,
  });
}
