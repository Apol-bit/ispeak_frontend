const nameExtensions = ['', 'Jr.', 'Sr.', 'III', 'IV', 'V'];

/// The existing API stores firstName/lastName, with no separate suffix field.
String lastNameWithExtension(String lastName, String extension) {
  final name = lastName.trim();
  return extension.isEmpty ? name : '$name $extension';
}
