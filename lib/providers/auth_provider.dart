import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';

class AuthProvider extends ChangeNotifier {
  final SupabaseClient? _explicitClient;
  bool? _isAuthenticatedForTesting;
  StreamSubscription<AuthState>? _authSubscription;
  Future<void>? _profileLoadFuture;
  String? _profileLoadUserId;

  User? _user;
  Session? _session;
  UserProfile? _profile;
  String? _role;
  bool _isInitializing = true;
  bool _isLoading = false;
  bool _isProfileLoading = false;
  bool _isProfileMissing = false;
  String? _profileLoadError;
  String? _errorMessage;

  AuthProvider({
    SupabaseClient? client,
    bool? isAuthenticatedForTesting,
    UserProfile? initialProfileForTesting,
    bool profileMissingForTesting = false,
    String? profileLoadErrorForTesting,
  }) : _explicitClient = client,
       _isAuthenticatedForTesting = isAuthenticatedForTesting {
    if (isAuthenticatedForTesting != null) {
      _isInitializing = false;
      _isLoading = false;
      if (isAuthenticatedForTesting) {
        _profile =
            initialProfileForTesting ??
            (profileMissingForTesting || profileLoadErrorForTesting != null
                ? null
                : UserProfile(
                    id: 'test-user-id',
                    fullName: 'Demo User',
                    role: 'customer',
                  ));
        _role = _profile?.role ?? '';
        _isProfileMissing = profileMissingForTesting;
        _profileLoadError = profileLoadErrorForTesting;
      }
    } else {
      _initialize();
    }
  }

  SupabaseClient? get _client {
    if (_explicitClient != null) return _explicitClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  bool get isInitializing => _isInitializing;
  bool get isLoading => _isLoading;
  bool get isProfileLoading => _isProfileLoading;
  bool get isProfileMissing => _isProfileMissing;
  String? get profileLoadError => _profileLoadError;
  bool get isAuthenticated =>
      _user != null ||
      (_isAuthenticatedForTesting ??
          (_explicitClient == null && _profile != null));
  User? get user => _user;
  Session? get session => _session;
  UserProfile? get profile => _profile;
  String get role => _role ?? _profile?.role ?? '';
  String? get errorMessage => _errorMessage;

  /// Initializes the provider, restores existing session, and subscribes to auth state changes.
  Future<void> _initialize() async {
    final client = _client;
    if (client == null) {
      _isInitializing = false;
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      // 1. Restore existing session if persisted
      final restoredSession = client.auth.currentSession;
      final restoredUser = client.auth.currentUser;
      _session = restoredSession;
      _user = restoredUser;

      if (_user != null) {
        _isProfileLoading = true;
        await _fetchProfileForUser(_user!.id);
      }
    } catch (e) {
      debugPrint('AuthProvider session restoration note: $e');
    }

    // 2. Subscribe to auth state changes
    try {
      _authSubscription = client.auth.onAuthStateChange.listen((data) async {
        final event = data.event;
        final session = data.session;
        _session = session;
        _user = session?.user ?? client.auth.currentUser;

        if (event == AuthChangeEvent.signedIn ||
            event == AuthChangeEvent.userUpdated) {
          if (_user != null) {
            if (_profileLoadUserId == _user!.id && _profileLoadFuture != null) {
              _isInitializing = false;
              _isLoading = false;
              notifyListeners();
              return;
            }
            _profile = null;
            _role = null;
            _isProfileMissing = false;
            _profileLoadError = null;
            _isProfileLoading = true;
            notifyListeners();
            await _fetchProfileForUser(_user!.id);
          }
        } else if (event == AuthChangeEvent.signedOut) {
          _session = null;
          _user = null;
          _profile = null;
          _role = null;
          _isProfileLoading = false;
          _isProfileMissing = false;
          _profileLoadError = null;
          _errorMessage = null;
        }

        _isInitializing = false;
        _isLoading = false;
        notifyListeners();
      });
    } catch (e) {
      debugPrint('AuthProvider onAuthStateChange subscription note: $e');
    }

    _isInitializing = false;
    _isLoading = false;
    notifyListeners();
  }

  /// Fetches profile details directly from the Supabase `profiles` table using auth.uid()
  Future<void> _fetchProfileForUser(String userId) {
    if (_profileLoadUserId == userId && _profileLoadFuture != null) {
      return _profileLoadFuture!;
    }

    _profileLoadUserId = userId;
    final request = _loadProfileForUser(userId);
    _profileLoadFuture = request;
    return request;
  }

  Future<void> _loadProfileForUser(String userId) async {
    final client = _client;
    if (client == null) {
      _isProfileMissing = false;
      _profileLoadError = 'Supabase is not available to load your profile.';
      _isProfileLoading = false;
      _profileLoadUserId = null;
      _profileLoadFuture = null;
      notifyListeners();
      return;
    }

    try {
      final response = await client
          .from('profiles')
          .select('id, full_name, role')
          .eq('id', userId)
          .maybeSingle()
          .timeout(const Duration(seconds: 12));

      if (_user?.id != userId) return;

      if (response != null) {
        _profile = UserProfile.fromJson(response);
        _role = _profile?.role;
        _isProfileMissing = false;
        _profileLoadError = null;
      } else {
        _profile = null;
        _role = null;
        _isProfileMissing = true;
        _profileLoadError = null;
      }
    } catch (e) {
      debugPrint('AuthProvider._fetchProfileForUser error: $e');
      if (_user?.id == userId) {
        _profile = null;
        _role = null;
        _isProfileMissing = false;
        _profileLoadError = _formatProfileLoadError(e);
      }
    } finally {
      if (_user?.id == userId) {
        _isProfileLoading = false;
        notifyListeners();
      }
      if (_profileLoadUserId == userId) {
        _profileLoadUserId = null;
        _profileLoadFuture = null;
      }
    }
  }

  Future<void> retryProfileLoad() async {
    final userId = _user?.id ?? _client?.auth.currentUser?.id;
    if (userId == null) return;

    _isProfileLoading = true;
    _isProfileMissing = false;
    _profileLoadError = null;
    notifyListeners();
    await _fetchProfileForUser(userId);
  }

  /// Authenticates with email and password via Supabase Auth
  Future<bool> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client == null) {
      _errorMessage = 'Supabase client is not available.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      _session = response.session;
      _user = response.user;

      if (_user != null) {
        if (_profileLoadUserId != _user!.id || _profileLoadFuture == null) {
          _profile = null;
          _role = null;
          _isProfileMissing = false;
          _profileLoadError = null;
          _isProfileLoading = true;
        }
        unawaited(_fetchProfileForUser(_user!.id));
      }

      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _isLoading = false;
      _errorMessage = _formatAuthError(e.message);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = _formatException(e);
      notifyListeners();
      return false;
    }
  }

  /// Creates a new demo account with Supabase Auth
  Future<bool> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    final client = _client;
    if (client == null) {
      _errorMessage = 'Supabase client is not available.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await client.auth.signUp(
        email: email.trim(),
        password: password,
        data: fullName != null && fullName.trim().isNotEmpty
            ? {'full_name': fullName.trim()}
            : null,
      );

      _session = response.session;
      _user = response.user;

      if (_user != null && _session != null) {
        // Session created immediately (email confirmation is disabled)
        try {
          await client.from('profiles').upsert({
            'id': _user!.id,
            'full_name': fullName?.trim(),
            'role': 'customer',
          });
        } catch (profileErr) {
          debugPrint('Profile upsert note: $profileErr');
        }

        await _fetchProfileForUser(_user!.id);
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
        return true;
      } else if (_user != null && _session == null) {
        // Account registered, but Supabase requires email confirmation before signing in
        _isLoading = false;
        _errorMessage = 'Account created! Please check your email inbox to confirm your account before logging in, or disable "Confirm email" in Supabase Auth settings to log in immediately.';
        notifyListeners();
        return false;
      }

      _isLoading = false;
      _errorMessage = 'Sign up could not be completed. Please try again.';
      notifyListeners();
      return false;
    } on AuthException catch (e) {
      _isLoading = false;
      _errorMessage = _formatAuthError(e.message);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = _formatException(e);
      notifyListeners();
      return false;
    }
  }

  /// Sends a Supabase password recovery email using the configured project URL.
  Future<bool> sendPasswordResetEmail({required String email}) async {
    final client = _client;
    if (client == null) {
      _errorMessage = 'Supabase client is not available.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await client.auth.resetPasswordForEmail(email.trim());
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (error) {
      _isLoading = false;
      _errorMessage = _formatAuthError(error.message);
      notifyListeners();
      return false;
    } catch (error) {
      _isLoading = false;
      _errorMessage = _formatException(error);
      notifyListeners();
      return false;
    }
  }

  /// Signs out of Supabase Auth and resets provider state
  Future<void> signOut() async {
    final client = _client;
    _isLoading = true;
    notifyListeners();

    try {
      if (client != null) {
        await client.auth.signOut().timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            debugPrint(
              'AuthProvider.signOut remote call timed out; completing local cleanup.',
            );
          },
        );
      }
    } catch (e) {
      debugPrint('AuthProvider.signOut notice: $e');
    } finally {
      _session = null;
      _user = null;
      _profile = null;
      _role = null;
      _isAuthenticatedForTesting = false;
      _isProfileLoading = false;
      _isProfileMissing = false;
      _profileLoadError = null;
      _profileLoadUserId = null;
      _profileLoadFuture = null;
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clears any transient error message
  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Formats raw Supabase Auth errors into readable, user-friendly messages
  String _formatAuthError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid login credentials')) {
      return 'Invalid email or password. Please verify your credentials and try again.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Email not confirmed. Please check your inbox or disable "Confirm email" in Supabase Auth settings.';
    }
    if (lower.contains('user already registered')) {
      return 'An account with this email already exists. Please sign in instead.';
    }
    if (lower.contains('password should be at least')) {
      return 'Password must be at least 6 characters.';
    }
    if (lower.contains('signup disabled')) {
      return 'Sign up is currently disabled in your Supabase Auth configuration.';
    }
    return message;
  }

  /// Formats network and transport errors
  String _formatException(dynamic error) {
    final str = error.toString().toLowerCase();
    if (str.contains('connection refused') ||
        str.contains('semaphore timeout') ||
        str.contains('socketexception') ||
        str.contains('connection timed out') ||
        str.contains('failed host lookup') ||
        str.contains('clientexception') ||
        str.contains('network is unreachable')) {
      return 'Network issue: Unable to reach Supabase (Connection refused).\n\nThis is typically caused by ISP DNS interception (such as ACT Fibernet in India). Setting Private DNS to "dns.google" or "1.1.1.1" in your Android/device settings resolves this immediately.';
    }

    return 'Authentication error: $error';
  }

  String _formatProfileLoadError(Object error) {
    final message = error.toString().toLowerCase();
    if (error is TimeoutException ||
        message.contains('socketexception') ||
        message.contains('software caused connection abort') ||
        message.contains('connection abort') ||
        message.contains('connection reset') ||
        message.contains('failed host lookup') ||
        message.contains('network is unreachable') ||
        message.contains('connection timed out')) {
      return 'Sign-in succeeded, but People Cart could not reach the account profile service. Check your internet connection, VPN, and device Private DNS, then retry. Your account role has not been verified yet.';
    }
    return 'Unable to load your account profile. Please retry. Details: $error';
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
