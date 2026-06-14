// School Hub — role-based school app (student / leadership / admin).
// Visual language: neo-brutalist sticker book — hard 2px borders, chunky
// offset shadows, vivid accents, big bold type. Light + dark themes.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  await state.load();
  runApp(SchoolHubApp(state: state));
}

// ─────────────────────────────────────────────────────────────────────────────
// BRAND + THEME
// ─────────────────────────────────────────────────────────────────────────────

class Brand {
  // light tones
  static const bg = Color(0xFFFAF8FF);
  static const paper = Colors.white;
  static const ink = Color(0xFF0F0B1F);
  static const mute = Color(0xFF6B6786);
  static const line = Color(0xFF0F0B1F);
  static const lineSoft = Color(0xFFE9E5F4);

  // dark tones
  static const bgDark = Color(0xFF0E0B1F);
  static const paperDark = Color(0xFF1A1535);
  static const inkDark = Color(0xFFF5F2FF);
  static const muteDark = Color(0xFFA8A3C2);
  static const lineDark = Color(0xFFF5F2FF);
  static const lineSoftDark = Color(0xFF2C2550);

  // accents (work in both modes)
  static const purple = Color(0xFF7C3AED);
  static const purpleSoft = Color(0xFFEDE4FF);
  static const purpleSoftDark = Color(0xFF3A2C7A);
  static const pink = Color(0xFFEC4899);
  static const pinkSoft = Color(0xFFFCE7F3);
  static const pinkSoftDark = Color(0xFF6B1E47);
  static const lime = Color(0xFFD9F99D);
  static const limeInk = Color(0xFF4D7C0F);
  static const coral = Color(0xFFFB7185);
  static const coralSoft = Color(0xFFFFE4E6);
  static const coralSoftDark = Color(0xFF6B1E27);
  static const sky = Color(0xFF38BDF8);
  static const skySoft = Color(0xFFE0F2FE);
  static const skySoftDark = Color(0xFF143352);
  static const sun = Color(0xFFFBBF24);
  static const sunSoft = Color(0xFFFEF3C7);
  static const sunSoftDark = Color(0xFF5C3E0E);
  static const mint = Color(0xFF34D399);
  static const mintSoft = Color(0xFFD1FAE5);
  static const mintSoftDark = Color(0xFF064E3B);
  static const danger = Color(0xFFE11D48);

  static Color roleColor(UserRole r) {
    switch (r) {
      case UserRole.admin: return coral;
      case UserRole.leadership: return sun;
      case UserRole.student: return purple;
    }
  }

  static String roleLabel(UserRole r) {
    switch (r) {
      case UserRole.admin: return 'Admin';
      case UserRole.leadership: return 'Leadership';
      case UserRole.student: return 'Student';
    }
  }
}

class Tones {
  final Color bg, paper, ink, mute, line, lineSoft, primaryWash;
  final bool isDark;
  const Tones({
    required this.bg, required this.paper, required this.ink, required this.mute,
    required this.line, required this.lineSoft, required this.primaryWash,
    required this.isDark,
  });
  static const light = Tones(
    bg: Brand.bg, paper: Brand.paper, ink: Brand.ink, mute: Brand.mute,
    line: Brand.line, lineSoft: Brand.lineSoft, primaryWash: Brand.purpleSoft,
    isDark: false,
  );
  static const dark = Tones(
    bg: Brand.bgDark, paper: Brand.paperDark, ink: Brand.inkDark, mute: Brand.muteDark,
    line: Brand.lineDark, lineSoft: Brand.lineSoftDark, primaryWash: Brand.purpleSoftDark,
    isDark: true,
  );
  static Tones of(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? dark : light;
}

/// The signature card look: hard 2px border + flat offset shadow.
BoxDecoration sticker(Tones t, {
  Color? fill,
  Color? border,
  double radius = 18,
  Offset offset = const Offset(4, 4),
}) {
  final b = border ?? t.line;
  return BoxDecoration(
    color: fill ?? t.paper,
    border: Border.all(color: b, width: 2),
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [BoxShadow(color: b, offset: offset, blurRadius: 0)],
  );
}

ThemeData _buildTheme(Tones t) {
  final cs = t.isDark
      ? const ColorScheme.dark(primary: Brand.purple).copyWith(
          primary: Brand.purple, secondary: Brand.pink,
          surface: Brand.paperDark, onSurface: Brand.inkDark)
      : const ColorScheme.light(primary: Brand.purple).copyWith(
          primary: Brand.purple, secondary: Brand.pink,
          surface: Brand.paper, onSurface: Brand.ink);
  return ThemeData(
    useMaterial3: true,
    brightness: t.isDark ? Brightness.dark : Brightness.light,
    colorScheme: cs,
    scaffoldBackgroundColor: t.bg,
    appBarTheme: AppBarTheme(
      backgroundColor: t.bg,
      foregroundColor: t.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: t.ink, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.6,
      ),
      iconTheme: IconThemeData(color: t.ink),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: t.paper,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: t.line, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: t.line, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Brand.purple, width: 3),
      ),
      labelStyle: TextStyle(color: t.mute, fontWeight: FontWeight.w700),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: const WidgetStatePropertyAll(Brand.purple),
        foregroundColor: const WidgetStatePropertyAll(Colors.white),
        padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: t.line, width: 2),
        )),
        textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        elevation: const WidgetStatePropertyAll(0),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(t.ink),
        side: WidgetStatePropertyAll(BorderSide(color: t.line, width: 2)),
        padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        )),
        textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w700)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: t.paper,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Brand.purple.withValues(alpha: 0.15),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: t.ink),
      ),
      iconTheme: WidgetStatePropertyAll(IconThemeData(color: t.mute, size: 22)),
      height: 68,
    ),
    dividerColor: t.lineSoft,
    snackBarTheme: SnackBarThemeData(
      backgroundColor: t.ink,
      contentTextStyle: TextStyle(color: t.bg, fontWeight: FontWeight.w700),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: t.paper,
      side: BorderSide(color: t.line, width: 2),
      selectedColor: Brand.purpleSoft,
      labelStyle: TextStyle(color: t.ink, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────────────────

enum UserRole { student, leadership, admin }

UserRole _roleFromString(String s) =>
    UserRole.values.firstWhere((r) => r.name == s, orElse: () => UserRole.student);

class AppUser {
  String id;
  String name;
  String email;
  String password; // demo only — never store plaintext in real apps
  UserRole role;
  String bio;
  String grade;
  String avatarEmoji;
  bool disabled;
  DateTime createdAt;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    this.bio = '',
    this.grade = '',
    this.avatarEmoji = '🙂',
    this.disabled = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'password': password,
        'role': role.name,
        'bio': bio,
        'grade': grade,
        'avatarEmoji': avatarEmoji,
        'disabled': disabled,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'],
        name: j['name'],
        email: j['email'],
        password: j['password'],
        role: _roleFromString(j['role']),
        bio: j['bio'] ?? '',
        grade: j['grade'] ?? '',
        avatarEmoji: j['avatarEmoji'] ?? '🙂',
        disabled: j['disabled'] ?? false,
        createdAt: DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now(),
      );
}

class Announcement {
  String id;
  String authorId;
  String authorName;
  UserRole authorRole;
  String title;
  String body;
  DateTime createdAt;
  bool pinned;
  int colorSeed;
  Announcement({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    required this.title,
    required this.body,
    required this.createdAt,
    this.pinned = false,
    this.colorSeed = 0,
  });
  Map<String, dynamic> toJson() => {
        'id': id, 'authorId': authorId, 'authorName': authorName,
        'authorRole': authorRole.name, 'title': title, 'body': body,
        'createdAt': createdAt.toIso8601String(), 'pinned': pinned,
        'colorSeed': colorSeed,
      };
  factory Announcement.fromJson(Map<String, dynamic> j) => Announcement(
        id: j['id'], authorId: j['authorId'], authorName: j['authorName'],
        authorRole: _roleFromString(j['authorRole']),
        title: j['title'], body: j['body'],
        createdAt: DateTime.parse(j['createdAt']),
        pinned: j['pinned'] ?? false,
        colorSeed: j['colorSeed'] ?? 0,
      );
}

class Flyer {
  String id;
  String authorId;
  String authorName;
  String title;
  String description;
  String emoji;
  int colorSeed;
  DateTime createdAt;
  Flyer({
    required this.id, required this.authorId, required this.authorName,
    required this.title, required this.description, required this.emoji,
    required this.colorSeed, required this.createdAt,
  });
  Map<String, dynamic> toJson() => {
        'id': id, 'authorId': authorId, 'authorName': authorName,
        'title': title, 'description': description, 'emoji': emoji,
        'colorSeed': colorSeed, 'createdAt': createdAt.toIso8601String(),
      };
  factory Flyer.fromJson(Map<String, dynamic> j) => Flyer(
        id: j['id'], authorId: j['authorId'], authorName: j['authorName'],
        title: j['title'], description: j['description'],
        emoji: j['emoji'] ?? '📣', colorSeed: j['colorSeed'] ?? 0,
        createdAt: DateTime.parse(j['createdAt']),
      );
}

class ResourceLink {
  String id;
  String authorId;
  String title;
  String url;
  String category;
  String description;
  DateTime createdAt;
  ResourceLink({
    required this.id, required this.authorId, required this.title,
    required this.url, required this.category, required this.description,
    required this.createdAt,
  });
  Map<String, dynamic> toJson() => {
        'id': id, 'authorId': authorId, 'title': title, 'url': url,
        'category': category, 'description': description,
        'createdAt': createdAt.toIso8601String(),
      };
  factory ResourceLink.fromJson(Map<String, dynamic> j) => ResourceLink(
        id: j['id'], authorId: j['authorId'], title: j['title'],
        url: j['url'], category: j['category'] ?? 'Other',
        description: j['description'] ?? '',
        createdAt: DateTime.parse(j['createdAt']),
      );
}

class Event {
  String id;
  String title;
  String description;
  DateTime date;
  String location;
  bool ticketed;
  double ticketPrice;
  int ticketsAvailable;
  int ticketsSold;
  Event({
    required this.id, required this.title, required this.description,
    required this.date, required this.location, required this.ticketed,
    required this.ticketPrice, required this.ticketsAvailable,
    this.ticketsSold = 0,
  });
  Map<String, dynamic> toJson() => {
        'id': id, 'title': title, 'description': description,
        'date': date.toIso8601String(), 'location': location,
        'ticketed': ticketed, 'ticketPrice': ticketPrice,
        'ticketsAvailable': ticketsAvailable, 'ticketsSold': ticketsSold,
      };
  factory Event.fromJson(Map<String, dynamic> j) => Event(
        id: j['id'], title: j['title'], description: j['description'],
        date: DateTime.parse(j['date']), location: j['location'],
        ticketed: j['ticketed'] ?? false,
        ticketPrice: (j['ticketPrice'] as num?)?.toDouble() ?? 0,
        ticketsAvailable: j['ticketsAvailable'] ?? 0,
        ticketsSold: j['ticketsSold'] ?? 0,
      );
}

class Ticket {
  String id;
  String eventId;
  String userId;
  String code;
  DateTime purchasedAt;
  Ticket({
    required this.id, required this.eventId, required this.userId,
    required this.code, required this.purchasedAt,
  });
  Map<String, dynamic> toJson() => {
        'id': id, 'eventId': eventId, 'userId': userId,
        'code': code, 'purchasedAt': purchasedAt.toIso8601String(),
      };
  factory Ticket.fromJson(Map<String, dynamic> j) => Ticket(
        id: j['id'], eventId: j['eventId'], userId: j['userId'],
        code: j['code'], purchasedAt: DateTime.parse(j['purchasedAt']),
      );
}

class Contact {
  String id;
  String name;
  String title;
  String email;
  String phone;
  String department;
  Contact({
    required this.id, required this.name, required this.title,
    required this.email, required this.phone, required this.department,
  });
  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'title': title,
        'email': email, 'phone': phone, 'department': department,
      };
  factory Contact.fromJson(Map<String, dynamic> j) => Contact(
        id: j['id'], name: j['name'], title: j['title'],
        email: j['email'], phone: j['phone'], department: j['department'],
      );
}

class AuditEntry {
  String id;
  String actorId;
  String actorName;
  String action;
  DateTime timestamp;
  AuditEntry({
    required this.id, required this.actorId, required this.actorName,
    required this.action, required this.timestamp,
  });
  Map<String, dynamic> toJson() => {
        'id': id, 'actorId': actorId, 'actorName': actorName,
        'action': action, 'timestamp': timestamp.toIso8601String(),
      };
  factory AuditEntry.fromJson(Map<String, dynamic> j) => AuditEntry(
        id: j['id'], actorId: j['actorId'], actorName: j['actorName'],
        action: j['action'], timestamp: DateTime.parse(j['timestamp']),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// APP STATE
// ─────────────────────────────────────────────────────────────────────────────

String _newId() =>
    DateTime.now().microsecondsSinceEpoch.toString() +
    Random().nextInt(99999).toString();

class AppState extends ChangeNotifier {
  AppUser? currentUser;
  bool darkMode = false;

  List<AppUser> users = [];
  List<Announcement> announcements = [];
  List<Flyer> flyers = [];
  List<ResourceLink> resources = [];
  List<Event> events = [];
  List<Ticket> tickets = [];
  List<Contact> contacts = [];
  List<AuditEntry> audit = [];

  static const _kKey = 'school_hub_state_v2';

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kKey);
    if (raw == null) {
      _seed();
      await save();
      return;
    }
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      darkMode = j['darkMode'] ?? false;
      users = (j['users'] as List)
          .map((e) => AppUser.fromJson(Map<String, dynamic>.from(e))).toList();
      announcements = (j['announcements'] as List)
          .map((e) => Announcement.fromJson(Map<String, dynamic>.from(e))).toList();
      flyers = (j['flyers'] as List)
          .map((e) => Flyer.fromJson(Map<String, dynamic>.from(e))).toList();
      resources = (j['resources'] as List)
          .map((e) => ResourceLink.fromJson(Map<String, dynamic>.from(e))).toList();
      events = (j['events'] as List)
          .map((e) => Event.fromJson(Map<String, dynamic>.from(e))).toList();
      tickets = (j['tickets'] as List)
          .map((e) => Ticket.fromJson(Map<String, dynamic>.from(e))).toList();
      contacts = (j['contacts'] as List)
          .map((e) => Contact.fromJson(Map<String, dynamic>.from(e))).toList();
      audit = (j['audit'] as List)
          .map((e) => AuditEntry.fromJson(Map<String, dynamic>.from(e))).toList();
      final activeId = j['currentUserId'] as String?;
      if (activeId != null) {
        currentUser = users.cast<AppUser?>().firstWhere(
            (u) => u!.id == activeId, orElse: () => null);
        if (currentUser?.disabled == true) currentUser = null;
      }
    } catch (_) {
      _seed();
      await save();
    }
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    final j = {
      'darkMode': darkMode,
      'users': users.map((e) => e.toJson()).toList(),
      'announcements': announcements.map((e) => e.toJson()).toList(),
      'flyers': flyers.map((e) => e.toJson()).toList(),
      'resources': resources.map((e) => e.toJson()).toList(),
      'events': events.map((e) => e.toJson()).toList(),
      'tickets': tickets.map((e) => e.toJson()).toList(),
      'contacts': contacts.map((e) => e.toJson()).toList(),
      'audit': audit.map((e) => e.toJson()).toList(),
      'currentUserId': currentUser?.id,
    };
    await p.setString(_kKey, jsonEncode(j));
  }

  void toggleDarkMode() {
    darkMode = !darkMode;
    save();
    notifyListeners();
  }

  void _seed() {
    final admin = AppUser(
      id: _newId(), name: 'Principal Adams', email: 'admin@school.edu',
      password: 'admin123', role: UserRole.admin,
      bio: 'Head of school administration.', grade: 'Staff', avatarEmoji: '👔',
    );
    final leader = AppUser(
      id: _newId(), name: 'Maya Chen', email: 'maya@school.edu',
      password: 'leader123', role: UserRole.leadership,
      bio: 'ASB President. Coffee + spirit weeks.', grade: '12', avatarEmoji: '🎤',
    );
    final student = AppUser(
      id: _newId(), name: 'Alex Park', email: 'alex@school.edu',
      password: 'student123', role: UserRole.student,
      bio: 'Sophomore. Robotics club, runs cross-country.', grade: '10', avatarEmoji: '🏃',
    );
    users = [admin, leader, student];

    announcements = [
      Announcement(
        id: _newId(), authorId: admin.id, authorName: admin.name,
        authorRole: UserRole.admin, title: 'Welcome back!',
        body: 'New semester starts Monday. Check your resources and events.',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        pinned: true, colorSeed: 2,
      ),
      Announcement(
        id: _newId(), authorId: leader.id, authorName: leader.name,
        authorRole: UserRole.leadership, title: 'Spirit week 🎉',
        body: 'Mon: Pajama day. Tue: Twin day. Wed: Decades. Thu: Jersey. Fri: Spirit colors!',
        createdAt: DateTime.now().subtract(const Duration(days: 1)), colorSeed: 1,
      ),
    ];

    flyers = [
      Flyer(id: _newId(), authorId: leader.id, authorName: leader.name,
        title: 'Homecoming Dance',
        description: 'Friday 7pm in the gym. Tickets \$15 at the door.',
        emoji: '💃', colorSeed: 1,
        createdAt: DateTime.now().subtract(const Duration(days: 2))),
      Flyer(id: _newId(), authorId: leader.id, authorName: leader.name,
        title: 'Blood Drive',
        description: 'Wednesday in the library. Sign up at the front desk.',
        emoji: '🩸', colorSeed: 3,
        createdAt: DateTime.now().subtract(const Duration(days: 3))),
    ];

    resources = [
      ResourceLink(id: _newId(), authorId: admin.id, title: 'Google Classroom',
        url: 'https://classroom.google.com', category: 'Classroom',
        description: 'All your classes and assignments.', createdAt: DateTime.now()),
      ResourceLink(id: _newId(), authorId: admin.id, title: 'Clever Portal',
        url: 'https://clever.com', category: 'Clever',
        description: 'Single sign-on to school apps.', createdAt: DateTime.now()),
      ResourceLink(id: _newId(), authorId: admin.id, title: 'Library Catalog',
        url: 'https://library.school.edu', category: 'Library',
        description: 'Search books and reserve study rooms.', createdAt: DateTime.now()),
      ResourceLink(id: _newId(), authorId: leader.id, title: 'Athletics',
        url: 'https://athletics.school.edu', category: 'Sports',
        description: 'Game schedules and standings.', createdAt: DateTime.now()),
    ];

    events = [
      Event(id: _newId(), title: 'Varsity Football vs. Lincoln',
        description: 'Home game — wear your spirit colors!',
        date: DateTime.now().add(const Duration(days: 5)),
        location: 'Memorial Stadium', ticketed: true,
        ticketPrice: 8.00, ticketsAvailable: 500),
      Event(id: _newId(), title: 'Spring Musical: Into the Woods',
        description: 'Drama club spring production.',
        date: DateTime.now().add(const Duration(days: 14)),
        location: 'Auditorium', ticketed: true,
        ticketPrice: 12.00, ticketsAvailable: 200),
      Event(id: _newId(), title: 'Parent-Teacher Conferences',
        description: 'Sign up via the office.',
        date: DateTime.now().add(const Duration(days: 21)),
        location: 'Classrooms', ticketed: false,
        ticketPrice: 0, ticketsAvailable: 0),
    ];

    contacts = [
      Contact(id: _newId(), name: 'Principal Adams', title: 'Principal',
        email: 'adams@school.edu', phone: '555-0100', department: 'Admin'),
      Contact(id: _newId(), name: 'Ms. Ortiz', title: 'School Counselor',
        email: 'ortiz@school.edu', phone: '555-0110', department: 'Counseling'),
      Contact(id: _newId(), name: 'Nurse Kim', title: 'School Nurse',
        email: 'kim@school.edu', phone: '555-0120', department: 'Health'),
      Contact(id: _newId(), name: 'Coach Rivera', title: 'Athletic Director',
        email: 'rivera@school.edu', phone: '555-0130', department: 'Athletics'),
    ];

    audit = [
      AuditEntry(id: _newId(), actorId: admin.id, actorName: admin.name,
        action: 'Seeded initial data', timestamp: DateTime.now()),
    ];
  }

  // ── auth ────────────────────────────────────────────────────────────────
  String? signIn(String email, String password) {
    final match = users.cast<AppUser?>().firstWhere(
      (u) => u!.email.toLowerCase() == email.toLowerCase() && u.password == password,
      orElse: () => null,
    );
    if (match == null) return 'Invalid email or password.';
    if (match.disabled) return 'This account has been disabled by an administrator.';
    currentUser = match;
    _log(match, 'Signed in');
    save();
    notifyListeners();
    return null;
  }

  String? signUp({
    required String name, required String email, required String password,
    required String grade,
  }) {
    if (users.any((u) => u.email.toLowerCase() == email.toLowerCase())) {
      return 'An account with that email already exists.';
    }
    final u = AppUser(
      id: _newId(), name: name, email: email, password: password,
      role: UserRole.student, grade: grade,
    );
    users.add(u);
    currentUser = u;
    _log(u, 'Created account');
    save();
    notifyListeners();
    return null;
  }

  void signOut() {
    if (currentUser != null) _log(currentUser!, 'Signed out');
    currentUser = null;
    save();
    notifyListeners();
  }

  // ── profile ─────────────────────────────────────────────────────────────
  void updateProfile({String? name, String? bio, String? grade, String? avatarEmoji}) {
    final u = currentUser;
    if (u == null) return;
    if (name != null) u.name = name;
    if (bio != null) u.bio = bio;
    if (grade != null) u.grade = grade;
    if (avatarEmoji != null) u.avatarEmoji = avatarEmoji;
    _log(u, 'Updated profile');
    save();
    notifyListeners();
  }

  // ── content ─────────────────────────────────────────────────────────────
  void postAnnouncement(String title, String body, {bool pinned = false, int colorSeed = 0}) {
    final u = currentUser;
    if (u == null || !(u.role == UserRole.leadership || u.role == UserRole.admin)) return;
    announcements.insert(0, Announcement(
      id: _newId(), authorId: u.id, authorName: u.name, authorRole: u.role,
      title: title, body: body, createdAt: DateTime.now(),
      pinned: pinned && u.role == UserRole.admin,
      colorSeed: colorSeed,
    ));
    _log(u, 'Posted announcement: $title');
    save();
    notifyListeners();
  }

  void deleteAnnouncement(String id) {
    final u = currentUser;
    if (u == null) return;
    final a = announcements.firstWhere((x) => x.id == id,
      orElse: () => Announcement(id: '', authorId: '', authorName: '',
        authorRole: UserRole.student, title: '', body: '', createdAt: DateTime.now()));
    if (a.id.isEmpty) return;
    if (u.role != UserRole.admin && u.id != a.authorId) return;
    announcements.removeWhere((x) => x.id == id);
    _log(u, 'Deleted announcement: ${a.title}');
    save();
    notifyListeners();
  }

  void postFlyer(String title, String description, String emoji, int colorSeed) {
    final u = currentUser;
    if (u == null || !(u.role == UserRole.leadership || u.role == UserRole.admin)) return;
    flyers.insert(0, Flyer(
      id: _newId(), authorId: u.id, authorName: u.name,
      title: title, description: description, emoji: emoji,
      colorSeed: colorSeed, createdAt: DateTime.now(),
    ));
    _log(u, 'Posted flyer: $title');
    save();
    notifyListeners();
  }

  void deleteFlyer(String id) {
    final u = currentUser;
    if (u == null) return;
    final f = flyers.firstWhere((x) => x.id == id,
      orElse: () => Flyer(id: '', authorId: '', authorName: '', title: '',
        description: '', emoji: '', colorSeed: 0, createdAt: DateTime.now()));
    if (f.id.isEmpty) return;
    if (u.role != UserRole.admin && u.id != f.authorId) return;
    flyers.removeWhere((x) => x.id == id);
    _log(u, 'Deleted flyer: ${f.title}');
    save();
    notifyListeners();
  }

  void postResource(String title, String url, String category, String description) {
    final u = currentUser;
    if (u == null || !(u.role == UserRole.leadership || u.role == UserRole.admin)) return;
    resources.insert(0, ResourceLink(
      id: _newId(), authorId: u.id, title: title, url: url,
      category: category, description: description, createdAt: DateTime.now(),
    ));
    _log(u, 'Posted resource: $title');
    save();
    notifyListeners();
  }

  void deleteResource(String id) {
    final u = currentUser;
    if (u == null) return;
    final r = resources.firstWhere((x) => x.id == id,
      orElse: () => ResourceLink(id: '', authorId: '', title: '', url: '',
        category: '', description: '', createdAt: DateTime.now()));
    if (r.id.isEmpty) return;
    if (u.role != UserRole.admin && u.id != r.authorId) return;
    resources.removeWhere((x) => x.id == id);
    _log(u, 'Deleted resource: ${r.title}');
    save();
    notifyListeners();
  }

  // ── events ──────────────────────────────────────────────────────────────
  void createEvent(Event e) {
    final u = currentUser;
    if (u == null || !(u.role == UserRole.leadership || u.role == UserRole.admin)) return;
    events.add(e);
    events.sort((a, b) => a.date.compareTo(b.date));
    _log(u, 'Created event: ${e.title}');
    save();
    notifyListeners();
  }

  void deleteEvent(String id) {
    final u = currentUser;
    if (u == null || u.role != UserRole.admin) return;
    final e = events.firstWhere((x) => x.id == id,
      orElse: () => Event(id: '', title: '', description: '',
        date: DateTime.now(), location: '', ticketed: false,
        ticketPrice: 0, ticketsAvailable: 0));
    if (e.id.isEmpty) return;
    events.removeWhere((x) => x.id == id);
    tickets.removeWhere((t) => t.eventId == id);
    _log(u, 'Deleted event: ${e.title}');
    save();
    notifyListeners();
  }

  String? buyTicket(String eventId) {
    final u = currentUser;
    if (u == null) return 'You must be signed in.';
    final i = events.indexWhere((e) => e.id == eventId);
    if (i < 0) return 'Event not found.';
    final e = events[i];
    if (!e.ticketed) return 'This event does not require a ticket.';
    if (e.ticketsSold >= e.ticketsAvailable) return 'Sold out.';
    if (tickets.any((t) => t.eventId == eventId && t.userId == u.id)) {
      return 'You already have a ticket for this event.';
    }
    e.ticketsSold += 1;
    final code = 'TKT-${Random().nextInt(999999).toString().padLeft(6, '0')}';
    tickets.add(Ticket(id: _newId(), eventId: eventId, userId: u.id,
      code: code, purchasedAt: DateTime.now()));
    _log(u, 'Bought ticket for: ${e.title}');
    save();
    notifyListeners();
    return null;
  }

  // ── contacts ────────────────────────────────────────────────────────────
  void upsertContact(Contact c) {
    final u = currentUser;
    if (u == null || u.role != UserRole.admin) return;
    final i = contacts.indexWhere((x) => x.id == c.id);
    if (i >= 0) {
      contacts[i] = c;
    } else {
      contacts.add(c);
    }
    _log(u, 'Saved contact: ${c.name}');
    save();
    notifyListeners();
  }

  void deleteContact(String id) {
    final u = currentUser;
    if (u == null || u.role != UserRole.admin) return;
    contacts.removeWhere((x) => x.id == id);
    save();
    notifyListeners();
  }

  // ── admin: user management ──────────────────────────────────────────────
  void setUserDisabled(String userId, bool disabled) {
    final u = currentUser;
    if (u == null || u.role != UserRole.admin) return;
    final target = users.firstWhere((x) => x.id == userId, orElse: () => u);
    if (target.id == u.id) return;
    target.disabled = disabled;
    _log(u, '${disabled ? "Disabled" : "Enabled"} user: ${target.name}');
    save();
    notifyListeners();
  }

  void setUserRole(String userId, UserRole role) {
    final u = currentUser;
    if (u == null || u.role != UserRole.admin) return;
    final target = users.firstWhere((x) => x.id == userId, orElse: () => u);
    if (target.id == u.id) return;
    target.role = role;
    _log(u, 'Set role of ${target.name} to ${Brand.roleLabel(role)}');
    save();
    notifyListeners();
  }

  void deleteUser(String userId) {
    final u = currentUser;
    if (u == null || u.role != UserRole.admin) return;
    if (userId == u.id) return;
    final target = users.firstWhere((x) => x.id == userId, orElse: () => u);
    users.removeWhere((x) => x.id == userId);
    tickets.removeWhere((t) => t.userId == userId);
    _log(u, 'Deleted user: ${target.name}');
    save();
    notifyListeners();
  }

  // ── audit ───────────────────────────────────────────────────────────────
  void _log(AppUser actor, String action) {
    audit.insert(0, AuditEntry(
      id: _newId(), actorId: actor.id, actorName: actor.name,
      action: action, timestamp: DateTime.now(),
    ));
    if (audit.length > 500) audit = audit.sublist(0, 500);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// APP ROOT
// ─────────────────────────────────────────────────────────────────────────────

class SchoolHubApp extends StatelessWidget {
  final AppState state;
  const SchoolHubApp({super.key, required this.state});
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (_, __) => MaterialApp(
        title: 'School Hub',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(Tones.light),
        darkTheme: _buildTheme(Tones.dark),
        themeMode: state.darkMode ? ThemeMode.dark : ThemeMode.light,
        home: state.currentUser == null
            ? AuthScreen(state: state)
            : HomeShell(state: state),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AUTH
// ─────────────────────────────────────────────────────────────────────────────

class AuthScreen extends StatefulWidget {
  final AppState state;
  const AuthScreen({super.key, required this.state});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isSignup = false;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _grade = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose(); _password.dispose();
    _name.dispose(); _grade.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { _error = null; _busy = true; });
    final err = _isSignup
        ? widget.state.signUp(
            name: _name.text.trim(), email: _email.text.trim(),
            password: _password.text, grade: _grade.text.trim())
        : widget.state.signIn(_email.text.trim(), _password.text);
    if (!mounted) return;
    setState(() { _error = err; _busy = false; });
  }

  void _fillDemo(String email, String password) {
    _email.text = email; _password.text = password;
    setState(() => _isSignup = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Transform.rotate(
                        angle: -0.08,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: sticker(t, fill: Brand.lime, radius: 14),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('🏫', style: TextStyle(fontSize: 22)),
                              SizedBox(width: 6),
                              Text('SCHOOL HUB',
                                style: TextStyle(fontWeight: FontWeight.w900,
                                  color: Brand.ink, letterSpacing: -0.4, fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      _IconBtn(
                        icon: widget.state.darkMode ? Icons.light_mode : Icons.dark_mode,
                        onTap: () => widget.state.toggleDarkMode(),
                        tones: t,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _isSignup ? 'Make your account.' : 'Welcome\nback.',
                    style: TextStyle(
                      fontSize: 44, height: 0.95, color: t.ink,
                      fontWeight: FontWeight.w900, letterSpacing: -1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isSignup
                        ? 'New students start here. Leadership and admin roles are assigned by your administrator.'
                        : 'Sign in for announcements, events, tickets, and everything else.',
                    style: TextStyle(color: t.mute, fontSize: 15, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  if (_isSignup) ...[
                    TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full name')),
                    const SizedBox(height: 10),
                    TextField(controller: _grade, decoration: const InputDecoration(labelText: 'Grade (e.g. 10)')),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'School email'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: sticker(t, fill: Brand.coralSoft, border: Brand.danger, radius: 10, offset: const Offset(2,2)),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Brand.danger, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!,
                            style: const TextStyle(color: Brand.danger, fontWeight: FontWeight.w700))),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(_isSignup ? 'Create account →' : 'Sign in →'),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => setState(() => _isSignup = !_isSignup),
                    style: TextButton.styleFrom(foregroundColor: t.ink),
                    child: Text(_isSignup
                      ? 'Already have an account? Sign in'
                      : "New student? Create an account",
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 18),
                  Row(children: [
                    Expanded(child: Container(height: 2, color: t.lineSoft)),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text('DEMO ACCOUNTS',
                        style: TextStyle(color: t.mute, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.2))),
                    Expanded(child: Container(height: 2, color: t.lineSoft)),
                  ]),
                  const SizedBox(height: 12),
                  _demoBtn(t, 'Admin', 'admin@school.edu', 'admin123', UserRole.admin),
                  const SizedBox(height: 8),
                  _demoBtn(t, 'Leadership', 'maya@school.edu', 'leader123', UserRole.leadership),
                  const SizedBox(height: 8),
                  _demoBtn(t, 'Student', 'alex@school.edu', 'student123', UserRole.student),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _demoBtn(Tones t, String label, String email, String password, UserRole role) {
    final c = Brand.roleColor(role);
    return GestureDetector(
      onTap: () => _fillDemo(email, password),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: sticker(t, fill: t.paper, border: c, radius: 12, offset: const Offset(3, 3)),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(6)),
            child: Text(label.toUpperCase(),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900,
                color: Colors.white, letterSpacing: 0.8)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(email,
            style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 13))),
          Icon(Icons.arrow_forward_rounded, color: t.ink, size: 18),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HOME SHELL
// ─────────────────────────────────────────────────────────────────────────────

class HomeShell extends StatefulWidget {
  final AppState state;
  const HomeShell({super.key, required this.state});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  List<_NavTab> _tabs(AppUser u) {
    final base = <_NavTab>[
      _NavTab(icon: Icons.bolt_outlined, active: Icons.bolt, label: 'Home',
        builder: (_) => HomeFeedScreen(state: widget.state)),
      _NavTab(icon: Icons.event_outlined, active: Icons.event, label: 'Events',
        builder: (_) => EventsScreen(state: widget.state)),
      _NavTab(icon: Icons.dashboard_outlined, active: Icons.dashboard, label: 'Hub',
        builder: (_) => ResourcesScreen(state: widget.state)),
      _NavTab(icon: Icons.contacts_outlined, active: Icons.contacts, label: 'People',
        builder: (_) => ContactsScreen(state: widget.state)),
      _NavTab(icon: Icons.person_outline, active: Icons.person, label: 'Me',
        builder: (_) => ProfileScreen(state: widget.state)),
    ];
    if (u.role == UserRole.leadership) {
      base.insert(1, _NavTab(icon: Icons.add_box_outlined, active: Icons.add_box,
        label: 'Post', builder: (_) => LeadershipPostScreen(state: widget.state)));
    } else if (u.role == UserRole.admin) {
      base.insert(1, _NavTab(icon: Icons.shield_outlined, active: Icons.shield,
        label: 'Admin', builder: (_) => AdminDashboard(state: widget.state)));
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.state.currentUser!;
    final tabs = _tabs(u);
    final idx = _index.clamp(0, tabs.length - 1);
    return Scaffold(
      body: tabs[idx].builder(context),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Tones.of(context).line, width: 2)),
        ),
        child: NavigationBar(
          selectedIndex: idx,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            for (final t in tabs)
              NavigationDestination(
                icon: Icon(t.icon),
                selectedIcon: Icon(t.active, color: Brand.purple),
                label: t.label,
              ),
          ],
        ),
      ),
    );
  }
}

class _NavTab {
  final IconData icon;
  final IconData active;
  final String label;
  final WidgetBuilder builder;
  _NavTab({required this.icon, required this.active, required this.label, required this.builder});
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Tones tones;
  final Color? bg;
  final String? tooltip;
  const _IconBtn({required this.icon, required this.onTap, required this.tones, this.bg, this.tooltip});
  @override
  Widget build(BuildContext context) {
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42, height: 42,
        decoration: sticker(tones, fill: bg ?? tones.paper, radius: 12, offset: const Offset(2, 2)),
        child: Icon(icon, color: tones.ink, size: 20),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn;
  }
}

class ThemeToggleBtn extends StatelessWidget {
  final AppState state;
  const ThemeToggleBtn({super.key, required this.state});
  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: _IconBtn(
        icon: state.darkMode ? Icons.light_mode : Icons.dark_mode,
        onTap: () => state.toggleDarkMode(),
        tones: t,
        tooltip: state.darkMode ? 'Switch to light' : 'Switch to dark',
      ),
    );
  }
}

class RoleBadge extends StatelessWidget {
  final UserRole role;
  final bool dense;
  const RoleBadge({super.key, required this.role, this.dense = false});
  @override
  Widget build(BuildContext context) {
    final c = Brand.roleColor(role);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 7 : 9, vertical: dense ? 2 : 3),
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Brand.ink, width: 1.5),
      ),
      child: Text(
        Brand.roleLabel(role).toUpperCase(),
        style: TextStyle(
          color: Brand.ink,
          fontWeight: FontWeight.w900,
          fontSize: dense ? 9 : 10,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String label;
  final String emoji;
  final Widget? trailing;
  const SectionHeader({super.key, required this.label, this.emoji = '', this.trailing});
  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
      child: Row(
        children: [
          if (emoji.isNotEmpty) ...[
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 6),
          ],
          Text(label,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
              color: t.ink, letterSpacing: -0.6)),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String message;
  const EmptyState({super.key, required this.emoji, required this.title, required this.message});
  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: sticker(t, fill: t.primaryWash, radius: 16, offset: const Offset(3, 3)),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 38)),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: t.ink)),
            const SizedBox(height: 4),
            Text(message, textAlign: TextAlign.center,
              style: TextStyle(color: t.mute, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

String _timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  return '${t.month}/${t.day}/${t.year}';
}

String _dateLabel(DateTime t) {
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  final h = t.hour == 0 ? 12 : (t.hour > 12 ? t.hour - 12 : t.hour);
  final m = t.minute.toString().padLeft(2, '0');
  final ampm = t.hour >= 12 ? 'PM' : 'AM';
  return '${months[t.month - 1]} ${t.day} · $h:$m $ampm';
}

String _monthAbbr(int m) =>
    const ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'][m - 1];

// Palette for stickers / flyers / announcements.
class StickerPalette {
  static const fills = <Color>[
    Brand.sunSoft, Brand.pinkSoft, Brand.skySoft, Brand.mintSoft, Brand.coralSoft,
  ];
  static const fillsDark = <Color>[
    Brand.sunSoftDark, Brand.pinkSoftDark, Brand.skySoftDark, Brand.mintSoftDark, Brand.coralSoftDark,
  ];
  static const accents = <Color>[
    Brand.sun, Brand.pink, Brand.sky, Brand.mint, Brand.coral,
  ];
  static Color fill(int seed, bool dark) =>
      (dark ? fillsDark : fills)[seed.abs() % fills.length];
  static Color accent(int seed) => accents[seed.abs() % accents.length];
}

// ─────────────────────────────────────────────────────────────────────────────
// HOME FEED
// ─────────────────────────────────────────────────────────────────────────────

class HomeFeedScreen extends StatelessWidget {
  final AppState state;
  const HomeFeedScreen({super.key, required this.state});
  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    final u = state.currentUser!;
    final pinned = state.announcements.where((a) => a.pinned).toList();
    final recent = state.announcements.where((a) => !a.pinned).toList();
    final upcoming = state.events.where((e) => e.date.isAfter(DateTime.now())).take(3).toList();
    final greeting = _greeting();

    return Scaffold(
      body: RefreshIndicator(
        color: Brand.purple,
        onRefresh: () async => state.notifyListeners(),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              backgroundColor: t.bg,
              titleSpacing: 20,
              title: Row(children: [
                Text('Hub',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                    color: t.ink, letterSpacing: -0.6)),
                const Spacer(),
                ThemeToggleBtn(state: state),
              ]),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _HeroCard(state: state, u: u, greeting: greeting),
              ),
            ),
            SliverToBoxAdapter(
              child: SectionHeader(label: 'Quick jump', emoji: '⚡'),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 108,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  children: [
                    _QuickTile(icon: Icons.event, label: 'Events', color: Brand.sun,
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => EventsScreen(state: state)))),
                    _QuickTile(icon: Icons.confirmation_num_outlined, label: 'My tickets', color: Brand.mint,
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => MyTicketsScreen(state: state)))),
                    _QuickTile(icon: Icons.dashboard, label: 'Resources', color: Brand.sky,
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => ResourcesScreen(state: state)))),
                    _QuickTile(icon: Icons.contacts, label: 'Contacts', color: Brand.pink,
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => ContactsScreen(state: state)))),
                  ],
                ),
              ),
            ),
            if (pinned.isNotEmpty)
              SliverToBoxAdapter(
                child: SectionHeader(label: 'Pinned', emoji: '📌'),
              ),
            if (pinned.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList.separated(
                  itemCount: pinned.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (_, i) => _AnnouncementCard(a: pinned[i], state: state),
                ),
              ),
            SliverToBoxAdapter(child: SectionHeader(label: 'Announcements', emoji: '📣')),
            if (recent.isEmpty)
              const SliverToBoxAdapter(
                child: EmptyState(emoji: '📭', title: 'No announcements yet',
                  message: 'Posts from leadership and admin will land here.'),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList.separated(
                  itemCount: recent.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (_, i) => _AnnouncementCard(a: recent[i], state: state),
                ),
              ),
            SliverToBoxAdapter(child: SectionHeader(label: 'Upcoming', emoji: '🗓️')),
            if (upcoming.isEmpty)
              const SliverToBoxAdapter(
                child: EmptyState(emoji: '📅', title: 'Nothing on the calendar', message: 'Check back soon.'),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList.separated(
                  itemCount: upcoming.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _EventCard(event: upcoming[i], state: state),
                ),
              ),
            SliverToBoxAdapter(child: SectionHeader(label: 'Flyers', emoji: '📄')),
            if (state.flyers.isEmpty)
              const SliverToBoxAdapter(
                child: EmptyState(emoji: '🪧', title: 'No flyers yet',
                  message: 'Leadership can post flyers from the Post tab.'),
              )
            else
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 210,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    scrollDirection: Axis.horizontal,
                    itemCount: state.flyers.length,
                    itemBuilder: (_, i) {
                      final f = state.flyers[i];
                      final tilt = ((i.isEven ? -1 : 1) * (0.02 + (i % 3) * 0.01));
                      return Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Transform.rotate(angle: tilt, child: _FlyerCard(f: f, state: state)),
                      );
                    },
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 5) return 'Late night,';
    if (h < 12) return 'Good morning,';
    if (h < 17) return 'Hey,';
    if (h < 21) return 'Good evening,';
    return 'Hey,';
  }
}

class _HeroCard extends StatelessWidget {
  final AppState state;
  final AppUser u;
  final String greeting;
  const _HeroCard({required this.state, required this.u, required this.greeting});
  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    return Container(
      decoration: sticker(t, fill: Brand.purple, radius: 22, offset: const Offset(5, 5)),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: Brand.lime,
                  border: Border.all(color: Brand.ink, width: 2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(child: Text(u.avatarEmoji, style: const TextStyle(fontSize: 30))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(greeting,
                      style: const TextStyle(color: Colors.white70,
                        fontWeight: FontWeight.w700, fontSize: 13)),
                    Text(u.name.split(' ').first,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 28,
                        fontWeight: FontWeight.w900, letterSpacing: -0.8)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              RoleBadge(role: u.role),
              const SizedBox(width: 8),
              if (u.grade.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('GRADE ${u.grade}'.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900,
                      fontSize: 10, letterSpacing: 0.8)),
                ),
              const Spacer(),
              _miniStat('📣', '${state.announcements.length}'),
              const SizedBox(width: 10),
              _miniStat('🎟️', '${state.tickets.where((t) => t.userId == u.id).length}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String emoji, String value) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(emoji, style: const TextStyle(fontSize: 14)),
      const SizedBox(width: 4),
      Text(value, style: const TextStyle(color: Colors.white,
        fontWeight: FontWeight.w900, fontSize: 14)),
    ],
  );
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickTile({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 110,
          padding: const EdgeInsets.all(12),
          decoration: sticker(t, fill: color, radius: 16, offset: const Offset(3, 3)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: Brand.ink, size: 28),
              Text(label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900,
                  color: Brand.ink, letterSpacing: -0.2)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Announcement a;
  final AppState state;
  const _AnnouncementCard({required this.a, required this.state});
  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    final u = state.currentUser!;
    final canDelete = u.role == UserRole.admin || u.id == a.authorId;
    final accent = StickerPalette.accent(a.colorSeed);
    final fill = StickerPalette.fill(a.colorSeed, t.isDark);
    return Container(
      decoration: sticker(t, fill: fill, radius: 18, offset: const Offset(4, 4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // colored "tape" band at top
          Container(
            height: 10,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16), topRight: Radius.circular(16),
              ),
              border: Border(bottom: BorderSide(color: t.line, width: 2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (a.pinned) ...[
                      Transform.rotate(angle: -0.3,
                        child: const Icon(Icons.push_pin, size: 18, color: Brand.danger)),
                      const SizedBox(width: 6),
                    ],
                    Expanded(child: Text(a.title,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900,
                        color: t.ink, letterSpacing: -0.4))),
                    if (canDelete)
                      GestureDetector(
                        onTap: () => state.deleteAnnouncement(a.id),
                        child: Icon(Icons.close, size: 18, color: t.mute),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(a.body, style: TextStyle(color: t.ink, height: 1.4, fontSize: 14)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    RoleBadge(role: a.authorRole, dense: true),
                    const SizedBox(width: 8),
                    Flexible(child: Text(
                      '${a.authorName} · ${_timeAgo(a.createdAt)}',
                      style: TextStyle(color: t.mute, fontSize: 12, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    )),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlyerCard extends StatelessWidget {
  final Flyer f;
  final AppState state;
  const _FlyerCard({required this.f, required this.state});

  static const _palette = [
    [Color(0xFFFEF3C7), Color(0xFFFCD34D)],
    [Color(0xFFDBEAFE), Color(0xFF60A5FA)],
    [Color(0xFFFEE2E2), Color(0xFFF87171)],
    [Color(0xFFD1FAE5), Color(0xFF34D399)],
    [Color(0xFFE9D5FF), Color(0xFFA78BFA)],
    [Color(0xFFFCE7F3), Color(0xFFF472B6)],
  ];

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    final pair = _palette[f.colorSeed.abs() % _palette.length];
    final u = state.currentUser!;
    final canDelete = u.role == UserRole.admin || u.id == f.authorId;
    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: t.paper,
          title: Text(f.title, style: TextStyle(color: t.ink, fontWeight: FontWeight.w900)),
          content: Text('${f.description}\n\nPosted by ${f.authorName} · ${_timeAgo(f.createdAt)}',
            style: TextStyle(color: t.ink)),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
        ),
      ),
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: pair, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: t.line, width: 2),
          boxShadow: [BoxShadow(color: t.line, offset: const Offset(4, 4), blurRadius: 0)],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Brand.ink, width: 1.5),
                ),
                child: Text(f.emoji, style: const TextStyle(fontSize: 22)),
              ),
              const Spacer(),
              if (canDelete)
                GestureDetector(
                  onTap: () => state.deleteFlyer(f.id),
                  child: const Icon(Icons.close, size: 18, color: Brand.ink),
                ),
            ]),
            const Spacer(),
            Text(f.title,
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900,
                color: Brand.ink, letterSpacing: -0.4, height: 1.05)),
            const SizedBox(height: 6),
            Text(f.description,
              maxLines: 3, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Brand.ink, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EVENTS + TICKETS
// ─────────────────────────────────────────────────────────────────────────────

class EventsScreen extends StatelessWidget {
  final AppState state;
  const EventsScreen({super.key, required this.state});
  @override
  Widget build(BuildContext context) {
    final u = state.currentUser!;
    final canCreate = u.role == UserRole.leadership || u.role == UserRole.admin;
    final upcoming = state.events.where((e) => e.date.isAfter(DateTime.now())).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final past = state.events.where((e) => !e.date.isAfter(DateTime.now())).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        actions: [
          IconButton(
            icon: const Icon(Icons.confirmation_num_outlined),
            tooltip: 'My tickets',
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => MyTicketsScreen(state: state))),
          ),
          ThemeToggleBtn(state: state),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              backgroundColor: Brand.lime,
              foregroundColor: Brand.ink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Brand.ink, width: 2),
              ),
              onPressed: () => _createEvent(context),
              icon: const Icon(Icons.add),
              label: const Text('New event',
                style: TextStyle(fontWeight: FontWeight.w900)),
            )
          : null,
      body: ListView(
        children: [
          const SectionHeader(label: 'Upcoming', emoji: '🔥'),
          if (upcoming.isEmpty)
            const EmptyState(emoji: '📅', title: 'Nothing upcoming', message: 'Check back soon.')
          else
            for (final e in upcoming)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: _EventCard(event: e, state: state),
              ),
          if (past.isNotEmpty) ...[
            const SectionHeader(label: 'Past', emoji: '✓'),
            for (final e in past)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: _EventCard(event: e, state: state, past: true),
              ),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  void _createEvent(BuildContext context) {
    final title = TextEditingController();
    final desc = TextEditingController();
    final location = TextEditingController();
    final price = TextEditingController(text: '0');
    final qty = TextEditingController(text: '100');
    DateTime date = DateTime.now().add(const Duration(days: 1));
    bool ticketed = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Tones.of(context).paper,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20,
            bottom: 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('New event',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                    color: Tones.of(ctx).ink, letterSpacing: -0.6)),
                const SizedBox(height: 14),
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 10),
                TextField(controller: desc, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 10),
                TextField(controller: location, decoration: const InputDecoration(labelText: 'Location')),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Date & time: ${_dateLabel(date)}'),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx, initialDate: date,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d == null) return;
                    // ignore: use_build_context_synchronously
                    final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(date));
                    setSt(() => date = DateTime(d.year, d.month, d.day, t?.hour ?? 19, t?.minute ?? 0));
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ticketed event'),
                  value: ticketed,
                  activeThumbColor: Brand.purple,
                  onChanged: (v) => setSt(() => ticketed = v),
                ),
                if (ticketed) ...[
                  TextField(controller: price, keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Ticket price (\$)')),
                  const SizedBox(height: 10),
                  TextField(controller: qty, keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Tickets available')),
                ],
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    if (title.text.trim().isEmpty) return;
                    state.createEvent(Event(
                      id: _newId(), title: title.text.trim(),
                      description: desc.text.trim(), date: date,
                      location: location.text.trim(), ticketed: ticketed,
                      ticketPrice: double.tryParse(price.text) ?? 0,
                      ticketsAvailable: int.tryParse(qty.text) ?? 0,
                    ));
                    Navigator.pop(ctx);
                  },
                  child: const Text('Create event'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Event event;
  final AppState state;
  final bool past;
  const _EventCard({required this.event, required this.state, this.past = false});
  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    final u = state.currentUser!;
    final hasTicket = state.tickets.any((tk) => tk.eventId == event.id && tk.userId == u.id);
    final soldOut = event.ticketed && event.ticketsSold >= event.ticketsAvailable;
    final stub = past ? t.lineSoft : Brand.lime;
    return Container(
      decoration: sticker(t, fill: t.paper, radius: 18, offset: const Offset(4, 4)),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ticket-stub date column
            Container(
              width: 76,
              decoration: BoxDecoration(
                color: stub,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16), bottomLeft: Radius.circular(16),
                ),
                border: Border(right: BorderSide(color: t.line, width: 2, style: BorderStyle.solid)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_monthAbbr(event.date.month),
                    style: TextStyle(color: Brand.ink, fontSize: 12,
                      fontWeight: FontWeight.w900, letterSpacing: 1)),
                  Text(event.date.day.toString(),
                    style: const TextStyle(color: Brand.ink, fontSize: 32,
                      fontWeight: FontWeight.w900, height: 1)),
                  const SizedBox(height: 4),
                  Text(_weekday(event.date),
                    style: const TextStyle(color: Brand.ink, fontSize: 10,
                      fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                ],
              ),
            ),
            // body
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(event.title,
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900,
                          color: t.ink, letterSpacing: -0.3))),
                      if (u.role == UserRole.admin)
                        GestureDetector(
                          onTap: () => state.deleteEvent(event.id),
                          child: Icon(Icons.close, size: 18, color: t.mute),
                        ),
                    ]),
                    const SizedBox(height: 4),
                    Text('${_dateLabel(event.date)} · ${event.location}',
                      style: TextStyle(color: t.mute, fontSize: 12, fontWeight: FontWeight.w700)),
                    if (event.description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(event.description,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: t.ink, height: 1.4, fontSize: 13)),
                    ],
                    if (event.ticketed) ...[
                      const SizedBox(height: 10),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Brand.mint,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Brand.ink, width: 1.5),
                          ),
                          child: Text('\$${event.ticketPrice.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w900, color: Brand.ink, fontSize: 13)),
                        ),
                        const SizedBox(width: 8),
                        Text('${event.ticketsAvailable - event.ticketsSold} left',
                          style: TextStyle(color: t.mute, fontSize: 11, fontWeight: FontWeight.w700)),
                        const Spacer(),
                        if (past)
                          Text('Ended', style: TextStyle(color: t.mute, fontWeight: FontWeight.w800))
                        else if (hasTicket)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Brand.mint,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Brand.ink, width: 1.5),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check, size: 14, color: Brand.ink),
                                SizedBox(width: 4),
                                Text('Got it', style: TextStyle(color: Brand.ink, fontWeight: FontWeight.w900, fontSize: 12)),
                              ],
                            ),
                          )
                        else
                          GestureDetector(
                            onTap: soldOut ? null : () {
                              final err = state.buyTicket(event.id);
                              if (err != null) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('🎟️ Ticket purchased!')));
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: soldOut ? t.lineSoft : Brand.purple,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Brand.ink, width: 1.5),
                              ),
                              child: Text(soldOut ? 'Sold out' : 'Buy →',
                                style: TextStyle(
                                  color: soldOut ? t.mute : Colors.white,
                                  fontWeight: FontWeight.w900, fontSize: 13)),
                            ),
                          ),
                      ]),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _weekday(DateTime d) =>
      const ['MON','TUE','WED','THU','FRI','SAT','SUN'][(d.weekday - 1) % 7];
}

class MyTicketsScreen extends StatelessWidget {
  final AppState state;
  const MyTicketsScreen({super.key, required this.state});
  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    final u = state.currentUser!;
    final mine = state.tickets.where((tk) => tk.userId == u.id).toList()
      ..sort((a, b) => b.purchasedAt.compareTo(a.purchasedAt));
    return Scaffold(
      appBar: AppBar(
        title: const Text('My tickets'),
        actions: [ThemeToggleBtn(state: state)],
      ),
      body: mine.isEmpty
          ? const EmptyState(emoji: '🎟️', title: 'No tickets yet', message: 'Buy tickets from the Events tab.')
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: mine.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (_, i) {
                final tk = mine[i];
                final e = state.events.cast<Event?>().firstWhere(
                  (ev) => ev!.id == tk.eventId, orElse: () => null);
                if (e == null) return const SizedBox.shrink();
                return Container(
                  decoration: sticker(t, fill: Brand.lime, radius: 16, offset: const Offset(4, 4)),
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    const Icon(Icons.confirmation_num, size: 40, color: Brand.ink),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.title,
                            style: const TextStyle(fontWeight: FontWeight.w900, color: Brand.ink, fontSize: 16)),
                          Text(_dateLabel(e.date),
                            style: const TextStyle(color: Brand.ink, fontSize: 12, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Brand.ink, width: 1.5),
                            ),
                            child: Text(tk.code,
                              style: const TextStyle(fontFamily: 'monospace',
                                color: Brand.ink, fontWeight: FontWeight.w900, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ]),
                );
              },
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RESOURCES
// ─────────────────────────────────────────────────────────────────────────────

class ResourcesScreen extends StatelessWidget {
  final AppState state;
  const ResourcesScreen({super.key, required this.state});
  @override
  Widget build(BuildContext context) {
    final u = state.currentUser!;
    final canPost = u.role == UserRole.leadership || u.role == UserRole.admin;
    final byCategory = <String, List<ResourceLink>>{};
    for (final r in state.resources) {
      byCategory.putIfAbsent(r.category, () => []).add(r);
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hub'),
        actions: [
          if (canPost)
            IconButton(icon: const Icon(Icons.add_link), onPressed: () => _addResource(context)),
          ThemeToggleBtn(state: state),
        ],
      ),
      body: state.resources.isEmpty
          ? const EmptyState(emoji: '🔗', title: 'No resources yet',
              message: 'Leadership or admin can add quick links to Classroom, Clever, library, and more.')
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                for (final entry in byCategory.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 16, 0, 10),
                    child: Row(children: [
                      Text(_emoji(entry.key), style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 6),
                      Text(entry.key.toUpperCase(),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900,
                          color: Tones.of(context).ink, letterSpacing: 1)),
                    ]),
                  ),
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.5,
                    children: [
                      for (final r in entry.value)
                        _ResourceTile(r: r, state: state),
                    ],
                  ),
                ],
              ],
            ),
    );
  }

  String _emoji(String cat) {
    switch (cat) {
      case 'Classroom': return '📚';
      case 'Clever': return '🪪';
      case 'Library': return '📖';
      case 'Sports': return '🏈';
      default: return '🔗';
    }
  }

  void _addResource(BuildContext context) {
    final title = TextEditingController();
    final url = TextEditingController();
    final desc = TextEditingController();
    String category = 'Classroom';
    const cats = ['Classroom', 'Clever', 'Library', 'Sports', 'Other'];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Tones.of(context).paper,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20,
            bottom: 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add resource link',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                  color: Tones.of(ctx).ink, letterSpacing: -0.6)),
              const SizedBox(height: 14),
              TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
              const SizedBox(height: 10),
              TextField(controller: url, decoration: const InputDecoration(labelText: 'URL (https://...)')),
              const SizedBox(height: 10),
              TextField(controller: desc, decoration: const InputDecoration(labelText: 'Description (optional)')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [for (final c in cats) DropdownMenuItem(value: c, child: Text(c))],
                onChanged: (v) => setSt(() => category = v ?? 'Other'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  if (title.text.trim().isEmpty || url.text.trim().isEmpty) return;
                  state.postResource(title.text.trim(), url.text.trim(), category, desc.text.trim());
                  Navigator.pop(ctx);
                },
                child: const Text('Add'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResourceTile extends StatelessWidget {
  final ResourceLink r;
  final AppState state;
  const _ResourceTile({required this.r, required this.state});

  IconData _icon() {
    switch (r.category) {
      case 'Classroom': return Icons.school_outlined;
      case 'Clever': return Icons.dashboard_outlined;
      case 'Library': return Icons.menu_book_outlined;
      case 'Sports': return Icons.sports_basketball_outlined;
      default: return Icons.link;
    }
  }

  Color _accent() {
    switch (r.category) {
      case 'Classroom': return Brand.sky;
      case 'Clever': return Brand.purple;
      case 'Library': return Brand.sun;
      case 'Sports': return Brand.coral;
      default: return Brand.mint;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    final u = state.currentUser!;
    final canDelete = u.role == UserRole.admin || u.id == r.authorId;
    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: t.paper,
          title: Text(r.title, style: TextStyle(color: t.ink, fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (r.description.isNotEmpty) Text(r.description, style: TextStyle(color: t.ink)),
              const SizedBox(height: 8),
              SelectableText(r.url, style: const TextStyle(color: Brand.purple, fontWeight: FontWeight.w700)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: r.url));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied')));
              },
              child: const Text('Copy link'),
            ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: sticker(t, fill: _accent(), radius: 14, offset: const Offset(3, 3)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Icon(_icon(), color: Brand.ink, size: 26),
              const Spacer(),
              if (canDelete)
                GestureDetector(
                  onTap: () => state.deleteResource(r.id),
                  child: const Icon(Icons.close, size: 16, color: Brand.ink),
                ),
            ]),
            Text(r.title,
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900, color: Brand.ink, fontSize: 14, letterSpacing: -0.2)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONTACTS
// ─────────────────────────────────────────────────────────────────────────────

class ContactsScreen extends StatelessWidget {
  final AppState state;
  const ContactsScreen({super.key, required this.state});
  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    final u = state.currentUser!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('People'),
        actions: [
          if (u.role == UserRole.admin)
            IconButton(icon: const Icon(Icons.add), onPressed: () => _editContact(context, null)),
          ThemeToggleBtn(state: state),
        ],
      ),
      body: state.contacts.isEmpty
          ? const EmptyState(emoji: '☎️', title: 'No contacts', message: 'Admin can add staff and important contacts.')
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: state.contacts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final c = state.contacts[i];
                final accent = StickerPalette.accent(c.name.codeUnitAt(0));
                return Container(
                  decoration: sticker(t, fill: t.paper, radius: 16, offset: const Offset(3, 3)),
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Brand.ink, width: 2),
                      ),
                      child: Center(child: Text(
                        c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                        style: const TextStyle(color: Brand.ink, fontWeight: FontWeight.w900, fontSize: 18))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.name,
                            style: TextStyle(fontWeight: FontWeight.w900, color: t.ink, fontSize: 15)),
                          Text('${c.title} · ${c.department}',
                            style: TextStyle(color: t.mute, fontSize: 12, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text('${c.email} · ${c.phone}',
                            style: TextStyle(color: t.ink, fontSize: 12, height: 1.4)),
                        ],
                      ),
                    ),
                    if (u.role == UserRole.admin)
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: t.mute),
                        onSelected: (v) {
                          if (v == 'edit') _editContact(context, c);
                          if (v == 'delete') state.deleteContact(c.id);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      )
                    else
                      IconButton(
                        icon: Icon(Icons.copy, size: 18, color: t.mute),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: c.email));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Email copied')));
                        },
                      ),
                  ]),
                );
              },
            ),
    );
  }

  void _editContact(BuildContext context, Contact? existing) {
    final name = TextEditingController(text: existing?.name ?? '');
    final title = TextEditingController(text: existing?.title ?? '');
    final email = TextEditingController(text: existing?.email ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '');
    final dept = TextEditingController(text: existing?.department ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Tones.of(context).paper,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20,
          bottom: 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(existing == null ? 'New contact' : 'Edit contact',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                color: Tones.of(ctx).ink, letterSpacing: -0.6)),
            const SizedBox(height: 14),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 10),
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 10),
            TextField(controller: dept, decoration: const InputDecoration(labelText: 'Department')),
            const SizedBox(height: 10),
            TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 10),
            TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (name.text.trim().isEmpty) return;
                state.upsertContact(Contact(
                  id: existing?.id ?? _newId(),
                  name: name.text.trim(),
                  title: title.text.trim(),
                  email: email.text.trim(),
                  phone: phone.text.trim(),
                  department: dept.text.trim(),
                ));
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE
// ─────────────────────────────────────────────────────────────────────────────

class ProfileScreen extends StatefulWidget {
  final AppState state;
  const ProfileScreen({super.key, required this.state});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _bio;
  late final TextEditingController _grade;
  late String _avatar;

  static const _avatars = ['🙂','😎','🤓','🏃','🎤','🎨','⚽','🎸','📚','🤖','🦄','🐱','🐶','👔','🧑‍🎓'];

  @override
  void initState() {
    super.initState();
    final u = widget.state.currentUser!;
    _name = TextEditingController(text: u.name);
    _bio = TextEditingController(text: u.bio);
    _grade = TextEditingController(text: u.grade);
    _avatar = u.avatarEmoji;
  }

  @override
  void dispose() {
    _name.dispose(); _bio.dispose(); _grade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    final u = widget.state.currentUser!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Me'),
        actions: [
          ThemeToggleBtn(state: widget.state),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => widget.state.signOut(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: sticker(t, fill: Brand.lime, radius: 22, offset: const Offset(5, 5)),
            child: Column(
              children: [
                Container(
                  width: 96, height: 96,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Brand.ink, width: 2),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(child: Text(_avatar, style: const TextStyle(fontSize: 56))),
                ),
                const SizedBox(height: 10),
                Text(u.name,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                    color: Brand.ink, letterSpacing: -0.4)),
                Text(u.email,
                  style: const TextStyle(color: Brand.ink, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                RoleBadge(role: u.role),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _settingsRow(t,
            icon: widget.state.darkMode ? Icons.dark_mode : Icons.light_mode,
            label: 'Dark mode',
            trailing: Switch(
              value: widget.state.darkMode,
              activeThumbColor: Brand.purple,
              onChanged: (_) => widget.state.toggleDarkMode(),
            ),
          ),
          const SizedBox(height: 22),
          Text('Avatar',
            style: TextStyle(fontWeight: FontWeight.w900, color: t.ink, fontSize: 14, letterSpacing: -0.2)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              for (final a in _avatars)
                GestureDetector(
                  onTap: () => setState(() => _avatar = a),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: _avatar == a ? Brand.purpleSoft : t.paper,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _avatar == a ? Brand.purple : t.line,
                        width: _avatar == a ? 3 : 2,
                      ),
                    ),
                    child: Center(child: Text(a, style: const TextStyle(fontSize: 22))),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Display name')),
          const SizedBox(height: 10),
          TextField(controller: _grade, decoration: const InputDecoration(labelText: 'Grade')),
          const SizedBox(height: 10),
          TextField(
            controller: _bio,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Bio', hintText: 'Tell others about yourself'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              widget.state.updateProfile(
                name: _name.text.trim(),
                bio: _bio.text.trim(),
                grade: _grade.text.trim(),
                avatarEmoji: _avatar,
              );
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved')));
            },
            child: const Text('Save profile'),
          ),
        ],
      ),
    );
  }

  Widget _settingsRow(Tones t, {required IconData icon, required String label, required Widget trailing}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: sticker(t, fill: t.paper, radius: 14, offset: const Offset(3, 3)),
      child: Row(children: [
        Icon(icon, color: t.ink),
        const SizedBox(width: 12),
        Expanded(child: Text(label,
          style: TextStyle(fontWeight: FontWeight.w800, color: t.ink, fontSize: 15))),
        trailing,
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LEADERSHIP: POST
// ─────────────────────────────────────────────────────────────────────────────

class LeadershipPostScreen extends StatelessWidget {
  final AppState state;
  const LeadershipPostScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Create'),
          actions: [ThemeToggleBtn(state: state)],
          bottom: const TabBar(
            indicatorColor: Brand.purple,
            indicatorWeight: 3,
            labelColor: Brand.purple,
            labelStyle: TextStyle(fontWeight: FontWeight.w900),
            tabs: [
              Tab(icon: Icon(Icons.campaign_outlined), text: 'Announce'),
              Tab(icon: Icon(Icons.image_outlined), text: 'Flyer'),
              Tab(icon: Icon(Icons.link), text: 'Link'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _AnnouncementForm(state: state),
            _FlyerForm(state: state),
            _ResourceForm(state: state),
          ],
        ),
      ),
    );
  }
}

class _AnnouncementForm extends StatefulWidget {
  final AppState state;
  const _AnnouncementForm({required this.state});
  @override
  State<_AnnouncementForm> createState() => _AnnouncementFormState();
}

class _AnnouncementFormState extends State<_AnnouncementForm> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _pin = false;
  int _color = 0;

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    final isAdmin = widget.state.currentUser!.role == UserRole.admin;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
        const SizedBox(height: 10),
        TextField(controller: _body, maxLines: 6, decoration: const InputDecoration(labelText: 'Message')),
        const SizedBox(height: 14),
        Text('Color',
          style: TextStyle(fontWeight: FontWeight.w900, color: t.ink, letterSpacing: -0.2)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          children: [
            for (var i = 0; i < StickerPalette.accents.length; i++)
              GestureDetector(
                onTap: () => setState(() => _color = i),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: StickerPalette.accents[i],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _color == i ? Brand.purple : t.line,
                      width: _color == i ? 3 : 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (isAdmin) ...[
          const SizedBox(height: 8),
          SwitchListTile(
            value: _pin,
            onChanged: (v) => setState(() => _pin = v),
            activeThumbColor: Brand.purple,
            contentPadding: EdgeInsets.zero,
            title: const Text('Pin to top'),
            subtitle: const Text('Pinned posts stay above everything else.'),
          ),
        ],
        const SizedBox(height: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.send),
          label: const Text('Post announcement'),
          onPressed: () {
            if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) return;
            widget.state.postAnnouncement(_title.text.trim(), _body.text.trim(),
              pinned: _pin, colorSeed: _color);
            _title.clear();
            _body.clear();
            setState(() { _pin = false; _color = 0; });
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🎉 Posted!')));
          },
        ),
      ],
    );
  }
}

class _FlyerForm extends StatefulWidget {
  final AppState state;
  const _FlyerForm({required this.state});
  @override
  State<_FlyerForm> createState() => _FlyerFormState();
}

class _FlyerFormState extends State<_FlyerForm> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  String _emoji = '📣';
  int _color = 0;
  static const _emojis = ['📣','🎉','🏈','🎭','🎨','🩸','🍕','📚','🏆','🎤'];

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(controller: _title, decoration: const InputDecoration(labelText: 'Flyer title')),
        const SizedBox(height: 10),
        TextField(controller: _desc, maxLines: 4, decoration: const InputDecoration(labelText: 'Description')),
        const SizedBox(height: 14),
        Text('Icon', style: TextStyle(fontWeight: FontWeight.w900, color: t.ink, letterSpacing: -0.2)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final e in _emojis)
              GestureDetector(
                onTap: () => setState(() => _emoji = e),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: _emoji == e ? Brand.purpleSoft : t.paper,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _emoji == e ? Brand.purple : t.line,
                      width: _emoji == e ? 3 : 2,
                    ),
                  ),
                  child: Center(child: Text(e, style: const TextStyle(fontSize: 22))),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text('Color', style: TextStyle(fontWeight: FontWeight.w900, color: t.ink, letterSpacing: -0.2)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (var i = 0; i < _FlyerCard._palette.length; i++)
              GestureDetector(
                onTap: () => setState(() => _color = i),
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: _FlyerCard._palette[i]),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _color == i ? Brand.purple : t.line,
                      width: _color == i ? 3 : 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.send),
          label: const Text('Post flyer'),
          onPressed: () {
            if (_title.text.trim().isEmpty) return;
            widget.state.postFlyer(_title.text.trim(), _desc.text.trim(), _emoji, _color);
            _title.clear();
            _desc.clear();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📄 Flyer posted!')));
          },
        ),
      ],
    );
  }
}

class _ResourceForm extends StatefulWidget {
  final AppState state;
  const _ResourceForm({required this.state});
  @override
  State<_ResourceForm> createState() => _ResourceFormState();
}

class _ResourceFormState extends State<_ResourceForm> {
  final _title = TextEditingController();
  final _url = TextEditingController();
  final _desc = TextEditingController();
  String _category = 'Classroom';
  static const _cats = ['Classroom', 'Clever', 'Library', 'Sports', 'Other'];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
        const SizedBox(height: 10),
        TextField(controller: _url, decoration: const InputDecoration(labelText: 'URL (https://...)')),
        const SizedBox(height: 10),
        TextField(controller: _desc, decoration: const InputDecoration(labelText: 'Description')),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _category,
          decoration: const InputDecoration(labelText: 'Category'),
          items: [for (final c in _cats) DropdownMenuItem(value: c, child: Text(c))],
          onChanged: (v) => setState(() => _category = v ?? 'Other'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.send),
          label: const Text('Post link'),
          onPressed: () {
            if (_title.text.trim().isEmpty || _url.text.trim().isEmpty) return;
            widget.state.postResource(_title.text.trim(), _url.text.trim(), _category, _desc.text.trim());
            _title.clear();
            _url.clear();
            _desc.clear();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🔗 Resource posted!')));
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADMIN DASHBOARD
// ─────────────────────────────────────────────────────────────────────────────

class AdminDashboard extends StatelessWidget {
  final AppState state;
  const AdminDashboard({super.key, required this.state});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin'),
          actions: [ThemeToggleBtn(state: state)],
          bottom: const TabBar(
            indicatorColor: Brand.purple,
            indicatorWeight: 3,
            labelColor: Brand.purple,
            labelStyle: TextStyle(fontWeight: FontWeight.w900),
            tabs: [
              Tab(icon: Icon(Icons.people_outline), text: 'Users'),
              Tab(icon: Icon(Icons.insights_outlined), text: 'Stats'),
              Tab(icon: Icon(Icons.history), text: 'Audit'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _UsersTab(state: state),
            _OverviewTab(state: state),
            _AuditTab(state: state),
          ],
        ),
      ),
    );
  }
}

class _UsersTab extends StatefulWidget {
  final AppState state;
  const _UsersTab({required this.state});
  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  String _filter = '';
  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    final me = widget.state.currentUser!;
    final list = widget.state.users
        .where((u) => _filter.isEmpty
            || u.name.toLowerCase().contains(_filter.toLowerCase())
            || u.email.toLowerCase().contains(_filter.toLowerCase()))
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search users',
            ),
            onChanged: (v) => setState(() => _filter = v),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final u = list[i];
              return Container(
                decoration: sticker(t, fill: t.paper, radius: 14, offset: const Offset(3, 3)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: Brand.roleColor(u.role),
                      border: Border.all(color: Brand.ink, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(child: Text(u.avatarEmoji, style: const TextStyle(fontSize: 20))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(child: Text(u.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              decoration: u.disabled ? TextDecoration.lineThrough : null,
                              color: u.disabled ? t.mute : t.ink,
                              fontSize: 14,
                            ))),
                          RoleBadge(role: u.role, dense: true),
                        ]),
                        Text('${u.email}${u.grade.isEmpty ? '' : ' · Grade ${u.grade}'}',
                          style: TextStyle(color: t.mute, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  if (u.id == me.id)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Brand.purpleSoft,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Brand.ink, width: 1.5),
                      ),
                      child: const Text('YOU',
                        style: TextStyle(color: Brand.ink, fontWeight: FontWeight.w900, fontSize: 10)),
                    )
                  else
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: t.mute),
                      onSelected: (v) {
                        if (v == 'disable') widget.state.setUserDisabled(u.id, !u.disabled);
                        if (v == 'student') widget.state.setUserRole(u.id, UserRole.student);
                        if (v == 'leadership') widget.state.setUserRole(u.id, UserRole.leadership);
                        if (v == 'admin') widget.state.setUserRole(u.id, UserRole.admin);
                        if (v == 'delete') {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              backgroundColor: t.paper,
                              title: const Text('Delete user?'),
                              content: Text('This permanently removes ${u.name}.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                TextButton(
                                  onPressed: () { widget.state.deleteUser(u.id); Navigator.pop(context); },
                                  child: const Text('Delete', style: TextStyle(color: Brand.danger)),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'disable', child: Text(u.disabled ? 'Re-enable access' : 'Disable access')),
                        const PopupMenuDivider(),
                        const PopupMenuItem(value: 'student', child: Text('Set role: Student')),
                        const PopupMenuItem(value: 'leadership', child: Text('Set role: Leadership')),
                        const PopupMenuItem(value: 'admin', child: Text('Set role: Admin')),
                        const PopupMenuDivider(),
                        const PopupMenuItem(value: 'delete', child: Text('Delete user')),
                      ],
                    ),
                ]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final AppState state;
  const _OverviewTab({required this.state});

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    final totalUsers = state.users.length;
    final students = state.users.where((u) => u.role == UserRole.student).length;
    final leaders = state.users.where((u) => u.role == UserRole.leadership).length;
    final admins = state.users.where((u) => u.role == UserRole.admin).length;
    final disabled = state.users.where((u) => u.disabled).length;
    final revenue = state.tickets.fold<double>(0, (sum, tk) {
      final e = state.events.cast<Event?>().firstWhere((ev) => ev!.id == tk.eventId, orElse: () => null);
      return sum + (e?.ticketPrice ?? 0);
    });

    Widget stat(String label, String value, IconData icon, Color color) => Container(
      decoration: sticker(t, fill: color, radius: 14, offset: const Offset(3, 3)),
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Brand.ink, width: 1.5),
          ),
          child: Icon(icon, color: Brand.ink, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                style: const TextStyle(color: Brand.ink, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              Text(value,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Brand.ink, letterSpacing: -0.6)),
            ],
          ),
        ),
      ]),
    );

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        stat('TOTAL USERS', '$totalUsers', Icons.people, Brand.purpleSoft),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: stat('STUDENTS', '$students', Icons.school, Brand.skySoft)),
          const SizedBox(width: 10),
          Expanded(child: stat('LEADERS', '$leaders', Icons.star, Brand.sunSoft)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: stat('ADMINS', '$admins', Icons.shield, Brand.coralSoft)),
          const SizedBox(width: 10),
          Expanded(child: stat('DISABLED', '$disabled', Icons.block, t.lineSoft)),
        ]),
        const SizedBox(height: 10),
        stat('ANNOUNCEMENTS', '${state.announcements.length}', Icons.campaign, Brand.pinkSoft),
        const SizedBox(height: 10),
        stat('EVENTS', '${state.events.length}', Icons.event, Brand.mintSoft),
        const SizedBox(height: 10),
        stat('TICKETS SOLD', '${state.tickets.length}', Icons.confirmation_num, Brand.lime),
        const SizedBox(height: 10),
        stat('REVENUE', '\$${revenue.toStringAsFixed(2)}', Icons.attach_money, Brand.mint),
      ],
    );
  }
}

class _AuditTab extends StatelessWidget {
  final AppState state;
  const _AuditTab({required this.state});
  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    if (state.audit.isEmpty) {
      return const EmptyState(emoji: '📜', title: 'No activity yet', message: 'User actions show up here.');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: state.audit.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: t.lineSoft),
      itemBuilder: (_, i) {
        final a = state.audit[i];
        return ListTile(
          dense: true,
          leading: Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
              color: Brand.purple,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: Brand.ink, width: 1),
            ),
          ),
          title: Text(a.action,
            style: TextStyle(fontWeight: FontWeight.w800, color: t.ink, fontSize: 14)),
          subtitle: Text('${a.actorName} · ${_timeAgo(a.timestamp)}',
            style: TextStyle(color: t.mute, fontSize: 12, fontWeight: FontWeight.w600)),
        );
      },
    );
  }
}
