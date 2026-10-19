/// Deleting a client was refused before anything was written (E3, owner
/// decision): the client still owes [owed], their balance or the total of
/// their debts documents, whichever is larger. The balance comes from the
/// debts, so a client in Trash must not take money owed with them.
class ClientDeleteRefusedException implements Exception {
  final double owed;

  const ClientDeleteRefusedException(this.owed);

  @override
  String toString() => 'ClientDeleteRefusedException($owed)';
}
