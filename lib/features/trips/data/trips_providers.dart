import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase_providers.dart';
import '../../auth/data/auth_provider.dart';
import '../domain/member.dart';
import '../domain/trip.dart';
import 'trip_repository.dart';

final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return TripRepository(firestore: ref.watch(firestoreProvider));
});

/// Streams all trips the user is a member of: active first, then archived.
final myTripsProvider = StreamProvider<List<Trip>>((ref) {
  final authUserAsync = ref.watch(authUserProvider);
  final user = authUserAsync.asData?.value;

  if (user == null) {
    return Stream.value([]);
  }

  final repo = ref.watch(tripRepositoryProvider);
  return repo.watchMyTrips(user.uid);
});

/// Streams a single trip by ID.
final tripProvider = StreamProvider.family<Trip?, String>((ref, tripId) {
  final repo = ref.watch(tripRepositoryProvider);
  return repo.watchTrip(tripId);
});

/// Streams active members of a trip by ID.
final tripMembersProvider = StreamProvider.family<List<Member>, String>((
  ref,
  tripId,
) {
  final repo = ref.watch(tripRepositoryProvider);
  return repo.watchMembers(tripId);
});

/// Streams all members (active and left) of a trip by ID.
final tripAllMembersProvider = StreamProvider.family<List<Member>, String>((
  ref,
  tripId,
) {
  final repo = ref.watch(tripRepositoryProvider);
  return repo.watchAllMembers(tripId);
});
