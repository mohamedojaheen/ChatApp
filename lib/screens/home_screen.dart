import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final currentUser = FirebaseAuth.instance.currentUser!;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setUserStatus(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setUserStatus(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setUserStatus(true);
    } else {
      _setUserStatus(false);
    }
  }

  Future<void> _setUserStatus(bool isOnline) async {
    await _database.child('status/${currentUser.uid}').set({
      'isOnline': isOnline,
      'lastSeen': ServerValue.timestamp,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _setUserStatus(false);
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Current User Header
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .snapshots(),
            builder: (context, snapshot) {
              String displayName = 'Me';
              String email = currentUser.email ?? '';
              
              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                displayName = data['name'] ?? 'Me';
              }

              return Container(
                padding: const EdgeInsets.all(16),
                color: const Color(0xFF1E1E1E),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.blue.shade900,
                      child: Text(
                        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontSize: 24,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            email,
                            style: TextStyle(color: Colors.grey.shade400),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          
          const Padding(
            padding: EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Users',
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // Users List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where(FieldPath.documentId, isNotEqualTo: currentUser.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No users found'));
                }

                final users = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index].data() as Map<String, dynamic>;
                    final userId = users[index].id;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.blue.shade900,
                              child: Text(
                                user['name'][0].toUpperCase(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: StreamBuilder<DatabaseEvent>(
                                stream: _database.child('status/$userId').onValue,
                                builder: (context, statusSnapshot) {
                                  if (statusSnapshot.hasData &&
                                      statusSnapshot.data!.snapshot.value != null) {
                                    final status = statusSnapshot.data!.snapshot.value as Map;
                                    final isOnline = status['isOnline'] ?? false;
                                    return Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: isOnline ? Colors.greenAccent : Colors.grey,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.black, width: 2),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                          ],
                        ),
                        title: Text(
                          user['name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        subtitle: Text(
                          user['email'],
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                receiverId: userId,
                                receiverName: user['name'],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}