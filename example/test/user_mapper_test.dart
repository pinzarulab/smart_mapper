import 'package:smart_mapper_example/models.dart';
import 'package:smart_mapper_example/user_mapper.dart';
import 'package:test/test.dart';

void main() {
  const remote = UserResponse(
    id: '42',
    fullName: 'Ada Lovelace',
    email: 'ada@example.com',
  );
  final mapper = createUserMapper();

  test('maps Remote DTO to Domain Entity', () {
    final user = mapper.map(remote);
    expect(user.id, '42');
    expect(user.name, 'Ada Lovelace');
    expect(user.email, 'ada@example.com');
  });

  test('maps Remote DTO through Local Model to Domain Entity', () {
    final local = mapper.toLocal(remote);
    final user = mapper.fromLocal(local);
    expect(local.fullName, 'Ada Lovelace');
    expect(user.name, 'Ada Lovelace');
  });

  test('maps into a target with an unnamed factory constructor', () {
    final summary = mapper.toSummary(remote);
    expect(summary.id, '42');
    expect(summary.email, 'ada@example.com');
  });
}
