// The titles a person can put before their name (registration's chips and
// Edit Profile's dropdown). One list, so the two can never offer different
// titles. Stored as typed, at the start of the profile's fullName
// ("Dr. Asha Mwita"); nothing else reads the title back out of the name.
const List<String> kPersonTitles = ['Mr.', 'Mrs.', 'Ms.', 'Miss', 'Dr.', 'Prof.'];

/// The title chosen when there is none yet.
const String kDefaultPersonTitle = 'Mr.';

/// A stored fullName split into its title and the rest, for Edit Profile.
/// The title is null when the name starts with none of [kPersonTitles].
/// A title is followed by a space (registration writes "$title $name"), so
/// "Miss" never takes the start of a name like "Missana".
({String? title, String name}) splitPersonTitle(String fullName) {
  for (final t in kPersonTitles) {
    if (fullName.startsWith('$t ')) return (title: t, name: fullName.substring(t.length).trim());
  }
  return (title: null, name: fullName);
}
