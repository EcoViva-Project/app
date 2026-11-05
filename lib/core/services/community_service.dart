import 'package:flutter/foundation.dart';

import 'api_client.dart';

class CommunityComment {
  CommunityComment({
    required this.id,
    required this.authorName,
    required this.authorInitials,
    required this.content,
    required this.timeLabel,
  });

  final String id;
  final String authorName;
  final String authorInitials;
  final String content;
  final String timeLabel;

  factory CommunityComment.fromApi(Map<String, dynamic> json) {
    return CommunityComment(
      id: json['id'].toString(),
      authorName: json['authorName'] as String? ?? 'Vizinho',
      authorInitials: json['authorInitials'] as String? ?? '??',
      content: json['content'] as String? ?? '',
      timeLabel: json['timeLabel'] as String? ?? '',
    );
  }
}

class CommunityPost {
  CommunityPost({
    required this.id,
    required this.authorName,
    required this.authorInitials,
    required this.content,
    required this.likes,
    required this.likedByMe,
    required this.timeLabel,
    required this.comments,
  });

  final String id;
  final String authorName;
  final String authorInitials;
  final String content;
  final int likes;
  final bool likedByMe;
  final String timeLabel;
  final List<CommunityComment> comments;

  factory CommunityPost.fromApi(Map<String, dynamic> json) {
    return CommunityPost(
      id: json['id'].toString(),
      authorName: json['authorName'] as String? ?? 'Vizinho',
      authorInitials: json['authorInitials'] as String? ?? '??',
      content: json['content'] as String? ?? '',
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      likedByMe: json['likedByMe'] as bool? ?? false,
      timeLabel: json['timeLabel'] as String? ?? '',
      comments:
          ((json['comments'] as List?) ?? const [])
              .map(
                (item) =>
                    CommunityComment.fromApi(item as Map<String, dynamic>),
              )
              .toList(),
    );
  }
}

class CommunityService extends ChangeNotifier {
  CommunityService._();

  static final CommunityService instance = CommunityService._();

  final List<CommunityPost> _posts = [];

  List<CommunityPost> get posts => List.unmodifiable(_posts);

  Future<void> load() async {
    final data = await ApiClient.instance.get('/community/posts');
    _posts
      ..clear()
      ..addAll(
        ((data['posts'] as List?) ?? const []).map(
          (item) => CommunityPost.fromApi(item as Map<String, dynamic>),
        ),
      );
    notifyListeners();
  }

  Future<CommunityPost> createPost(String content) async {
    final data = await ApiClient.instance.post('/community/posts', {
      'content': content,
    });
    final post = CommunityPost.fromApi(data['post'] as Map<String, dynamic>);
    _posts.insert(0, post);
    notifyListeners();
    return post;
  }

  Future<void> toggleLike(String id) async {
    final data = await ApiClient.instance.post('/community/posts/$id/like');
    final index = _posts.indexWhere((post) => post.id == id);
    if (index < 0) return;
    final current = _posts[index];
    _posts[index] = CommunityPost(
      id: current.id,
      authorName: current.authorName,
      authorInitials: current.authorInitials,
      content: current.content,
      likes: (data['likes'] as num?)?.toInt() ?? current.likes,
      likedByMe: data['likedByMe'] as bool? ?? current.likedByMe,
      timeLabel: current.timeLabel,
      comments: current.comments,
    );
    notifyListeners();
  }

  Future<CommunityComment?> addComment(String postId, String content) async {
    final data = await ApiClient.instance.post(
      '/community/posts/$postId/comments',
      {'content': content},
    );
    final comment = CommunityComment.fromApi(
      data['comment'] as Map<String, dynamic>,
    );
    final index = _posts.indexWhere((post) => post.id == postId);
    if (index >= 0) {
      final current = _posts[index];
      _posts[index] = CommunityPost(
        id: current.id,
        authorName: current.authorName,
        authorInitials: current.authorInitials,
        content: current.content,
        likes: current.likes,
        likedByMe: current.likedByMe,
        timeLabel: current.timeLabel,
        comments: [...current.comments, comment],
      );
      notifyListeners();
    }
    return comment;
  }

  void reset() {
    _posts.clear();
    notifyListeners();
  }
}
