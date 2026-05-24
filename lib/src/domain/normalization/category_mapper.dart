class CategoryMapper {
  const CategoryMapper();

  static const aliases = <String, String>{
    'DG': 'Vegetables and legumes',
    'GA': 'Nuts and seeds',
    'FA': 'Fruit',
    'H': 'Herbs and spices',
    '1穀類': 'Grains',
    '2いも及びでん粉類': 'Tubers and starches',
    '3砂糖及び甘味類': 'Sugars and sweeteners',
    '4豆類': 'Legumes',
    '5種実類': 'Nuts and seeds',
    '6野菜類': 'Vegetables',
    '7果実類': 'Fruits',
    '8きのこ類': 'Mushrooms',
    '9藻類': 'Seaweeds',
    '10魚介類': 'Seafood',
    '11肉類': 'Meat',
    '12卵類': 'Eggs',
    '13乳類': 'Dairy',
    '14油脂類': 'Fats and oils',
    '15菓子類': 'Confectionery',
    '16し好飲料類': 'Beverages',
    '17調味料及び香辛料類': 'Seasonings and spices',
    '18調理済み流通食品類': 'Prepared foods',
  };

  String map(String cleanedCategory) {
    return aliases[cleanedCategory] ?? cleanedCategory;
  }
}
