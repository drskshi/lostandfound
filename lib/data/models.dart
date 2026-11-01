class Campus {
  Campus({
    required this.id,
    required this.name,
    required this.shortName,
    required this.city,
  });
  final String id;
  final String name;
  final String shortName;
  final String city;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'shortName': shortName,
    'city': city,
  };
  factory Campus.fromJson(Map<String, dynamic> json) => Campus(
    id: json['id'] as String,
    name: json['name'] as String,
    shortName: json['shortName'] as String,
    city: json['city'] as String,
  );
}

class Place {
  Place({
    required this.id,
    required this.campusId,
    required this.name,
    required this.shortName,
    required this.x,
    required this.y,
    required this.hours,
    required this.collection,
  });
  final String id;
  final String campusId;
  final String name;
  final String shortName;
  final double x;
  final double y;
  final String hours;
  final bool collection;

  Map<String, dynamic> toJson() => {
    'id': id,
    'campusId': campusId,
    'name': name,
    'shortName': shortName,
    'x': x,
    'y': y,
    'hours': hours,
    'collection': collection,
  };
  factory Place.fromJson(Map<String, dynamic> json) => Place(
    id: json['id'] as String,
    campusId: json['campusId'] as String,
    name: json['name'] as String,
    shortName: json['shortName'] as String,
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    hours: json['hours'] as String,
    collection: json['collection'] as bool,
  );
}

class Person {
  Person({
    required this.id,
    required this.campusId,
    required this.name,
    required this.email,
    required this.passwordHash,
    required this.department,
    required this.bio,
    required this.role,
    required this.status,
    required this.createdAt,
    required this.emailVerified,
    this.verifyCode,
    this.verifyAttempts = 0,
    this.notifications = true,
    required this.tone,
  });

  final String id;
  final String campusId;
  String name;
  String email;
  String passwordHash;
  String department;
  String bio;
  String role;
  String status;
  final DateTime createdAt;
  bool emailVerified;
  String? verifyCode;
  int verifyAttempts;
  bool notifications;
  final int tone;

  bool get isStaff =>
      role == 'staff' ||
      role == 'admin' ||
      role == 'subadmin' ||
      role == 'superadmin';
  bool get isAdmin => role == 'admin' || role == 'superadmin';
  bool get canSignIn => passwordHash.isNotEmpty;
  String get initials {
    final parts = name.split(' ').where((part) => part.isNotEmpty).take(2);
    return parts.map((part) => part[0]).join().toUpperCase();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'campusId': campusId,
    'name': name,
    'email': email,
    'passwordHash': passwordHash,
    'department': department,
    'bio': bio,
    'role': role,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
    'emailVerified': emailVerified,
    'verifyCode': verifyCode,
    'verifyAttempts': verifyAttempts,
    'notifications': notifications,
    'tone': tone,
  };

  factory Person.fromJson(Map<String, dynamic> json) => Person(
    id: json['id'] as String,
    campusId: json['campusId'] as String,
    name: json['name'] as String,
    email: json['email'] as String,
    passwordHash: json['passwordHash'] as String? ?? '',
    department: json['department'] as String? ?? '',
    bio: json['bio'] as String? ?? '',
    role: json['role'] as String? ?? 'member',
    status: json['status'] as String? ?? 'active',
    createdAt: DateTime.parse(json['createdAt'] as String),
    emailVerified: json['emailVerified'] as bool? ?? false,
    verifyCode: json['verifyCode'] as String?,
    verifyAttempts: json['verifyAttempts'] as int? ?? 0,
    notifications: json['notifications'] as bool? ?? true,
    tone: json['tone'] as int? ?? 0xFF285DE5,
  );
}

class CampusItem {
  CampusItem({
    required this.id,
    required this.campusId,
    required this.ref,
    required this.title,
    required this.type,
    required this.category,
    required this.placeId,
    required this.authorId,
    required this.colour,
    required this.description,
    required this.privateDetails,
    required this.status,
    required this.createdAt,
    required this.likeCount,
    required this.likedBy,
    required this.shelf,
    required this.retainUntil,
    this.photoPath,
    this.sensitive = false,
    this.custody = 'finder',
    this.disposalMethod,
  });

  final String id;
  final String campusId;
  final String ref;
  String title;
  String type;
  String category;
  String placeId;
  String authorId;
  String colour;
  String description;
  String privateDetails;
  String status;
  final DateTime createdAt;
  int likeCount;
  final Set<String> likedBy;
  String shelf;
  DateTime retainUntil;
  String? photoPath;
  bool sensitive;
  String custody;
  String? disposalMethod;

  bool get isOpen => status == 'open' || status == 'reserved';

  Map<String, dynamic> toJson() => {
    'id': id,
    'campusId': campusId,
    'ref': ref,
    'title': title,
    'type': type,
    'category': category,
    'placeId': placeId,
    'authorId': authorId,
    'colour': colour,
    'description': description,
    'privateDetails': privateDetails,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
    'likeCount': likeCount,
    'likedBy': likedBy.toList(),
    'shelf': shelf,
    'retainUntil': retainUntil.toIso8601String(),
    'photoPath': photoPath,
    'sensitive': sensitive,
    'custody': custody,
    'disposalMethod': disposalMethod,
  };

  factory CampusItem.fromJson(Map<String, dynamic> json) => CampusItem(
    id: json['id'] as String,
    campusId: json['campusId'] as String,
    ref: json['ref'] as String,
    title: json['title'] as String,
    type: json['type'] as String,
    category: json['category'] as String,
    placeId: json['placeId'] as String,
    authorId: json['authorId'] as String,
    colour: json['colour'] as String? ?? '',
    description: json['description'] as String? ?? '',
    privateDetails: json['privateDetails'] as String? ?? '',
    status: json['status'] as String? ?? 'open',
    createdAt: DateTime.parse(json['createdAt'] as String),
    likeCount: json['likeCount'] as int? ?? 0,
    likedBy: {...(json['likedBy'] as List? ?? const []).cast<String>()},
    shelf: json['shelf'] as String? ?? '',
    retainUntil: DateTime.parse(json['retainUntil'] as String),
    photoPath: json['photoPath'] as String?,
    sensitive: json['sensitive'] as bool? ?? false,
    custody: json['custody'] as String? ?? 'finder',
    disposalMethod: json['disposalMethod'] as String?,
  );
}

class ClaimMessage {
  ClaimMessage({
    required this.authorId,
    required this.text,
    required this.at,
    this.flagged = false,
  });
  final String authorId;
  final String text;
  final DateTime at;
  final bool flagged;

  Map<String, dynamic> toJson() => {
    'authorId': authorId,
    'text': text,
    'at': at.toIso8601String(),
    'flagged': flagged,
  };
  factory ClaimMessage.fromJson(Map<String, dynamic> json) => ClaimMessage(
    authorId: json['authorId'] as String,
    text: json['text'] as String,
    at: DateTime.parse(json['at'] as String),
    flagged: json['flagged'] as bool? ?? false,
  );
}

class ClaimEvent {
  ClaimEvent({required this.title, this.detail, required this.at});
  final String title;
  final String? detail;
  final DateTime at;

  Map<String, dynamic> toJson() => {
    'title': title,
    'detail': detail,
    'at': at.toIso8601String(),
  };
  factory ClaimEvent.fromJson(Map<String, dynamic> json) => ClaimEvent(
    title: json['title'] as String,
    detail: json['detail'] as String?,
    at: DateTime.parse(json['at'] as String),
  );
}

class Claim {
  Claim({
    required this.id,
    required this.itemId,
    required this.userId,
    required this.description,
    required this.where,
    required this.when,
    required this.status,
    required this.note,
    required this.createdAt,
    this.code,
    this.codeExpires,
    this.attempts = 0,
    this.evidencePath,
    List<ClaimMessage>? messages,
    List<ClaimEvent>? events,
  }) : messages = messages ?? [],
       events = events ?? [];

  final String id;
  final String itemId;
  final String userId;
  String description;
  String where;
  String when;
  String status;
  String note;
  final DateTime createdAt;
  String? code;
  DateTime? codeExpires;
  int attempts;
  String? evidencePath;
  final List<ClaimMessage> messages;
  final List<ClaimEvent> events;

  bool get isActive =>
      status == 'pending' || status == 'needsInfo' || status == 'approved';

  Map<String, dynamic> toJson() => {
    'id': id,
    'itemId': itemId,
    'userId': userId,
    'description': description,
    'where': where,
    'when': when,
    'status': status,
    'note': note,
    'createdAt': createdAt.toIso8601String(),
    'code': code,
    'codeExpires': codeExpires?.toIso8601String(),
    'attempts': attempts,
    'evidencePath': evidencePath,
    'messages': messages.map((message) => message.toJson()).toList(),
    'events': events.map((event) => event.toJson()).toList(),
  };

  factory Claim.fromJson(Map<String, dynamic> json) => Claim(
    id: json['id'] as String,
    itemId: json['itemId'] as String,
    userId: json['userId'] as String,
    description: json['description'] as String,
    where: json['where'] as String? ?? '',
    when: json['when'] as String? ?? '',
    status: json['status'] as String,
    note: json['note'] as String? ?? '',
    createdAt: DateTime.parse(json['createdAt'] as String),
    code: json['code'] as String?,
    codeExpires: json['codeExpires'] == null
        ? null
        : DateTime.parse(json['codeExpires'] as String),
    attempts: json['attempts'] as int? ?? 0,
    evidencePath: json['evidencePath'] as String?,
    messages: [
      for (final row in (json['messages'] as List? ?? const []))
        ClaimMessage.fromJson(row as Map<String, dynamic>),
    ],
    events: [
      for (final row in (json['events'] as List? ?? const []))
        ClaimEvent.fromJson(row as Map<String, dynamic>),
    ],
  );
}

class ItemComment {
  ItemComment({
    required this.id,
    required this.itemId,
    required this.authorId,
    required this.text,
    required this.at,
    this.hidden = false,
    this.flagged = false,
  });
  final String id;
  final String itemId;
  final String authorId;
  final String text;
  final DateTime at;
  bool hidden;
  final bool flagged;

  Map<String, dynamic> toJson() => {
    'id': id,
    'itemId': itemId,
    'authorId': authorId,
    'text': text,
    'at': at.toIso8601String(),
    'hidden': hidden,
    'flagged': flagged,
  };
  factory ItemComment.fromJson(Map<String, dynamic> json) => ItemComment(
    id: json['id'] as String,
    itemId: json['itemId'] as String,
    authorId: json['authorId'] as String,
    text: json['text'] as String,
    at: DateTime.parse(json['at'] as String),
    hidden: json['hidden'] as bool? ?? false,
    flagged: json['flagged'] as bool? ?? false,
  );
}

class ContentReport {
  ContentReport({
    required this.id,
    required this.itemId,
    required this.reason,
    required this.status,
    required this.at,
    this.commentId,
  });
  final String id;
  final String itemId;
  final String? commentId;
  final String reason;
  String status;
  final DateTime at;

  Map<String, dynamic> toJson() => {
    'id': id,
    'itemId': itemId,
    'commentId': commentId,
    'reason': reason,
    'status': status,
    'at': at.toIso8601String(),
  };
  factory ContentReport.fromJson(Map<String, dynamic> json) => ContentReport(
    id: json['id'] as String,
    itemId: json['itemId'] as String,
    commentId: json['commentId'] as String?,
    reason: json['reason'] as String,
    status: json['status'] as String,
    at: DateTime.parse(json['at'] as String),
  );
}

class Notice {
  Notice({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.route,
    required this.at,
    this.read = false,
  });
  final String id;
  final String userId;
  final String title;
  final String body;
  final String route;
  final DateTime at;
  bool read;

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'title': title,
    'body': body,
    'route': route,
    'at': at.toIso8601String(),
    'read': read,
  };
  factory Notice.fromJson(Map<String, dynamic> json) => Notice(
    id: json['id'] as String,
    userId: json['userId'] as String,
    title: json['title'] as String,
    body: json['body'] as String? ?? '',
    route: json['route'] as String? ?? '/feed',
    at: DateTime.parse(json['at'] as String),
    read: json['read'] as bool? ?? false,
  );
}

class AuditEntry {
  AuditEntry({
    required this.id,
    required this.campusId,
    required this.actor,
    required this.action,
    required this.detail,
    required this.at,
  });
  final String id;
  final String campusId;
  final String actor;
  final String action;
  final String detail;
  final DateTime at;

  Map<String, dynamic> toJson() => {
    'id': id,
    'campusId': campusId,
    'actor': actor,
    'action': action,
    'detail': detail,
    'at': at.toIso8601String(),
  };
  factory AuditEntry.fromJson(Map<String, dynamic> json) => AuditEntry(
    id: json['id'] as String,
    campusId: json['campusId'] as String,
    actor: json['actor'] as String,
    action: json['action'] as String,
    detail: json['detail'] as String,
    at: DateTime.parse(json['at'] as String),
  );
}

class CampusSettings {
  CampusSettings({
    this.retentionDays = 30,
    this.notifications = true,
    this.requireProof = true,
  });
  int retentionDays;
  bool notifications;
  bool requireProof;

  Map<String, dynamic> toJson() => {
    'retentionDays': retentionDays,
    'notifications': notifications,
    'requireProof': requireProof,
  };
  factory CampusSettings.fromJson(Map<String, dynamic> json) => CampusSettings(
    retentionDays: json['retentionDays'] as int? ?? 30,
    notifications: json['notifications'] as bool? ?? true,
    requireProof: json['requireProof'] as bool? ?? true,
  );
}

class CampusSnapshot {
  CampusSnapshot({
    required this.campuses,
    required this.places,
    required this.people,
    required this.items,
    required this.claims,
    required this.comments,
    required this.reports,
    required this.notices,
    required this.audit,
    required this.savedByUser,
    required this.settings,
  });

  final List<Campus> campuses;
  final List<Place> places;
  final List<Person> people;
  final List<CampusItem> items;
  final List<Claim> claims;
  final List<ItemComment> comments;
  final List<ContentReport> reports;
  final List<Notice> notices;
  final List<AuditEntry> audit;
  final Map<String, List<String>> savedByUser;
  final Map<String, CampusSettings> settings;

  Map<String, dynamic> toJson() => {
    'version': 1,
    'campuses': campuses.map((row) => row.toJson()).toList(),
    'places': places.map((row) => row.toJson()).toList(),
    'people': people.map((row) => row.toJson()).toList(),
    'items': items.map((row) => row.toJson()).toList(),
    'claims': claims.map((row) => row.toJson()).toList(),
    'comments': comments.map((row) => row.toJson()).toList(),
    'reports': reports.map((row) => row.toJson()).toList(),
    'notices': notices.map((row) => row.toJson()).toList(),
    'audit': audit.map((row) => row.toJson()).toList(),
    'savedByUser': savedByUser,
    'settings': settings.map((key, value) => MapEntry(key, value.toJson())),
  };

  factory CampusSnapshot.fromJson(Map<String, dynamic> json) => CampusSnapshot(
    campuses: [
      for (final row in json['campuses'] as List)
        Campus.fromJson(row as Map<String, dynamic>),
    ],
    places: [
      for (final row in json['places'] as List)
        Place.fromJson(row as Map<String, dynamic>),
    ],
    people: [
      for (final row in json['people'] as List)
        Person.fromJson(row as Map<String, dynamic>),
    ],
    items: [
      for (final row in json['items'] as List)
        CampusItem.fromJson(row as Map<String, dynamic>),
    ],
    claims: [
      for (final row in json['claims'] as List)
        Claim.fromJson(row as Map<String, dynamic>),
    ],
    comments: [
      for (final row in json['comments'] as List)
        ItemComment.fromJson(row as Map<String, dynamic>),
    ],
    reports: [
      for (final row in json['reports'] as List)
        ContentReport.fromJson(row as Map<String, dynamic>),
    ],
    notices: [
      for (final row in json['notices'] as List)
        Notice.fromJson(row as Map<String, dynamic>),
    ],
    audit: [
      for (final row in json['audit'] as List)
        AuditEntry.fromJson(row as Map<String, dynamic>),
    ],
    savedByUser: {
      for (final entry in (json['savedByUser'] as Map).entries)
        entry.key as String: (entry.value as List).cast<String>(),
    },
    settings: {
      for (final entry in (json['settings'] as Map).entries)
        entry.key as String: CampusSettings.fromJson(
          entry.value as Map<String, dynamic>,
        ),
    },
  );
}
