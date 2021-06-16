import 'package:async_redux/async_redux.dart';
import "package:test/test.dart";

// ////////////////////////////////////////////////////////////////////////////

class MyObjPlain {
  @override
  bool operator ==(Object other) =>
      identical(this, other) || //
      other is MyObjPlain && runtimeType == other.runtimeType;

  @override
  int get hashCode => 0;
}

// ////////////////////////////////////////////////////////////////////////////

class MyObjVmEquals extends VmEquals<MyObjVmEquals> {
  @override
  bool operator ==(Object other) =>
      identical(this, other) || //
      other is MyObjVmEquals && runtimeType == other.runtimeType;

  @override
  int get hashCode => 0;
}

// ////////////////////////////////////////////////////////////////////////////

class ViewModel_Deprecated extends BaseModel<List<int>, int> {
  String name;
  int age;

  ViewModel_Deprecated(this.name, this.age)
      : super(equals: [
          name,
          age,
        ]);

  @override
  BaseModel fromStore() => throw AssertionError();
}

// ////////////////////////////////////////////////////////////////////////////

class ViewModel extends Vm {
  final String name;
  final int age;
  final dynamic myObj;

  ViewModel(this.name, this.age, this.myObj)
      : super(equals: [
          name,
          age,
          myObj,
        ]);
}

void main() {
  ///////////////////////////////////////////////////////////////////////////////

  test('BaseModel (deprecated) equality.', () {
    var vm1 = ViewModel_Deprecated("John", 35);
    var vm2 = ViewModel_Deprecated("Mary", 35);
    var vm3 = ViewModel_Deprecated("Mary", 35);
    expect(vm1 != vm2, isTrue);
    expect(vm2 == vm3, isTrue);
  });

  ///////////////////////////////////////////////////////////////////////////////

  test('Vm equality.', () {
    //

    // Comparison by equality. Same object.
    dynamic myObj = MyObjPlain();
    var vm1 = ViewModel("John", 35, myObj);
    var vm2 = ViewModel("John", 35, myObj);
    expect(vm1 == vm2, isTrue);

    // Comparison by equality. Different objects.
    vm1 = ViewModel("John", 35, MyObjPlain());
    vm2 = ViewModel("John", 35, MyObjPlain());
    expect(vm1 == vm2, isTrue);

    //

    // Now we're going to use a VmEquals object:
    // Same by equality, but Different by vmEquals().
    expect(MyObjVmEquals() == MyObjVmEquals(), isTrue);
    expect(MyObjVmEquals().vmEquals(MyObjVmEquals()), isFalse);

    // Comparison by identity. Same object.
    myObj = MyObjVmEquals();
    vm1 = ViewModel("John", 35, myObj);
    vm2 = ViewModel("John", 35, myObj);
    expect(vm1 == vm2, isTrue);

    // Comparison by identity. Different objects.
    vm1 = ViewModel("John", 35, MyObjVmEquals());
    vm2 = ViewModel("John", 35, MyObjVmEquals());
    expect(vm1 != vm2, isTrue);
  });

  ///////////////////////////////////////////////////////////////////////////////
}
