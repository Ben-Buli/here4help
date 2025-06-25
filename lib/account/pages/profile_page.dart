// home_page.dart
import 'package:flutter/material.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? editingField;
  String firstName = 'Jack';
  String lastName = 'Wu';
  String email = 'Jackywu@gmail.com';
  String phone = '0912345678';
  String dob = '2000-02-29';
  String gender = 'Male';
  String school = 'NCCU';
  String aboutMe =
      "Hi, I'm Jack! I'm currently studying at National Chengchi University. I enjoy making new friends, have a good command of English, and love helping others!";
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                const CircleAvatar(
                  radius: 48,
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.person, size: 60, color: Colors.white),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(8),
                      backgroundColor: Colors.blue,
                    ),
                    onPressed: () {
                      // TODO: 編輯頭像
                    },
                    child:
                        const Icon(Icons.edit, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () {
                // TODO: 編輯頭像
              },
              child: const Text('Edit My Resume'),
            ),
          ),
          const SizedBox(height: 12),
          // ... 其餘 profile 欄位 ...
        ],
      ),
    );
  }
}
