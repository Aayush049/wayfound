import 'package:cloud_firestore/cloud_firestore.dart';

/// Representation of a user document stored in `users/{uid}`.
class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final DateTime? createdAt;

  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.createdAt,
  });

  /// Factory constructor to create an [AppUser] from Firestore document data.
  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final createdAtRaw = data['createdAt'];
    DateTime? createdAt;

    if (createdAtRaw is Timestamp) {
      createdAt = createdAtRaw.toDate();
    } else if (createdAtRaw is String) {
      createdAt = DateTime.tryParse(createdAtRaw);
    }

    return AppUser(
      uid: doc.id,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      createdAt: createdAt,
    );
  }

  /// Converts this [AppUser] to a Firestore map for creation.
  /// Note: The `users/{uid}` security rules strictly require only
  /// `displayName`, `photoUrl`, `email`, and `createdAt`.
  Map<String, dynamic> toFirestoreCreate() {
    return {
      'displayName': displayName,
      'photoUrl': photoUrl,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// Converts this [AppUser] to a map for updating profile info.
  Map<String, dynamic> toFirestoreUpdate() {
    return {'displayName': displayName, 'photoUrl': photoUrl};
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          email == other.email &&
          displayName == other.displayName &&
          photoUrl == other.photoUrl;

  @override
  int get hashCode =>
      uid.hashCode ^ email.hashCode ^ displayName.hashCode ^ photoUrl.hashCode;
}
