import 'package:flutter/material.dart';

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

/// PH5a: the icon a service's row leads with on a phone (R6). Unknown
/// categories (old records) get the general one.
IconData serviceCategoryIcon(String category) => switch (category) {
      'Surgical' => Icons.healing_outlined,
      'Treatment' => Icons.medication_outlined,
      'Management' => Icons.assignment_outlined,
      'Consultation' => Icons.forum_outlined,
      'Diagnostics' => Icons.biotech_outlined,
      'Preventive' => Icons.vaccines_outlined,
      _ => Icons.medical_services_outlined,
    };
