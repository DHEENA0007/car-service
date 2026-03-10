import 'service_center_model.dart';

class ScanModel {
  final int id;
  final String? image;
  final String? description;
  final String? detectedIssue;
  final String? problemExplanation;
  final String? possibleCauses;
  final String urgencyLevel;
  final double confidenceScore;
  final String? recommendedServiceType;
  final bool isAnalyzed;
  final String createdAt;
  final List<ServiceCenterModel> serviceCenters;

  const ScanModel({
    required this.id,
    this.image,
    this.description,
    this.detectedIssue,
    this.problemExplanation,
    this.possibleCauses,
    required this.urgencyLevel,
    required this.confidenceScore,
    this.recommendedServiceType,
    required this.isAnalyzed,
    required this.createdAt,
    required this.serviceCenters,
  });

  String get dateString => createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt;

  factory ScanModel.fromMap(Map<String, dynamic> map) {
    final centers = (map['service_centers'] as List? ?? [])
        .map((c) => ServiceCenterModel.fromMap(c as Map<String, dynamic>))
        .toList();

    return ScanModel(
      id: map['id'] ?? 0,
      image: map['image'],
      description: map['description'],
      detectedIssue: map['detected_issue'],
      problemExplanation: map['problem_explanation'],
      possibleCauses: map['possible_causes'],
      urgencyLevel: map['urgency_level'] ?? 'medium',
      confidenceScore: (map['confidence_score'] ?? 0).toDouble(),
      recommendedServiceType: map['recommended_service_type'],
      isAnalyzed: map['is_analyzed'] ?? false,
      createdAt: map['created_at']?.toString() ?? '',
      serviceCenters: centers,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'image': image,
        'description': description,
        'detected_issue': detectedIssue,
        'problem_explanation': problemExplanation,
        'possible_causes': possibleCauses,
        'urgency_level': urgencyLevel,
        'confidence_score': confidenceScore,
        'recommended_service_type': recommendedServiceType,
        'is_analyzed': isAnalyzed,
        'created_at': createdAt,
        'service_centers': serviceCenters.map((c) => c.toMap()).toList(),
      };
}
