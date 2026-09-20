/// The canonical list of service categories, shared between the Add/Edit
/// Service form (where they're chosen from a dropdown) and the Services
/// list screen (where they appear as filter chips). Defined once here so
/// the two can never silently drift apart - previously the list screen
/// only showed chips for categories some existing service already used,
/// so a category with zero services yet simply never appeared as an
/// option to filter by.
const List<String> kServiceCategories = [
  'Surgical',
  'Treatment',
  'Management',
  'Consultation',
  'Diagnostics',
  'Preventive',
  'Other',
];
