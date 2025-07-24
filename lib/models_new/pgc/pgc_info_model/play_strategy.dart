class PlayStrategy {
  List? strategies;

  PlayStrategy({this.strategies});

  factory PlayStrategy.fromJson(Map<String, dynamic> json) => PlayStrategy(
    strategies: json['strategies'],
  );
}
