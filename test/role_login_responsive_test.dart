import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e_archive/features/auth/domain/repositories/auth_repository.dart';
import 'package:e_archive/features/auth/domain/usecases/login_usecase.dart';
import 'package:e_archive/features/auth/presentation/pages/login_page.dart';
import 'package:e_archive/features/auth/presentation/pages/role_login_page.dart';
import 'package:e_archive/models/user_role.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<UserRole?> login({
    required String username,
    required String password,
  }) async {
    return UserRole.admin;
  }
}

void main() {
  testWidgets('role-choice landing page fits a small phone screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(
          loginUseCase: LoginUseCase(_FakeAuthRepository()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Student records,\norganized.'), findsOneWidget);
    expect(find.text('Administrator'), findsOneWidget);
    expect(find.text('Staff'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('credential login and recovery notice fit a small phone screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: RoleLoginPage(
          loginUseCase: LoginUseCase(_FakeAuthRepository()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Administrator Login'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    expect(find.text('Password recovery'), findsOneWidget);
    expect(
      find.textContaining('password resets require administrator verification'),
      findsOneWidget,
    );
    expect(find.text('Reset password'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('role login fits a short desktop window without flex overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 520);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: RoleLoginPage(
          loginUseCase: LoginUseCase(_FakeAuthRepository()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Administrator Login'), findsOneWidget);
    expect(find.text('Email or username'), findsOneWidget);
    expect(find.text('Sign in as Admin'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));

    final card = find.ancestor(
      of: find.text('Administrator Login'),
      matching: find.byType(Container),
    );
    final cardCenter = tester.getCenter(card.first).dx;
    expect(cardCenter, moreOrLessEquals(400, epsilon: 1));
    expect(tester.takeException(), isNull);
  });
}
