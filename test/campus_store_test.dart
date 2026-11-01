import 'package:flutter_test/flutter_test.dart';
import 'package:lost_found_mobile/data/logic.dart';
import 'package:lost_found_mobile/data/store.dart';

void main() {
  test(
    'private-detail hint matches the bottle story and does not approve it',
    () {
      final assist = verificationAssist(
        'Black loop lid. The initials A.O. are written on the base.',
        'It has a black loop lid with my initials A.O. written on the base.',
      );
      expect(assist.score, greaterThanOrEqualTo(60));
      expect(assist.matched, contains('black'));
    },
  );

  test('a member cannot approve a claim', () {
    final store = CampusStore.demo();
    expect(store.signIn('amara@ravensbourne.example', demoPassword), isNull);
    expect(store.decide(claimId: 'megan', decision: 'approve'), isNotNull);
    expect(store.claim('megan')?.status, 'pending');
  });

  test('staff approval, bad code, expiry and reuse', () {
    final store = CampusStore.demo();
    expect(store.signIn('dave@ravensbourne.example', demoPassword), isNull);
    expect(
      store.decide(
        claimId: 'megan',
        decision: 'approve',
        note: 'Checked the initials.',
      ),
      isNull,
    );
    expect(store.item('headphones')?.status, 'reserved');
    expect(
      store.decide(claimId: 'callum', decision: 'approve', note: 'Too late'),
      contains('already approved'),
    );
    final code = store.claim('megan')!.code!;
    expect(store.handover('megan', '000000'), contains("doesn't match"));
    store.expireCodeForTest('megan');
    expect(store.handover('megan', code), contains('expired'));
    store.claim('megan')!.codeExpires = DateTime.now().add(
      const Duration(days: 1),
    );
    expect(store.handover('megan', code), isNull);
    expect(store.claim('megan')?.status, 'completed');
    expect(store.handover('megan', code), contains('already been used'));
    expect(store.claim('callum')?.status, 'rejected');
  });

  test('another campus cannot see Ravensbourne posts', () {
    final store = CampusStore.demo();
    store.signIn('leo@kingsmere.example', demoPassword);
    expect(store.visibleItems().map((item) => item.id), ['km-notebook']);
    expect(store.item('bottle')?.campusId, 'ravensbourne');
    expect(store.visibleItems().any((item) => item.id == 'bottle'), isFalse);
  });

  test('creating a post shows it on that campus feed', () {
    final store = CampusStore.demo();
    store.signIn('amara@ravensbourne.example', demoPassword);
    expect(
      store.createItem(
        type: 'lost',
        title: 'Blue pencil case',
        category: 'Books & stationery',
        colour: 'Blue',
        placeId: 'library',
        description: 'Left it in a study pod on the second floor.',
      ),
      isNull,
    );
    expect(store.feedItems().first.title, 'Blue pencil case');
    expect(
      store.createItem(
        type: 'lost',
        title: 'Blue pencil case',
        category: 'Books & stationery',
        colour: 'Blue',
        placeId: 'library',
        description: 'Left it in a study pod on the second floor.',
      ),
      contains('just added'),
    );
  });

  test('wrong password and suspended-style sign-in failure', () {
    final store = CampusStore.demo();
    expect(
      store.signIn('amara@ravensbourne.example', 'not-the-password'),
      isNotNull,
    );
    expect(store.me, isNull);
  });
}
