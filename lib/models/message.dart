import 'package:hive/hive.dart';

part 'message.g.dart';

@HiveType(typeId: 2)
class Message extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String contactId;

  @HiveField(2)
  String content;

  @HiveField(3)
  DateTime timestamp;

  @HiveField(4)
  bool isSent;

  @HiveField(5)
  MessageStatus status;

  Message({
    required this.id,
    required this.contactId,
    required this.content,
    required this.timestamp,
    required this.isSent,
    this.status = MessageStatus.sent,
  });
}

@HiveType(typeId: 3)
enum MessageStatus {
  @HiveField(0)
  sent,
  
  @HiveField(1)
  delivered,
  
  @HiveField(2)
  failed,

  @HiveField(3)
  read,
}
