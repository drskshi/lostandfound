import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'logic.dart';
import 'models.dart';
import 'seed.dart';

/// On-device campus data. Roles come from the saved account, never from a
/// control on the sign-in form. This is not the shared website database.
class CampusStore extends ChangeNotifier {
  CampusStore();

  CampusStore.demo() {
    _memory = true;
    _replace(seedSnapshot());
    ready = true;
    seenOnboarding = true;
  }

  bool _memory = false;
  SharedPreferences? _prefs;
  bool ready = false;
  bool seenOnboarding = false;
  ThemeMode themeMode = ThemeMode.light;
  String? userId;
  bool serverAccount = false;
  String? authMessage;
  Future<void> Function()? endServerSession;

  List<Campus> campuses = [];
  List<Place> places = [];
  List<Person> people = [];
  List<CampusItem> items = [];
  List<Claim> claims = [];
  List<ItemComment> comments = [];
  List<ContentReport> reports = [];
  List<Notice> notices = [];
  List<AuditEntry> audit = [];
  Map<String, List<String>> savedByUser = {};
  Map<String, CampusSettings> settings = {};
  List<String> departmentNames = [];

  Person? get me {
    final id = userId;
    if (id == null) return null;
    for (final person in people) {
      if (person.id == id) return person;
    }
    return null;
  }

  Campus? get campus {
    final id = me?.campusId;
    if (id == null) return null;
    for (final campus in campuses) {
      if (campus.id == id) return campus;
    }
    return null;
  }

  CampusSettings get campusSettings =>
      settings[me?.campusId] ?? CampusSettings();

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    seenOnboarding = prefs.getBool('onboarding') ?? false;
    themeMode = switch (prefs.getString('theme')) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };
    final raw = prefs.getString('campus');
    if (raw == null) {
      _replace(seedSnapshot());
    } else {
      try {
        _replace(
          CampusSnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>),
        );
      } catch (_) {
        _replace(seedSnapshot());
      }
    }
    serverAccount = prefs.getBool('server-account') ?? false;
    userId = prefs.getString('user');
    if (serverAccount) {
      _replace(
        CampusSnapshot(
          campuses: const [],
          places: const [],
          people: const [],
          items: const [],
          claims: const [],
          comments: const [],
          reports: const [],
          notices: const [],
          audit: const [],
          savedByUser: const {},
          settings: const {},
        ),
      );
    } else if (me == null) {
      userId = null;
    }
    ready = true;
    notifyListeners();
  }

  void _replace(CampusSnapshot snapshot) {
    departmentNames = [];
    campuses = snapshot.campuses;
    places = snapshot.places;
    people = snapshot.people;
    items = snapshot.items;
    claims = snapshot.claims;
    comments = snapshot.comments;
    reports = snapshot.reports;
    notices = snapshot.notices;
    audit = snapshot.audit;
    savedByUser = snapshot.savedByUser;
    settings = snapshot.settings;
  }

  void showServerRecords(CampusSnapshot snapshot, List<String> departments) {
    _replace(snapshot);
    departmentNames = departments;
    serverAccount = true;
    notifyListeners();
    _persist();
  }

  Future<void> _persist() async {
    final prefs = _prefs;
    if (_memory || prefs == null) return;
    if (serverAccount) {
      await prefs.remove('campus');
      if (userId == null) {
        await prefs.remove('user');
      } else {
        await prefs.setString('user', userId!);
      }
      await prefs.setBool('server-account', true);
      return;
    }
    await prefs.setString(
      'campus',
      jsonEncode(
        CampusSnapshot(
          campuses: campuses,
          places: places,
          people: people,
          items: items,
          claims: claims,
          comments: comments,
          reports: reports,
          notices: notices,
          audit: audit,
          savedByUser: savedByUser,
          settings: settings,
        ).toJson(),
      ),
    );
    if (userId == null) {
      await prefs.remove('user');
    } else {
      await prefs.setString('user', userId!);
    }
    await prefs.setBool('server-account', serverAccount);
  }

  /// Opens the account returned by the database. [role] must already be the
  /// server value. This does not accept a role chosen on the sign-in screen.
  void replaceSignedInAccount({
    required String id,
    required String email,
    required String name,
    required String role,
    required bool emailVerified,
    required String status,
  }) {
    final campusId = campuses.isEmpty ? 'ravensbourne' : campuses.first.id;
    Person? existing;
    for (final person in people) {
      if (person.id == id) existing = person;
    }
    if (existing == null) {
      people.add(
        Person(
          id: id,
          campusId: campusId,
          name: name,
          email: email,
          passwordHash: '',
          department: '',
          bio: '',
          role: role,
          status: status,
          createdAt: DateTime.now(),
          emailVerified: emailVerified,
          tone: 0xFF285DE5,
        ),
      );
    } else {
      existing.name = name;
      existing.email = email;
      existing.role = role;
      existing.status = status;
      existing.emailVerified = emailVerified;
      existing.passwordHash = '';
    }
    userId = id;
    serverAccount = true;
    authMessage = null;
    _touch();
  }

  void setAuthMessage(String? message) {
    authMessage = message;
    notifyListeners();
  }

  void clearServerSession() {
    if (!serverAccount && userId == null) return;
    userId = null;
    serverAccount = false;
    _touch();
  }

  void _touch() {
    notifyListeners();
    _persist();
  }

  void finishOnboarding() {
    seenOnboarding = true;
    _prefs?.setBool('onboarding', true);
    notifyListeners();
  }

  void setTheme(ThemeMode mode) {
    themeMode = mode;
    _prefs?.setString('theme', switch (mode) {
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
      ThemeMode.light => 'light',
    });
    notifyListeners();
  }

  Future<void> resetDemo() async {
    _replace(seedSnapshot());
    userId = null;
    await _persist();
    notifyListeners();
  }

  String? signIn(String email, String password) {
    final person = _byEmail(email);
    final hashed = hashPassword(password);
    if (person == null ||
        person.passwordHash.isEmpty ||
        person.passwordHash != hashed) {
      return "That email and password don't match.";
    }
    if (person.status != 'active') {
      return 'This account is suspended. Contact your campus lost property office.';
    }
    userId = person.id;
    _touch();
    return null;
  }

  String? register({
    required String name,
    required String email,
    required String password,
    required String department,
  }) {
    final cleanEmail = email.trim().toLowerCase();
    final campusId = campusForEmail(cleanEmail);
    if (name.trim().length < 2) return 'Enter your name.';
    if (campusId == null) {
      return 'Use a sample campus address ending in @ravensbourne.example or @kingsmere.example.';
    }
    if (password.length < 10) return 'Use at least 10 characters.';
    if (_byEmail(cleanEmail) != null)
      return 'There is already an account with that email. Try signing in.';
    final id = 'user-${DateTime.now().microsecondsSinceEpoch}';
    final code = newCode(Random.secure().nextInt(1000000));
    people.add(
      Person(
        id: id,
        campusId: campusId,
        name: name.trim(),
        email: cleanEmail,
        passwordHash: hashPassword(password),
        department: department.trim(),
        bio: '',
        role: 'member',
        status: 'active',
        createdAt: DateTime.now(),
        emailVerified: false,
        verifyCode: code,
        tone: 0xFF285DE5,
      ),
    );
    userId = id;
    _touch();
    return null;
  }

  String? verify(String code) {
    final person = me;
    if (person == null) return 'Sign in first.';
    if (person.verifyAttempts >= maxCodeAttempts)
      return 'Too many wrong attempts. Send a new code.';
    if (person.verifyCode == null)
      return 'That code has expired. Send a new one.';
    if (code.trim() != person.verifyCode) {
      person.verifyAttempts += 1;
      _touch();
      return "That code isn't right.";
    }
    person.emailVerified = true;
    person.verifyCode = null;
    person.verifyAttempts = 0;
    _notice(
      person.id,
      'Welcome',
      'Your campus membership is ready on this phone.',
      '/feed',
    );
    _touch();
    return null;
  }

  String? resendCode() {
    final person = me;
    if (person == null) return 'Sign in first.';
    person.verifyCode = newCode(Random.secure().nextInt(1000000));
    person.verifyAttempts = 0;
    _touch();
    return null;
  }

  bool _endingServerSession = false;

  void signOut() {
    final wasServer = serverAccount;
    userId = null;
    serverAccount = false;
    if (wasServer) _replace(seedSnapshot());
    _touch();
    final end = endServerSession;
    if (end == null || _endingServerSession) return;
    _endingServerSession = true;
    end().whenComplete(() => _endingServerSession = false);
  }

  String? changePassword(String current, String next) {
    final person = me;
    if (person == null) return 'Sign in first.';
    if (person.passwordHash != hashPassword(current))
      return "That password isn't right.";
    if (next.length < 10) return 'Use at least 10 characters.';
    person.passwordHash = hashPassword(next);
    _touch();
    return null;
  }

  void updateProfile({
    required String name,
    required String department,
    required String bio,
  }) {
    final person = me;
    if (person == null || name.trim().length < 2) return;
    person.name = name.trim();
    person.department = department.trim();
    person.bio = bio.trim();
    _touch();
  }

  void setMyNotifications(bool enabled) {
    final person = me;
    if (person == null) return;
    person.notifications = enabled;
    _touch();
  }

  String exportJson() {
    final person = me;
    if (person == null) return '{}';
    final mineItems = items
        .where((item) => item.authorId == person.id)
        .map((item) => item.toJson())
        .toList();
    final mineClaims = claims.where((claim) => claim.userId == person.id).map((
      claim,
    ) {
      final copy = claim.toJson();
      copy.remove('code');
      return copy;
    }).toList();
    return const JsonEncoder.withIndent('  ').convert({
      'exportedAt': DateTime.now().toIso8601String(),
      'note': 'Local copy from this phone. Private details of other people are not included.',
      'account': person.toJson()
        ..remove('passwordHash')
        ..remove('verifyCode'),
      'posts': mineItems,
      'claims': mineClaims,
      'notices': notices
          .where((notice) => notice.userId == person.id)
          .map((notice) => notice.toJson())
          .toList(),
    });
  }

  void deleteMyAccount() {
    final person = me;
    if (person == null || person.isAdmin) return;
    final office = people.cast<Person?>().firstWhere(
      (candidate) =>
          candidate!.campusId == person.campusId && candidate.id == 'office',
      orElse: () => null,
    );
    for (final item
        in items.where((item) => item.authorId == person.id).toList()) {
      if (item.type == 'found' && item.custody == 'office' && office != null) {
        item.authorId = office.id;
      } else {
        items.remove(item);
        claims.removeWhere((claim) => claim.itemId == item.id);
        comments.removeWhere((comment) => comment.itemId == item.id);
      }
    }
    claims.removeWhere((claim) => claim.userId == person.id);
    comments.removeWhere((comment) => comment.authorId == person.id);
    notices.removeWhere((notice) => notice.userId == person.id);
    savedByUser.remove(person.id);
    people.remove(person);
    _audit(
      person.campusId,
      'Account deleted',
      'An account was deleted at the user\'s request.',
    );
    userId = null;
    _touch();
  }

  List<CampusItem> visibleItems({
    String type = 'all',
    String category = 'all',
    String colour = 'all',
    String placeId = 'all',
    String query = '',
    bool includeClosed = false,
  }) {
    final campusId = me?.campusId;
    final terms = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .take(8)
        .toList();
    return items.where((item) {
      if (item.campusId != campusId) return false;
      if (!includeClosed &&
          item.status != 'open' &&
          item.status != 'reserved' &&
          item.status != 'returned') {
        return false;
      }
      if (!includeClosed && item.status == 'returned') return false;
      if (type != 'all' && item.type != type) return false;
      if (category != 'all' && item.category != category) return false;
      if (colour != 'all' && item.colour.toLowerCase() != colour.toLowerCase())
        return false;
      if (placeId != 'all' && item.placeId != placeId) return false;
      if (terms.isEmpty) return true;
      final haystack =
          '${item.title} ${item.description} ${item.colour} ${item.category} ${item.ref} ${placeName(item.placeId)}'
              .toLowerCase();
      return terms.every(haystack.contains);
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<CampusItem> feedItems({String type = 'all', String category = 'all'}) {
    final open = visibleItems(type: type, category: category);
    final returned = items.where((item) {
      if (item.campusId != me?.campusId || item.status != 'returned')
        return false;
      if (type != 'all' && item.type != type) return false;
      if (category != 'all' && item.category != category) return false;
      return true;
    });
    return [...open, ...returned];
  }

  bool isSaved(String itemId) => savedByUser[me?.id]?.contains(itemId) ?? false;

  void toggleSave(String itemId) {
    final id = me?.id;
    final item = this.item(itemId);
    if (id == null || item == null || item.campusId != me!.campusId) return;
    final saved = savedByUser.putIfAbsent(id, () => []);
    if (saved.contains(itemId)) {
      saved.remove(itemId);
    } else {
      saved.add(itemId);
    }
    _touch();
  }

  bool likedByMe(String itemId) =>
      item(itemId)?.likedBy.contains(me?.id) ?? false;

  void toggleLike(String itemId) {
    final id = me?.id;
    final item = this.item(itemId);
    if (id == null || item == null || item.campusId != me!.campusId) return;
    if (item.likedBy.contains(id)) {
      item.likedBy.remove(id);
      item.likeCount = max(0, item.likeCount - 1);
    } else {
      item.likedBy.add(id);
      item.likeCount += 1;
    }
    _touch();
  }

  List<CampusItem> savedItems() {
    final ids = savedByUser[me?.id] ?? const [];
    return [
      for (final id in ids)
        if (item(id) != null && item(id)!.campusId == me?.campusId) item(id)!,
    ];
  }

  String? createItem({
    required String type,
    required String title,
    required String category,
    required String colour,
    required String placeId,
    required String description,
    String privateDetails = '',
    String? photoPath,
  }) {
    final person = me;
    if (person == null) return 'Sign in first.';
    if (person.status != 'active') return 'This account is suspended.';
    final cleanTitle = title.trim();
    if (cleanTitle.length < 3) return 'Add a short title.';
    if (description.trim().length < 10)
      return 'Describe the item in a sentence or two.';
    if (!categories.contains(category)) return 'Choose a category.';
    if (place(placeId)?.campusId != person.campusId)
      return 'Choose a place on your campus.';
    final recent = items.any(
      (item) =>
          item.authorId == person.id &&
          item.title == cleanTitle &&
          DateTime.now().difference(item.createdAt).inSeconds < 20,
    );
    if (recent) return 'That post was just added.';
    final rules = settings[person.campusId] ?? CampusSettings();
    if (type == 'found' &&
        rules.requireProof &&
        privateDetails.trim().length < 8) {
      return 'Add a private detail only the owner would know.';
    }
    final refPrefix = person.campusId == 'kingsmere' ? 'KM' : 'NB';
    final count = items
        .where((item) => item.campusId == person.campusId)
        .length;
    final created = DateTime.now();
    final id = 'item-${created.microsecondsSinceEpoch}';
    items.insert(
      0,
      CampusItem(
        id: id,
        campusId: person.campusId,
        ref: '$refPrefix-${1100 + count}',
        title: cleanTitle,
        type: type,
        category: category,
        placeId: placeId,
        authorId: person.id,
        colour: colour,
        description: description.trim(),
        privateDetails: type == 'found' ? privateDetails.trim() : '',
        status: 'open',
        createdAt: created,
        likeCount: 0,
        likedBy: {},
        shelf: type == 'found' ? 'Intake' : '',
        retainUntil: created.add(Duration(days: rules.retentionDays)),
        photoPath: photoPath,
        custody: type == 'found' && person.isStaff ? 'office' : 'finder',
      ),
    );
    _audit(person.campusId, 'Item posted', '$refPrefix · $cleanTitle');
    _touch();
    return null;
  }

  String? addComment(String itemId, String text) {
    final person = me;
    final item = this.item(itemId);
    if (person == null || item == null || item.campusId != person.campusId)
      return 'That post is not available.';
    final screened = screenText(text.trim());
    if (screened.text.length < 2) return 'Write a comment first.';
    final id = 'comment-${DateTime.now().microsecondsSinceEpoch}';
    comments.add(
      ItemComment(
        id: id,
        itemId: itemId,
        authorId: person.id,
        text: screened.text,
        at: DateTime.now(),
        flagged: screened.flagged,
      ),
    );
    if (screened.flagged) {
      reports.add(
        ContentReport(
          id: 'report-$id',
          itemId: itemId,
          commentId: id,
          reason: screened.reasons.join(', '),
          status: 'open',
          at: DateTime.now(),
        ),
      );
      _audit(person.campusId, 'Comment flagged', screened.reasons.join(', '));
    }
    _touch();
    return screened.flagged
        ? 'Sent. Keep contact on the app, and never pay to get an item back.'
        : null;
  }

  String? reportContent({
    required String itemId,
    String? commentId,
    required String reason,
  }) {
    final person = me;
    final item = this.item(itemId);
    if (person == null || item == null || item.campusId != person.campusId)
      return 'That post is not available.';
    if (reason.trim().isEmpty) return 'Choose a reason.';
    final duplicate = reports.any(
      (report) =>
          report.itemId == itemId &&
          report.commentId == commentId &&
          report.status == 'open',
    );
    if (duplicate) return 'This has already been reported.';
    reports.add(
      ContentReport(
        id: 'report-${DateTime.now().microsecondsSinceEpoch}',
        itemId: itemId,
        commentId: commentId,
        reason: reason.trim(),
        status: 'open',
        at: DateTime.now(),
      ),
    );
    for (final staff in people.where(
      (candidate) => candidate.campusId == person.campusId && candidate.isStaff,
    )) {
      _notice(staff.id, 'New report', reason.trim(), '/staff/moderation');
    }
    _touch();
    return null;
  }

  String? submitClaim({
    required String itemId,
    required String description,
    required String where,
    required String when,
    String? evidencePath,
  }) {
    final person = me;
    final item = this.item(itemId);
    if (person == null || item == null || item.campusId != person.campusId)
      return 'This item is not on your campus.';
    if (item.type != 'found') return 'You can only claim a found item.';
    if (item.authorId == person.id)
      return 'You posted this item, so you cannot claim it.';
    if (item.status != 'open')
      return 'This item already has an approved claim.';
    if (description.trim().length < 30)
      return 'Describe the item in a bit more detail (at least a couple of sentences).';
    if (claims.any(
      (claim) => claim.itemId == itemId && claim.userId == person.id,
    )) {
      return 'You already have a claim on this item.';
    }
    final active = claims
        .where((claim) => claim.userId == person.id && claim.isActive)
        .length;
    if (active >= maxActiveClaims)
      return 'You already have $maxActiveClaims claims in progress.';
    final screened = screenText(description.trim());
    final id = 'claim-${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now();
    claims.add(
      Claim(
        id: id,
        itemId: itemId,
        userId: person.id,
        description: screened.text,
        where: where.trim(),
        when: when.trim(),
        status: 'pending',
        note: '',
        createdAt: now,
        evidencePath: evidencePath,
        events: [
          ClaimEvent(
            title: 'Claim submitted',
            detail: 'A reviewer will compare it with the private details.',
            at: now,
          ),
        ],
      ),
    );
    final reviewers = people.where(
      (candidate) =>
          candidate.campusId == item.campusId &&
          (candidate.isStaff ||
              (candidate.id == item.authorId && !item.sensitive)),
    );
    for (final reviewer in reviewers) {
      if (reviewer.id == person.id) continue;
      _notice(
        reviewer.id,
        'New claim on ${item.title}',
        item.ref,
        reviewer.isStaff ? '/staff/reviews/$id' : '/claims/$id',
      );
    }
    _audit(item.campusId, 'Claim received', '${person.name} · ${item.ref}');
    _touch();
    return null;
  }

  String? withdrawClaim(String claimId) {
    final person = me;
    final claim = this.claim(claimId);
    if (person == null || claim == null || claim.userId != person.id)
      return 'This claim is not yours.';
    if (!claim.isActive) return 'This claim is already closed.';
    final item = this.item(claim.itemId);
    claim.status = 'withdrawn';
    claim.code = null;
    claim.events.add(ClaimEvent(title: 'Withdrawn', at: DateTime.now()));
    if (item != null && item.status == 'reserved') item.status = 'open';
    _audit(
      item?.campusId ?? person.campusId,
      'Claim withdrawn',
      item?.ref ?? claim.id,
    );
    _touch();
    return null;
  }

  String? reply(String claimId, String text) {
    final person = me;
    final claim = this.claim(claimId);
    final item = claim == null ? null : this.item(claim.itemId);
    if (person == null || claim == null || item == null)
      return 'Claim not found.';
    if (item.campusId != person.campusId)
      return 'This claim is on another campus.';
    final allowed = claim.userId == person.id || canReview(item);
    if (!allowed) return 'You are not part of this claim.';
    if (claim.status == 'rejected' ||
        claim.status == 'withdrawn' ||
        claim.status == 'completed') {
      return 'This claim is closed.';
    }
    final screened = screenText(text.trim());
    if (screened.text.isEmpty) return 'Write a message first.';
    claim.messages.add(
      ClaimMessage(
        authorId: person.id,
        text: screened.text,
        at: DateTime.now(),
        flagged: screened.flagged,
      ),
    );
    if (claim.userId == person.id && claim.status == 'needsInfo') {
      claim.status = 'pending';
      claim.events.add(
        ClaimEvent(
          title: 'More information sent',
          detail: screened.text,
          at: DateTime.now(),
        ),
      );
    }
    final target = claim.userId == person.id ? item.authorId : claim.userId;
    if (person.isStaff || item.custody == 'office') {
      if (claim.userId == person.id) {
        for (final staff in people.where(
          (candidate) =>
              candidate.campusId == item.campusId && candidate.isStaff,
        )) {
          _notice(
            staff.id,
            'Claimant replied: ${item.title}',
            screened.text,
            '/staff/reviews/${claim.id}',
          );
        }
      } else {
        _notice(
          claim.userId,
          'New message about ${item.title}',
          screened.text,
          '/claims/${claim.id}',
        );
      }
    } else {
      _notice(
        target,
        'New message about ${item.title}',
        screened.text,
        '/claims/${claim.id}',
      );
    }
    _touch();
    return screened.flagged
        ? 'Sent. We noticed ${screened.reasons.join(', ')}.'
        : null;
  }

  String? decide({
    required String claimId,
    required String decision,
    String note = '',
  }) {
    final person = me;
    final claim = this.claim(claimId);
    final item = claim == null ? null : this.item(claim.itemId);
    if (person == null || claim == null || item == null)
      return 'Claim not found.';
    if (!canReview(item))
      return 'Only the finder or the lost property office can review this claim.';
    if (claim.status != 'pending' && claim.status != 'needsInfo')
      return 'This claim has already been decided.';
    if (decision != 'approve' && note.trim().isEmpty)
      return 'Add a short note so the claimant knows why.';
    final now = DateTime.now();
    if (decision == 'approve') {
      if (item.status != 'open')
        return 'Another claim on this item is already approved.';
      final code = newCode(Random.secure().nextInt(1000000));
      claim.status = 'approved';
      claim.note = note.trim();
      claim.code = code;
      claim.codeExpires = now.add(const Duration(days: handoverDays));
      claim.attempts = 0;
      item.status = 'reserved';
      claim.events.add(
        ClaimEvent(
          title: 'Approved, ready to collect',
          detail: 'A collection code was issued.',
          at: now,
        ),
      );
      _notice(
        claim.userId,
        'Your claim for ${item.title} was approved',
        'Open the claim to see your collection code.',
        '/claims/${claim.id}',
      );
      _audit(item.campusId, 'Claim approved', '${item.ref} by ${person.name}');
    } else if (decision == 'reject') {
      claim.status = 'rejected';
      claim.note = note.trim();
      claim.events.add(
        ClaimEvent(title: 'Not approved', detail: note.trim(), at: now),
      );
      _notice(
        claim.userId,
        'Your claim for ${item.title} was not approved',
        note.trim(),
        '/claims/${claim.id}',
      );
      _audit(item.campusId, 'Claim rejected', '${item.ref}: ${note.trim()}');
    } else if (decision == 'needsInfo') {
      claim.status = 'needsInfo';
      claim.note = note.trim();
      claim.messages.add(
        ClaimMessage(authorId: person.id, text: note.trim(), at: now),
      );
      claim.events.add(
        ClaimEvent(
          title: 'More information needed',
          detail: note.trim(),
          at: now,
        ),
      );
      _notice(
        claim.userId,
        'More information needed for ${item.title}',
        note.trim(),
        '/claims/${claim.id}',
      );
      _audit(
        item.campusId,
        'Information requested',
        '${item.ref}: ${note.trim()}',
      );
    } else {
      return 'Unknown decision.';
    }
    _touch();
    return null;
  }

  String? handover(String claimId, String code) {
    final person = me;
    final claim = this.claim(claimId);
    final item = claim == null ? null : this.item(claim.itemId);
    if (person == null || claim == null || item == null)
      return 'Claim not found.';
    if (!canReview(item))
      return 'Only the finder or the office can confirm a handover.';
    if (claim.status == 'completed') return 'This code has already been used.';
    if (claim.status != 'approved' || claim.code == null)
      return "This claim isn't ready for collection.";
    if (claim.attempts >= maxCodeAttempts)
      return 'Too many wrong codes. Ask the office to reissue one.';
    if (claim.codeExpires != null &&
        claim.codeExpires!.isBefore(DateTime.now())) {
      return 'This code has expired. Ask the office to reissue one.';
    }
    if (code.replaceAll(' ', '') != claim.code) {
      claim.attempts += 1;
      _touch();
      return "That code doesn't match. Ask the owner to read it from their claim.";
    }
    final now = DateTime.now();
    claim.status = 'completed';
    claim.code = null;
    claim.events.add(
      ClaimEvent(
        title: 'Collected',
        detail: 'Handover confirmed with the collection code.',
        at: now,
      ),
    );
    item.status = 'returned';
    for (final other in claims.where(
      (other) =>
          other.itemId == item.id &&
          other.id != claim.id &&
          (other.status == 'pending' || other.status == 'needsInfo'),
    )) {
      other.status = 'rejected';
      other.note = 'This item has been returned to its owner.';
      other.events.add(
        ClaimEvent(title: 'Not approved', detail: other.note, at: now),
      );
      _notice(
        other.userId,
        '${item.title} was returned to its owner',
        other.note,
        '/claims/${other.id}',
      );
    }
    _notice(
      claim.userId,
      '${item.title} is back with you',
      'Glad it found its way home.',
      '/claims/${claim.id}',
    );
    _audit(
      item.campusId,
      'Item returned',
      '${item.ref} handed over with a verified code',
    );
    _touch();
    return null;
  }

  String? reissue(String claimId) {
    final person = me;
    final claim = this.claim(claimId);
    final item = claim == null ? null : this.item(claim.itemId);
    if (person == null || !person.isStaff || claim == null || item == null)
      return 'Only campus staff can reissue a code.';
    if (item.campusId != person.campusId || claim.status != 'approved')
      return 'This claim is not waiting for collection.';
    claim.code = newCode(Random.secure().nextInt(1000000));
    claim.codeExpires = DateTime.now().add(const Duration(days: handoverDays));
    claim.attempts = 0;
    claim.events.add(
      ClaimEvent(title: 'New collection code', at: DateTime.now()),
    );
    _notice(
      claim.userId,
      'You have a new collection code',
      item.title,
      '/claims/${claim.id}',
    );
    _audit(item.campusId, 'Code reissued', item.ref);
    _touch();
    return null;
  }

  /// Used by tests to move a code past its expiry without waiting seven days.
  void expireCodeForTest(String claimId) {
    final claim = this.claim(claimId);
    claim?.codeExpires = DateTime.now().subtract(const Duration(hours: 1));
  }

  void markAllRead() {
    for (final notice in myNotices) {
      notice.read = true;
    }
    _touch();
  }

  void markRead(String id) {
    for (final notice in notices) {
      if (notice.id == id) notice.read = true;
    }
    _touch();
  }

  String? setRole(String personId, String role) {
    final actor = me;
    final target = person(personId);
    if (actor == null || !actor.isAdmin || target == null)
      return 'You cannot change roles.';
    if (target.campusId != actor.campusId)
      return 'That person is on another campus.';
    if (target.id == actor.id ||
        target.role == 'admin' ||
        target.id == 'office')
      return 'That role cannot be changed here.';
    if (role != 'member' && role != 'staff') return 'Choose member or staff.';
    target.role = role;
    _audit(actor.campusId, 'Role updated', '${target.name} is now $role');
    _touch();
    return null;
  }

  String? setSuspended(String personId, bool suspended) {
    final actor = me;
    final target = person(personId);
    if (actor == null || !actor.isStaff || target == null)
      return 'You cannot change this account.';
    if (target.campusId != actor.campusId ||
        target.id == actor.id ||
        target.role == 'admin' ||
        target.id == 'office') {
      return 'That account cannot be suspended here.';
    }
    target.status = suspended ? 'suspended' : 'active';
    _audit(
      actor.campusId,
      suspended ? 'Account suspended' : 'Account restored',
      target.name,
    );
    _touch();
    return null;
  }

  String? moderate(String reportId, String decision) {
    final actor = me;
    final report = reports.cast<ContentReport?>().firstWhere(
      (row) => row!.id == reportId,
      orElse: () => null,
    );
    final item = report == null ? null : this.item(report.itemId);
    if (actor == null || !actor.isStaff || report == null || item == null)
      return 'You cannot review this report.';
    if (item.campusId != actor.campusId || report.status != 'open')
      return 'This report is already closed.';
    if (decision == 'removed') {
      report.status = 'removed';
      if (report.commentId != null) {
        for (final comment in comments) {
          if (comment.id == report.commentId) comment.hidden = true;
        }
      } else {
        item.status = 'archived';
      }
      _audit(actor.campusId, 'Report actioned', report.reason);
    } else if (decision == 'dismissed') {
      report.status = 'dismissed';
      _audit(actor.campusId, 'Report dismissed', report.reason);
    } else {
      return 'Unknown decision.';
    }
    _touch();
    return null;
  }

  String? setShelf(String itemId, String shelf) {
    final actor = me;
    final item = this.item(itemId);
    if (actor == null ||
        !actor.isStaff ||
        item == null ||
        item.campusId != actor.campusId)
      return 'You cannot edit this item.';
    item.shelf = shelf.trim();
    _touch();
    return null;
  }

  String? extendHold(String itemId) {
    final actor = me;
    final item = this.item(itemId);
    if (actor == null ||
        !actor.isStaff ||
        item == null ||
        item.campusId != actor.campusId)
      return 'You cannot edit this item.';
    item.retainUntil = item.retainUntil.add(const Duration(days: 14));
    _audit(actor.campusId, 'Hold extended', '${item.ref} · 14 more days');
    _touch();
    return null;
  }

  String? closeItem(String itemId, String method) {
    final actor = me;
    final item = this.item(itemId);
    if (actor == null ||
        !actor.isStaff ||
        item == null ||
        item.campusId != actor.campusId)
      return 'You cannot edit this item.';
    if (item.status == 'returned')
      return 'This item has already been returned.';
    item.status = 'archived';
    item.disposalMethod = method;
    _audit(actor.campusId, 'Item closed', '${item.ref} · $method');
    _touch();
    return null;
  }

  void updateStaffSettings({
    int? retentionDays,
    bool? notifications,
    bool? requireProof,
  }) {
    final actor = me;
    if (actor == null || !actor.isAdmin) return;
    final current = settings.putIfAbsent(actor.campusId, CampusSettings.new);
    if (retentionDays != null)
      current.retentionDays = retentionDays.clamp(7, 90);
    if (notifications != null) current.notifications = notifications;
    if (requireProof != null) current.requireProof = requireProof;
    _audit(
      actor.campusId,
      'Settings updated',
      'Holding period ${current.retentionDays} days',
    );
    _touch();
  }

  bool canReview(CampusItem item) {
    final person = me;
    if (person == null ||
        person.status != 'active' ||
        person.campusId != item.campusId)
      return false;
    if (person.isStaff) return true;
    return item.authorId == person.id &&
        item.custody == 'finder' &&
        !item.sensitive;
  }

  bool canSeePrivate(CampusItem item) {
    final person = me;
    if (person == null || person.campusId != item.campusId) return false;
    return person.isStaff || person.id == item.authorId;
  }

  bool canSeeEvidence(Claim claim) {
    final person = me;
    final item = this.item(claim.itemId);
    if (person == null || item == null) return false;
    return claim.userId == person.id || canReview(item);
  }

  Assist assistFor(Claim claim) {
    final item = this.item(claim.itemId);
    final replies = claim.messages
        .where((message) => message.authorId == claim.userId)
        .map((message) => message.text)
        .join(' ');
    return verificationAssist(
      item?.privateDetails,
      '${claim.description} $replies',
    );
  }

  Risk riskFor(Claim claim) {
    final claimant = person(claim.userId);
    final since = DateTime.now().subtract(const Duration(days: 30));
    final mine = claims.where((other) => other.userId == claim.userId).toList();
    final categoriesClaimed = mine
        .where((other) => other.createdAt.isAfter(since))
        .map((other) => item(other.itemId)?.category)
        .whereType<String>()
        .toSet();
    final flagged =
        comments
            .where(
              (comment) => comment.authorId == claim.userId && comment.flagged,
            )
            .length +
        claim.messages
            .where(
              (message) => message.authorId == claim.userId && message.flagged,
            )
            .length;
    return claimRisk(
      accountAgeDays: claimant == null
          ? 0
          : DateTime.now().difference(claimant.createdAt).inHours / 24,
      claimsLast30Days: mine
          .where((other) => other.createdAt.isAfter(since))
          .length,
      rejectedClaims: mine.where((other) => other.status == 'rejected').length,
      distinctCategories: categoriesClaimed.length,
      flaggedMessages: flagged,
      assistScore: assistFor(claim).score,
    );
  }

  List<Notice> get myNotices {
    final id = me?.id;
    final rows = notices.where((notice) => notice.userId == id).toList();
    rows.sort((a, b) => b.at.compareTo(a.at));
    return rows;
  }

  int get unread => myNotices.where((notice) => !notice.read).length;

  List<Claim> myClaims() {
    final rows = claims
        .where(
          (claim) =>
              claim.userId == me?.id &&
              item(claim.itemId)?.campusId == me?.campusId,
        )
        .toList();
    rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return rows;
  }

  List<Claim> reviewQueue() {
    final person = me;
    if (person == null) return [];
    final rows = claims.where((claim) {
      final item = this.item(claim.itemId);
      return item != null && canReview(item);
    }).toList();
    rows.sort((a, b) {
      const rank = {
        'pending': 0,
        'needsInfo': 1,
        'approved': 2,
        'rejected': 3,
        'completed': 4,
        'withdrawn': 5,
      };
      return (rank[a.status] ?? 9).compareTo(rank[b.status] ?? 9);
    });
    return rows;
  }

  List<ContentReport> openReports() {
    return reports.where((report) {
      final item = this.item(report.itemId);
      return report.status == 'open' && item?.campusId == me?.campusId;
    }).toList();
  }

  Place? place(String? id) {
    for (final place in places) {
      if (place.id == id) return place;
    }
    return null;
  }

  String placeName(String? id) => place(id)?.name ?? 'Campus';

  Person? person(String? id) {
    for (final person in people) {
      if (person.id == id) return person;
    }
    return null;
  }

  CampusItem? item(String? id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  Claim? claim(String? id) {
    for (final claim in claims) {
      if (claim.id == id) return claim;
    }
    return null;
  }

  List<Claim> claimsForItem(String itemId) =>
      claims.where((claim) => claim.itemId == itemId).toList();

  List<ItemComment> commentsFor(String itemId) => comments
      .where((comment) => comment.itemId == itemId && !comment.hidden)
      .toList();

  List<Place> get myPlaces =>
      places.where((place) => place.campusId == me?.campusId).toList();

  Person? _byEmail(String email) {
    final clean = email.trim().toLowerCase();
    for (final person in people) {
      if (person.email == clean) return person;
    }
    return null;
  }

  void _notice(String userId, String title, String body, String route) {
    final person = this.person(userId);
    final campusId = person?.campusId;
    if (person == null || !person.notifications) return;
    if (campusId != null && settings[campusId]?.notifications == false) return;
    notices.insert(
      0,
      Notice(
        id: 'n-${DateTime.now().microsecondsSinceEpoch}-$userId',
        userId: userId,
        title: title,
        body: body,
        route: route,
        at: DateTime.now(),
      ),
    );
  }

  void _audit(String campusId, String action, String detail) {
    audit.insert(
      0,
      AuditEntry(
        id: 'audit-${DateTime.now().microsecondsSinceEpoch}',
        campusId: campusId,
        actor: me?.name ?? 'System',
        action: action,
        detail: detail,
        at: DateTime.now(),
      ),
    );
  }
}

String formatWhen(DateTime time) {
  final local = time.toLocal();
  final diff = DateTime.now().difference(local);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}

String formatDate(DateTime time) {
  final local = time.toLocal();
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${months[local.month - 1]} ${local.year}, $hour:$minute';
}

String statusLabel(String status) {
  return switch (status) {
    'open' => 'Open',
    'reserved' => 'Claim approved',
    'returned' => 'Returned',
    'archived' => 'Closed',
    'pending' => 'Under review',
    'needsInfo' => 'More info needed',
    'approved' => 'Ready to collect',
    'rejected' => 'Not approved',
    'withdrawn' => 'Withdrawn',
    'completed' => 'Collected',
    _ => status,
  };
}
