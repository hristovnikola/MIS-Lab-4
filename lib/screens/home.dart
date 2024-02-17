import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:lab3_201097/widgets/authentication.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/Exam.dart';
import '../widgets/add_new.dart';
import '../screens/calendar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CollectionReference _itemsCollection =
      FirebaseFirestore.instance.collection('exams');
  List<Exam> _exams = [];
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  String? _deviceToken;

  static void initialize() {
    // Initialization  setting for android
    const InitializationSettings initializationSettingsAndroid =
        InitializationSettings(
      android: AndroidInitializationSettings('image'),
    );
    _notificationsPlugin.initialize(
      initializationSettingsAndroid,
      // to handle event when we receive notification
      onDidReceiveNotificationResponse: (details) {
        if (details.input != null) {}
      },
    );
  }

  Future<void> _requestNotificationPermission() async {
    PermissionStatus status = await Permission.notification.request();
    if (status.isGranted) {
      print("Notification permission granted");
    } else if (status.isDenied) {
      print("Notification permission denied");
    } else if (status.isPermanentlyDenied) {
      print("Notification permission permanently denied");
      // You might want to open the app settings in this case
      openAppSettings();
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    initialize();
    _requestNotificationPermission();

    OneSignal.shared.setAppId("657ac24e-e486-475b-85ab-925e4654ddfc");

    OneSignal.shared
        .setNotificationOpenedHandler((OSNotificationOpenedResult result) {
      // Handle notification open
    });

    FirebaseMessaging.instance.getToken().then((token) {
      _deviceToken = token;
    });

    // To initialise when app is not terminated
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      // Handle initial message
    });

    FirebaseMessaging.onMessage.listen((message) {
      if (message.notification != null) {
        display(message);
      }
    });
  }

  Future<void> requestPermission() async {
    await OneSignal.shared.promptUserForPushNotificationPermission();
  }

  static Future<void> display(RemoteMessage message) async {
    // To display the notification in device
    try {
      print(message.notification!.android!.sound);
      final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      NotificationDetails notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
            message.notification!.android!.sound ?? "Channel Id",
            message.notification!.android!.sound ?? "Main Channel",
            groupKey: "gfg",
            color: Colors.green,
            importance: Importance.max,
            sound: RawResourceAndroidNotificationSound(
                message.notification!.android!.sound ?? "gfg"),

            // different sound for
            // different notification
            playSound: true,
            priority: Priority.high),
      );
      await _notificationsPlugin.show(id, message.notification?.title,
          message.notification?.body, notificationDetails,
          payload: message.data['route']);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void _addExam() {
    showModalBottomSheet(
        context: context,
        builder: (_) {
          return GestureDetector(
            onTap: () {},
            behavior: HitTestBehavior.opaque,
            child: NewExam(
              addExam: _addNewExamToDatabase,
            ),
          );
        });
  }

  void _addNewExamToDatabase(String subject, DateTime date, TimeOfDay time) {
    addExam(subject, date, time);
  }

  Future<void> addExam(String subject, DateTime date, TimeOfDay time) {
    User? user = FirebaseAuth.instance.currentUser;
    DateTime newDate = DateTime(
        date.year, date.month, date.day, time.hour, time.minute, 0, 0, 0);
    if (user != null) {
      return FirebaseFirestore.instance
          .collection('exams')
          .add({'subject': subject, 'date': newDate, 'userId': user.uid});
    }

    return FirebaseFirestore.instance
        .collection('exams')
        .add({'subject': subject, 'date': newDate, 'userId': 'invalid'});
  }

  Future<void> _signOutAndNavigateToLogin(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => AuthGate()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      print('Error during sign out: $e');
    }
  }

  void _deleteExam(String subject, DateTime date) {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      var query = _itemsCollection
          .where('subject', isEqualTo: subject)
          .where('date', isEqualTo: date)
          .where('userId', isEqualTo: user.uid);

      query.get().then((querySnapshot) {
        querySnapshot.docs.forEach((doc) {
          _itemsCollection.doc(doc.id).delete();
        });
      });
    }
  }

  void _goToCalendar() {
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => CalendarScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("201097"),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          actions: [
            ElevatedButton(
              onPressed: () => _addExam(),
              style: const ButtonStyle(
                  backgroundColor:
                      MaterialStatePropertyAll<Color>(Colors.deepPurpleAccent)),
              child: const Text(
                "Add exam date",
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: () => _signOutAndNavigateToLogin(context),
              style: const ButtonStyle(
                  backgroundColor: MaterialStatePropertyAll<Color>(Colors.red)),
              child: const Text(
                "Sign out",
                style: TextStyle(
                    color: Color.fromRGBO(49, 49, 131, 1),
                    fontWeight: FontWeight.bold),
              ),
            )
          ],
        ),
        body: StreamBuilder<QuerySnapshot>(
            stream: _itemsCollection
                .where('userId',
                    isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return CircularProgressIndicator();
              }

              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }

              // If the data is ready, convert it to a list of MyItem
              List<Exam> items =
                  snapshot.data!.docs.map((DocumentSnapshot doc) {
                return Exam.fromMap(doc.data() as Map<String, dynamic>);
              }).toList();

              // Now you have a list of items, you can use it as needed
              return GridView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  return Card(
                    child: Stack(
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Display Exam details
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  items[index].subject,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 30,
                                      color: Color.fromRGBO(49, 49, 131, 1)),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  DateFormat('yyyy-MM-dd HH:mm')
                                      .format(items[index].date),
                                  style: const TextStyle(
                                      fontSize: 20,
                                      color: Color.fromRGBO(42, 147, 209, 1)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Positioned(
                          top: 7.0,
                          // Adjust the top position according to your preference
                          right: 7.0,
                          // Adjust the right position according to your preference
                          child: IconButton(
                            icon: Icon(Icons.delete_forever_rounded),
                            onPressed: () {
                              _deleteExam(
                                  items[index].subject, items[index].date);
                            },
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  );
                },
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                ),
              );
            }),
        floatingActionButton: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton(
                onPressed: _goToCalendar,
                style: const ButtonStyle(
                  backgroundColor: MaterialStatePropertyAll<Color>(
                      Color.fromRGBO(55, 220, 214, 1)),
                ),
                child: const Row(
                  children: [
                    Text(
                      "View calendar",
                      style: TextStyle(color: Colors.white),
                    ),
                    Icon(
                      Icons.calendar_today,
                      color: Colors.white,
                    )
                  ],
                ))
          ],
        ));
  }
}
