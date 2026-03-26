import 'package:flutter/foundation.dart';

class ProfileModel extends ChangeNotifier {
  String name;
  String bio;
  String avatarPath;

  ProfileModel({
    this.name = 'Ayush',
    this.bio = 'Flutter developer with 45% coffee and 55% code',
    this.avatarPath = 'assets/images/user1.png',
  });

  void updateName(String value) {
    name = value;
    notifyListeners();
  }

  void updateBio(String value) {
    bio = value;
    notifyListeners();
  }

  void updateAvatar(String path) {
    avatarPath = path;
    notifyListeners();
  }
}
