import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../config/app_limits.dart';
import '../data/announcement_fields.dart';
import '../data/collections.dart';
import '../data/upload_content_types.dart';
import '../utils/poster_image_check.dart';
import '../utils/social_link.dart';

/// Where announcement posters are kept: Firebase Storage in the app, a fake
/// in tests. [delete] throws a FirebaseException with code
/// 'object-not-found' when there is no such file.
abstract class PosterStore {
  /// Stores the poster with its real content type and returns its download URL.
  Future<String> upload(String path, Uint8List bytes, PosterImageType type);
  Future<void> delete(String path);
}

/// [PosterStore] on Firebase Storage (storage.rules: announcement_posters/).
class FirebasePosterStore implements PosterStore {
  Reference _ref(String path) => FirebaseStorage.instance.ref().child(path);

  @override
  Future<String> upload(String path, Uint8List bytes, PosterImageType type) async {
    final ref = _ref(path);
    await ref.putData(bytes, UploadContentTypes.poster(type));
    return ref.getDownloadURL();
  }

  @override
  Future<void> delete(String path) => _ref(path).delete();
}

/// One public_announcements document as read (docs/design/announcements_v2.md
/// section 2). A document from before AN1 has no kind or audience: it reads
/// as text for everyone.
class Announcement {
  Announcement.fromMap(this.id, Map<String, dynamic> data)
      : kind = AnnouncementKind.fromStored(data[AnnouncementFields.kind]),
        title = _string(data[AnnouncementFields.title]),
        message = _string(data[AnnouncementFields.message]),
        audience = AnnouncementAudience.fromStored(data[AnnouncementFields.audience]),
        imageUrl = data[AnnouncementFields.imageUrl] as String?,
        imagePath = data[AnnouncementFields.imagePath] as String?,
        imageWidth = (data[AnnouncementFields.imageWidth] as num?)?.toInt(),
        imageHeight = (data[AnnouncementFields.imageHeight] as num?)?.toInt(),
        linkUrl = _string(data[AnnouncementFields.linkUrl]),
        linkLabel = _string(data[AnnouncementFields.linkLabel]),
        urgent = data[AnnouncementFields.urgent] == true,
        hidden = data[AnnouncementFields.hidden] == true;

  static String _string(Object? value) => value is String ? value : '';

  final String id;
  final AnnouncementKind kind;
  final String title;
  final String message;
  final AnnouncementAudience audience;
  final String? imageUrl;
  final String? imagePath;
  final int? imageWidth;
  final int? imageHeight;
  final String linkUrl;
  final String linkLabel;
  final bool urgent;
  final bool hidden;
}

/// What the Platform Admin's form holds. [image] is a newly picked poster;
/// when editing a poster without one, its saved image is kept.
class AnnouncementDraft {
  AnnouncementDraft({
    required this.kind,
    required this.title,
    required this.message,
    this.audience = AnnouncementAudience.all,
    this.linkUrl = '',
    this.linkLabel = '',
    this.urgent = false,
    this.image,
  });

  /// The form opened on a saved announcement.
  AnnouncementDraft.from(Announcement a)
      : kind = a.kind,
        title = a.title,
        message = a.message,
        audience = a.audience,
        linkUrl = a.linkUrl,
        linkLabel = a.linkLabel,
        urgent = a.urgent;

  AnnouncementKind kind;
  String title;
  String message;
  AnnouncementAudience audience;
  String linkUrl;
  String linkLabel;
  bool urgent;
  PosterImage? image;
}

/// The form's problems, one per field; all null when it may be saved.
class AnnouncementErrors {
  const AnnouncementErrors({this.title, this.message, this.image, this.link, this.linkLabel});

  final String? title;
  final String? message;
  final String? image;
  final String? link;
  final String? linkLabel;

  bool get isEmpty => [title, message, image, link, linkLabel].every((e) => e == null);
}

/// Saves and deletes announcements and their posters, in the order that
/// never leaves a document pointing at a missing file (design section 5).
/// The sentences are English: the operator console is (spec 2.8).
class AnnouncementService {
  AnnouncementService({FirebaseFirestore? firestore, PosterStore? store, DateTime Function()? now, this.beforeDocumentWrite})
      : _firestore = firestore,
        _store = store ?? FirebasePosterStore(),
        _now = now ?? DateTime.now;

  final FirebaseFirestore? _firestore;
  final PosterStore _store;
  final DateTime Function() _now;

  /// Tests: runs just before the document is written, to make that write fail.
  final Future<void> Function()? beforeDocumentWrite;

  static final titleLength =
      'Enter a title of ${AppLimits.announcementTitleMin} to ${AppLimits.announcementTitleMax} characters.';
  static final messageLength =
      'Enter a message of ${AppLimits.announcementMessageMin} to ${AppLimits.announcementMessageMax} characters.';
  static final captionLength = 'Keep the message to ${AppLimits.posterMessageMax} characters or fewer.';
  static const imageMissing = 'Choose a poster image.';
  static const linkInvalid = 'Enter a full web address, like https://example.com/page';
  static final labelLength =
      'Enter a button label of ${AppLimits.announcementLinkLabelMin} to ${AppLimits.announcementLinkLabelMax} characters.';
  static const labelWithoutLink = 'Add the link for this button, or clear its label.';

  CollectionReference<Map<String, dynamic>> get _collection =>
      (_firestore ?? FirebaseFirestore.instance).collection(Collections.publicAnnouncements);

  /// The poster's file: a new name for every upload, so a day-long cache
  /// never shows an old image and cleanup never deletes the wrong file.
  static String posterPath(String docId, int millis, PosterImageType type) =>
      '${AnnouncementFields.posterFolder}/$docId-$millis.${type.extension}';

  static bool _lengthOk(String value, int min, int max) => value.length >= min && value.length <= max;

  /// Checks [draft]. A title or message unchanged from [previous] is not
  /// checked, so an old announcement longer than today's limits still saves.
  static AnnouncementErrors validate(AnnouncementDraft draft, {Announcement? previous}) {
    final title = draft.title.trim();
    final message = draft.message.trim();
    final isPoster = draft.kind == AnnouncementKind.poster;
    final titleKept = previous != null && title == previous.title.trim();
    final messageKept = previous != null && message == previous.message.trim();

    String? messageError;
    if (!messageKept) {
      if (isPoster && message.length > AppLimits.posterMessageMax) messageError = captionLength;
      if (!isPoster && !_lengthOk(message, AppLimits.announcementMessageMin, AppLimits.announcementMessageMax)) {
        messageError = messageLength;
      }
    }

    final link = SocialLink.sanitize(draft.linkUrl);
    final label = draft.linkLabel.trim();
    String? linkError;
    String? labelError;
    if (link == null) {
      linkError = linkInvalid;
    } else if (link.isEmpty && label.isNotEmpty) {
      linkError = labelWithoutLink;
    } else if (link.isNotEmpty &&
        !_lengthOk(label, AppLimits.announcementLinkLabelMin, AppLimits.announcementLinkLabelMax)) {
      labelError = labelLength;
    }

    final hasImage = draft.image != null || (previous?.kind == AnnouncementKind.poster && previous?.imagePath != null);
    return AnnouncementErrors(
      title: titleKept || _lengthOk(title, AppLimits.announcementTitleMin, AppLimits.announcementTitleMax) ? null : titleLength,
      message: messageError,
      image: isPoster && !hasImage ? imageMissing : null,
      link: linkError,
      linkLabel: labelError,
    );
  }

  /// Saves [draft] as a new announcement, or over [existing]. A new poster is
  /// uploaded FIRST; if that fails nothing is written, and if the document
  /// write then fails the new file is deleted. An old file is deleted only
  /// after the document no longer points at it. Returns false when that old
  /// file could not be removed (the save itself succeeded).
  Future<bool> save(AnnouncementDraft draft, {Announcement? existing}) async {
    if (!validate(draft, previous: existing).isEmpty) throw ArgumentError('The announcement is not valid.');
    final doc = existing == null ? _collection.doc() : _collection.doc(existing.id);
    final isPoster = draft.kind == AnnouncementKind.poster;
    final message = draft.message.trim();
    final link = SocialLink.sanitize(draft.linkUrl)!;
    final remove = existing == null ? null : FieldValue.delete();

    final image = isPoster ? draft.image : null;
    String? newPath;
    final data = <String, dynamic>{
      AnnouncementFields.kind: draft.kind.key,
      AnnouncementFields.title: draft.title.trim(),
      AnnouncementFields.audience: draft.audience.key,
      AnnouncementFields.urgent: draft.urgent,
      if (message.isNotEmpty) AnnouncementFields.message: message else if (remove != null) AnnouncementFields.message: remove,
      if (link.isNotEmpty) ...{
        AnnouncementFields.linkUrl: link,
        AnnouncementFields.linkLabel: draft.linkLabel.trim(),
      } else if (remove != null) ...{
        AnnouncementFields.linkUrl: remove,
        AnnouncementFields.linkLabel: remove,
      },
      if (!isPoster && remove != null) ...{
        AnnouncementFields.imageUrl: remove,
        AnnouncementFields.imagePath: remove,
        AnnouncementFields.imageWidth: remove,
        AnnouncementFields.imageHeight: remove,
      },
      if (existing == null) ...{
        AnnouncementFields.hidden: false,
        // The readers sort by timestamp, and orderBy leaves out a document
        // without it (an early version wrote createdAt and never showed).
        AnnouncementFields.timestamp: FieldValue.serverTimestamp(),
      },
    };

    if (image != null) {
      newPath = posterPath(doc.id, _now().millisecondsSinceEpoch, image.type);
      final url = await _store.upload(newPath, image.bytes, image.type);
      data.addAll({
        AnnouncementFields.imageUrl: url,
        AnnouncementFields.imagePath: newPath,
        AnnouncementFields.imageWidth: image.width,
        AnnouncementFields.imageHeight: image.height,
      });
    }

    try {
      await beforeDocumentWrite?.call();
      // hidden and timestamp are untouched on edit: showing or hiding is a
      // separate action, and the order of the list stays as published.
      existing == null ? await doc.set(data) : await doc.update(data);
    } catch (_) {
      if (newPath != null) await _deleteFile(newPath);
      rethrow;
    }

    final oldPath = existing?.imagePath;
    final oldReplaced = oldPath != null && (newPath != null || !isPoster) && oldPath != newPath;
    return oldReplaced ? _deleteFile(oldPath) : true;
  }

  /// Deletes the document, then its poster: a file left behind is harmless,
  /// a document pointing at a deleted file is not. Returns false when the
  /// file could not be removed.
  Future<bool> delete(Announcement announcement) async {
    await _collection.doc(announcement.id).delete();
    final path = announcement.imagePath;
    return path == null ? true : _deleteFile(path);
  }

  /// True when the file is gone, including when it was never there.
  Future<bool> _deleteFile(String path) async {
    try {
      await _store.delete(path);
      return true;
    } on FirebaseException catch (e) {
      return e.code == 'object-not-found';
    } catch (_) {
      return false;
    }
  }
}
