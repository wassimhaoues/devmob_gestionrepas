enum RecipeCategory {
  breakfast('breakfast'),
  lunch('lunch'),
  dinner('dinner'),
  dessert('dessert');

  const RecipeCategory(this.value);

  final String value;

  static RecipeCategory fromValue(String value) {
    return RecipeCategory.values.firstWhere(
      (category) => category.value == value,
      orElse: () => RecipeCategory.breakfast,
    );
  }
}
