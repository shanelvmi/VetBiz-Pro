/// An assistant asked for something only an admin may do (owner decision,
/// E4d-2): Edit Service, Edit Transaction or deleting a transaction.
/// Assistants record, take payments and see everything; the owner
/// corrects. Thrown by the provider before anything is written. The
/// screens hide these buttons from assistants, and firestore.rules refuses
/// the writes as well.
class AdminOnlyException implements Exception {
  const AdminOnlyException();

  @override
  String toString() => 'AdminOnlyException';
}
