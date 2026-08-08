class Photo {
  final String id;
  final String imageData;

  Photo({required this.id, required this.imageData});

  factory Photo.fromJson(Map<String, dynamic> json) {
    return Photo(id: json['id'] as String, imageData: json['imageData'] as String? ?? '');
  }
}
