import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'package:card_box/models/wallet_card.dart';

part 'card_database.g.dart';

class CardRecords extends Table {
  TextColumn get id => text()();

  TextColumn get payloadJson => text()();

  IntColumn get createdAtMillis => integer()();

  IntColumn get updatedAtMillis => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [CardRecords])
class CardDatabase extends _$CardDatabase {
  CardDatabase(super.executor);

  factory CardDatabase.defaults() {
    return CardDatabase(driftDatabase(name: 'card_box'));
  }

  factory CardDatabase.inMemory() {
    return CardDatabase(NativeDatabase.memory());
  }

  @override
  int get schemaVersion => 3;

  /// Raw DDL for the v1→v2 schema bump. The nine normalized columns
  /// were never read by any code path and are dropped again in v3,
  /// but v1 installs still need to traverse v2 on the way to v3 to
  /// preserve any in-flight row data.
  static const List<String> _v1ToV2AlterStatements = <String>[
    "ALTER TABLE card_records ADD COLUMN name_text TEXT NOT NULL "
    "DEFAULT ''",
    "ALTER TABLE card_records ADD COLUMN issuer_text TEXT NOT NULL "
    "DEFAULT ''",
    "ALTER TABLE card_records ADD COLUMN category_name TEXT NOT NULL "
    "DEFAULT 'other'",
    'ALTER TABLE card_records ADD COLUMN custom_category_text TEXT',
    "ALTER TABLE card_records ADD COLUMN card_type_name TEXT NOT NULL "
    "DEFAULT 'standard'",
    "ALTER TABLE card_records ADD COLUMN compatibility_status_name "
    "TEXT NOT NULL DEFAULT 'untested'",
    "ALTER TABLE card_records ADD COLUMN search_text TEXT NOT NULL "
    "DEFAULT ''",
    'ALTER TABLE card_records ADD COLUMN is_archived INTEGER NOT NULL '
    'DEFAULT 0',
    'ALTER TABLE card_records ADD COLUMN is_favorite INTEGER NOT NULL '
    'DEFAULT 0',
  ];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        // v1 → v2: the v1 schema already had id, payload_json,
        // created_at_millis, updated_at_millis. v2 added nine
        // normalized columns (name_text, issuer_text, category_name,
        // custom_category_text, card_type_name,
        // compatibility_status_name, search_text, is_archived,
        // is_favorite) that the v1→v2 migration populated via a
        // per-row backfill. Those columns were never read by any
        // code path: the repository always re-decodes payload_json
        // into a WalletCard. v3 drops them again so the schema is
        // the minimal storage-of-record.
        //
        // The columns are not on the v3 CardRecords class, so the
        // ALTER TABLE statements are issued as raw SQL — drift's
        // type-safe addColumn only sees the v3 columns.
        // customStatement is the supported path; migrator.issueCustomQuery
        // is the deprecated alias.
        for (final ddl in _v1ToV2AlterStatements) {
          await customStatement(ddl);
        }
        await _backfillNormalizedColumns();
      }
      if (from < 3) {
        // v2 → v3: the normalized columns were never read; the
        // payload JSON is the only source of truth. Drop them.
        await migrator.dropColumn(cardRecords, 'name_text');
        await migrator.dropColumn(cardRecords, 'issuer_text');
        await migrator.dropColumn(cardRecords, 'category_name');
        await migrator.dropColumn(cardRecords, 'custom_category_text');
        await migrator.dropColumn(cardRecords, 'card_type_name');
        await migrator.dropColumn(
          cardRecords,
          'compatibility_status_name',
        );
        await migrator.dropColumn(cardRecords, 'search_text');
        await migrator.dropColumn(cardRecords, 'is_archived');
        await migrator.dropColumn(cardRecords, 'is_favorite');
      }
    },
  );

  Future<List<WalletCard>> loadCards() async {
    final rows = await select(cardRecords).get();
    final cards = <WalletCard>[];
    for (final row in rows) {
      final card = _tryDecodeRow(row);
      if (card != null) {
        cards.add(card);
      }
    }
    return cards;
  }

  Future<bool> isEmpty() async {
    return (await countCards()) == 0;
  }

  Future<int> countCards() async {
    final countExpression = cardRecords.id.count();
    final row = await (selectOnly(
      cardRecords,
    )..addColumns([countExpression])).getSingle();
    return row.read(countExpression) ?? 0;
  }

  Future<void> upsertCard(WalletCard card) {
    return into(cardRecords).insertOnConflictUpdate(_rowForCard(card));
  }

  Future<void> upsertCards(Iterable<WalletCard> cards) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(
        cardRecords,
        cards.map(_rowForCard).toList(growable: false),
      );
    });
  }

  Future<void> replaceAllCards(Iterable<WalletCard> cards) async {
    await transaction(() async {
      await delete(cardRecords).go();
      if (cards.isNotEmpty) {
        await upsertCards(cards);
      }
    });
  }

  Future<void> deleteCardById(String id) {
    return (delete(cardRecords)..where((row) => row.id.equals(id))).go();
  }

  CardRecordsCompanion _rowForCard(WalletCard card) {
    return CardRecordsCompanion.insert(
      id: card.id,
      payloadJson: jsonEncode(card.toJson()),
      createdAtMillis: card.createdAt.millisecondsSinceEpoch,
      updatedAtMillis: card.updatedAt.millisecondsSinceEpoch,
    );
  }

  WalletCard? _tryDecodeRow(CardRecord row) {
    try {
      final decoded = jsonDecode(row.payloadJson);
      if (decoded is! Map<String, Object?>) {
        throw FormatException(
          'Card payload for ${row.id} is not a JSON object.',
        );
      }
      return WalletCard.fromJson(decoded);
    } catch (error) {
      // Corrupt or partially-written rows must not poison the
      // entire loadCards() call. The user's other cards should
      // still surface.
      // ignore: avoid_print
      print('CardDatabase: skipping corrupt card ${row.id}: $error');
      return null;
    }
  }

  /// Populates the v2-only normalized columns from the payload JSON.
  /// Used by the v1→v2 migration path. The columns are dropped again
  /// in v3; this is only here to support users on v1/v2 installs
  /// that haven't yet upgraded past v2.
  Future<void> _backfillNormalizedColumns() async {
    final rows = await select(cardRecords).get();
    for (final row in rows) {
      WalletCard? card;
      try {
        final decoded = jsonDecode(row.payloadJson);
        if (decoded is! Map<String, Object?>) {
          throw FormatException('Not a JSON object.');
        }
        card = WalletCard.fromJson(decoded);
      } catch (error) {
        // A single corrupt row must not abort the migration.
        // ignore: avoid_print
        print(
          'CardDatabase: skipping v1->v2 backfill for corrupt card '
          '${row.id}: $error',
        );
        continue;
      }
      // The normalized columns were dropped from the v3
      // CardRecords class, so the backfill is issued as raw SQL
      // for forward compatibility.
      await customStatement(
        'UPDATE card_records SET '
        'name_text = ?, '
        'issuer_text = ?, '
        'category_name = ?, '
        'custom_category_text = ?, '
        'card_type_name = ?, '
        'compatibility_status_name = ?, '
        'search_text = ? '
        'WHERE id = ?',
        [
          card.name,
          card.issuer,
          card.category.name,
          card.customCategory,
          card.cardType.name,
          card.compatibilityStatus.name,
          _searchTextForCard(card),
          row.id,
        ],
      );
    }
  }

  String _searchTextForCard(WalletCard card) {
    return <String>[
      card.name,
      card.issuer,
      card.category.name,
      card.categoryLabel,
      card.notes,
      card.barcodePayload,
      card.barcodeFormat,
      card.barcodeImagePath,
      card.barcodeDisplayValue,
      card.barcodeValueType,
      card.barcodeStructuredData,
      card.barcodeRawBytesHex,
      card.nfcTagSummary,
      card.rawOcrText,
      card.contactTitle,
      card.contactAddress,
      ...card.contactPhones,
      ...card.contactEmails,
      ...card.contactWebsites,
    ].where((value) => value.trim().isNotEmpty).join('\n').toLowerCase();
  }
}
