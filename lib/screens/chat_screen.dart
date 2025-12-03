import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;

  const ChatScreen({
    Key? key,
    required this.receiverId,
    required this.receiverName,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  late String chatRoomId;
  final currentUser = FirebaseAuth.instance.currentUser!;
  final DatabaseReference _rtdb = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    chatRoomId = _getChatRoomId();
    _updateTypingStatus(false);
  }

  String _getChatRoomId() {
    List<String> ids = [currentUser.uid, widget.receiverId];
    ids.sort();
    return ids.join('_');
  }

  Future<void> _updateTypingStatus(bool isTyping) async {
    await _rtdb.child('typing/$chatRoomId/${currentUser.uid}').set({
      'isTyping': isTyping,
    });
  }

  void _markMessagesAsRead(List<QueryDocumentSnapshot> docs) {
    final batch = FirebaseFirestore.instance.batch();
    bool needsUpdate = false;

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['receiverId'] == currentUser.uid && data['read'] == false) {
        batch.update(doc.reference, {'read': true});
        needsUpdate = true;
      }
    }

    if (needsUpdate) {
      batch.commit();
    }
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    _messageController.clear();
    _updateTypingStatus(false);

    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatRoomId)
          .collection('messages')
          .add({
        'text': messageText,
        'senderId': currentUser.uid,
        'receiverId': widget.receiverId,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    }
  }

  @override
  void dispose() {
    _updateTypingStatus(false);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatLastSeen(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return 'Last seen ${DateFormat('MMM d').format(date)}';
    } else if (difference.inHours > 0) {
      return 'Last seen ${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return 'Last seen ${difference.inMinutes}m ago';
    } else {
      return 'Last seen just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.receiverName),
            StreamBuilder(
              stream: _rtdb.child('typing/$chatRoomId/${widget.receiverId}').onValue,
              builder: (context, AsyncSnapshot<DatabaseEvent> typingSnapshot) {
                if (typingSnapshot.hasData && typingSnapshot.data!.snapshot.value != null) {
                  final data = typingSnapshot.data!.snapshot.value as Map;
                  if (data['isTyping'] == true) {
                    return const Text(
                      'typing...',
                      style: TextStyle(fontSize: 12, color: Colors.greenAccent, fontStyle: FontStyle.italic),
                    );
                  }
                }

                return StreamBuilder(
                  stream: _rtdb.child('status/${widget.receiverId}').onValue,
                  builder: (context, AsyncSnapshot<DatabaseEvent> statusSnapshot) {
                    if (statusSnapshot.hasData && statusSnapshot.data!.snapshot.value != null) {
                      final data = statusSnapshot.data!.snapshot.value as Map;
                      final isOnline = data['isOnline'] ?? false;
                      final lastSeen = data['lastSeen'] as int?;

                      return Text(
                        isOnline ? 'Online' : (lastSeen != null ? _formatLastSeen(lastSeen) : 'Offline'),
                        style: TextStyle(
                          fontSize: 12, 
                          color: isOnline ? Colors.blueAccent : Colors.grey
                        ),
                      );
                    }
                    return const Text('Offline', style: TextStyle(fontSize: 12, color: Colors.grey));
                  },
                );
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(chatRoomId)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Say Hi!'));
                }

                final messages = snapshot.data!.docs;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                   _markMessagesAsRead(messages);
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index].data() as Map<String, dynamic>;
                    final isMe = message['senderId'] == currentUser.uid;
                    final isRead = message['read'] ?? false;
                    final timestamp = message['timestamp'] as Timestamp?;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          // Sent messages: Dark Blue, Received: Dark Grey
                          color: isMe ? Colors.blue.shade900 : const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              message['text'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (timestamp != null)
                                  Text(
                                    DateFormat('HH:mm').format(timestamp.toDate()),
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 10,
                                    ),
                                  ),
                                if (isMe) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    isRead ? Icons.done_all : Icons.check,
                                    size: 16,
                                    // Blue ticks for read, grey for sent
                                    color: isRead ? Colors.lightBlueAccent : Colors.grey,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      // Background of input area blends with scaffold
      color: Colors.black,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(color: Colors.grey.shade600),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                // Input box background
                fillColor: const Color(0xFF1E1E1E),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              onChanged: (text) {
                _updateTypingStatus(text.isNotEmpty);
              },
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: Colors.blue.shade800,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}