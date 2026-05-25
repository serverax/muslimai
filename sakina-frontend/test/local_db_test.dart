import 'package:flutter_test/flutter_test.dart';
import 'package:sakina_frontend/services/local_db_service.dart';

void main() {
  test('Message round-trips through toMap/fromMap', () {
    final msg = Message(
      id: 'abc',
      content: 'Assalamu alaikum',
      role: 'user',
      timestamp: 1700000000,
      sources: null,
      createdAt: 1700000001,
    );

    final restored = Message.fromMap(msg.toMap());

    expect(restored.id, 'abc');
    expect(restored.content, 'Assalamu alaikum');
    expect(restored.role, 'user');
    expect(restored.timestamp, 1700000000);
    expect(restored.sources, isNull);
    expect(restored.createdAt, 1700000001);
  });
}
