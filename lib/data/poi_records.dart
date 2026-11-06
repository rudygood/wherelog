/// Data record that mirrors the poi_items table in the SQLite schema.
/// The table's columns as typed fields: a field's type and nullability
/// here match its column definition
/// (see wherelog-schema-description.md).

class PoiItem {
  final int? id;
  final String name;

  /// GPS coordinates. Required — a POI exists to be shown on the map.
  final double latitude;
  final double longitude;

  /// Street address when known; empty string when not.
  final String address;

  final String notes;

  /// Filename only, in the app's WhereLog/photos folder. NULL = no photo.
  final String? photoFilename;

  /// Where these coordinates came from: an import origin ('Google
  /// Maps link', 'GPX file', ...) or a direct-entry channel ('Map
  /// pick', 'Device GPS', 'Manual entry') — whichever set them last.
  /// NULL = not recorded (every record predating schema v3).
  final String? source;

  /// System stamps, UTC ISO-8601 with the Z marker, written by
  /// SqlitePoiRepository. Empty strings on a not-yet-saved record.
  final String createdAt;
  final String modifiedAt;

  const PoiItem({
    this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address = '',
    this.notes = '',
    this.photoFilename,
    this.source,
    this.createdAt = '',
    this.modifiedAt = '',
  });

  factory PoiItem.fromMap(Map<String, Object?> map) => PoiItem(
        id: map['id'] as int?,
        name: map['name'] as String,
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        address: map['address'] as String,
        notes: map['notes'] as String,
        photoFilename: map['photo_filename'] as String?,
        source: map['source'] as String?,
        createdAt: map['created_at'] as String,
        modifiedAt: map['modified_at'] as String,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'notes': notes,
        'photo_filename': photoFilename,
        'source': source,
        'created_at': createdAt,
        'modified_at': modifiedAt,
      };
}
