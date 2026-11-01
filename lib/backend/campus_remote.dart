import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../domain/access_role.dart';
import 'google_auth.dart';
import 'local_bytes.dart';
import 'supabase_bootstrap.dart';

/// Reads and writes the shared campus database for a signed-in session.
/// The on-phone demo store stays in use until [SupabaseBootstrap.isReady].
class CampusRemote {
  static Future<String?>? _pending;

  static Future<String?> signIn(
    CampusStore store,
    String email,
    String password,
  ) async {
    if (!SupabaseBootstrap.isReady) return store.signIn(email, password);
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = response.user;
      if (user == null) return 'Sign-in did not finish.';
      return await adopt(store, user);
    } catch (error) {
      return safeDatabaseError(error);
    }
  }

  static Future<String?> register(
    CampusStore store, {
    required String name,
    required String email,
    required String password,
    required String department,
  }) async {
    if (!SupabaseBootstrap.isReady) {
      return store.register(
        name: name,
        email: email,
        password: password,
        department: department,
      );
    }
    final cleanName = name.trim();
    final cleanEmail = email.trim().toLowerCase();
    if (cleanName.length < 2) return 'Enter your name.';
    if (!cleanEmail.contains('@') || cleanEmail.startsWith('@')) {
      return 'Enter an email address.';
    }
    if (password.length < 10) return 'Use at least 10 characters.';
    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: cleanEmail,
        password: password,
        data: {'name': cleanName},
        emailRedirectTo: googleRedirect(web: kIsWeb),
      );
      final user = response.user;
      if (user == null || response.session == null) {
        return 'Check your email to confirm the account. New accounts join as students.';
      }
      await Supabase.instance.client
          .from('profiles')
          .update({'name': cleanName, 'department': department.trim()})
          .eq('id', user.id);
      return await adopt(store, user);
    } catch (error) {
      return safeDatabaseError(error);
    }
  }

  static Future<String?> sendPasswordReset(String email) async {
    if (!SupabaseBootstrap.isReady) {
      return 'Password reset needs a build that includes the shared database.';
    }
    final clean = email.trim().toLowerCase();
    if (!clean.contains('@')) return 'Enter the email on the account.';
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        clean,
        redirectTo: googleRedirect(web: kIsWeb),
      );
      return null;
    } catch (error) {
      return safeDatabaseError(error);
    }
  }

  static Future<String?> adopt(CampusStore store, User user) {
    return _pending ??= _adopt(
      store,
      user,
    ).whenComplete(() => _pending = null);
  }

  static Future<String?> _adopt(CampusStore store, User user) async {
    final client = Supabase.instance.client;
    Map<String, dynamic>? row;
    for (var attempt = 0; attempt < 2; attempt++) {
      row = await client
          .from('profiles')
          .select('id, email, name, role, status')
          .eq('id', user.id)
          .maybeSingle();
      if (row != null) break;
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    if (row == null) {
      store.setAuthMessage(
        'The account was created, but the student profile is not ready yet.',
      );
      await client.auth.signOut();
      return 'The student profile is not ready yet.';
    }
    if (row['status'] == 'suspended') {
      store.setAuthMessage(
        'This account is suspended. Contact your campus lost property office.',
      );
      await client.auth.signOut();
      return 'This account is suspended.';
    }
    final role = switch (parseAccessRole(row['role'] as String?)) {
      AccessRole.superadmin => 'superadmin',
      AccessRole.admin => 'admin',
      AccessRole.subadmin => 'subadmin',
      AccessRole.student || null => 'student',
    };
    store.replaceSignedInAccount(
      id: row['id'] as String,
      email: (row['email'] as String?) ?? user.email ?? '',
      name: (row['name'] as String?) ?? 'Student',
      role: role,
      emailVerified: user.emailConfirmedAt != null || responseConfirmed(user),
      status: (row['status'] as String?) ?? 'active',
    );
    return pull(store);
  }

  static bool responseConfirmed(User user) => user.emailConfirmedAt != null;

  static Future<String?> pull(CampusStore store) async {
    final me = store.me;
    if (me == null) return 'Sign in first.';
    try {
      final client = Supabase.instance.client;
      final universities = await client
          .from('universities')
          .select('id, name, short_name, city');
      final locations = await client
          .from('locations')
          .select('id, university_id, name, kind, lat, lng, hours, is_collection_point');
      final profiles = await client
          .from('profiles')
          .select(
            'id, university_id, email, name, role, status, department, bio, notifications_on, created_at',
          );
      final items = await client
          .from('items')
          .select(
            'id, ref, university_id, author_id, type, status, title, description, category, colour, location_id, sensitive, custody, retain_until, disposal_method, created_at',
          );
      final photos = await client
          .from('item_photos')
          .select('item_id, file_path, position');
      final watches = await client.from('watches').select('user_id, item_id');
      final claims = await client
          .from('claims')
          .select(
            'id, item_id, claimant_id, status, details, lost_where, decision_note, handover_code_expires_at, created_at',
          );
      final events = await _optional(
        client.from('claim_events').select('claim_id, title, detail, created_at'),
      );
      final comments = await _optional(
        client.from('comments').select('id, item_id, author_id, body, created_at'),
      );
      final notices = await client
          .from('notifications')
          .select('id, user_id, title, body, href, read_at, created_at');
      final departments = await _optional(
        client.from('departments').select('name'),
      );
      final audits = await _optional(
        client
            .from('audit_logs')
            .select('id, university_id, actor_id, action, summary, created_at'),
      );

      final photoByItem = <String, String>{};
      for (final row in _rows(photos)) {
        final itemId = row['item_id'] as String;
        final path = row['file_path'] as String?;
        if (path == null || photoByItem.containsKey(itemId)) continue;
        photoByItem[itemId] = await _signed('item-photos', path);
      }

      final saved = <String, List<String>>{};
      for (final row in _rows(watches)) {
        final userId = row['user_id'] as String;
        saved.putIfAbsent(userId, () => []).add(row['item_id'] as String);
      }

      final eventsByClaim = <String, List<ClaimEvent>>{};
      for (final row in events) {
        final claimId = row['claim_id'] as String;
        eventsByClaim.putIfAbsent(claimId, () => []).add(
          ClaimEvent(
            title: row['title'] as String? ?? '',
            detail: row['detail'] as String?,
            at: DateTime.parse(row['created_at'] as String),
          ),
        );
      }

      final claimModels = <Claim>[];
      for (final row in _rows(claims)) {
        final id = row['id'] as String;
        String? evidence;
        try {
          final path = await client.rpc(
            'claim_evidence_path',
            params: {'p_claim_id': id},
          );
          if (path is String && path.isNotEmpty) {
            evidence = await _signed('claim-evidence', path);
          }
        } catch (_) {
          evidence = null;
        }
        final status = row['status'] == 'needs_info'
            ? 'needsInfo'
            : row['status'] as String;
        claimModels.add(
          Claim(
            id: id,
            itemId: row['item_id'] as String,
            userId: row['claimant_id'] as String,
            description: row['details'] as String? ?? '',
            where: row['lost_where'] as String? ?? '',
            when: '',
            status: status,
            note: row['decision_note'] as String? ?? '',
            createdAt: DateTime.parse(row['created_at'] as String),
            codeExpires: row['handover_code_expires_at'] == null
                ? null
                : DateTime.parse(row['handover_code_expires_at'] as String),
            evidencePath: evidence,
            events: eventsByClaim[id] ?? const [],
          ),
        );
      }

      final campuses = [
        for (final row in _rows(universities))
          Campus(
            id: row['id'] as String,
            name: row['name'] as String? ?? 'Campus',
            shortName: row['short_name'] as String? ?? 'Campus',
            city: row['city'] as String? ?? '',
          ),
      ];
      store.showServerRecords(
        CampusSnapshot(
          campuses: campuses,
          places: [
            for (final row in _rows(locations))
              Place(
                id: row['id'] as String,
                campusId: row['university_id'] as String,
                name: row['name'] as String? ?? 'Campus',
                shortName: row['kind'] as String? ?? 'place',
                x: (row['lat'] as num?)?.toDouble() ?? 0,
                y: (row['lng'] as num?)?.toDouble() ?? 0,
                hours: row['hours'] as String? ?? '',
                collection: row['is_collection_point'] as bool? ?? false,
              ),
          ],
          people: [
            for (final row in _rows(profiles))
              Person(
                id: row['id'] as String,
                campusId: row['university_id'] as String,
                name: row['name'] as String? ?? 'Student',
                email: row['email'] as String? ?? '',
                passwordHash: '',
                department: row['department'] as String? ?? '',
                bio: row['bio'] as String? ?? '',
                role: switch (parseAccessRole(row['role'] as String?)) {
                  AccessRole.superadmin => 'superadmin',
                  AccessRole.admin => 'admin',
                  AccessRole.subadmin => 'subadmin',
                  AccessRole.student || null => 'student',
                },
                status: row['status'] as String? ?? 'active',
                createdAt: DateTime.parse(row['created_at'] as String),
                emailVerified: true,
                notifications: row['notifications_on'] as bool? ?? true,
                tone: 0xFF285DE5,
              ),
          ],
          items: [
            for (final row in _rows(items))
              CampusItem(
                id: row['id'] as String,
                campusId: row['university_id'] as String,
                ref: row['ref'] as String? ?? '',
                title: row['title'] as String? ?? '',
                type: row['type'] as String? ?? 'lost',
                category: row['category'] as String? ?? 'Other',
                placeId: row['location_id'] as String? ?? '',
                authorId: row['author_id'] as String,
                colour: row['colour'] as String? ?? '',
                description: row['description'] as String? ?? '',
                privateDetails: '',
                status: row['status'] as String? ?? 'open',
                createdAt: DateTime.parse(row['created_at'] as String),
                likeCount: 0,
                likedBy: {},
                shelf: '',
                retainUntil: row['retain_until'] == null
                    ? DateTime.parse(row['created_at'] as String).add(
                        const Duration(days: 30),
                      )
                    : DateTime.parse(row['retain_until'] as String),
                photoPath: photoByItem[row['id']],
                sensitive: row['sensitive'] as bool? ?? false,
                custody: row['custody'] as String? ?? 'finder',
                disposalMethod: row['disposal_method'] as String?,
              ),
          ],
          claims: claimModels,
          comments: [
            for (final row in comments)
              ItemComment(
                id: row['id'] as String,
                itemId: row['item_id'] as String,
                authorId: row['author_id'] as String,
                text: row['body'] as String? ?? '',
                at: DateTime.parse(row['created_at'] as String),
              ),
          ],
          reports: const [],
          notices: [
            for (final row in _rows(notices))
              Notice(
                id: row['id'] as String,
                userId: row['user_id'] as String,
                title: row['title'] as String? ?? '',
                body: row['body'] as String? ?? '',
                route: row['href'] as String? ?? '/feed',
                at: DateTime.parse(row['created_at'] as String),
                read: row['read_at'] != null,
              ),
          ],
          audit: [
            for (final row in audits)
              AuditEntry(
                id: row['id'] as String,
                campusId: row['university_id'] as String? ?? '',
                actor: row['actor_id'] as String? ?? '',
                action: row['action'] as String? ?? '',
                detail: row['summary'] as String? ?? '',
                at: DateTime.parse(row['created_at'] as String),
              ),
          ],
          savedByUser: saved,
          settings: {
            for (final campus in campuses) campus.id: CampusSettings(),
          },
        ),
        [
          for (final row in departments)
            if ((row['name'] as String?)?.isNotEmpty ?? false)
              row['name'] as String,
        ],
      );
      return null;
    } catch (error) {
      debugPrint('Campus records did not load: ${error.runtimeType}');
      return safeDatabaseError(error);
    }
  }

  static Future<String?> publishItem(
    CampusStore store, {
    required String type,
    required String title,
    required String category,
    required String colour,
    required String placeId,
    required String description,
    String privateDetails = '',
    String? photoPath,
  }) async {
    final person = store.me;
    if (person == null) return 'Sign in first.';
    if (title.trim().length < 3) return 'Add a short title.';
    if (description.trim().length < 10) {
      return 'Describe the item in a sentence or two.';
    }
    try {
      final inserted = await Supabase.instance.client
          .from('items')
          .insert({
            'university_id': person.campusId,
            'author_id': person.id,
            'type': type,
            'title': title.trim(),
            'description': description.trim(),
            'category': category,
            'colour': colour,
            'location_id': _uuid.hasMatch(placeId) ? placeId : null,
            'sensitive': false,
            'custody': person.isStaff && type == 'found' ? 'office' : 'finder',
            'private_details': type == 'found' ? privateDetails.trim() : '',
            'retain_until': DateTime.now()
                .toUtc()
                .add(const Duration(days: 30))
                .toIso8601String(),
          })
          .select('id')
          .single();
      final itemId = inserted['id'] as String;
      if (photoPath != null) {
        final uploaded = await _storeFile(
          bucket: 'item-photos',
          folder: itemId,
          path: photoPath,
        );
        if (uploaded != null) {
          await Supabase.instance.client.from('item_photos').insert({
            'item_id': itemId,
            'file_path': uploaded,
            'width': 0,
            'height': 0,
            'position': 0,
          });
        }
      }
      return await pull(store);
    } catch (error) {
      return safeDatabaseError(error);
    }
  }

  static Future<String?> toggleWatch(CampusStore store, String itemId) async {
    final person = store.me;
    if (person == null) return 'Sign in first.';
    try {
      final table = Supabase.instance.client.from('watches');
      if (store.isSaved(itemId)) {
        await table.delete().eq('user_id', person.id).eq('item_id', itemId);
      } else {
        await table.insert({'user_id': person.id, 'item_id': itemId});
      }
      return await pull(store);
    } catch (error) {
      return safeDatabaseError(error);
    }
  }

  static Future<RemoteClaim> submitClaim(
    CampusStore store, {
    required String itemId,
    required String description,
    required String where,
    required String when,
    String? evidencePath,
  }) async {
    final person = store.me;
    if (person == null) return const RemoteClaim('Sign in first.');
    if (description.trim().length < 10) {
      return const RemoteClaim('Describe how you know this is yours.');
    }
    try {
      String? proof;
      if (evidencePath != null) {
        proof = await _storeFile(
          bucket: 'claim-evidence',
          folder: 'pending',
          path: evidencePath,
        );
      }
      final inserted = await Supabase.instance.client
          .from('claims')
          .insert({
            'item_id': itemId,
            'claimant_id': person.id,
            'details': when.trim().isEmpty
                ? description.trim()
                : '${description.trim()}\nWhen: ${when.trim()}',
            'lost_where': where.trim(),
            'proof_path': proof,
          })
          .select('id')
          .single();
      final id = inserted['id'] as String;
      await _mail('claim_submitted', id);
      final error = await pull(store);
      return RemoteClaim(error, id: id);
    } catch (error) {
      return RemoteClaim(safeDatabaseError(error));
    }
  }

  static Future<String?> decide(
    CampusStore store, {
    required String claimId,
    required String decision,
    required String note,
  }) async {
    try {
      if (decision == 'approve') {
        final code = await Supabase.instance.client.rpc(
          'approve_claim',
          params: {'p_claim_id': claimId, 'p_note': note.trim()},
        );
        await _mail('claim_approved', claimId);
        final error = await pull(store);
        if (error != null) return error;
        return 'Approved. Collection code $code. It is also saved for the claimant.';
      }
      final function = decision == 'reject'
          ? 'reject_claim'
          : 'request_claim_info';
      await Supabase.instance.client.rpc(
        function,
        params: {'p_claim_id': claimId, 'p_note': note.trim()},
      );
      await _mail(
        decision == 'reject' ? 'claim_rejected' : 'claim_evidence',
        claimId,
      );
      return await pull(store);
    } catch (error) {
      return safeDatabaseError(error);
    }
  }

  static Future<String?> redeem(
    CampusStore store,
    String claimId,
    String code,
  ) async {
    try {
      await Supabase.instance.client.rpc(
        'redeem_collection_code',
        params: {'p_claim_id': claimId, 'p_code': code.trim()},
      );
      await _mail('handover', claimId);
      return await pull(store);
    } catch (error) {
      return safeDatabaseError(error);
    }
  }

  static void savePost(CampusStore store, String itemId) {
    if (!store.serverAccount) {
      store.toggleSave(itemId);
      return;
    }
    toggleWatch(store, itemId);
  }

  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static Future<List<Map<String, dynamic>>> _optional(dynamic query) async {
    try {
      return _rows(await query);
    } catch (error) {
      debugPrint('Optional campus read skipped: ${error.runtimeType}');
      return const [];
    }
  }

  static List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is! List) return const [];
    return [
      for (final row in value)
        if (row is Map<String, dynamic>) row,
    ];
  }

  static Future<String> _signed(String bucket, String path) async {
    if (path.startsWith('https://')) return path;
    try {
      return await Supabase.instance.client.storage
          .from(bucket)
          .createSignedUrl(path, 3600);
    } catch (_) {
      return path;
    }
  }

  static Future<String?> _storeFile({
    required String bucket,
    required String folder,
    required String path,
  }) async {
    final bytes = await readLocalBytes(path);
    if (bytes == null || bytes.isEmpty) return null;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return null;
    final name = '$userId/$folder/${DateTime.now().microsecondsSinceEpoch}.jpg';
    await Supabase.instance.client.storage
        .from(bucket)
        .uploadBinary(
          name,
          Uint8List.fromList(bytes),
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    return name;
  }

  static Future<void> _mail(String kind, String claimId) async {
    try {
      await Supabase.instance.client.functions.invoke(
        'send-campus-email',
        body: {'kind': kind, 'claimId': claimId},
      );
    } catch (error) {
      debugPrint('Campus mail was not accepted: ${error.runtimeType}');
    }
  }
}

class RemoteClaim {
  const RemoteClaim(this.error, {this.id});
  final String? error;
  final String? id;
}

String safeDatabaseError(Object error) {
  final raw = switch (error) {
    AuthException(:final message) => message,
    PostgrestException(:final message) => message,
    StorageException(:final message) => message,
    _ => '',
  };
  final lower = raw.toLowerCase();
  if (lower.contains('invalid login') || lower.contains('invalid credentials')) {
    return "That email and password don't match.";
  }
  if (lower.contains('already registered') ||
      lower.contains('already been registered')) {
    return 'There is already an account with that email. Try signing in.';
  }
  if (lower.contains('email not confirmed')) {
    return 'Confirm your email before signing in.';
  }
  if (lower.contains('not authorised') || lower.contains('permission')) {
    return 'You do not have permission for that action.';
  }
  if (lower.contains('network') ||
      lower.contains('socket') ||
      lower.contains('failed host')) {
    return 'The shared database could not be reached.';
  }
  if (raw.isEmpty ||
      raw.length > 180 ||
      raw.contains('eyJ') ||
      raw.contains('Bearer')) {
    return 'The shared database did not accept that change.';
  }
  return raw;
}
