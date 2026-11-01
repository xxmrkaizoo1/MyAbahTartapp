import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/shop_models.dart';
import 'shop_repository.dart';

/// The signed-in Firebase user and their shop profile (name, phone, address, role).
class AuthService extends ChangeNotifier {
  AuthService(this._repository) {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(_onUserChanged);
  }

  /// A fixed signed-in (or signed-out) state without Firebase, for previews and tests.
  @visibleForTesting
  AuthService.preview(this._repository, {this.profile}) : _previewUid = profile?.uid;

  final ShopRepository _repository;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<AppUser?>? _profileSubscription;
  String? _previewUid;

  /// The account whose website history has already been looked up this session.
  String? _claimedFor;

  User? user;
  AppUser? profile;

  String? get uid => user?.uid ?? _previewUid;

  bool get isSignedIn => uid != null;

  bool get emailVerified => user?.emailVerified ?? true;

  bool get isAdmin => profile?.isAdmin ?? false;

  void _onUserChanged(User? next) {
    user = next;
    profile = null;
    _profileSubscription?.cancel();

    if (next != null) {
      _profileSubscription = _repository.userProfile(next.uid).listen((loaded) {
        if (loaded == null) {
          // Accounts made outside the app get a profile the first time they sign in.
          _repository.saveProfile(next.uid, name: next.displayName ?? next.email?.split('@').first ?? 'Customer', email: next.email ?? '');
          return;
        }
        profile = loaded;
        notifyListeners();
        _claimWebsiteHistory();
      });
    }
    notifyListeners();
  }

  Future<void> signIn(String email, String password) => FirebaseAuth.instance.signInWithEmailAndPassword(email: email.trim(), password: password);

  Future<void> register({required String name, required String email, required String password, String? phone}) async {
    final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email.trim(), password: password);
    final created = credential.user!;
    await created.updateDisplayName(name.trim());
    await _repository.saveProfile(created.uid, name: name.trim(), email: email.trim(), phone: phone?.trim().isEmpty ?? true ? null : phone!.trim());
    await created.sendEmailVerification();
  }

  Future<void> sendPasswordReset(String email) => FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());

  Future<void> resendVerification() async => user?.sendEmailVerification();

  Future<void> reloadUser() async {
    await user?.reload();
    user = FirebaseAuth.instance.currentUser;
    notifyListeners();
    _claimWebsiteHistory();
  }

  /// Customers who shopped on the website before see those orders here once their email is verified.
  void _claimWebsiteHistory() {
    final current = user;
    if (current == null || !current.emailVerified || current.email == null || _claimedFor == current.uid) return;
    _claimedFor = current.uid;
    _repository.claimWebsiteHistory(current.uid, current.email!).catchError((Object error) {
      debugPrint('Could not attach website orders: $error');
      _claimedFor = null;
      return 0;
    });
  }

  Future<void> signOut() => FirebaseAuth.instance.signOut();

  @override
  void dispose() {
    _authSubscription?.cancel();
    _profileSubscription?.cancel();
    super.dispose();
  }
}

String authErrorMessage(Object error) {
  if (error is! FirebaseAuthException) return 'Something went wrong. Please try again.';
  return switch (error.code) {
    'invalid-email' => 'That email address doesn’t look right.',
    'user-disabled' => 'This account has been disabled.',
    'user-not-found' || 'wrong-password' || 'invalid-credential' => 'Wrong email or password.',
    'email-already-in-use' => 'An account with this email already exists. Try signing in.',
    'weak-password' => 'Use a password with at least 8 characters.',
    'too-many-requests' => 'Too many attempts. Please wait a moment and try again.',
    'network-request-failed' => 'No internet connection.',
    'operation-not-allowed' => 'Email sign-in isn’t switched on in Firebase yet.',
    _ => error.message ?? 'Something went wrong. Please try again.',
  };
}
