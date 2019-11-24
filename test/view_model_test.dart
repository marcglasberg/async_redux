import 'package:async_redux/async_redux.dart';
import "package:test/test.dart";

class ViewModel extends BaseModel<List<int>> {
  List<int> list;

  ViewModel(this.list) : super(equals: [list]);

  @override
  BaseModel fromStore() {
    return ViewModel(state);
  }
}

void main() {
  ///////////////////////////////////////////////////////////////////////////////

  test('Get title and content from UserException.', () {
    final vm1 = ViewModel([1]);
    final vm2 = ViewModel([2]);
    final vm3 = ViewModel([2]);
    assert(vm1 != vm2);
    assert(vm2 != vm3);
  });

  ///////////////////////////////////////////////////////////////////////////////
}
