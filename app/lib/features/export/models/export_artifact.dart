/// Runtime output location; never persisted in a project document.
class ExportArtifact {
  final String location;
  final String filename;
  final String mimeType;
  final int bytes;
  final bool browser;
  const ExportArtifact({
    required this.location,
    required this.filename,
    required this.mimeType,
    required this.bytes,
    this.browser = false,
  });
}
