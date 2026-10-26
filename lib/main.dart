import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  // التأكد من تهيئة أدوات فلاتر قبل تشغيل الـ Async
  WidgetsFlutterBinding.ensureInitialized();
  // ربط التطبيق بسيرفر Firebase
  await Firebase.initializeApp(); 
  runApp(AlKaserApp());
}

class AlKaserApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'الكاسر أب العالمي',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: AuthGate(), // فحص حالة المستخدم (مسجل دخول أم لا)
    );
  }
}

// مكون لفحص حالة المستخدم وتوجيهه للشاشة المناسبة
class AuthGate extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(), // مراقبة حالة تسجيل الدخول
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        // إذا كان المستخدم مسجلاً دخوله، نتوجه لشاشة المحادثة مباشرة
        if (snapshot.hasData) {
          return ChatScreen();
        }
        // إذا لم يكن مسجلاً، نتوجه لشاشة تسجيل الدخول المجهول (لتسهيل التجربة أولاً)
        return LoginScreen();
      },
    );
  }
}

// شاشة تسجيل دخول مبسطة (مجهول كمثال سريع)
class LoginScreen extends StatelessWidget {
  void _loginAnonymously(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تسجيل الدخول: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('تسجيل الدخول - الكاسر أب')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _loginAnonymously(context),
          child: Text('الدخول كزائر سريع', style: TextStyle(fontSize: 18)),
          style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
        ),
      ),
    );
  }
}

// الشاشة الرئيسية للمحادثة
class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // دالة إرسال الرسالة إلى Firestore
  void _sendMessage() async {
    if (_messageController.text.trim().isNotEmpty) {
      String msg = _messageController.text.trim();
      _messageController.clear(); // مسح الحقل فوراً لتجربة مستخدم سلسة

      await _firestore.collection('messages').add({
        'text': msg,
        'senderId': _auth.currentUser?.uid ?? 'مجهول',
        'createdAt': FieldValue.serverTimestamp(), // ترتيب الرسائل بالوقت بدقة
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('غرفة المحادثة العالمية'),
        actions: [
          IconButton(
            icon: Icon(Icons.exit_to_app),
            onPressed: () => _auth.signOut(), // تسجيل الخروج
          )
        ],
      ),
      body: Column(
        children: [
          // عرض الرسائل مباشرة من Firestore (Stream)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('messages')
                  .orderBy('createdAt', descending: true) // عرض الأحدث في الأسفل
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('لا توجد رسائل بعد.. ابدأ المحادثة!'));
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true, // لجعل الرسائل تبدأ من الأسفل
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    bool isMe = data['senderId'] == _auth.currentUser?.uid;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue : Colors.grey[300],
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          data['text'] ?? '',
                          style: TextStyle(color: isMe ? Colors.white : Colors.black),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // حقل إدخال الرسالة وزر الإرسال
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'اكتب رسالتك هنا...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send, color: Colors.blue),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
