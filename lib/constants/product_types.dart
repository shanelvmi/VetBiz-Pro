/// The list of physical/dosage forms a product can be - covers standard
/// veterinary pharmaceutical forms and common agrochemical formulation
/// types. Existing values are kept exactly as they were (so no already-
/// saved product's type value ever stops matching) - only new options
/// were added alongside them.
const List<String> kProductTypes = [
  'Injectable',
  'Oral Liquid',
  'Powder',
  'Tablet/Bolus',
  'Topical',
  'Intramammary',
  'Spray',
  'Granules',
  'Wettable Powder',
  'Emulsifiable Concentrate',
  'Seed',
  'Fertilizer',
  'Feed',
  'Equipment',
  'Other',
];
