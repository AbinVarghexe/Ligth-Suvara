class CustomField {
  final String id;
  final String name;
  final String type;
  final bool isMandatory;
  final List<String>? options;

  CustomField({
    required this.id,
    required this.name,
    required this.type,
    required this.isMandatory,
    this.options,
  });

  factory CustomField.fromMap(Map<String, dynamic> map) {
    List<String>? parsedOptions;
    if (map['options'] != null) {
      parsedOptions = (map['options'] as List)
          .map((item) => item.toString())
          .toList();
    }

    return CustomField(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      type: map['type']?.toString() ?? 'text',
      isMandatory: map['isMandatory'] == true,
      options: parsedOptions,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'isMandatory': isMandatory,
      if (options != null) 'options': options,
    };
  }
}

