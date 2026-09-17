import 'package:accord_memo/application/ports/id_generator.dart';

List<String> spareIds([int count = 24]) {
  return List.generate(
    count,
    (i) => '00000000-0000-4000-8000-${(i + 1).toString().padLeft(12, '0')}',
  );
}

final class FakeIdGenerator implements IdGenerator {
  FakeIdGenerator(this._ids);

  final List<String> _ids;
  var _index = 0;

  @override
  String next() {
    final id = _ids[_index];
    _index += 1;
    return id;
  }
}
