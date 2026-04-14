import 'package:hive/hive.dart';

part 'profile.g.dart';

@HiveType(typeId: 0)
class Profile extends HiveObject {
  @HiveField(0)
  String displayName;

  @HiveField(1)
  String? avatarPath;

  @HiveField(2)
  String publicKey;

  @HiveField(3)
  String privateKey;

  @HiveField(4)
  String ipv6Address;

  Profile({
    required this.displayName,
    this.avatarPath,
    required this.publicKey,
    required this.privateKey,
    required this.ipv6Address,
  });
}
