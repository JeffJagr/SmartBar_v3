class Note {
  const Note({
    required this.id,
    required this.timestamp,
    required this.authorId,
    required this.authorName,
    required this.content,
    required this.tag,
    this.linkedProductId,
    this.isDone = false,
    this.doneBy,
    this.doneAt,
    this.priority, // optional priority/color/emoji marker
  });

  final String id;
  final DateTime timestamp;
  final String authorId;
  final String authorName;
  final String content;
  final String tag;
  final String? linkedProductId;
  final bool isDone;
  final String? doneBy;
  final DateTime? doneAt;
  final String? priority;

  Note copyWith({
    String? id,
    DateTime? timestamp,
    String? authorId,
    String? authorName,
    String? content,
    String? tag,
    String? linkedProductId,
    bool? isDone,
    String? doneBy,
    DateTime? doneAt,
    String? priority,
  }) {
    return Note(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      content: content ?? this.content,
      tag: tag ?? this.tag,
      linkedProductId: linkedProductId ?? this.linkedProductId,
      isDone: isDone ?? this.isDone,
      doneBy: doneBy ?? this.doneBy,
      doneAt: doneAt ?? this.doneAt,
      priority: priority ?? this.priority,
    );
  }
}
