/// Data record that mirrors the inventory_items table in the SQLite
/// schema (v2). The table's columns as typed fields: a field's type and
/// nullability here match its column definition
/// (see wherelog-schema-description.md).

class InventoryItem {
  final int? id;
  final String name;

  /// References general_locations.id. Always known.
  final int generalId;

  /// References inventory_specifics.id. NULL means "General only"
  /// (schema Decision D1 — no blank-name sentinel).
  final int? specificId;

  /// Manufacturer/brand. NULL = not recorded (Decision D4).
  final String? brand;

  /// Model name/number. NULL = not recorded.
  final String? model;

  /// Serial number as printed on the item. NULL = not recorded —
  /// consistent with brand/model (v2 correction; the empty string is
  /// not a second way to say "no value").
  final String? serialNumber;

  /// Date-only text, YYYY-MM-DD, no time and no timezone, so it can
  /// never drift across timezones. NULL = not recorded.
  final String? acquisitionDate;

  final int quantity;

  /// What was paid, integer cents. NULL = not recorded.
  final int? purchasePriceCents;

  /// Current replacement value, integer cents — the figure an insurance
  /// claim pays on. NULL = no value recorded.
  final int? valueCents;

  final String notes;

  /// Filename only, in the app's WhereLog/photos folder. NULL = no photo.
  final String? photoFilename;

  /// System stamps, UTC ISO-8601 with the Z marker, written by
  /// SqliteInventoryRepository. Empty strings on a not-yet-saved record.
  final String createdAt;
  final String modifiedAt;

  const InventoryItem({
    this.id,
    required this.name,
    required this.generalId,
    this.specificId,
    this.brand,
    this.model,
    this.serialNumber,
    this.acquisitionDate,
    this.quantity = 1,
    this.purchasePriceCents,
    this.valueCents,
    this.notes = '',
    this.photoFilename,
    this.createdAt = '',
    this.modifiedAt = '',
  });

  factory InventoryItem.fromMap(Map<String, Object?> map) => InventoryItem(
        id: map['id'] as int?,
        name: map['name'] as String,
        generalId: map['general_id'] as int,
        specificId: map['specific_id'] as int?,
        brand: map['brand'] as String?,
        model: map['model'] as String?,
        serialNumber: map['serial_number'] as String?,
        acquisitionDate: map['acquisition_date'] as String?,
        quantity: map['quantity'] as int,
        purchasePriceCents: map['purchase_price_cents'] as int?,
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
        'brand': brand,
        'model': model,
        'serial_number': serialNumber,
        'acquisition_date': acquisitionDate,
        'quantity': quantity,
        'purchase_price_cents': purchasePriceCents,
        'value_cents': valueCents,
        'notes': notes,
        'photo_filename': photoFilename,
        'created_at': createdAt,
        'modified_at': modifiedAt,
      };
}
