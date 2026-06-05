// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'card_database.dart';

// ignore_for_file: type=lint
class $CardRecordsTable extends CardRecords
    with TableInfo<$CardRecordsTable, CardRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CardRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameTextMeta = const VerificationMeta(
    'nameText',
  );
  @override
  late final GeneratedColumn<String> nameText = GeneratedColumn<String>(
    'name_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _issuerTextMeta = const VerificationMeta(
    'issuerText',
  );
  @override
  late final GeneratedColumn<String> issuerText = GeneratedColumn<String>(
    'issuer_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _categoryNameMeta = const VerificationMeta(
    'categoryName',
  );
  @override
  late final GeneratedColumn<String> categoryName = GeneratedColumn<String>(
    'category_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('other'),
  );
  static const VerificationMeta _customCategoryTextMeta =
      const VerificationMeta('customCategoryText');
  @override
  late final GeneratedColumn<String> customCategoryText =
      GeneratedColumn<String>(
        'custom_category_text',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _cardTypeNameMeta = const VerificationMeta(
    'cardTypeName',
  );
  @override
  late final GeneratedColumn<String> cardTypeName = GeneratedColumn<String>(
    'card_type_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('standard'),
  );
  static const VerificationMeta _compatibilityStatusNameMeta =
      const VerificationMeta('compatibilityStatusName');
  @override
  late final GeneratedColumn<String> compatibilityStatusName =
      GeneratedColumn<String>(
        'compatibility_status_name',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('untested'),
      );
  static const VerificationMeta _searchTextMeta = const VerificationMeta(
    'searchText',
  );
  @override
  late final GeneratedColumn<String> searchText = GeneratedColumn<String>(
    'search_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isFavoriteMeta = const VerificationMeta(
    'isFavorite',
  );
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
    'is_favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMillisMeta = const VerificationMeta(
    'createdAtMillis',
  );
  @override
  late final GeneratedColumn<int> createdAtMillis = GeneratedColumn<int>(
    'created_at_millis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMillisMeta = const VerificationMeta(
    'updatedAtMillis',
  );
  @override
  late final GeneratedColumn<int> updatedAtMillis = GeneratedColumn<int>(
    'updated_at_millis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    payloadJson,
    nameText,
    issuerText,
    categoryName,
    customCategoryText,
    cardTypeName,
    compatibilityStatusName,
    searchText,
    isArchived,
    isFavorite,
    createdAtMillis,
    updatedAtMillis,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'card_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<CardRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('name_text')) {
      context.handle(
        _nameTextMeta,
        nameText.isAcceptableOrUnknown(data['name_text']!, _nameTextMeta),
      );
    }
    if (data.containsKey('issuer_text')) {
      context.handle(
        _issuerTextMeta,
        issuerText.isAcceptableOrUnknown(data['issuer_text']!, _issuerTextMeta),
      );
    }
    if (data.containsKey('category_name')) {
      context.handle(
        _categoryNameMeta,
        categoryName.isAcceptableOrUnknown(
          data['category_name']!,
          _categoryNameMeta,
        ),
      );
    }
    if (data.containsKey('custom_category_text')) {
      context.handle(
        _customCategoryTextMeta,
        customCategoryText.isAcceptableOrUnknown(
          data['custom_category_text']!,
          _customCategoryTextMeta,
        ),
      );
    }
    if (data.containsKey('card_type_name')) {
      context.handle(
        _cardTypeNameMeta,
        cardTypeName.isAcceptableOrUnknown(
          data['card_type_name']!,
          _cardTypeNameMeta,
        ),
      );
    }
    if (data.containsKey('compatibility_status_name')) {
      context.handle(
        _compatibilityStatusNameMeta,
        compatibilityStatusName.isAcceptableOrUnknown(
          data['compatibility_status_name']!,
          _compatibilityStatusNameMeta,
        ),
      );
    }
    if (data.containsKey('search_text')) {
      context.handle(
        _searchTextMeta,
        searchText.isAcceptableOrUnknown(data['search_text']!, _searchTextMeta),
      );
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
        _isFavoriteMeta,
        isFavorite.isAcceptableOrUnknown(data['is_favorite']!, _isFavoriteMeta),
      );
    }
    if (data.containsKey('created_at_millis')) {
      context.handle(
        _createdAtMillisMeta,
        createdAtMillis.isAcceptableOrUnknown(
          data['created_at_millis']!,
          _createdAtMillisMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMillisMeta);
    }
    if (data.containsKey('updated_at_millis')) {
      context.handle(
        _updatedAtMillisMeta,
        updatedAtMillis.isAcceptableOrUnknown(
          data['updated_at_millis']!,
          _updatedAtMillisMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMillisMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CardRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CardRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      nameText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_text'],
      )!,
      issuerText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}issuer_text'],
      )!,
      categoryName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_name'],
      )!,
      customCategoryText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}custom_category_text'],
      ),
      cardTypeName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}card_type_name'],
      )!,
      compatibilityStatusName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}compatibility_status_name'],
      )!,
      searchText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}search_text'],
      )!,
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archived'],
      )!,
      isFavorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_favorite'],
      )!,
      createdAtMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_millis'],
      )!,
      updatedAtMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_millis'],
      )!,
    );
  }

  @override
  $CardRecordsTable createAlias(String alias) {
    return $CardRecordsTable(attachedDatabase, alias);
  }
}

class CardRecord extends DataClass implements Insertable<CardRecord> {
  final String id;
  final String payloadJson;
  final String nameText;
  final String issuerText;
  final String categoryName;
  final String? customCategoryText;
  final String cardTypeName;
  final String compatibilityStatusName;
  final String searchText;
  final bool isArchived;
  final bool isFavorite;
  final int createdAtMillis;
  final int updatedAtMillis;
  const CardRecord({
    required this.id,
    required this.payloadJson,
    required this.nameText,
    required this.issuerText,
    required this.categoryName,
    this.customCategoryText,
    required this.cardTypeName,
    required this.compatibilityStatusName,
    required this.searchText,
    required this.isArchived,
    required this.isFavorite,
    required this.createdAtMillis,
    required this.updatedAtMillis,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['payload_json'] = Variable<String>(payloadJson);
    map['name_text'] = Variable<String>(nameText);
    map['issuer_text'] = Variable<String>(issuerText);
    map['category_name'] = Variable<String>(categoryName);
    if (!nullToAbsent || customCategoryText != null) {
      map['custom_category_text'] = Variable<String>(customCategoryText);
    }
    map['card_type_name'] = Variable<String>(cardTypeName);
    map['compatibility_status_name'] = Variable<String>(
      compatibilityStatusName,
    );
    map['search_text'] = Variable<String>(searchText);
    map['is_archived'] = Variable<bool>(isArchived);
    map['is_favorite'] = Variable<bool>(isFavorite);
    map['created_at_millis'] = Variable<int>(createdAtMillis);
    map['updated_at_millis'] = Variable<int>(updatedAtMillis);
    return map;
  }

  CardRecordsCompanion toCompanion(bool nullToAbsent) {
    return CardRecordsCompanion(
      id: Value(id),
      payloadJson: Value(payloadJson),
      nameText: Value(nameText),
      issuerText: Value(issuerText),
      categoryName: Value(categoryName),
      customCategoryText: customCategoryText == null && nullToAbsent
          ? const Value.absent()
          : Value(customCategoryText),
      cardTypeName: Value(cardTypeName),
      compatibilityStatusName: Value(compatibilityStatusName),
      searchText: Value(searchText),
      isArchived: Value(isArchived),
      isFavorite: Value(isFavorite),
      createdAtMillis: Value(createdAtMillis),
      updatedAtMillis: Value(updatedAtMillis),
    );
  }

  factory CardRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CardRecord(
      id: serializer.fromJson<String>(json['id']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      nameText: serializer.fromJson<String>(json['nameText']),
      issuerText: serializer.fromJson<String>(json['issuerText']),
      categoryName: serializer.fromJson<String>(json['categoryName']),
      customCategoryText: serializer.fromJson<String?>(
        json['customCategoryText'],
      ),
      cardTypeName: serializer.fromJson<String>(json['cardTypeName']),
      compatibilityStatusName: serializer.fromJson<String>(
        json['compatibilityStatusName'],
      ),
      searchText: serializer.fromJson<String>(json['searchText']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      createdAtMillis: serializer.fromJson<int>(json['createdAtMillis']),
      updatedAtMillis: serializer.fromJson<int>(json['updatedAtMillis']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'nameText': serializer.toJson<String>(nameText),
      'issuerText': serializer.toJson<String>(issuerText),
      'categoryName': serializer.toJson<String>(categoryName),
      'customCategoryText': serializer.toJson<String?>(customCategoryText),
      'cardTypeName': serializer.toJson<String>(cardTypeName),
      'compatibilityStatusName': serializer.toJson<String>(
        compatibilityStatusName,
      ),
      'searchText': serializer.toJson<String>(searchText),
      'isArchived': serializer.toJson<bool>(isArchived),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'createdAtMillis': serializer.toJson<int>(createdAtMillis),
      'updatedAtMillis': serializer.toJson<int>(updatedAtMillis),
    };
  }

  CardRecord copyWith({
    String? id,
    String? payloadJson,
    String? nameText,
    String? issuerText,
    String? categoryName,
    Value<String?> customCategoryText = const Value.absent(),
    String? cardTypeName,
    String? compatibilityStatusName,
    String? searchText,
    bool? isArchived,
    bool? isFavorite,
    int? createdAtMillis,
    int? updatedAtMillis,
  }) => CardRecord(
    id: id ?? this.id,
    payloadJson: payloadJson ?? this.payloadJson,
    nameText: nameText ?? this.nameText,
    issuerText: issuerText ?? this.issuerText,
    categoryName: categoryName ?? this.categoryName,
    customCategoryText: customCategoryText.present
        ? customCategoryText.value
        : this.customCategoryText,
    cardTypeName: cardTypeName ?? this.cardTypeName,
    compatibilityStatusName:
        compatibilityStatusName ?? this.compatibilityStatusName,
    searchText: searchText ?? this.searchText,
    isArchived: isArchived ?? this.isArchived,
    isFavorite: isFavorite ?? this.isFavorite,
    createdAtMillis: createdAtMillis ?? this.createdAtMillis,
    updatedAtMillis: updatedAtMillis ?? this.updatedAtMillis,
  );
  CardRecord copyWithCompanion(CardRecordsCompanion data) {
    return CardRecord(
      id: data.id.present ? data.id.value : this.id,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      nameText: data.nameText.present ? data.nameText.value : this.nameText,
      issuerText: data.issuerText.present
          ? data.issuerText.value
          : this.issuerText,
      categoryName: data.categoryName.present
          ? data.categoryName.value
          : this.categoryName,
      customCategoryText: data.customCategoryText.present
          ? data.customCategoryText.value
          : this.customCategoryText,
      cardTypeName: data.cardTypeName.present
          ? data.cardTypeName.value
          : this.cardTypeName,
      compatibilityStatusName: data.compatibilityStatusName.present
          ? data.compatibilityStatusName.value
          : this.compatibilityStatusName,
      searchText: data.searchText.present
          ? data.searchText.value
          : this.searchText,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
      isFavorite: data.isFavorite.present
          ? data.isFavorite.value
          : this.isFavorite,
      createdAtMillis: data.createdAtMillis.present
          ? data.createdAtMillis.value
          : this.createdAtMillis,
      updatedAtMillis: data.updatedAtMillis.present
          ? data.updatedAtMillis.value
          : this.updatedAtMillis,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CardRecord(')
          ..write('id: $id, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('nameText: $nameText, ')
          ..write('issuerText: $issuerText, ')
          ..write('categoryName: $categoryName, ')
          ..write('customCategoryText: $customCategoryText, ')
          ..write('cardTypeName: $cardTypeName, ')
          ..write('compatibilityStatusName: $compatibilityStatusName, ')
          ..write('searchText: $searchText, ')
          ..write('isArchived: $isArchived, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('createdAtMillis: $createdAtMillis, ')
          ..write('updatedAtMillis: $updatedAtMillis')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    payloadJson,
    nameText,
    issuerText,
    categoryName,
    customCategoryText,
    cardTypeName,
    compatibilityStatusName,
    searchText,
    isArchived,
    isFavorite,
    createdAtMillis,
    updatedAtMillis,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CardRecord &&
          other.id == this.id &&
          other.payloadJson == this.payloadJson &&
          other.nameText == this.nameText &&
          other.issuerText == this.issuerText &&
          other.categoryName == this.categoryName &&
          other.customCategoryText == this.customCategoryText &&
          other.cardTypeName == this.cardTypeName &&
          other.compatibilityStatusName == this.compatibilityStatusName &&
          other.searchText == this.searchText &&
          other.isArchived == this.isArchived &&
          other.isFavorite == this.isFavorite &&
          other.createdAtMillis == this.createdAtMillis &&
          other.updatedAtMillis == this.updatedAtMillis);
}

class CardRecordsCompanion extends UpdateCompanion<CardRecord> {
  final Value<String> id;
  final Value<String> payloadJson;
  final Value<String> nameText;
  final Value<String> issuerText;
  final Value<String> categoryName;
  final Value<String?> customCategoryText;
  final Value<String> cardTypeName;
  final Value<String> compatibilityStatusName;
  final Value<String> searchText;
  final Value<bool> isArchived;
  final Value<bool> isFavorite;
  final Value<int> createdAtMillis;
  final Value<int> updatedAtMillis;
  final Value<int> rowid;
  const CardRecordsCompanion({
    this.id = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.nameText = const Value.absent(),
    this.issuerText = const Value.absent(),
    this.categoryName = const Value.absent(),
    this.customCategoryText = const Value.absent(),
    this.cardTypeName = const Value.absent(),
    this.compatibilityStatusName = const Value.absent(),
    this.searchText = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.createdAtMillis = const Value.absent(),
    this.updatedAtMillis = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CardRecordsCompanion.insert({
    required String id,
    required String payloadJson,
    this.nameText = const Value.absent(),
    this.issuerText = const Value.absent(),
    this.categoryName = const Value.absent(),
    this.customCategoryText = const Value.absent(),
    this.cardTypeName = const Value.absent(),
    this.compatibilityStatusName = const Value.absent(),
    this.searchText = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.isFavorite = const Value.absent(),
    required int createdAtMillis,
    required int updatedAtMillis,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       payloadJson = Value(payloadJson),
       createdAtMillis = Value(createdAtMillis),
       updatedAtMillis = Value(updatedAtMillis);
  static Insertable<CardRecord> custom({
    Expression<String>? id,
    Expression<String>? payloadJson,
    Expression<String>? nameText,
    Expression<String>? issuerText,
    Expression<String>? categoryName,
    Expression<String>? customCategoryText,
    Expression<String>? cardTypeName,
    Expression<String>? compatibilityStatusName,
    Expression<String>? searchText,
    Expression<bool>? isArchived,
    Expression<bool>? isFavorite,
    Expression<int>? createdAtMillis,
    Expression<int>? updatedAtMillis,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (nameText != null) 'name_text': nameText,
      if (issuerText != null) 'issuer_text': issuerText,
      if (categoryName != null) 'category_name': categoryName,
      if (customCategoryText != null)
        'custom_category_text': customCategoryText,
      if (cardTypeName != null) 'card_type_name': cardTypeName,
      if (compatibilityStatusName != null)
        'compatibility_status_name': compatibilityStatusName,
      if (searchText != null) 'search_text': searchText,
      if (isArchived != null) 'is_archived': isArchived,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (createdAtMillis != null) 'created_at_millis': createdAtMillis,
      if (updatedAtMillis != null) 'updated_at_millis': updatedAtMillis,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CardRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? payloadJson,
    Value<String>? nameText,
    Value<String>? issuerText,
    Value<String>? categoryName,
    Value<String?>? customCategoryText,
    Value<String>? cardTypeName,
    Value<String>? compatibilityStatusName,
    Value<String>? searchText,
    Value<bool>? isArchived,
    Value<bool>? isFavorite,
    Value<int>? createdAtMillis,
    Value<int>? updatedAtMillis,
    Value<int>? rowid,
  }) {
    return CardRecordsCompanion(
      id: id ?? this.id,
      payloadJson: payloadJson ?? this.payloadJson,
      nameText: nameText ?? this.nameText,
      issuerText: issuerText ?? this.issuerText,
      categoryName: categoryName ?? this.categoryName,
      customCategoryText: customCategoryText ?? this.customCategoryText,
      cardTypeName: cardTypeName ?? this.cardTypeName,
      compatibilityStatusName:
          compatibilityStatusName ?? this.compatibilityStatusName,
      searchText: searchText ?? this.searchText,
      isArchived: isArchived ?? this.isArchived,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAtMillis: createdAtMillis ?? this.createdAtMillis,
      updatedAtMillis: updatedAtMillis ?? this.updatedAtMillis,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (nameText.present) {
      map['name_text'] = Variable<String>(nameText.value);
    }
    if (issuerText.present) {
      map['issuer_text'] = Variable<String>(issuerText.value);
    }
    if (categoryName.present) {
      map['category_name'] = Variable<String>(categoryName.value);
    }
    if (customCategoryText.present) {
      map['custom_category_text'] = Variable<String>(customCategoryText.value);
    }
    if (cardTypeName.present) {
      map['card_type_name'] = Variable<String>(cardTypeName.value);
    }
    if (compatibilityStatusName.present) {
      map['compatibility_status_name'] = Variable<String>(
        compatibilityStatusName.value,
      );
    }
    if (searchText.present) {
      map['search_text'] = Variable<String>(searchText.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (createdAtMillis.present) {
      map['created_at_millis'] = Variable<int>(createdAtMillis.value);
    }
    if (updatedAtMillis.present) {
      map['updated_at_millis'] = Variable<int>(updatedAtMillis.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CardRecordsCompanion(')
          ..write('id: $id, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('nameText: $nameText, ')
          ..write('issuerText: $issuerText, ')
          ..write('categoryName: $categoryName, ')
          ..write('customCategoryText: $customCategoryText, ')
          ..write('cardTypeName: $cardTypeName, ')
          ..write('compatibilityStatusName: $compatibilityStatusName, ')
          ..write('searchText: $searchText, ')
          ..write('isArchived: $isArchived, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('createdAtMillis: $createdAtMillis, ')
          ..write('updatedAtMillis: $updatedAtMillis, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$CardDatabase extends GeneratedDatabase {
  _$CardDatabase(QueryExecutor e) : super(e);
  $CardDatabaseManager get managers => $CardDatabaseManager(this);
  late final $CardRecordsTable cardRecords = $CardRecordsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [cardRecords];
}

typedef $$CardRecordsTableCreateCompanionBuilder =
    CardRecordsCompanion Function({
      required String id,
      required String payloadJson,
      Value<String> nameText,
      Value<String> issuerText,
      Value<String> categoryName,
      Value<String?> customCategoryText,
      Value<String> cardTypeName,
      Value<String> compatibilityStatusName,
      Value<String> searchText,
      Value<bool> isArchived,
      Value<bool> isFavorite,
      required int createdAtMillis,
      required int updatedAtMillis,
      Value<int> rowid,
    });
typedef $$CardRecordsTableUpdateCompanionBuilder =
    CardRecordsCompanion Function({
      Value<String> id,
      Value<String> payloadJson,
      Value<String> nameText,
      Value<String> issuerText,
      Value<String> categoryName,
      Value<String?> customCategoryText,
      Value<String> cardTypeName,
      Value<String> compatibilityStatusName,
      Value<String> searchText,
      Value<bool> isArchived,
      Value<bool> isFavorite,
      Value<int> createdAtMillis,
      Value<int> updatedAtMillis,
      Value<int> rowid,
    });

class $$CardRecordsTableFilterComposer
    extends Composer<_$CardDatabase, $CardRecordsTable> {
  $$CardRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nameText => $composableBuilder(
    column: $table.nameText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get issuerText => $composableBuilder(
    column: $table.issuerText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryName => $composableBuilder(
    column: $table.categoryName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customCategoryText => $composableBuilder(
    column: $table.customCategoryText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cardTypeName => $composableBuilder(
    column: $table.cardTypeName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get compatibilityStatusName => $composableBuilder(
    column: $table.compatibilityStatusName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMillis => $composableBuilder(
    column: $table.createdAtMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMillis => $composableBuilder(
    column: $table.updatedAtMillis,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CardRecordsTableOrderingComposer
    extends Composer<_$CardDatabase, $CardRecordsTable> {
  $$CardRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nameText => $composableBuilder(
    column: $table.nameText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get issuerText => $composableBuilder(
    column: $table.issuerText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryName => $composableBuilder(
    column: $table.categoryName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customCategoryText => $composableBuilder(
    column: $table.customCategoryText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cardTypeName => $composableBuilder(
    column: $table.cardTypeName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get compatibilityStatusName => $composableBuilder(
    column: $table.compatibilityStatusName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMillis => $composableBuilder(
    column: $table.createdAtMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMillis => $composableBuilder(
    column: $table.updatedAtMillis,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CardRecordsTableAnnotationComposer
    extends Composer<_$CardDatabase, $CardRecordsTable> {
  $$CardRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nameText =>
      $composableBuilder(column: $table.nameText, builder: (column) => column);

  GeneratedColumn<String> get issuerText => $composableBuilder(
    column: $table.issuerText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get categoryName => $composableBuilder(
    column: $table.categoryName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get customCategoryText => $composableBuilder(
    column: $table.customCategoryText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cardTypeName => $composableBuilder(
    column: $table.cardTypeName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get compatibilityStatusName => $composableBuilder(
    column: $table.compatibilityStatusName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtMillis => $composableBuilder(
    column: $table.createdAtMillis,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtMillis => $composableBuilder(
    column: $table.updatedAtMillis,
    builder: (column) => column,
  );
}

class $$CardRecordsTableTableManager
    extends
        RootTableManager<
          _$CardDatabase,
          $CardRecordsTable,
          CardRecord,
          $$CardRecordsTableFilterComposer,
          $$CardRecordsTableOrderingComposer,
          $$CardRecordsTableAnnotationComposer,
          $$CardRecordsTableCreateCompanionBuilder,
          $$CardRecordsTableUpdateCompanionBuilder,
          (
            CardRecord,
            BaseReferences<_$CardDatabase, $CardRecordsTable, CardRecord>,
          ),
          CardRecord,
          PrefetchHooks Function()
        > {
  $$CardRecordsTableTableManager(_$CardDatabase db, $CardRecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CardRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CardRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CardRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<String> nameText = const Value.absent(),
                Value<String> issuerText = const Value.absent(),
                Value<String> categoryName = const Value.absent(),
                Value<String?> customCategoryText = const Value.absent(),
                Value<String> cardTypeName = const Value.absent(),
                Value<String> compatibilityStatusName = const Value.absent(),
                Value<String> searchText = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<int> createdAtMillis = const Value.absent(),
                Value<int> updatedAtMillis = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CardRecordsCompanion(
                id: id,
                payloadJson: payloadJson,
                nameText: nameText,
                issuerText: issuerText,
                categoryName: categoryName,
                customCategoryText: customCategoryText,
                cardTypeName: cardTypeName,
                compatibilityStatusName: compatibilityStatusName,
                searchText: searchText,
                isArchived: isArchived,
                isFavorite: isFavorite,
                createdAtMillis: createdAtMillis,
                updatedAtMillis: updatedAtMillis,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String payloadJson,
                Value<String> nameText = const Value.absent(),
                Value<String> issuerText = const Value.absent(),
                Value<String> categoryName = const Value.absent(),
                Value<String?> customCategoryText = const Value.absent(),
                Value<String> cardTypeName = const Value.absent(),
                Value<String> compatibilityStatusName = const Value.absent(),
                Value<String> searchText = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                required int createdAtMillis,
                required int updatedAtMillis,
                Value<int> rowid = const Value.absent(),
              }) => CardRecordsCompanion.insert(
                id: id,
                payloadJson: payloadJson,
                nameText: nameText,
                issuerText: issuerText,
                categoryName: categoryName,
                customCategoryText: customCategoryText,
                cardTypeName: cardTypeName,
                compatibilityStatusName: compatibilityStatusName,
                searchText: searchText,
                isArchived: isArchived,
                isFavorite: isFavorite,
                createdAtMillis: createdAtMillis,
                updatedAtMillis: updatedAtMillis,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CardRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$CardDatabase,
      $CardRecordsTable,
      CardRecord,
      $$CardRecordsTableFilterComposer,
      $$CardRecordsTableOrderingComposer,
      $$CardRecordsTableAnnotationComposer,
      $$CardRecordsTableCreateCompanionBuilder,
      $$CardRecordsTableUpdateCompanionBuilder,
      (
        CardRecord,
        BaseReferences<_$CardDatabase, $CardRecordsTable, CardRecord>,
      ),
      CardRecord,
      PrefetchHooks Function()
    >;

class $CardDatabaseManager {
  final _$CardDatabase _db;
  $CardDatabaseManager(this._db);
  $$CardRecordsTableTableManager get cardRecords =>
      $$CardRecordsTableTableManager(_db, _db.cardRecords);
}
