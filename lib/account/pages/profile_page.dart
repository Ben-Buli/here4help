import 'package:flutter/material.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // 控制每個欄位是否進入編輯狀態
  String? editingField;

  // 假資料
  String firstName = 'Jack';
  String lastName = 'Wu';
  String email = 'Jackywu@gmail.com';
  String phone = '0912345678';
  String dob = '2000-02-29';
  String gender = 'Male';
  String school = 'NCCU';
  String aboutMe =
      "Hi, I'm Jack! I'm currently studying at National Chengchi University. I enjoy making new friends, have a good command of English, and love helping others!";

  // 編輯暫存
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
          // 頭像與 Edit
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
          // Name 欄位
          _profileField(
            label: 'Name',
            value: '$firstName $lastName',
            fieldKey: 'name',
            isEditing: editingField == 'name',
            editWidget: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: firstNameController..text = firstName,
                    decoration: const InputDecoration(labelText: 'First Name'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: lastNameController..text = lastName,
                    decoration: const InputDecoration(labelText: 'Last Name'),
                  ),
                ),
              ],
            ),
            onEdit: () {
              setState(() {
                editingField = 'name';
              });
            },
            onCancel: () {
              setState(() {
                editingField = null;
              });
            },
            onDone: () {
              setState(() {
                firstName = firstNameController.text;
                lastName = lastNameController.text;
                editingField = null;
              });
            },
          ),
          // Email
          _profileField(
            label: 'Email',
            value: email,
            fieldKey: 'email',
            isEditing: editingField == 'email',
            editWidget: TextField(
              controller: TextEditingController(text: email),
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            onEdit: () {
              setState(() {
                editingField = 'email';
              });
            },
            onCancel: () {
              setState(() {
                editingField = null;
              });
            },
            onDone: () {
              // TODO: 更新 email
              setState(() {
                editingField = null;
              });
            },
          ),
          // Phone
          _profileField(
            label: 'Phone',
            value: phone,
            fieldKey: 'phone',
            isEditing: editingField == 'phone',
            editWidget: TextField(
              controller: TextEditingController(text: phone),
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            onEdit: () {
              setState(() {
                editingField = 'phone';
              });
            },
            onCancel: () {
              setState(() {
                editingField = null;
              });
            },
            onDone: () {
              // TODO: 更新 phone
              setState(() {
                editingField = null;
              });
            },
          ),
          // Date of Birth
          _profileField(
            label: 'Date of Birth',
            value: dob,
            fieldKey: 'dob',
            isEditing: editingField == 'dob',
            editWidget: TextField(
              controller: TextEditingController(text: dob),
              decoration: const InputDecoration(labelText: 'Date of Birth'),
            ),
            onEdit: () {
              setState(() {
                editingField = 'dob';
              });
            },
            onCancel: () {
              setState(() {
                editingField = null;
              });
            },
            onDone: () {
              // TODO: 更新 dob
              setState(() {
                editingField = null;
              });
            },
          ),
          // Gender
          _profileField(
            label: 'Gender',
            value: gender,
            fieldKey: 'gender',
            isEditing: editingField == 'gender',
            editWidget: TextField(
              controller: TextEditingController(text: gender),
              decoration: const InputDecoration(labelText: 'Gender'),
            ),
            onEdit: () {
              setState(() {
                editingField = 'gender';
              });
            },
            onCancel: () {
              setState(() {
                editingField = null;
              });
            },
            onDone: () {
              // TODO: 更新 gender
              setState(() {
                editingField = null;
              });
            },
          ),
          // School
          _profileField(
            label: 'School',
            value: school,
            fieldKey: 'school',
            isEditing: editingField == 'school',
            editWidget: TextField(
              controller: TextEditingController(text: school),
              decoration: const InputDecoration(labelText: 'School'),
            ),
            onEdit: () {
              setState(() {
                editingField = 'school';
              });
            },
            onCancel: () {
              setState(() {
                editingField = null;
              });
            },
            onDone: () {
              // TODO: 更新 school
              setState(() {
                editingField = null;
              });
            },
          ),
          // About Me
          _profileField(
            label: 'About Me',
            value: aboutMe,
            fieldKey: 'aboutMe',
            isEditing: editingField == 'aboutMe',
            editWidget: TextField(
              controller: TextEditingController(text: aboutMe),
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'About Me'),
            ),
            onEdit: () {
              setState(() {
                editingField = 'aboutMe';
              });
            },
            onCancel: () {
              setState(() {
                editingField = null;
              });
            },
            onDone: () {
              // TODO: 更新 aboutMe
              setState(() {
                editingField = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _profileField({
    required String label,
    required String value,
    required String fieldKey,
    required bool isEditing,
    required Widget editWidget,
    required VoidCallback onEdit,
    required VoidCallback onCancel,
    required VoidCallback onDone,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              onPressed: onEdit,
            ),
          ],
        ),
        if (!isEditing)
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(value),
          ),
        if (isEditing)
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                editWidget,
                Row(
                  children: [
                    TextButton(
                      onPressed: onCancel,
                      child: const Text('Cancel',
                          style: TextStyle(color: Colors.red)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: onDone,
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        const Divider(),
      ],
    );
  }
}
