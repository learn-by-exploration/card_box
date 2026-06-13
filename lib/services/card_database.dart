import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';

import 'package:card_box/models/wallet_card.dart';

part 'card_database.g.dart';

class CardRecords extends Table {
  TextColumn get id => text()();

  TextColumn get payloadJson => text()();

  TextColumn get nameText => text().withDefault(const Constant(''))();

  TextColumn get issuerText => text().withDefault(const Constant(''))();

  TextColumn get categoryName => text().withDefault(const Constant('other'))();

  TextColumn get customCategoryText => text().nullable()();

  TextColumn get cardTypeName =>
      text().withDefault(const Constant('standard'))();

  TextColumn get compatibilityStatusName =>
      text().withDefault(const Constant('untested'))();

  TextColumn get searchText => text().withDefault(const Constant(''))();

  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();

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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(cardRecords, cardRecords.nameText);
        await migrator.addColumn(cardRecords, cardRecords.issuerText);
        await migrator.addColumn(cardRecords, cardRecords.categoryName);
        await migrator.addColumn(cardRecords, cardRecords.customCategoryText);
        await migrator.addColumn(cardRecords, cardRecords.cardTypeName);
        await migrator.addColumn(
          cardRecords,
          cardRecords.compatibilityStatusName,
        );
        await migrator.addColumn(cardRecords, cardRecords.searchText);
        await _backfillNormalizedColumns();
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
    final count = await countCards();
    return count == 0;
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
      nameText: Value(card.name),
      issuerText: Value(card.issuer),
      categoryName: Value(card.category.name),
      customCategoryText: Value(card.customCategory),
      cardTypeName: Value(card.cardType.name),
      compatibilityStatusName: Value(card.compatibilityStatus.name),
      searchText: Value(_searchTextForCard(card)),
      isArchived: Value(card.archived),
      isFavorite: Value(card.favorite),
      createdAtMillis: card.createdAt.millisecondsSinceEpoch,
      updatedAtMillis: card.updatedAt.millisecondsSinceEpoch,
    );
  }

  WalletCard? _tryDecodeRow(CardRecord row) {
    try {
      return _cardFromRow(row);
    } catch (error) {
      // Corrupt or partially-written rows must not poison the entire
      // loadCards() call — the user's other cards should still surface.
      debugPrint('Skipping corrupt card ${row.id}: $error');
      return null;
    }
  }

  WalletCard _cardFromRow(CardRecord row) {
    final decoded = jsonDecode(row.payloadJson);
    if (decoded is! Map<String, Object?>) {
      throw FormatException(
        'Card payload for ${row.id} is not a JSON object.',
      );
    }
    return WalletCard.fromJson(decoded);
  }

  Future<void> _backfillNormalizedColumns() async {
    final rows = await select(cardRecords).get();
    for (final row in rows) {
      WalletCard? card;
      try {
        card = _cardFromRow(row);
      } catch (error) {
        // A single corrupt row must not abort the v1→v2
        // migration. The schema upgrade has already been applied;
        // if we threw, every other card would lose its
        // normalized columns and search would silently break.
        // The row's payload is unchanged and loadCards() will
        // skip it again at read time.
        debugPrint('Skipping backfill for corrupt card ${row.id}: $error');
        continue;
      }
      await (update(cardRecords)..where((tbl) => tbl.id.equals(row.id))).write(
        CardRecordsCompanion(
          nameText: Value(card.name),
          issuerText: Value(card.issuer),
          categoryName: Value(card.category.name),
          customCategoryText: Value(card.customCategory),
          cardTypeName: Value(card.cardType.name),
          compatibilityStatusName: Value(card.compatibilityStatus.name),
          searchText: Value(_searchTextForCard(card)),
        ),
      );
    }
  }

  /// Visible for tests: re-runs the v1→v2 backfill. Production code
  /// gets this for free via the migration strategy; tests use it to
  /// drive the backfill against a database they have hand-corrupted
  /// to simulate a partial-write scenario.
  @visibleForTesting
  Future<void> debugRerunBackfill() => _backfillNormalizedColumns();

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
