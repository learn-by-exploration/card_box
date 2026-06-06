import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

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
    return rows.map(_cardFromRow).toList();
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

  WalletCard _cardFromRow(CardRecord row) {
    final decoded = jsonDecode(row.payloadJson);
    return WalletCard.fromJson((decoded as Map).cast<String, Object?>());
  }

  Future<void> _backfillNormalizedColumns() async {
    final rows = await select(cardRecords).get();
    for (final row in rows) {
      final card = _cardFromRow(row);
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
