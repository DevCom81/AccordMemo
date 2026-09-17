import 'package:accord_memo/application/ports/id_generator.dart';

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
