/// SWAPPABLE SCHEMA FILE
/// ─────────────────────────────────────────────────────────────────────────────
/// To use AskBase with a different database:
///   1. Replace assets/agri.db with your new .db file
///   2. Create a new schema file (e.g. lib/schema/sales_schema.dart)
///      following the same structure below
///   3. Update lib/main.dart to import and use your new schema
///   4. No other file needs to change
/// ─────────────────────────────────────────────────────────────────────────────

import '../models/db_schema_model.dart';

const DatabaseSchema agriSchema = DatabaseSchema(
  databaseName: 'AgriTrack',
  dbFileName: 'agri.db',
  assetPath: 'assets/agri.db',
  databaseDescription:
      'Agricultural management database tracking farmers, their farms, crops '
      'sown and harvested each season. Tables are linked by farmer_id, farm_id, '
      'crop_id, variety_id and grade_id. Use JOINs across tables to answer '
      'questions about farming activity, yield, and crop distribution.',
  tables: [
    TableSchema(
      tableName: 'farmer',
      tableDescription:
          'Stores individual farmer profiles. Every farm, sowing and harvest '
          'record belongs to a farmer.',
      fields: [
        FieldDef(
          name: 'farmer_id',
          type: FieldType.integer,
          description: 'Unique identifier for each farmer.',
          isPrimaryKey: true,
        ),
        FieldDef(
          name: 'name',
          type: FieldType.text,
          description: 'Full name of the farmer.',
        ),
      ],
    ),

    TableSchema(
      tableName: 'farm',
      tableDescription:
          'Each farmer can own multiple farms. A farm is identified by its '
          'name and belongs to exactly one farmer.',
      fields: [
        FieldDef(
          name: 'farm_id',
          type: FieldType.integer,
          description: 'Unique identifier for each farm.',
          isPrimaryKey: true,
        ),
        FieldDef(
          name: 'name',
          type: FieldType.text,
          description: 'Name or label for the farm plot (e.g. "North Field 1").',
        ),
        FieldDef(
          name: 'farmer_id',
          type: FieldType.integer,
          description: 'The farmer who owns this farm.',
          foreignKeyRef: 'farmer.farmer_id',
        ),
      ],
    ),

    TableSchema(
      tableName: 'crop',
      tableDescription:
          'Master list of crop types (e.g. Paddy, Wheat, Maize). '
          'A crop has many varieties.',
      fields: [
        FieldDef(
          name: 'crop_id',
          type: FieldType.integer,
          description: 'Unique identifier for the crop type.',
          isPrimaryKey: true,
        ),
        FieldDef(
          name: 'name',
          type: FieldType.text,
          description: 'Common name of the crop (e.g. Paddy, Wheat, Maize, Cotton, Sugarcane).',
        ),
      ],
    ),

    TableSchema(
      tableName: 'variety',
      tableDescription:
          'A specific variety of a crop (e.g. IR64 is a variety of Paddy). '
          'Each variety belongs to one crop and has multiple grades.',
      fields: [
        FieldDef(
          name: 'variety_id',
          type: FieldType.integer,
          description: 'Unique identifier for the variety.',
          isPrimaryKey: true,
        ),
        FieldDef(
          name: 'name',
          type: FieldType.text,
          description: 'Name of the variety (e.g. IR64, Swarna, HD2967, BPT5204).',
        ),
        FieldDef(
          name: 'crop_id',
          type: FieldType.integer,
          description: 'The crop this variety belongs to.',
          foreignKeyRef: 'crop.crop_id',
        ),
      ],
    ),

    TableSchema(
      tableName: 'grade',
      tableDescription:
          'Quality grade assigned to a variety (e.g. Grade-A, Premium, Export). '
          'Each grade belongs to exactly one variety.',
      fields: [
        FieldDef(
          name: 'grade_id',
          type: FieldType.integer,
          description: 'Unique identifier for the grade.',
          isPrimaryKey: true,
        ),
        FieldDef(
          name: 'name',
          type: FieldType.text,
          description: 'Grade label (Grade-A, Grade-B, Premium, Standard, Export).',
        ),
        FieldDef(
          name: 'variety_id',
          type: FieldType.integer,
          description: 'The variety this grade belongs to.',
          foreignKeyRef: 'variety.variety_id',
        ),
      ],
    ),

    TableSchema(
      tableName: 'sowing',
      tableDescription:
          'Records each sowing event — which farmer sowed which crop variety '
          'on which farm, on what date, and how many kilograms of seed were sown.',
      fields: [
        FieldDef(
          name: 'sowing_id',
          type: FieldType.integer,
          description: 'Unique identifier for the sowing record.',
          isPrimaryKey: true,
        ),
        FieldDef(
          name: 'farmer_id',
          type: FieldType.integer,
          description: 'Farmer who performed the sowing.',
          foreignKeyRef: 'farmer.farmer_id',
        ),
        FieldDef(
          name: 'farm_id',
          type: FieldType.integer,
          description: 'Farm on which the sowing took place.',
          foreignKeyRef: 'farm.farm_id',
        ),
        FieldDef(
          name: 'crop_id',
          type: FieldType.integer,
          description: 'Type of crop sown.',
          foreignKeyRef: 'crop.crop_id',
        ),
        FieldDef(
          name: 'variety_id',
          type: FieldType.integer,
          description: 'Specific variety of the crop that was sown.',
          foreignKeyRef: 'variety.variety_id',
        ),
        FieldDef(
          name: 'grade_id',
          type: FieldType.integer,
          description: 'Grade of seed used during sowing.',
          foreignKeyRef: 'grade.grade_id',
        ),
        FieldDef(
          name: 'sow_date',
          type: FieldType.text,
          description: 'Date when sowing occurred, stored as ISO-8601 text (YYYY-MM-DD).',
        ),
        FieldDef(
          name: 'quantity_kg',
          type: FieldType.real,
          description: 'Quantity of seed sown in kilograms.',
        ),
      ],
    ),

    TableSchema(
      tableName: 'harvest',
      tableDescription:
          'Records each harvest event — which farmer harvested which crop variety '
          'from which farm, on what date, and how many kilograms were harvested.',
      fields: [
        FieldDef(
          name: 'harvest_id',
          type: FieldType.integer,
          description: 'Unique identifier for the harvest record.',
          isPrimaryKey: true,
        ),
        FieldDef(
          name: 'farmer_id',
          type: FieldType.integer,
          description: 'Farmer who performed the harvest.',
          foreignKeyRef: 'farmer.farmer_id',
        ),
        FieldDef(
          name: 'farm_id',
          type: FieldType.integer,
          description: 'Farm from which the harvest took place.',
          foreignKeyRef: 'farm.farm_id',
        ),
        FieldDef(
          name: 'crop_id',
          type: FieldType.integer,
          description: 'Type of crop harvested.',
          foreignKeyRef: 'crop.crop_id',
        ),
        FieldDef(
          name: 'variety_id',
          type: FieldType.integer,
          description: 'Specific variety of the crop that was harvested.',
          foreignKeyRef: 'variety.variety_id',
        ),
        FieldDef(
          name: 'grade_id',
          type: FieldType.integer,
          description: 'Grade of the harvested crop.',
          foreignKeyRef: 'grade.grade_id',
        ),
        FieldDef(
          name: 'harvest_date',
          type: FieldType.text,
          description: 'Date when harvest occurred, stored as ISO-8601 text (YYYY-MM-DD).',
        ),
        FieldDef(
          name: 'quantity_kg',
          type: FieldType.real,
          description: 'Quantity of crop harvested in kilograms.',
        ),
      ],
    ),
  ],
);
