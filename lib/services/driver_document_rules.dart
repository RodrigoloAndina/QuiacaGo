class DriverDocumentDefinition {
  final String type;
  final String label;
  final bool requiresExpiry;

  const DriverDocumentDefinition({
    required this.type,
    required this.label,
    this.requiresExpiry = false,
  });
}

class DriverDocumentSummary {
  final List<String> missing;
  final List<String> pending;
  final List<String> rejected;
  final List<String> expired;
  final List<String> expiringSoon;

  const DriverDocumentSummary({
    required this.missing,
    required this.pending,
    required this.rejected,
    required this.expired,
    required this.expiringSoon,
  });

  bool get isComplete => missing.isEmpty;
  bool get canBeApproved => isComplete && expired.isEmpty;
  bool get isFullyApproved =>
      canBeApproved && pending.isEmpty && rejected.isEmpty;
}

class DriverDocumentRules {
  static const maxUploadBytes = 10 * 1024 * 1024;
  static const allowedExtensions = {'jpg', 'jpeg', 'png', 'pdf'};

  static const definitions = <DriverDocumentDefinition>[
    DriverDocumentDefinition(type: 'dni_front', label: 'DNI frente'),
    DriverDocumentDefinition(type: 'dni_back', label: 'DNI dorso'),
    DriverDocumentDefinition(
        type: 'license', label: 'Licencia de conducir', requiresExpiry: true),
    DriverDocumentDefinition(
        type: 'insurance',
        label: 'Póliza de seguro de taxi',
        requiresExpiry: true),
    DriverDocumentDefinition(
        type: 'vtv', label: 'VTV / RTO vigente', requiresExpiry: true),
  ];

  static Set<String> get requiredTypes =>
      definitions.map((definition) => definition.type).toSet();

  static DriverDocumentDefinition definitionFor(String type) =>
      definitions.firstWhere((definition) => definition.type == type,
          orElse: () => DriverDocumentDefinition(type: type, label: type));

  static String? validateUpload(String fileName, int byteLength) {
    final extension = extensionOf(fileName);
    if (!allowedExtensions.contains(extension)) {
      return 'El archivo debe ser JPG, PNG o PDF.';
    }
    if (byteLength <= 0) return 'El archivo está vacío.';
    if (byteLength > maxUploadBytes) {
      return 'El archivo supera el máximo permitido de 10 MB.';
    }
    return null;
  }

  static String extensionOf(String fileName) {
    final parts = fileName.toLowerCase().split('.');
    return parts.length > 1 ? parts.last : '';
  }

  static String contentTypeFor(String fileName) {
    return switch (extensionOf(fileName)) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      _ => 'image/jpeg',
    };
  }

  static int? daysUntilExpiry(DateTime? expiry, {DateTime? now}) {
    if (expiry == null) return null;
    final reference = now ?? DateTime.now();
    final today = DateTime(reference.year, reference.month, reference.day);
    final expiryDay = DateTime(expiry.year, expiry.month, expiry.day);
    return expiryDay.difference(today).inDays;
  }

  static DriverDocumentSummary summarize(
    Iterable<Map<String, dynamic>> documents, {
    DateTime? now,
    int warningDays = 30,
  }) {
    final byType = <String, Map<String, dynamic>>{};
    for (final document in documents) {
      final type = document['document_type']?.toString();
      if (type != null && requiredTypes.contains(type)) byType[type] = document;
    }

    final missing = <String>[];
    final pending = <String>[];
    final rejected = <String>[];
    final expired = <String>[];
    final expiringSoon = <String>[];

    for (final definition in definitions) {
      final document = byType[definition.type];
      if (document == null) {
        missing.add(definition.type);
        continue;
      }
      final status = document['status']?.toString() ?? 'pending';
      if (status == 'pending') pending.add(definition.type);
      if (status == 'rejected') rejected.add(definition.type);

      if (!definition.requiresExpiry) continue;
      final expiry =
          DateTime.tryParse(document['expires_at']?.toString() ?? '');
      final days = daysUntilExpiry(expiry, now: now);
      if (days == null || days < 0 || status == 'expired') {
        expired.add(definition.type);
      } else if (days <= warningDays) {
        expiringSoon.add(definition.type);
      }
    }

    return DriverDocumentSummary(
      missing: missing,
      pending: pending,
      rejected: rejected,
      expired: expired,
      expiringSoon: expiringSoon,
    );
  }
}
