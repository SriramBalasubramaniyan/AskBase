/// SWAPPABLE SCHEMA FILE — AgriTrack (50-table expanded schema)
/// Replace this file and assets/agri.db to switch to a different domain.

import '../models/db_schema_model.dart';

const DatabaseSchema agriSchema = DatabaseSchema(
  databaseName: 'AgriTrack',
  dbFileName: 'agri.db',
  assetPath: 'assets/agri.db',
  databaseDescription:
  'Comprehensive agricultural management database covering farmer profiles, '
      'land, crops, seasons, inputs, labour, sales, finance, logistics, '
      'government schemes and cooperative activities. Tables are linked by '
      'farmer_id, farm_id, crop_id, variety_id, grade_id, season_id and other '
      'foreign keys. Use JOINs to answer questions across domains.',
  tables: [

    // ── 1. state ─────────────────────────────────────────────────────────────
    TableSchema(
      tableName: 'state',
      tableDescription: 'Indian states where farming activities are recorded.',
      fields: [
        FieldDef(name: 'state_id', type: FieldType.integer, description: 'Unique state identifier.', isPrimaryKey: true),
        FieldDef(name: 'name', type: FieldType.text, description: 'State name (e.g. Tamil Nadu, Punjab).'),
        FieldDef(name: 'region', type: FieldType.text, description: 'Geographic region (North, South, East, West, Central).'),
        FieldDef(name: 'agri_zone', type: FieldType.text, description: 'Agricultural zone classification.'),
      ],
    ),

    // ── 2. district ───────────────────────────────────────────────────────────
    TableSchema(
      tableName: 'district',
      tableDescription: 'Districts within states. Villages, buyers, suppliers and training are linked here.',
      fields: [
        FieldDef(name: 'district_id', type: FieldType.integer, description: 'Unique district identifier.', isPrimaryKey: true),
        FieldDef(name: 'name', type: FieldType.text, description: 'District name.'),
        FieldDef(name: 'state_id', type: FieldType.integer, description: 'State this district belongs to.', foreignKeyRef: 'state.state_id'),
        FieldDef(name: 'headquarters', type: FieldType.text, description: 'Headquarters city of the district.'),
      ],
    ),

    // ── 3. village ────────────────────────────────────────────────────────────
    TableSchema(
      tableName: 'village',
      tableDescription: 'Villages where farmers, labour and cooperatives are located.',
      fields: [
        FieldDef(name: 'village_id', type: FieldType.integer, description: 'Unique village identifier.', isPrimaryKey: true),
        FieldDef(name: 'name', type: FieldType.text, description: 'Village name.'),
        FieldDef(name: 'district_id', type: FieldType.integer, description: 'District this village belongs to.', foreignKeyRef: 'district.district_id'),
        FieldDef(name: 'pincode', type: FieldType.text, description: 'Postal pincode.'),
        FieldDef(name: 'total_farmers', type: FieldType.integer, description: 'Approximate number of farmers in the village.'),
        FieldDef(name: 'total_area_acres', type: FieldType.real, description: 'Total cultivable area in the village in acres.'),
      ],
    ),

    // ── 4. farmer ─────────────────────────────────────────────────────────────
    TableSchema(
      tableName: 'farmer',
      tableDescription: 'Registered farmer profiles. Central entity — farms, sowing, harvest, loans, subsidies and more are linked here.',
      fields: [
        FieldDef(name: 'farmer_id', type: FieldType.integer, description: 'Unique farmer identifier.', isPrimaryKey: true),
        FieldDef(name: 'name', type: FieldType.text, description: 'Full name of the farmer.'),
        FieldDef(name: 'phone', type: FieldType.text, description: 'Mobile phone number.'),
        FieldDef(name: 'gender', type: FieldType.text, description: 'Gender (Male/Female/Other).'),
        FieldDef(name: 'dob', type: FieldType.text, description: 'Date of birth in YYYY-MM-DD format.'),
        FieldDef(name: 'address', type: FieldType.text, description: 'Residential address.'),
        FieldDef(name: 'village_id', type: FieldType.integer, description: 'Village where the farmer resides.', foreignKeyRef: 'village.village_id'),
        FieldDef(name: 'education_level', type: FieldType.text, description: 'Highest education level (Illiterate, Primary, Secondary, Graduate).'),
        FieldDef(name: 'land_holding_acres', type: FieldType.real, description: 'Total land held by the farmer in acres.'),
      ],
    ),

    // ── 5. soil_type ─────────────────────────────────────────────────────────
    TableSchema(
      tableName: 'soil_type',
      tableDescription: 'Soil type classifications used to describe farm soil characteristics.',
      fields: [
        FieldDef(name: 'soil_type_id', type: FieldType.integer, description: 'Unique soil type identifier.', isPrimaryKey: true),
        FieldDef(name: 'name', type: FieldType.text, description: 'Soil type name (e.g. Black Cotton, Red Laterite, Alluvial).'),
        FieldDef(name: 'texture', type: FieldType.text, description: 'Soil texture (Sandy, Loamy, Clayey, Silty).'),
        FieldDef(name: 'ph_min', type: FieldType.real, description: 'Minimum pH value typical for this soil type.'),
        FieldDef(name: 'ph_max', type: FieldType.real, description: 'Maximum pH value typical for this soil type.'),
        FieldDef(name: 'organic_matter_pct', type: FieldType.real, description: 'Organic matter percentage.'),
        FieldDef(name: 'water_retention', type: FieldType.text, description: 'Water retention capacity (Low, Medium, High).'),
      ],
    ),

    // ── 6. land_document ─────────────────────────────────────────────────────
    TableSchema(
      tableName: 'land_document',
      tableDescription: 'Legal land ownership documents linked to farmers.',
      fields: [
        FieldDef(name: 'land_document_id', type: FieldType.integer, description: 'Unique document identifier.', isPrimaryKey: true),
        FieldDef(name: 'farmer_id', type: FieldType.integer, description: 'Farmer who owns this land document.', foreignKeyRef: 'farmer.farmer_id'),
        FieldDef(name: 'document_type', type: FieldType.text, description: 'Type of document (Patta, Chitta, Adangal, ROR).'),
        FieldDef(name: 'document_number', type: FieldType.text, description: 'Unique document registration number.'),
        FieldDef(name: 'issued_date', type: FieldType.text, description: 'Date document was issued in YYYY-MM-DD format.'),
        FieldDef(name: 'area_acres', type: FieldType.real, description: 'Land area covered by this document in acres.'),
        FieldDef(name: 'issuing_authority', type: FieldType.text, description: 'Government authority that issued the document.'),
      ],
    ),

    // ── 7. farm ───────────────────────────────────────────────────────────────
    TableSchema(
      tableName: 'farm',
      tableDescription: 'Individual farm plots owned by farmers. Each farmer can have multiple farms.',
      fields: [
        FieldDef(name: 'farm_id', type: FieldType.integer, description: 'Unique farm identifier.', isPrimaryKey: true),
        FieldDef(name: 'name', type: FieldType.text, description: 'Farm plot name or label (e.g. North Field 1).'),
        FieldDef(name: 'farmer_id', type: FieldType.integer, description: 'Farmer who owns this farm.', foreignKeyRef: 'farmer.farmer_id'),
        FieldDef(name: 'area_acres', type: FieldType.real, description: 'Total area of the farm in acres.'),
        FieldDef(name: 'soil_type_id', type: FieldType.integer, description: 'Soil type of this farm.', foreignKeyRef: 'soil_type.soil_type_id'),
        FieldDef(name: 'water_source_type', type: FieldType.text, description: 'Primary water source (Borewell, Canal, Rain-fed, River, Tank).'),
        FieldDef(name: 'latitude', type: FieldType.real, description: 'GPS latitude coordinate of the farm.'),
        FieldDef(name: 'longitude', type: FieldType.real, description: 'GPS longitude coordinate of the farm.'),
        FieldDef(name: 'land_document_id', type: FieldType.integer, description: 'Land ownership document for this farm.', foreignKeyRef: 'land_document.land_document_id'),
      ],
    ),

    // ── 8. crop ───────────────────────────────────────────────────────────────
    TableSchema(
      tableName: 'crop',
      tableDescription: 'Master list of crop types such as Paddy, Wheat, Maize, Cotton, Sugarcane.',
      fields: [
        FieldDef(name: 'crop_id', type: FieldType.integer, description: 'Unique crop identifier.', isPrimaryKey: true),
        FieldDef(name: 'name', type: FieldType.text, description: 'Common crop name (e.g. Paddy, Wheat, Maize, Cotton, Sugarcane).'),
        FieldDef(name: 'category', type: FieldType.text, description: 'Crop category (Cereal, Pulse, Oilseed, Fibre, Cash Crop, Vegetable, Fruit).'),
        FieldDef(name: 'season_type', type: FieldType.text, description: 'Suitable season type (Kharif, Rabi, Zaid, Perennial).'),
        FieldDef(name: 'min_temp_c', type: FieldType.real, description: 'Minimum temperature in Celsius required for growth.'),
        FieldDef(name: 'max_temp_c', type: FieldType.real, description: 'Maximum temperature in Celsius tolerated.'),
        FieldDef(name: 'water_requirement_mm', type: FieldType.real, description: 'Water requirement in millimetres per season.'),
      ],
    ),

    // ── 9. variety ────────────────────────────────────────────────────────────
    TableSchema(
      tableName: 'variety',
      tableDescription: 'Specific cultivar or variety of a crop (e.g. IR64 is a variety of Paddy).',
      fields: [
        FieldDef(name: 'variety_id', type: FieldType.integer, description: 'Unique variety identifier.', isPrimaryKey: true),
        FieldDef(name: 'name', type: FieldType.text, description: 'Variety name (e.g. IR64, Swarna, HD2967, BPT5204, Bt-Bollgard).'),
        FieldDef(name: 'crop_id', type: FieldType.integer, description: 'Crop this variety belongs to.', foreignKeyRef: 'crop.crop_id'),
        FieldDef(name: 'duration_days', type: FieldType.integer, description: 'Days from sowing to harvest for this variety.'),
        FieldDef(name: 'yield_potential_kg_acre', type: FieldType.real, description: 'Expected yield in kg per acre under good conditions.'),
        FieldDef(name: 'is_hybrid', type: FieldType.integer, description: '1 if hybrid variety, 0 if traditional/open-pollinated.'),
      ],
    ),

    // ── 10. grade ────────────────────────────────────────────────────────────
    TableSchema(
      tableName: 'grade',
      tableDescription: 'Quality grade assigned to a crop variety (e.g. Grade-A, Premium, Export).',
      fields: [
        FieldDef(name: 'grade_id', type: FieldType.integer, description: 'Unique grade identifier.', isPrimaryKey: true),
        FieldDef(name: 'name', type: FieldType.text, description: 'Grade label (Grade-A, Grade-B, Premium, Standard, Export).'),
        FieldDef(name: 'variety_id', type: FieldType.integer, description: 'Variety this grade applies to.', foreignKeyRef: 'variety.variety_id'),
        FieldDef(name: 'min_quality_score', type: FieldType.real, description: 'Minimum quality score (0-100) required for this grade.'),
        FieldDef(name: 'market_premium_pct', type: FieldType.real, description: 'Price premium percentage over base price for this grade.'),
      ],
    ),

    // ── 11. season ───────────────────────────────────────────────────────────
    TableSchema(
      tableName: 'season',
      tableDescription: 'Agricultural seasons. Sowing and harvest records reference a season.',
      fields: [
        FieldDef(name: 'season_id', type: FieldType.integer, description: 'Unique season identifier.', isPrimaryKey: true),
        FieldDef(name: 'name', type: FieldType.text, description: 'Season name (e.g. Kharif 2023, Rabi 2023-24).'),
        FieldDef(name: 'year', type: FieldType.integer, description: 'Primary year of the season.'),
        FieldDef(name: 'start_date', type: FieldType.text, description: 'Season start date in YYYY-MM-DD format.'),
        FieldDef(name: 'end_date', type: FieldType.text, description: 'Season end date in YYYY-MM-DD format.'),
        FieldDef(name: 'season_type', type: FieldType.text, description: 'Season type (Kharif, Rabi, Zaid).'),
      ],
    ),

    // ── 12. sowing ───────────────────────────────────────────────────────────
    TableSchema(
      tableName: 'sowing',
      tableDescription: 'Records each sowing event — which farmer sowed which crop variety on which farm in which season.',
      fields: [
        FieldDef(name: 'sowing_id', type: FieldType.integer, description: 'Unique sowing record identifier.', isPrimaryKey: true),
        FieldDef(name: 'farmer_id', type: FieldType.integer, description: 'Farmer who performed the sowing.', foreignKeyRef: 'farmer.farmer_id'),
        FieldDef(name: 'farm_id', type: FieldType.integer, description: 'Farm where sowing took place.', foreignKeyRef: 'farm.farm_id'),
        FieldDef(name: 'crop_id', type: FieldType.integer, description: 'Crop type sown.', foreignKeyRef: 'crop.crop_id'),
        FieldDef(name: 'variety_id', type: FieldType.integer, description: 'Specific variety sown.', foreignKeyRef: 'variety.variety_id'),
        FieldDef(name: 'grade_id', type: FieldType.integer, description: 'Seed grade used for sowing.', foreignKeyRef: 'grade.grade_id'),
        FieldDef(name: 'season_id', type: FieldType.integer, description: 'Season in which sowing occurred.', foreignKeyRef: 'season.season_id'),
        FieldDef(name: 'sow_date', type: FieldType.text, description: 'Date of sowing in YYYY-MM-DD format.'),
        FieldDef(name: 'quantity_kg', type: FieldType.real, description: 'Quantity of seed used in kilograms.'),
        FieldDef(name: 'area_sown_acres', type: FieldType.real, description: 'Area sown in acres.'),
      ],
    ),

    // ── 13. harvest ──────────────────────────────────────────────────────────
    TableSchema(
      tableName: 'harvest',
      tableDescription: 'Records each harvest event — which farmer harvested which crop from which farm.',
      fields: [
        FieldDef(name: 'harvest_id', type: FieldType.integer, description: 'Unique harvest record identifier.', isPrimaryKey: true),
        FieldDef(name: 'farmer_id', type: FieldType.integer, description: 'Farmer who performed the harvest.', foreignKeyRef: 'farmer.farmer_id'),
        FieldDef(name: 'farm_id', type: FieldType.integer, description: 'Farm from which harvest took place.', foreignKeyRef: 'farm.farm_id'),
        FieldDef(name: 'crop_id', type: FieldType.integer, description: 'Crop type harvested.', foreignKeyRef: 'crop.crop_id'),
        FieldDef(name: 'variety_id', type: FieldType.integer, description: 'Specific variety harvested.', foreignKeyRef: 'variety.variety_id'),
        FieldDef(name: 'grade_id', type: FieldType.integer, description: 'Grade of harvested produce.', foreignKeyRef: 'grade.grade_id'),
        FieldDef(name: 'season_id', type: FieldType.integer, description: 'Season in which harvest occurred.', foreignKeyRef: 'season.season_id'),
        FieldDef(name: 'harvest_date', type: FieldType.text, description: 'Date of harvest in YYYY-MM-DD format.'),
        FieldDef(name: 'quantity_kg', type: FieldType.real, description: 'Quantity harvested in kilograms.'),
        FieldDef(name: 'area_harvested_acres', type: FieldType.real, description: 'Area harvested in acres.'),
      ],
    ),

    // ── 14. soil_test ─────────────────────────────────────────────────────────
    TableSchema(
      tableName: 'soil_test',
      tableDescription: 'Soil health test results for farm plots, showing pH and nutrient levels.',
      fields: [
        FieldDef(name: 'soil_test_id', type: FieldType.integer, description: 'Unique soil test identifier.', isPrimaryKey: true),
        FieldDef(name: 'farm_id', type: FieldType.integer, description: 'Farm that was tested.', foreignKeyRef: 'farm.farm_id'),
        FieldDef(name: 'test_date', type: FieldType.text, description: 'Date of soil testing in YYYY-MM-DD format.'),
        FieldDef(name: 'ph_value', type: FieldType.real, description: 'Measured soil pH value.'),
        FieldDef(name: 'nitrogen_ppm', type: FieldType.real, description: 'Nitrogen content in parts per million.'),
        FieldDef(name: 'phosphorus_ppm', type: FieldType.real, description: 'Phosphorus content in parts per million.'),
        FieldDef(name: 'potassium_ppm', type: FieldType.real, description: 'Potassium content in parts per million.'),
        FieldDef(name: 'organic_carbon_pct', type: FieldType.real, description: 'Organic carbon percentage.'),
        FieldDef(name: 'tested_by', type: FieldType.text, description: 'Name of testing agency or laboratory.'),
      ],
    ),

    // ── 15. irrigation ───────────────────────────────────────────────────────
    TableSchema(
      tableName: 'irrigation',
      tableDescription: 'Irrigation events applied to farms during a sowing cycle.',
      fields: [
        FieldDef(name: 'irrigation_id', type: FieldType.integer, description: 'Unique irrigation event identifier.', isPrimaryKey: true),
        FieldDef(name: 'farm_id', type: FieldType.integer, description: 'Farm that was irrigated.', foreignKeyRef: 'farm.farm_id'),
        FieldDef(name: 'sowing_id', type: FieldType.integer, description: 'Sowing record this irrigation supports.', foreignKeyRef: 'sowing.sowing_id'),
        FieldDef(name: 'irrigation_date', type: FieldType.text, description: 'Date of irrigation in YYYY-MM-DD format.'),
        FieldDef(name: 'method', type: FieldType.text, description: 'Irrigation method (Flood, Drip, Sprinkler, Furrow).'),
        FieldDef(name: 'duration_hours', type: FieldType.real, description: 'Duration of irrigation in hours.'),
        FieldDef(name: 'water_used_liters', type: FieldType.real, description: 'Estimated water used in litres.'),
      ],
    ),

    // ── 16. fertilizer ───────────────────────────────────────────────────────
    TableSchema(
      tableName: 'fertilizer',
      tableDescription: 'Master list of fertilizers with their nutrient composition.',
      fields: [
        FieldDef(name: 'fertilizer_id', type: FieldType.integer, description: 'Unique fertilizer identifier.', isPrimaryKey: true),
        FieldDef(name: 'name', type: FieldType.text, description: 'Fertilizer name (e.g. Urea, DAP, MOP, NPK 19-19-19).'),
        FieldDef(name: 'type', type: FieldType.text, description: 'Fertilizer type (Chemical, Organic, Bio-fertilizer).'),
        FieldDef(name: 'nitrogen_pct', type: FieldType.real, description: 'Nitrogen (N) content percentage.'),
        FieldDef(name: 'phosphorus_pct', type: FieldType.real, description: 'Phosphorus (P) content percentage.'),
        FieldDef(name: 'potassium_pct', type: FieldType.real, description: 'Potassium (K) content percentage.'),
        FieldDef(name: 'manufacturer', type: FieldType.text, description: 'Manufacturer or brand name.'),
      ],
    ),

    // ── 17. fertilizer_application ───────────────────────────────────────────
    TableSchema(
      tableName: 'fertilizer_application',
      tableDescription: 'Records fertilizer applications made to a sowing event.',
      fields: [
        FieldDef(name: 'application_id', type: FieldType.integer, description: 'Unique application identifier.', isPrimaryKey: true),
        FieldDef(name: 'sowing_id', type: FieldType.integer, description: 'Sowing this fertilizer was applied to.', foreignKeyRef: 'sowing.sowing_id'),
        FieldDef(name: 'fertilizer_id', type: FieldType.integer, description: 'Fertilizer used.', foreignKeyRef: 'fertilizer.fertilizer_id'),
        FieldDef(name: 'application_date', type: FieldType.text, description: 'Date of application in YYYY-MM-DD format.'),
        FieldDef(name: 'quantity_kg', type: FieldType.real, description: 'Quantity of fertilizer applied in kilograms.'),
        FieldDef(name: 'method', type: FieldType.text, description: 'Application method (Broadcasting, Band Placement, Foliar Spray).'),
        FieldDef(name: 'crop_stage', type: FieldType.text, description: 'Crop growth stage at time of application (Basal, Tillering, Panicle).'),
      ],
    ),

    // ── 18. pesticide ────────────────────────────────────────────────────────
    TableSchema(
      tableName: 'pesticide',
      tableDescription: 'Master list of pesticides, herbicides and fungicides used in farming.',
      fields: [
        FieldDef(name: 'pesticide_id', type: FieldType.integer, description: 'Unique pesticide identifier.', isPrimaryKey: true),
        FieldDef(name: 'name', type: FieldType.text, description: 'Pesticide brand or common name.'),
        FieldDef(name: 'type', type: FieldType.text, description: 'Type (Insecticide, Herbicide, Fungicide, Bactericide).'),
        FieldDef(name: 'active_ingredient', type: FieldType.text, description: 'Active chemical ingredient.'),
        FieldDef(name: 'manufacturer', type: FieldType.text, description: 'Manufacturer name.'),
        FieldDef(name: 'target_pest', type: FieldType.text, description: 'Primary pest or disease it targets.'),
        FieldDef(name: 'waiting_period_days', type: FieldType.integer, description: 'Days to wait after application before harvest.'),
      ],
    ),

    // ── 19. pesticide_application ────────────────────────────────────────────
    TableSchema(
      tableName: 'pesticide_application',
      tableDescription: 'Records pesticide applications made to a sowing event.',
      fields: [
        FieldDef(name: 'application_id', type: FieldType.integer, description: 'Unique application identifier.', isPrimaryKey: true),
        FieldDef(name: 'sowing_id', type: FieldType.integer, description: 'Sowing this pesticide was applied to.', foreignKeyRef: 'sowing.sowing_id'),
        FieldDef(name: 'pesticide_id', type: FieldType.integer, description: 'Pesticide used.', foreignKeyRef: 'pesticide.pesticide_id'),
        FieldDef(name: 'application_date', type: FieldType.text, description: 'Date of application in YYYY-MM-DD format.'),
        FieldDef(name: 'quantity_liters', type: FieldType.real, description: 'Quantity of pesticide solution applied in litres.'),
        FieldDef(name: 'method', type: FieldType.text, description: 'Application method (Spraying, Dusting, Seed Treatment).'),
        FieldDef(name: 'crop_stage', type: FieldType.text, description: 'Crop stage at application (Vegetative, Flowering, Fruiting).'),
      ],
    ),

    // ── 20. weather_log ──────────────────────────────────────────────────────
    TableSchema(
      tableName: 'weather_log',
      tableDescription: 'Daily weather observations recorded per village. Used for climate analysis.',
      fields: [
        FieldDef(name: 'log_id', type: FieldType.integer, description: 'Unique weather log identifier.', isPrimaryKey: true),
        FieldDef(name: 'village_id', type: FieldType.integer, description: 'Village where observation was recorded.', foreignKeyRef: 'village.village_id'),
        FieldDef(name: 'log_date', type: FieldType.text, description: 'Observation date in YYYY-MM-DD format.'),
        FieldDef(name: 'min_temp_c', type: FieldType.real, description: 'Minimum temperature in Celsius.'),
        FieldDef(name: 'max_temp_c', type: FieldType.real, description: 'Maximum temperature in Celsius.'),
        FieldDef(name: 'rainfall_mm', type: FieldType.real, description: 'Rainfall in millimetres.'),
        FieldDef(name: 'humidity_pct', type: FieldType.real, description: 'Relative humidity percentage.'),
        FieldDef(name: 'wind_speed_kmh', type: FieldType.real, description: 'Wind speed in kilometres per hour.'),
      ],
    ),

    // ── 21. equipment ────────────────────────────────────────────────────────
    TableSchema(
      tableName: 'equipment',
      tableDescription: 'Farm machinery and equipment owned by farmers (tractors, harvesters, pumps).',
      fields: [
        FieldDef(name: 'equipment_id', type: FieldType.integer, description: 'Unique equipment identifier.', isPrimaryKey: true),
        FieldDef(name: 'name', type: FieldType.text, description: 'Equipment name (e.g. Tractor, Harvester, Water Pump, Sprayer).'),
        FieldDef(name: 'type', type: FieldType.text, description: 'Equipment category (Tillage, Irrigation, Harvesting, Spraying).'),
        FieldDef(name: 'owner_id', type: FieldType.integer, description: 'Farmer who owns this equipment.', foreignKeyRef: 'farmer.farmer_id'),
        FieldDef(name: 'purchase_date', type: FieldType.text, description: 'Purchase date in YYYY-MM-DD format.'),
        FieldDef(name: 'purchase_cost', type: FieldType.real, description: 'Original purchase cost in rupees.'),
        FieldDef(name: 'current_value', type: FieldType.real, description: 'Current depreciated value in rupees.'),
        FieldDef(name: 'condition', type: FieldType.text, description: 'Current condition (Good, Fair, Poor, Under Repair).'),
      ],
    ),

    // ── 22. labour ───────────────────────────────────────────────────────────
    TableSchema(
      tableName: 'labour',
      tableDescription: 'Agricultural labourers available for farm work. Linked to attendance and equipment usage.',
      fields: [
        FieldDef(name: 'labour_id', type: FieldType.integer, description: 'Unique labour identifier.', isPrimaryKey: true),
        FieldDef(name: 'name', type: FieldType.text, description: 'Full name of the labourer.'),
        FieldDef(name: 'phone', type: FieldType.text, description: 'Contact phone number.'),
        FieldDef(name: 'gender', type: FieldType.text, description: 'Gender (Male/Female/Other).'),
        FieldDef(name: 'village_id', type: FieldType.integer, description: 'Village where labourer resides.', foreignKeyRef: 'village.village_id'),
        FieldDef(name: 'skill_type', type: FieldType.text, description: 'Primary skill (Ploughing, Planting, Harvesting, Spraying, General).'),
        FieldDef(name: 'daily_wage', type: FieldType.real, description: 'Standard daily wage in rupees.'),
        FieldDef(name: 'is_available', type: FieldType.integer, description: '1 if currently available for work, 0 otherwise.'),
      ],
    ),

    // ── 23. equipment_usage ──────────────────────────────────────────────────
    TableSchema(
      tableName: 'equipment_usage',
      tableDescription: 'Log of equipment used on specific farms or sowing events.',
      fields: [
        FieldDef(name: 'usage_id', type: FieldType.integer, description: 'Unique usage record identifier.', isPrimaryKey: true),
        FieldDef(name: 'equipment_id', type: FieldType.integer, description: 'Equipment used.', foreignKeyRef: 'equipment.equipment_id'),
        FieldDef(name: 'farm_id', type: FieldType.integer, description: 'Farm where equipment was used.', foreignKeyRef: 'farm.farm_id'),
        FieldDef(name: 'sowing_id', type: FieldType.integer, description: 'Sowing event this usage was for.', foreignKeyRef: 'sowing.sowing_id'),
        FieldDef(name: 'usage_date', type: FieldType.text, description: 'Date of usage in YYYY-MM-DD format.'),
        FieldDef(name: 'hours_used', type: FieldType.real, description: 'Number of hours the equipment was operated.'),
        FieldDef(name: 'operator_id', type: FieldType.integer, description: 'Labour who operated the equipment.', foreignKeyRef: 'labour.labour_id'),
        FieldDef(name: 'cost', type: FieldType.real, description: 'Total cost of equipment usage in rupees.'),
      ],
    ),

    // ── 24. labour_attendance ────────────────────────────────────────────────
    TableSchema(
      tableName: 'labour_attendance',
      tableDescription: 'Daily attendance records for labourers working on farms.',
      fields: [
        FieldDef(name: 'attendance_id', type: FieldType.integer, description: 'Unique attendance record identifier.', isPrimaryKey: true),
        FieldDef(name: 'labour_id', type: FieldType.integer, description: 'Labourer who worked.', foreignKeyRef: 'labour.labour_id'),
        FieldDef(name: 'farm_id', type: FieldType.integer, description: 'Farm where work was done.', foreignKeyRef: 'farm.farm_id'),
        FieldDef(name: 'sowing_id', type: FieldType.integer, description: 'Sowing event this labour supports.', foreignKeyRef: 'sowing.sowing_id'),
        FieldDef(name: 'work_date', type: FieldType.text, description: 'Date of work in YYYY-MM-DD format.'),
        FieldDef(name: 'hours_worked', type: FieldType.real, description: 'Number of hours worked.'),
        FieldDef(name: 'task_type', type: FieldType.text, description: 'Task performed (Land Prep, Sowing, Weeding, Harvesting, Spraying).'),
        FieldDef(name: 'wage_paid', type: FieldType.real, description: 'Wages paid for this day in rupees.'),
      ],
    ),

    // ── 25. warehouse ────────────────────────────────────────────────────────
    TableSchema(
      tableName: 'warehouse',
      tableDescription: 'Storage facilities where harvested produce is stored before sale.',
      fields: [
        FieldDef(name: 'warehouse_id', type: FieldType.integer, description: 'Unique warehouse identifier.', isPrimaryKey: true),
        FieldDef(name: 'name', type: FieldType.text, description: 'Warehouse name.'),
        FieldDef(name: 'village_id', type: FieldType.integer, description: 'Village where the warehouse is located.', foreignKeyRef: 'village.village_id'),
        FieldDef(name: 'capacity_tonnes', type: FieldType.real, description: 'Storage capacity in metric tonnes.'),
        FieldDef(name: 'owner_type', type: FieldType.text, description: 'Ownership type (Government, Cooperative, Private).'),
        FieldDef(name: 'contact_phone', type: FieldType.text, description: 'Contact phone number for the warehouse.'),
        FieldDef(name: 'is_cold_storage', type: FieldType.integer, description: '1 if cold storage facility, 0 otherwise.'),
      ],
    ),

    // ── 26. stock ────────────────────────────────────────────────────────────
    TableSchema(
      tableName: 'stock',
      tableDescription: 'Inventory of produce stored in warehouses after harvest.',
      fields: [
        FieldDef(name: 'stock_id', type: FieldType.integer, description: 'Unique stock record identifier.', isPrimaryKey: true),
        FieldDef(name: 'warehouse_id', type: FieldType.integer, description: 'Warehouse where produce is stored.', foreignKeyRef: 'warehouse.warehouse_id'),
        FieldDef(name: 'harvest_id', type: FieldType.integer, description: 'Harvest event this stock came from.', foreignKeyRef: 'harvest.harvest_id'),
        FieldDef(name: 'crop_id', type: FieldType.integer, description: 'Crop stored.', foreignKeyRef: 'crop.crop_id'),
        FieldDef(name: 'variety_id', type: FieldType.integer, description: 'Variety stored.', foreignKeyRef: 'variety.variety_id'),
        FieldDef(name: 'quantity_kg', type: FieldType.real, description: 'Quantity in storage in kilograms.'),
        FieldDef(name: 'stored_date', type: FieldType.text, description: 'Date produce was stored in YYYY-MM-DD format.'),
        FieldDef(name: 'expected_dispatch_date', type: FieldType.text, description: 'Expected date of dispatch in YYYY-MM-DD format.'),
        FieldDef(name: 'storage_cost_per_day', type: FieldType.real, description: 'Storage cost per day in rupees.'),
      ],
    ),

    // ── 27. buyer ────────────────────────────────────────────────────────────
    TableSchema(
      tableName: 'buyer',
      tableDescription: 'Buyers who purchase produce from farmers (traders, processors, exporters).',
      fields: [
        FieldDef(name: 'buyer_id', type: FieldType.integer, description: 'Unique buyer identifier.', isPrimaryKey: true),
        FieldDef(name: 'name', type: FieldType.text, description: 'Buyer name or company name.'),
        FieldDef(name: 'type', type: FieldType.text, description: 'Buyer type (Trader, Processor, Exporter, Retailer, FPO).'),
        FieldDef(name: 'phone', type: FieldType.text, description: 'Contact phone number.'),
        FieldDef(name: 'address', type: FieldType.text, description: 'Business address.'),
        FieldDef(name: 'district_id', type: FieldType.integer, description: 'District where buyer operates.', foreignKeyRef: 'district.district_id'),
        FieldDef(name: 'gst_number', type: FieldType.text, description: 'GST registration number.'),
      ],
    ),

    // ── 28. sale ─────────────────────────────────────────────────────────────
    TableSchema(
      tableName: 'sale',
      tableDescription: 'Produce sale transactions between farmers and buyers.',
      fields: [
        FieldDef(name: 'sale_id', type: FieldType.integer, description: 'Unique sale transaction identifier.', isPrimaryKey: true),
        FieldDef(name: 'farmer_id', type: FieldType.integer, description: 'Farmer who sold the produce.', foreignKeyRef: 'farmer.farmer_id'),
        FieldDef(name: 'buyer_id', type: FieldType.integer, description: 'Buyer who purchased the produce.', foreignKeyRef: 'buyer.buyer_id'),
        FieldDef(name: 'crop_id', type: FieldType.integer, description: 'Crop sold.', foreignKeyRef: 'crop.crop_id'),
        FieldDef(name: 'variety_id', type: FieldType.integer, description: 'Variety sold.', foreignKeyRef: 'variety.variety_id'),
        FieldDef(name: 'grade_id', type: FieldType.integer, description: 'Grade of produce sold.', foreignKeyRef: 'grade.grade_id'),
        FieldDef(name: 'sale_date', type: FieldType.text, description: 'Date of sale in YYYY-MM-DD format.'),
        FieldDef(name: 'quantity_kg', type: FieldType.real, description: 'Quantity sold in kilograms.'),
        FieldDef(name: 'price_per_kg', type: FieldType.real, description: 'Sale price per kilogram in rupees.'),
        FieldDef(name: 'total_amount', type: FieldType.real, description: 'Total sale amount in rupees.'),
        FieldDef(name: 'payment_status', type: FieldType.text, description: 'Payment status (Paid, Pending, Partial).'),
      ],
    ),

    // ── 29. market_price ─────────────────────────────────────────────────────
    TableSchema(
      tableName: 'market_price',
      tableDescription: 'Daily mandi market prices for crops by district. Used for price trend analysis.',
      fields: [
        FieldDef(name: 'price_id', type: FieldType.integer, description: 'Unique price record identifier.', isPrimaryKey: true),
        FieldDef(name: 'crop_id', type: FieldType.integer, description: 'Crop for this price record.', foreignKeyRef: 'crop.crop_id'),
        FieldDef(name: 'variety_id', type: FieldType.integer, description: 'Variety for this price record.', foreignKeyRef: 'variety.variety_id'),
        FieldDef(name: 'grade_id', type: FieldType.integer, description: 'Grade for this price record.', foreignKeyRef: 'grade.grade_id'),
        FieldDef(name: 'district_id', type: FieldType.integer, description: 'District mandi where price was recorded.', foreignKeyRef: 'district.district_id'),
        FieldDef(name: 'price_date', type: FieldType.text, description: 'Date of price record in YYYY-MM-DD format.'),
        FieldDef(name: 'min_price', type: FieldType.real, description: 'Minimum price per kg in rupees.'),
        FieldDef(name: 'max_price', type: FieldType.real, description: 'Maximum price per kg in rupees.'),
        FieldDef(name: 'modal_price', type: FieldType.real, description: 'Modal (most common) price per kg in rupees.'),
      ],
    ),

    // ── 30. bank_account ─────────────────────────────────────────────────────
    TableSchema(
      tableName: 'bank_account',
      tableDescription: 'Bank account details of farmers for subsidy and loan disbursements.',
      fields: [
        FieldDef(name: 'account_id', type: FieldType.integer, description: 'Unique account identifier.', isPrimaryKey: true),
        FieldDef(name: 'farmer_id', type: FieldType.integer, description: 'Farmer who owns this account.', foreignKeyRef: 'farmer.farmer_id'),
        FieldDef(name: 'bank_name', type: FieldType.text, description: 'Name of the bank.'),
        FieldDef(name: 'branch', type: FieldType.text, description: 'Branch name.'),
        FieldDef(name: 'account_number', type: FieldType.text, description: 'Account number.'),
        FieldDef(name: 'ifsc_code', type: FieldType.text, description: 'IFSC code of the bank branch.'),
        FieldDef(name: 'account_type', type: FieldType.text, description: 'Account type (Savings, Current, KCC).'),
      ],
    ),

    // ── 31. loan ─────────────────────────────────────────────────────────────
    TableSchema(
      tableName: 'loan',
      tableDescription: 'Agricultural loans taken by farmers from banks or cooperatives.',
      fields: [
        FieldDef(name: 'loan_id', type: FieldType.integer, description: 'Unique loan identifier.', isPrimaryKey: true),
        FieldDef(name: 'farmer_id', type: FieldType.integer, description: 'Farmer who took the loan.', foreignKeyRef: 'farmer.farmer_id'),
        FieldDef(name: 'bank_account_id', type: FieldType.integer, description: 'Bank account through which loan was disbursed.', foreignKeyRef: 'bank_account.account_id'),
        FieldDef(name: 'loan_type', type: FieldType.text, description: 'Type of loan (KCC, Term Loan, Gold Loan, Cooperative Loan).'),
        FieldDef(name: 'sanctioned_amount', type: FieldType.real, description: 'Amount sanctioned in rupees.'),
        FieldDef(name: 'disbursed_amount', type: FieldType.real, description: 'Amount actually disbursed in rupees.'),
        FieldDef(name: 'interest_rate_pct', type: FieldType.real, description: 'Annual interest rate percentage.'),
        FieldDef(name: 'disbursement_date', type: FieldType.text, description: 'Date of disbursement in YYYY-MM-DD format.'),
        FieldDef(name: 'due_date', type: FieldType.text, description: 'Loan repayment due date in YYYY-MM-DD format.'),
        FieldDef(name: 'status', type: FieldType.text, description: 'Loan status (Active, Repaid, Overdue, NPA).'),
      ],
    ),

    // ── 32. insurance ────────────────────────────────────────────────────────
    TableSchema(
      tableName: 'insurance',
      tableDescription: 'Crop insurance policies taken by farmers to cover harvest losses.',
      fields: [
        FieldDef(name: 'insurance_id', type: FieldType.integer, description: 'Unique insurance record identifier.', isPrimaryKey: true),
        FieldDef(name: 'farmer_id', type: FieldType.integer, description: 'Farmer who took the insurance.', foreignKeyRef: 'farmer.farmer_id'),
        FieldDef(name: 'sowing_id', type: FieldType.integer, description: 'Sowing event covered by this insurance.', foreignKeyRef: 'sowing.sowing_id'),
        FieldDef(name: 'scheme_name', type: FieldType.text, description: 'Insurance scheme name (e.g. PMFBY, WBCIS).'),
        FieldDef(name: 'policy_number', type: FieldType.text, description: 'Insurance policy number.'),
        FieldDef(name: 'sum_insured', type: FieldType.real, description: 'Total insured amount in rupees.'),
        FieldDef(name: 'premium_paid', type: FieldType.real, description: 'Premium paid by farmer in rupees.'),
        FieldDef(name: 'start_date', type: FieldType.text, description: 'Policy start date in YYYY-MM-DD format.'),
        FieldDef(name: 'end_date', type: FieldType.text, description: 'Policy end date in YYYY-MM-DD format.'),
        FieldDef(name: 'claim_status', type: FieldType.text, description: 'Claim status (None, Filed, Approved, Rejected, Paid).'),
      ],
    ),

    // ── 33. crop_disease ─────────────────────────────────────────────────────
    TableSchema(
      tableName: 'crop_disease',
      tableDescription: 'Known diseases and pest infestations that affect specific crops.',
      fields: [
        FieldDef(name: 'disease_id', type: FieldType.integer, description: 'Unique disease identifier.', isPrimaryKey: true),
        FieldDef(name: 'name', type: FieldType.text, description: 'Disease or pest name (e.g. Blast, Blight, Brown Planthopper).'),
        FieldDef(name: 'crop_id', type: FieldType.integer, description: 'Crop this disease affects.', foreignKeyRef: 'crop.crop_id'),
        FieldDef(name: 'type', type: FieldType.text, description: 'Disease type (Fungal, Bacterial, Viral, Pest, Weed).'),
        FieldDef(name: 'symptoms', type: FieldType.text, description: 'Visible symptoms of the disease.'),
        FieldDef(name: 'recommended_pesticide_id', type: FieldType.integer, description: 'Recommended pesticide to treat this disease.', foreignKeyRef: 'pesticide.pesticide_id'),
        FieldDef(name: 'severity_level', type: FieldType.text, description: 'Typical severity (Low, Medium, High, Critical).'),
      ],
    ),

    // ── 34. disease_report ───────────────────────────────────────────────────
    TableSchema(
      tableName: 'disease_report',
      tableDescription: 'Reports of crop disease or pest incidence filed for specific farms.',
      fields: [
        FieldDef(name: 'report_id', type: FieldType.integer, description: 'Unique disease report identifier.', isPrimaryKey: true),
        FieldDef(name: 'farm_id', type: FieldType.integer, description: 'Farm where disease was observed.', foreignKeyRef: 'farm.farm_id'),
        FieldDef(name: 'sowing_id', type: FieldType.integer, description: 'Sowing event affected.', foreignKeyRef: 'sowing.sowing_id'),
        FieldDef(name: 'disease_id', type: FieldType.integer, description: 'Disease or pest identified.', foreignKeyRef: 'crop_disease.disease_id'),
        FieldDef(name: 'report_date', type: FieldType.text, description: 'Date of report in YYYY-MM-DD format.'),
        FieldDef(name: 'affected_area_acres', type: FieldType.real, description: 'Area affected in acres.'),
        FieldDef(name: 'loss_estimated_pct', type: FieldType.real, description: 'Estimated yield loss percentage.'),
        FieldDef(name: 'action_taken', type: FieldType.text, description: 'Control measures taken.'),
      ],
    ),

    // ── 35. advisory ─────────────────────────────────────────────────────────
    TableSchema(
      tableName: 'advisory',
      tableDescription: 'Agricultural advisories and recommendations sent to farmers.',
      fields: [
        FieldDef(name: 'advisory_id', type: FieldType.integer, description: 'Unique advisory identifier.', isPrimaryKey: true),
        FieldDef(name: 'farmer_id', type: FieldType.integer, description: 'Farmer this advisory is for.', foreignKeyRef: 'farmer.farmer_id'),
        FieldDef(name: 'crop_id', type: FieldType.integer, description: 'Crop the advisory relates to.', foreignKeyRef: 'crop.crop_id'),
        FieldDef(name: 'issued_date', type: FieldType.text, description: 'Date advisory was issued in YYYY-MM-DD format.'),
        FieldDef(name: 'advisory_type', type: FieldType.text, description: 'Advisory type (Pest Alert, Weather, Fertilizer, Market Price, General).'),
        FieldDef(name: 'message', type: FieldType.text, description: 'Advisory message text.'),
        FieldDef(name: 'issued_by', type: FieldType.text, description: 'Source agency or officer who issued the advisory.'),
        FieldDef(name: 'is_read', type: FieldType.integer, description: '1 if farmer has read the advisory, 0 if unread.'),
      ],
    ),

    // ── 36. input_supplier ───────────────────────────────────────────────────
    TableSchema(
      tableName: 'input_supplier',
      tableDescription: 'Suppliers of agricultural inputs like seeds, fertilizers, and pesticides.',
      fields: [
        FieldDef(name: 'supplier_id', type: FieldType.integer, description: 'Unique supplier identifier.', isPrimaryKey: true),
        FieldDef(name: 'name', type: FieldType.text, description: 'Supplier or shop name.'),
        FieldDef(name: 'type', type: FieldType.text, description: 'Supplier type (Seed, Fertilizer, Pesticide, Multi-input).'),
        FieldDef(name: 'phone', type: FieldType.text, description: 'Contact phone number.'),
        FieldDef(name: 'district_id', type: FieldType.integer, description: 'District where supplier operates.', foreignKeyRef: 'district.district_id'),
        FieldDef(name: 'license_number', type: FieldType.text, description: 'Government license number.'),
        FieldDef(name: 'is_active', type: FieldType.integer, description: '1 if supplier is currently active, 0 otherwise.'),
      ],
    ),

    // ── 37. input_purchase ───────────────────────────────────────────────────
    TableSchema(
      tableName: 'input_purchase',
      tableDescription: 'Records of farmers purchasing agricultural inputs from suppliers.',
      fields: [
        FieldDef(name: 'purchase_id', type: FieldType.integer, description: 'Unique purchase record identifier.', isPrimaryKey: true),
        FieldDef(name: 'farmer_id', type: FieldType.integer, description: 'Farmer who made the purchase.', foreignKeyRef: 'farmer.farmer_id'),
        FieldDef(name: 'supplier_id', type: FieldType.integer, description: 'Supplier from whom purchase was made.', foreignKeyRef: 'input_supplier.supplier_id'),
        FieldDef(name: 'item_type', type: FieldType.text, description: 'Type of input purchased (Seed, Fertilizer, Pesticide, Tool).'),
        FieldDef(name: 'item_name', type: FieldType.text, description: 'Specific name of the item purchased.'),
        FieldDef(name: 'quantity', type: FieldType.real, description: 'Quantity purchased.'),
        FieldDef(name: 'unit', type: FieldType.text, description: 'Unit of quantity (kg, litre, bag, piece).'),
        FieldDef(name: 'unit_price', type: FieldType.real, description: 'Price per unit in rupees.'),
        FieldDef(name: 'total_amount', type: FieldType.real, description: 'Total purchase amount in rupees.'),
        FieldDef(name: 'purchase_date', type: FieldType.text, description: 'Date of purchase in YYYY-MM-DD format.'),
      ],
    ),

    // ── 38. payment ──────────────────────────────────────────────────────────
    TableSchema(
      tableName: 'payment',
      tableDescription: 'Payment transactions made to or from farmers (wages, sale proceeds, loan repayments).',
      fields: [
        FieldDef(name: 'payment_id', type: FieldType.integer, description: 'Unique payment identifier.', isPrimaryKey: true),
        FieldDef(name: 'farmer_id', type: FieldType.integer, description: 'Farmer involved in this payment.', foreignKeyRef: 'farmer.farmer_id'),
        FieldDef(name: 'payment_type', type: FieldType.text, description: 'Payment type (Sale Proceed, Subsidy, Loan, Labour Wage, Input Purchase).'),
        FieldDef(name: 'reference_id', type: FieldType.integer, description: 'ID of the related record (sale_id, loan_id, etc.).'),
        FieldDef(name: 'reference_type', type: FieldType.text, description: 'Type of reference (sale, loan, subsidy, labour_attendance).'),
        FieldDef(name: 'amount', type: FieldType.real, description: 'Payment amount in rupees.'),
        FieldDef(name: 'payment_date', type: FieldType.text, description: 'Date of payment in YYYY-MM-DD format.'),
        FieldDef(name: 'mode', type: FieldType.text, description: 'Payment mode (Cash, Bank Transfer, UPI, Cheque).'),
        FieldDef(name: 'transaction_id', type: FieldType.text, description: 'Bank or UPI transaction reference ID.'),
        FieldDef(name: 'status', type: FieldType.text, description: 'Payment status (Completed, Pending, Failed).'),
      ],
    ),

    // ── 39. government_scheme ────────────────────────────────────────────────
    TableSchema(
      tableName: 'government_scheme',
      tableDescription: 'Central and state government schemes for agricultural support.',
      fields: [
        FieldDef(name: 'scheme_id', type: FieldType.integer, description: 'Unique scheme identifier.', isPrimaryKey: true),
        FieldDef(name: 'name', type: FieldType.text, description: 'Scheme name (e.g. PM-KISAN, PMFBY, Soil Health Card).'),
        FieldDef(name: 'type', type: FieldType.text, description: 'Scheme type (Subsidy, Insurance, Credit, Training, Infrastructure).'),
        FieldDef(name: 'state_id', type: FieldType.integer, description: 'State this scheme applies to (null for central schemes).', foreignKeyRef: 'state.state_id'),
        FieldDef(name: 'start_date', type: FieldType.text, description: 'Scheme start date in YYYY-MM-DD format.'),
        FieldDef(name: 'end_date', type: FieldType.text, description: 'Scheme end date in YYYY-MM-DD format.'),
        FieldDef(name: 'budget_crore', type: FieldType.real, description: 'Scheme budget in crore rupees.'),
        FieldDef(name: 'eligibility_criteria', type: FieldType.text, description: 'Eligibility criteria description.'),
        FieldDef(name: 'is_active', type: FieldType.integer, description: '1 if scheme is currently active, 0 otherwise.'),
      ],
    ),

    // ── 40. scheme_enrollment ────────────────────────────────────────────────
    TableSchema(
      tableName: 'scheme_enrollment',
      tableDescription: 'Farmer enrollments in government schemes.',
      fields: [
        FieldDef(name: 'enrollment_id', type: FieldType.integer, description: 'Unique enrollment identifier.', isPrimaryKey: true),
        FieldDef(name: 'scheme_id', type: FieldType.integer, description: 'Government scheme enrolled in.', foreignKeyRef: 'government_scheme.scheme_id'),
        FieldDef(name: 'farmer_id', type: FieldType.integer, description: 'Farmer enrolled.', foreignKeyRef: 'farmer.farmer_id'),
        FieldDef(name: 'enrollment_date', type: FieldType.text, description: 'Date of enrollment in YYYY-MM-DD format.'),
        FieldDef(name: 'status', type: FieldType.text, description: 'Enrollment status (Active, Completed, Cancelled).'),
        FieldDef(name: 'benefit_received', type: FieldType.real, description: 'Total benefit received in rupees.'),
      ],
    ),

    // ── 41. subsidy ──────────────────────────────────────────────────────────
    TableSchema(
      tableName: 'subsidy',
      tableDescription: 'Subsidy applications and disbursements to farmers under government schemes.',
      fields: [
        FieldDef(name: 'subsidy_id', type: FieldType.integer, description: 'Unique subsidy record identifier.', isPrimaryKey: true),
        FieldDef(name: 'scheme_id', type: FieldType.integer, description: 'Government scheme providing the subsidy.', foreignKeyRef: 'government_scheme.scheme_id'),
        FieldDef(name: 'farmer_id', type: FieldType.integer, description: 'Farmer receiving the subsidy.', foreignKeyRef: 'farmer.farmer_id'),
        FieldDef(name: 'crop_id', type: FieldType.integer, description: 'Crop for which subsidy is given.', foreignKeyRef: 'crop.crop_id'),
        FieldDef(name: 'application_date', type: FieldType.text, description: 'Date of subsidy application in YYYY-MM-DD format.'),
        FieldDef(name: 'approved_amount', type: FieldType.real, description: 'Approved subsidy amount in rupees.'),
        FieldDef(name: 'disbursed_amount', type: FieldType.real, description: 'Amount actually disbursed in rupees.'),
        FieldDef(name: 'status', type: FieldType.text, description: 'Status (Applied, Approved, Disbursed, Rejected).'),
        FieldDef(name: 'disbursement_date', type: FieldType.text, description: 'Date of disbursement in YYYY-MM-DD format.'),
      ],
    ),

    // ── 42. inspection ───────────────────────────────────────────────────────
    TableSchema(
      tableName: 'inspection',
      tableDescription: 'Official field inspections of farms by agricultural officers.',
      fields: [
        FieldDef(name: 'inspection_id', type: FieldType.integer, description: 'Unique inspection identifier.', isPrimaryKey: true),
        FieldDef(name: 'farm_id', type: FieldType.integer, description: 'Farm that was inspected.', foreignKeyRef: 'farm.farm_id'),
        FieldDef(name: 'inspector_name', type: FieldType.text, description: 'Name of the inspecting officer.'),
        FieldDef(name: 'inspection_date', type: FieldType.text, description: 'Date of inspection in YYYY-MM-DD format.'),
        FieldDef(name: 'inspection_type', type: FieldType.text, description: 'Type of inspection (Crop Health, Soil, Organic, Insurance, Scheme).'),
        FieldDef(name: 'findings', type: FieldType.text, description: 'Summary of inspection findings.'),
        FieldDef(name: 'rating', type: FieldType.text, description: 'Farm rating given (Excellent, Good, Average, Poor).'),
        FieldDef(name: 'next_inspection_date', type: FieldType.text, description: 'Scheduled next inspection date in YYYY-MM-DD format.'),
      ],
    ),

    // ── 43. certification ────────────────────────────────────────────────────
    TableSchema(
      tableName: 'certification',
      tableDescription: 'Certifications obtained by farmers (Organic, GAP, ISO).',
      fields: [
        FieldDef(name: 'certification_id', type: FieldType.integer, description: 'Unique certification identifier.', isPrimaryKey: true),
        FieldDef(name: 'farmer_id', type: FieldType.integer, description: 'Farmer who holds this certification.', foreignKeyRef: 'farmer.farmer_id'),
        FieldDef(name: 'certification_type', type: FieldType.text, description: 'Type (Organic, GAP, GlobalG.A.P, FSSAI, ISO 22000).'),
        FieldDef(name: 'issuing_body', type: FieldType.text, description: 'Organization that issued the certification.'),
        FieldDef(name: 'issue_date', type: FieldType.text, description: 'Date of issue in YYYY-MM-DD format.'),
        FieldDef(name: 'expiry_date', type: FieldType.text, description: 'Expiry date in YYYY-MM-DD format.'),
        FieldDef(name: 'certificate_number', type: FieldType.text, description: 'Certificate reference number.'),
        FieldDef(name: 'status', type: FieldType.text, description: 'Certificate status (Active, Expired, Suspended).'),
      ],
    ),

    // ── 44. transport ────────────────────────────────────────────────────────
    TableSchema(
      tableName: 'transport',
      tableDescription: 'Transport vehicles used for delivering produce from farms to markets or warehouses.',
      fields: [
        FieldDef(name: 'transport_id', type: FieldType.integer, description: 'Unique transport vehicle identifier.', isPrimaryKey: true),
        FieldDef(name: 'vehicle_number', type: FieldType.text, description: 'Vehicle registration number.'),
        FieldDef(name: 'vehicle_type', type: FieldType.text, description: 'Vehicle type (Tractor-Trolley, Mini Truck, Lorry, Auto).'),
        FieldDef(name: 'driver_name', type: FieldType.text, description: 'Driver full name.'),
        FieldDef(name: 'driver_phone', type: FieldType.text, description: 'Driver contact phone number.'),
        FieldDef(name: 'capacity_tonnes', type: FieldType.real, description: 'Maximum load capacity in metric tonnes.'),
        FieldDef(name: 'owner_name', type: FieldType.text, description: 'Vehicle owner name.'),
      ],
    ),

    // ── 45. delivery ─────────────────────────────────────────────────────────
    TableSchema(
      tableName: 'delivery',
      tableDescription: 'Delivery records for produce shipped from farms to buyers or warehouses.',
      fields: [
        FieldDef(name: 'delivery_id', type: FieldType.integer, description: 'Unique delivery identifier.', isPrimaryKey: true),
        FieldDef(name: 'sale_id', type: FieldType.integer, description: 'Sale transaction this delivery fulfils.', foreignKeyRef: 'sale.sale_id'),
        FieldDef(name: 'transport_id', type: FieldType.integer, description: 'Transport vehicle used.', foreignKeyRef: 'transport.transport_id'),
        FieldDef(name: 'dispatch_date', type: FieldType.text, description: 'Date of dispatch in YYYY-MM-DD format.'),
        FieldDef(name: 'delivery_date', type: FieldType.text, description: 'Date of delivery in YYYY-MM-DD format.'),
        FieldDef(name: 'from_location', type: FieldType.text, description: 'Dispatch location (farm or warehouse name).'),
        FieldDef(name: 'to_location', type: FieldType.text, description: 'Delivery destination (market or buyer address).'),
        FieldDef(name: 'quantity_kg', type: FieldType.real, description: 'Quantity delivered in kilograms.'),
        FieldDef(name: 'freight_cost', type: FieldType.real, description: 'Freight cost in rupees.'),
        FieldDef(name: 'status', type: FieldType.text, description: 'Delivery status (Dispatched, In Transit, Delivered, Returned).'),
      ],
    ),

    // ── 46. cooperative ──────────────────────────────────────────────────────
    TableSchema(
      tableName: 'cooperative',
      tableDescription: 'Farmer Producer Organisations (FPOs) and cooperatives operating in villages.',
      fields: [
        FieldDef(name: 'cooperative_id', type: FieldType.integer, description: 'Unique cooperative identifier.', isPrimaryKey: true),
        FieldDef(name: 'name', type: FieldType.text, description: 'Cooperative or FPO name.'),
        FieldDef(name: 'registration_number', type: FieldType.text, description: 'Government registration number.'),
        FieldDef(name: 'village_id', type: FieldType.integer, description: 'Village where cooperative is based.', foreignKeyRef: 'village.village_id'),
        FieldDef(name: 'president_name', type: FieldType.text, description: 'Name of the cooperative president.'),
        FieldDef(name: 'contact_phone', type: FieldType.text, description: 'Cooperative contact phone number.'),
        FieldDef(name: 'established_date', type: FieldType.text, description: 'Date established in YYYY-MM-DD format.'),
        FieldDef(name: 'total_members', type: FieldType.integer, description: 'Total number of member farmers.'),
      ],
    ),

    // ── 47. cooperative_member ───────────────────────────────────────────────
    TableSchema(
      tableName: 'cooperative_member',
      tableDescription: 'Farmers who are members of cooperatives or FPOs.',
      fields: [
        FieldDef(name: 'member_id', type: FieldType.integer, description: 'Unique membership identifier.', isPrimaryKey: true),
        FieldDef(name: 'cooperative_id', type: FieldType.integer, description: 'Cooperative the farmer belongs to.', foreignKeyRef: 'cooperative.cooperative_id'),
        FieldDef(name: 'farmer_id', type: FieldType.integer, description: 'Member farmer.', foreignKeyRef: 'farmer.farmer_id'),
        FieldDef(name: 'join_date', type: FieldType.text, description: 'Date of joining in YYYY-MM-DD format.'),
        FieldDef(name: 'share_amount', type: FieldType.real, description: 'Share capital contributed in rupees.'),
        FieldDef(name: 'role', type: FieldType.text, description: 'Role in cooperative (Member, Secretary, Treasurer, President).'),
        FieldDef(name: 'is_active', type: FieldType.integer, description: '1 if active member, 0 otherwise.'),
      ],
    ),

    // ── 48. training ─────────────────────────────────────────────────────────
    TableSchema(
      tableName: 'training',
      tableDescription: 'Agricultural training programmes and workshops organised for farmers.',
      fields: [
        FieldDef(name: 'training_id', type: FieldType.integer, description: 'Unique training identifier.', isPrimaryKey: true),
        FieldDef(name: 'title', type: FieldType.text, description: 'Training programme title.'),
        FieldDef(name: 'topic', type: FieldType.text, description: 'Training topic (Organic Farming, Drip Irrigation, Pest Management, SRI).'),
        FieldDef(name: 'conducted_by', type: FieldType.text, description: 'Organisation or department conducting the training.'),
        FieldDef(name: 'venue', type: FieldType.text, description: 'Training venue name and location.'),
        FieldDef(name: 'training_date', type: FieldType.text, description: 'Date of training in YYYY-MM-DD format.'),
        FieldDef(name: 'duration_hours', type: FieldType.real, description: 'Training duration in hours.'),
        FieldDef(name: 'district_id', type: FieldType.integer, description: 'District where training was held.', foreignKeyRef: 'district.district_id'),
      ],
    ),

    // ── 49. training_attendance ──────────────────────────────────────────────
    TableSchema(
      tableName: 'training_attendance',
      tableDescription: 'Attendance records of farmers at training programmes.',
      fields: [
        FieldDef(name: 'attendance_id', type: FieldType.integer, description: 'Unique attendance record identifier.', isPrimaryKey: true),
        FieldDef(name: 'training_id', type: FieldType.integer, description: 'Training programme attended.', foreignKeyRef: 'training.training_id'),
        FieldDef(name: 'farmer_id', type: FieldType.integer, description: 'Farmer who attended.', foreignKeyRef: 'farmer.farmer_id'),
        FieldDef(name: 'attended', type: FieldType.integer, description: '1 if farmer attended, 0 if absent.'),
        FieldDef(name: 'certificate_issued', type: FieldType.integer, description: '1 if participation certificate was issued, 0 otherwise.'),
      ],
    ),

    // ── 50. feedback ─────────────────────────────────────────────────────────
    TableSchema(
      tableName: 'feedback',
      tableDescription: 'Farmer feedback and ratings on services, advisories, training and schemes.',
      fields: [
        FieldDef(name: 'feedback_id', type: FieldType.integer, description: 'Unique feedback identifier.', isPrimaryKey: true),
        FieldDef(name: 'farmer_id', type: FieldType.integer, description: 'Farmer who submitted the feedback.', foreignKeyRef: 'farmer.farmer_id'),
        FieldDef(name: 'feedback_type', type: FieldType.text, description: 'Type of feedback (Training, Advisory, Scheme, Sale, Cooperative).'),
        FieldDef(name: 'reference_id', type: FieldType.integer, description: 'ID of the record being rated.'),
        FieldDef(name: 'rating', type: FieldType.integer, description: 'Rating given 1-5 (1=Poor, 5=Excellent).'),
        FieldDef(name: 'comments', type: FieldType.text, description: 'Detailed comments from the farmer.'),
        FieldDef(name: 'submitted_date', type: FieldType.text, description: 'Date of feedback submission in YYYY-MM-DD format.'),
      ],
    ),

  ],
);
