/// Data records that mirror the location tables in the SQLite schema.
/// One class per table, with the table's columns as typed fields:
/// a field's type and nullability here match its column definition.

class GeneralLocation {
  final int? id;
  final String name;

  const GeneralLocation({this.id, required this.name});

  factory GeneralLocation.fromMap(Map<String, Object?> map) => GeneralLocation(
        id: map['id'] as int?,
        name: map['name'] as String,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
      };
}

class StorageSpecific {
  final int? id;
  final int generalId;
  final String name;

  const StorageSpecific({this.id, required this.generalId, required this.name});

  factory StorageSpecific.fromMap(Map<String, Object?> map) => StorageSpecific(
        id: map['id'] as int?,
        generalId: map['general_id'] as int,
        name: map['name'] as String,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'general_id': generalId,
        'name': name,
      };
}

class InventorySpecific {
  final int? id;
  final int generalId;
  final String name;

  const InventorySpecific({this.id, required this.generalId, required this.name});

  factory InventorySpecific.fromMap(Map<String, Object?> map) => InventorySpecific(
        id: map['id'] as int?,
        generalId: map['general_id'] as int,
        name: map['name'] as String,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'general_id': generalId,
        'name': name,
      };
}
