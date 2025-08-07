import 'dart:convert';
import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _userPoolId = 'ap-southeast-2_X3QW09Ym7';
  static const String _clientId = '5spq960f0mujgka10sc1t7k8u2';
  static const String _region = 'ap-southeast-2';
  
  late CognitoUserPool _userPool;
  CognitoUser? _currentUser;
  
  AuthService() {
    _userPool = CognitoUserPool(_userPoolId, _clientId);
  }
  
  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('cognito_user');
      if (userJson != null) {
        final userData = json.decode(userJson);
        _currentUser = CognitoUser(userData['username'], _userPool);
        
        // Check if session is still valid
        final session = await _currentUser!.getSession();
        return session != null && session.isValid();
      }
      return false;
    } catch (e) {
      return false;
    }
  }
  
  // Get current user info
  Future<Map<String, dynamic>?> getCurrentUser() async {
    if (_currentUser == null) return null;
    
    try {
      final attributes = await _currentUser!.getUserAttributes();
      final userInfo = <String, dynamic>{};
      
      for (var attr in attributes!) {
        userInfo[attr.name!] = attr.value;
      }
      
      return userInfo;
    } catch (e) {
      return null;
    }
  }
  
  // Sign up with email and password
  Future<Map<String, dynamic>> signUp(String email, String password, String name) async {
    try {
      final userAttributes = [
        AttributeArg(name: 'email', value: email),
        AttributeArg(name: 'name', value: name),
      ];
      
      final result = await _userPool.signUp(email, password, userAttributes: userAttributes);
      
      return {
        'success': true,
        'message': 'Sign up successful. Please check your email for verification code.',
        'userSub': result.userSub,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }
  
  // Confirm sign up with verification code
  Future<Map<String, dynamic>> confirmSignUp(String email, String confirmationCode) async {
    try {
      final cognitoUser = CognitoUser(email, _userPool);
      final result = await cognitoUser.confirmRegistration(confirmationCode);
      
      return {
        'success': result,
        'message': result ? 'Email verified successfully!' : 'Verification failed',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }
  
  // Sign in with email and password
  Future<Map<String, dynamic>> signIn(String email, String password) async {
    try {
      final cognitoUser = CognitoUser(email, _userPool);
      final authDetails = AuthenticationDetails(username: email, password: password);
      
      final session = await cognitoUser.authenticateUser(authDetails);
      
      if (session != null && session.isValid()) {
        _currentUser = cognitoUser;
        
        // Save user session
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cognito_user', json.encode({
          'username': email,
          'accessToken': session.getAccessToken().getJwtToken(),
        }));
        
        return {
          'success': true,
          'message': 'Sign in successful!',
          'user': await getCurrentUser(),
        };
      } else {
        return {
          'success': false,
          'message': 'Invalid session',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }
  
  // Sign out
  Future<void> signOut() async {
    try {
      if (_currentUser != null) {
        await _currentUser!.signOut();
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cognito_user');
      
      _currentUser = null;
    } catch (e) {
      // Handle error silently
    }
  }

}