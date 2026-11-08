import 'active_facility_memory.dart';
import 'session_policy.dart';

/// Not web: the in-memory flag, so every cold start lacks the marker.
SessionMarker platformSessionMarker() => MemorySessionMarker();

/// Not web: in memory, gone with the process like the marker (RELOAD1).
SessionStore platformSessionStore() => MemorySessionStore();
