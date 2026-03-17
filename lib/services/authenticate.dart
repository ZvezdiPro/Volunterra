import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:volunteer_app/models/registration_data.dart';
import 'package:volunteer_app/models/volunteer.dart';
import 'package:volunteer_app/services/database.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FacebookAuth _facebookAuth = FacebookAuth.instance;
  int loginType = 0;

  // Auth change user stream
  // Maps the Firebase User to a VolunteerUser using asyncMap
  // and the helper method which uses the id to fetch the full data
  Stream<VolunteerUser?> get user {
    return _auth.authStateChanges().asyncMap(_fullUserFromFirebaseUser);
  }

  // Create user object based on Firebase User
  // The method is asynchronous because it fetches additional data from Firestore (which takes time)
  Future<VolunteerUser?> _fullUserFromFirebaseUser(User? user) async {
    if (user == null) {
      return null; 
    }
    // Get the VolunteerUser from the database using the uid or return the default auth-only object
    return await DatabaseService(uid: user.uid).getVolunteerUser() ?? VolunteerUser.forAuth(uid: user.uid);
  }
  
  // Return VolunteerUser object from Firebase User and Registration Data
  Future<VolunteerUser?> _volunteerFromFirebaseUser(User? user, RegistrationData data) async {
    return user != null ? VolunteerUser(
      uid: user.uid,
      email: data.email,
      firstName: data.firstName,
      lastName: data.lastName,
      interests: data.interests, 
      experiencePoints: 0,
      userLevel: 1,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      bio: data.bio,
      avatarUrl: data.avatarUrl,
      phoneNumber: data.phoneNumber,
      dateOfBirth: data.dateOfBirth,
    ) : null;
  }

  // Register with email and password
  Future<VolunteerUser?> registerWithEmailAndPassword(String email, String password, RegistrationData data) async {
    try {
      // Attempt to create the user
      UserCredential result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      // Get the newly created firebase (authenticated) user (could be null)
      User? user = result.user;
      // Create a new document for the user with the uid using the registration data
      await DatabaseService(uid: user!.uid).updateUserData(data);
      // Return the VolunteerUser object using both Firebase User (for the uid) and registration data
      return await _volunteerFromFirebaseUser(user, data);
    }
    catch (e) {
      // print(e.toString());
      return null;
    }
  }

  // Sign in with email and password
  Future<VolunteerUser?> signInWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      User? user = result.user;
      // Fetch and return the VolunteerUser object from the database
      if (user != null) {
        await DatabaseService(uid: user.uid).updateLastSeen();
        return await DatabaseService(uid: user.uid).getVolunteerUser();
      }
      return null;
    } catch (e) {
      // print(e.toString());
      return null;
    }
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      // print(e.toString());
      rethrow;
    }
  }

  // Sign in with Google
  Future<VolunteerUser?> googleLogin() async {
    // Trigger the authentication flow
    final user = await _googleSignIn.signIn();
 
    // If the user cancels the sign-in, user will be null
    if (user == null) {
      return null; 
    }

    // Obtain the auth details from the request
    GoogleSignInAuthentication userAuth = await user.authentication;

    // Create a new credential
    var credential = GoogleAuthProvider.credential(
      idToken: userAuth.idToken, 
      accessToken: userAuth.accessToken
    );

    // Sign in to Firebase with the Google credential
    await FirebaseAuth.instance.signInWithCredential(credential);

    if (_auth.currentUser != null) {
      RegistrationData data = RegistrationData();
      data.email = _auth.currentUser!.email ?? '';
      data.firstName = _auth.currentUser!.displayName?.split(' ').first ?? '';
      data.lastName = _auth.currentUser!.displayName?.split(' ').last ?? '';
      data.avatarUrl = _auth.currentUser!.photoURL ?? '';

      // Update the user data in the database (as the user could be new or they could've changed their info)
      await DatabaseService(uid: _auth.currentUser!.uid).updateUserData(data, isOAuthLogin: true);
      // Return the VolunteerUser object from the firebase document
      return await DatabaseService(uid: _auth.currentUser!.uid).getVolunteerUser();
    }
    return null;
  }

  // Sign in with facebook
  Future<VolunteerUser?> facebookLogin() async {
    // Trigger the sign-in flow
    final LoginResult result = await _facebookAuth.login();

    // Check the result status
    if (result.status == LoginStatus.success) {
      // Get the access token
      final AccessToken accessToken = result.accessToken!;
      // Create a credential from the access token
      final OAuthCredential credential = FacebookAuthProvider.credential(accessToken.tokenString);
      // Sign in to Firebase with the Facebook credential
      await _auth.signInWithCredential(credential);

      if (_auth.currentUser != null) {
        RegistrationData data = RegistrationData();
        data.email = _auth.currentUser!.email ?? '';
        data.firstName = _auth.currentUser!.displayName?.split(' ').first ?? '';
        data.lastName = _auth.currentUser!.displayName?.split(' ').last ?? '';
        data.avatarUrl = _auth.currentUser!.photoURL ?? '';

        // Update the user data in the database
        await DatabaseService(uid: _auth.currentUser!.uid).updateUserData(data, isOAuthLogin: true);
        // Return the VolunteerUser object
        return await DatabaseService(uid: _auth.currentUser!.uid).getVolunteerUser();
      }
    }
    return null;
  }

  // Sign in anonymously
  Future<VolunteerUser?> signInAnon() async {
    try {
      // Sign in anonymously with Firebase
      UserCredential result = await _auth.signInAnonymously();
      // Get the Firebase user
      User? user = result.user;
      // Fetch and return the VolunteerUser object
      return VolunteerUser.forAuth(uid: user!.uid);
    } catch (e) {
      // print(e.toString());
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    // Determine the provider used for sign-in
    final User? user = _auth.currentUser;
    // If no user is signed in, simply return
    if (user == null) return;
    // Handle anonymous sign-out
    if (user.isAnonymous) {
      try {
        // Delete the anonymous user account
        await user.delete();
      } catch (e) {
        // print('Error deleting anonymous user: $e');
        await _signOutFirebaseOnly();
      }
      return;
    }
    // Get the provider ID of the first linked provider
    String providerId = user.providerData[0].providerId;
    // Handle sign-out based on the provider
    switch (providerId) {
      case 'google.com':
        await _signOutGoogle();
        break;
      case 'facebook.com':
        await _signOutFacebook();
        break;
      case 'password': // Email/Password login
        await _signOutFirebaseOnly();
        break;
      default:
        // Handle other providers or default to Firebase sign-out
        await _signOutFirebaseOnly();
        break;
    }
  }

  // --- Specific Sign-Out Functions ---

  // 1. Sign out for Google-authenticated users
  Future<void> _signOutGoogle() async {
    try {
      // 1. Clear the Google session
      await _googleSignIn.signOut();
      // 2. Clear the Firebase session
      await _auth.signOut();
    } catch (e) {
      // print('Error signing out Google: $e');
    }
  }

  Future<void> _signOutFacebook() async {
    try {
      // 1. Clear the Facebook session
      await _facebookAuth.logOut();
      // 2. Clear the Firebase session
      await _auth.signOut();
    } catch (e) {
      // print('Error signing out Facebook: $e');
    }
  }

  // 2. Sign out for Email/Password or other simple providers
  Future<void> _signOutFirebaseOnly() async {
    try {
      // Clear only the Firebase session
      await _auth.signOut();
    } catch (e) {
      // print('Error signing out Firebase: $e');
    }
  }
  
}