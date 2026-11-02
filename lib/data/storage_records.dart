/// Data record that mirrors the storage_items table in the SQLite schema.
/// The table's columns as typed fields: a field's type and nullability
/// here match its column definition (see wherelog-schema-description.md).

class StorageItem {
  final int? id;
  final String name;

  /// References general_locations.id. Always known: every item sits in a
  /// General location.
  final int generalId;

  /// References storage_specifics.id. NULL means "General only" — there
  /// is no blank-name sentinel row (schema Decision D1).
  final int? specificId;

  final int quantity;

  /// Money is integer cents, never a floating-point amount (Decision D2).
  /// NULL means no value recorded.
  final int? valueCents;

  final String notes;

  /// Filename only, in the app's WhereLog/photos folder — never a full
  /// path. NULL means no photo. PhotoStore resolves and deletes files.
  final String? photoFilename;

  /// System stamps, UTC ISO-8601 with the Z marker, written by
  /// SqliteStorageRepository — screens never set them. Empty strings on a
  /// not-yet-saved record.
  final String createdAt;
  final String modifiedAt;

  const StorageItem({
    this.id,
    required this.name,
    required this.generalId,
    this.specificId,
    this.quantity = 1,
    this.valueCents,
    this.notes = '',
    this.photoFilename,
    this.createdAt = '',
    this.modifiedAt = '',
  });

  factory StorageItem.fromMap(Map<String, Object?> map) => StorageItem(
        id: map['id'] as int?,
        name: map['name'] as String,
        generalId: map['general_id'] as int,
        specificId: map['specific_id'] as int?,
        quantity: map['quantity'] as int,
        valueCents: map['value_cents'] as int?,
        notes: map['notes'] as String,
        photoFilename: map['photo_filename'] as String?,
        createdAt: map['created_at'] as String,
        modifiedAt: map['modified_at'] as String,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'general_id': generalId,
        'specific_id': specificId,
        'quantity': quantity,
        'value_cents': valueCents,
        'notes': notes,
        'photo_filename': photoFilename,
        'created_at': createdAt,
        'modified_at': modifiedAt,
      };
}
