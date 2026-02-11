enum Gender { male, female }

enum ActivityLevel { sedentary, light, moderate, active, veryActive }

enum HealthGoal { loseWeight, maintain, gainMuscle }

class UserProfile {
  int age;
  double weight; // in kg
  double height; // in cm
  Gender gender;
  ActivityLevel activityLevel;
  HealthGoal goal;

  UserProfile({
    required this.age,
    required this.weight,
    required this.height,
    required this.gender,
    required this.activityLevel,
    required this.goal,
  });
}
