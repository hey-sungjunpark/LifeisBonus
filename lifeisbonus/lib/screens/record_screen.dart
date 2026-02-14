import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:xml/xml.dart';

final Map<String, List<String>> _globalDistrictCache = {};
final Map<String, List<String>> _globalDongCache = {};
List<Map<String, dynamic>>? _globalRegionRows;
Future<List<Map<String, dynamic>>>? _globalRegionRowsFuture;

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  int _tabIndex = 0;
  final List<_SchoolRecord> _schools = [];
  final List<_NeighborhoodRecord> _neighborhoods = [];
  final List<_MemoryRecord> _memories = [];
  final Map<String, bool> _memorySectionExpanded = {};
  int? _memoryYearFilter;
  final List<_MediaItem> _mediaItems = [];
  final ImagePicker _picker = ImagePicker();
  bool _loadingSchools = false;
  String? _schoolLoadError;
  bool _loadingNeighborhoods = false;
  String? _neighborhoodLoadError;
  bool _loadingMemories = false;
  String? _memoryLoadError;
  bool _loadingMedia = false;
  String? _mediaLoadError;
  bool _didDebugFirestore = false;

  @override
  void initState() {
    super.initState();
    _loadSchools();
    _loadNeighborhoods();
    _loadMemories();
    _loadMedia();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        children: [
          const Text(
            '나의 기록',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFFFF7A3D),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '지나온 소중한 순간들을 기록해보세요',
            style: TextStyle(fontSize: 12, color: Color(0xFF9B9B9B)),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                _RecordTab(
                  label: '학교',
                  active: _tabIndex == 0,
                  onTap: () => _setTab(0),
                ),
                _RecordTab(
                  label: '동네',
                  active: _tabIndex == 1,
                  onTap: () => _setTab(1),
                ),
                _RecordTab(
                  label: '추억',
                  active: _tabIndex == 2,
                  onTap: () => _setTab(2),
                ),
                _RecordTab(
                  label: '사진',
                  active: _tabIndex == 3,
                  onTap: () => _setTab(3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_tabIndex == 0) ...[
            _SchoolHeader(
              onAdd: _openAddSchool,
            ),
            const SizedBox(height: 12),
            if (_loadingSchools)
              const _EmptyHint(
                icon: Icons.hourglass_bottom_rounded,
                title: '학교 기록을 불러오는 중이에요',
                subtitle: '잠시만 기다려주세요',
              )
            else if (_schoolLoadError != null)
              _EmptyHint(
                icon: Icons.error_outline_rounded,
                title: '학교 기록을 불러오지 못했어요',
                subtitle: _schoolLoadError!,
              )
            else if (_schools.isEmpty)
              const _EmptyHint(
                icon: Icons.school_rounded,
                title: '아직 추가한 학교가 없어요',
                subtitle: '다닌 학교를 추가해보세요',
              )
            else
              ..._schools
                  .map(
                    (record) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SchoolCard(
                        record: record,
                        onEdit: () => _openEditSchool(record),
                        onDelete: () => _deleteSchool(record),
                      ),
                    ),
                  )
                  .toList(),
          ] else if (_tabIndex == 1) ...[
            _NeighborhoodHeader(onAdd: _openAddNeighborhood),
            const SizedBox(height: 12),
            if (_loadingNeighborhoods)
              const _EmptyHint(
                icon: Icons.hourglass_bottom_rounded,
                title: '동네 기록을 불러오는 중이에요',
                subtitle: '잠시만 기다려주세요',
              )
            else if (_neighborhoodLoadError != null)
              _EmptyHint(
                icon: Icons.error_outline_rounded,
                title: '동네 기록을 불러오지 못했어요',
                subtitle: _neighborhoodLoadError!,
              )
            else if (_neighborhoods.isEmpty)
              const _EmptyHint(
                icon: Icons.home_rounded,
                title: '아직 추가한 동네가 없어요',
                subtitle: '살았던 동네를 기록해보세요',
              )
            else
              ..._neighborhoods
                  .map(
                    (record) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _NeighborhoodCard(
                        record: record,
                        onEdit: () => _openEditNeighborhood(record),
                        onDelete: () => _deleteNeighborhood(record),
                      ),
                    ),
                  )
                  .toList(),
          ] else if (_tabIndex == 2) ...[
            _MemoryHeader(onAdd: _openAddMemory),
            const SizedBox(height: 10),
            _MemoryYearFilter(
              years: _memoryYears,
              selectedYear: _memoryYearFilter,
              onSelected: (value) {
                setState(() {
                  _memoryYearFilter = value;
                });
              },
            ),
            const SizedBox(height: 12),
            if (_loadingMemories)
              const _EmptyHint(
                icon: Icons.hourglass_bottom_rounded,
                title: '추억 일기를 불러오는 중이에요',
                subtitle: '잠시만 기다려주세요',
              )
            else if (_memoryLoadError != null)
              _EmptyHint(
                icon: Icons.error_outline_rounded,
                title: '추억 일기를 불러오지 못했어요',
                subtitle: _memoryLoadError!,
              )
            else if (_memories.isEmpty)
              const _EmptyHint(
                icon: Icons.event_note_rounded,
                title: '아직 작성한 추억이 없어요',
                subtitle: '소중한 순간을 기록해보세요',
              )
            else
              ..._buildMemorySections(),
          ] else
            _buildOtherTabs(),
        ],
      ),
    );
  }

  void _setTab(int index) {
    setState(() {
      _tabIndex = index;
    });
  }

  Widget _buildOtherTabs() {
    if (_tabIndex == 3) {
      return _PhotoTab(
        items: _mediaItems,
        onUploadTap: _openMediaPicker,
        onFileSelectTap: _openMediaPicker,
        loading: _loadingMedia,
        error: _mediaLoadError,
        onDeleteTap: _deleteMediaItem,
      );
    }
    return const _EmptyHint(
      icon: Icons.hourglass_empty_rounded,
      title: '준비 중인 탭입니다',
      subtitle: '곧 새로운 기록 기능을 제공할게요',
    );
  }

  Future<void> _openAddSchool() async {
    final record = await showModalBottomSheet<_SchoolRecord>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => _AddSchoolSheet(onSave: _saveSchoolFromSheet),
    );
    if (record == null) {
      return;
    }
    _showSnack('학교가 저장되었습니다.');
  }

  Future<void> _openAddNeighborhood() async {
    final record = await showModalBottomSheet<_NeighborhoodRecord>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => const _AddNeighborhoodSheet(),
    );
    if (record == null) {
      return;
    }
    final saved = await _persistNeighborhood(record);
    if (saved == null) {
      return;
    }
    setState(() {
      _neighborhoods.add(saved);
      _sortNeighborhoods();
    });
    _showSnack('동네가 저장되었습니다.');
  }

  Future<void> _openAddMemory() async {
    final record = await showModalBottomSheet<_MemoryRecord>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => const _AddMemorySheet(),
    );
    if (record == null) {
      return;
    }
    final saved = await _persistMemory(record);
    if (saved == null) {
      return;
    }
    setState(() {
      _memories.add(saved);
      _sortMemories();
    });
    _showSnack('추억이 저장되었습니다.');
  }

  Future<void> _openEditMemory(_MemoryRecord record) async {
    final updated = await showModalBottomSheet<_MemoryRecord>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => _AddMemorySheet(initialRecord: record),
    );
    if (updated == null) {
      return;
    }
    final saved = await _persistMemory(updated);
    if (saved == null) {
      return;
    }
    setState(() {
      final index = _memories.indexWhere((item) => item.id == saved.id);
      if (index >= 0) {
        _memories[index] = saved;
      }
      _sortMemories();
    });
    _showSnack('추억이 수정되었습니다.');
  }

  Future<void> _deleteMemory(_MemoryRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('삭제할까요?'),
        content: Text('${record.title} 기록을 삭제합니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    final userDocId = await _resolveUserDocId();
    if (userDocId == null) {
      _showSnack('로그인 정보가 없어 삭제할 수 없어요.');
      return;
    }
    if (record.id.isEmpty) {
      _showSnack('저장되지 않은 항목이라 삭제할 수 없어요.');
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userDocId)
          .collection('memories')
          .doc(record.id)
          .delete();
      if (!mounted) {
        return;
      }
      setState(() {
        _memories.removeWhere((item) => item.id == record.id);
      });
      _showSnack('삭제되었습니다.');
    } catch (e) {
      _showSnack('삭제에 실패했어요. (${e.toString().replaceAll('Exception: ', '')})');
    }
  }

  Future<void> _openEditNeighborhood(_NeighborhoodRecord record) async {
    final updated = await showModalBottomSheet<_NeighborhoodRecord>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => _AddNeighborhoodSheet(initialRecord: record),
    );
    if (updated == null) {
      return;
    }
    final saved = await _persistNeighborhood(updated);
    if (saved == null) {
      return;
    }
    setState(() {
      final index =
          _neighborhoods.indexWhere((item) => item.id == saved.id);
      if (index >= 0) {
        _neighborhoods[index] = saved;
      }
      _sortNeighborhoods();
    });
    _showSnack('동네 정보가 수정되었습니다.');
  }

  Future<void> _deleteNeighborhood(_NeighborhoodRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('삭제할까요?'),
        content: Text('${record.title} 기록을 삭제합니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    final userDocId = await _resolveUserDocId();
    if (userDocId == null) {
      _showSnack('로그인 정보가 없어 삭제할 수 없어요.');
      return;
    }
    if (record.id.isEmpty) {
      _showSnack('저장되지 않은 항목이라 삭제할 수 없어요.');
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userDocId)
          .collection('neighborhoods')
          .doc(record.id)
          .delete();
      if (!mounted) {
        return;
      }
      setState(() {
        _neighborhoods.removeWhere((item) => item.id == record.id);
      });
      _showSnack('삭제되었습니다.');
    } catch (e) {
      _showSnack('삭제에 실패했어요. (${e.toString().replaceAll('Exception: ', '')})');
    }
  }

  Future<void> _openMediaPicker() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('사진 선택'),
                onTap: () => Navigator.of(context).pop('photo'),
              ),
              ListTile(
                leading: const Icon(Icons.videocam_rounded),
                title: const Text('동영상 선택'),
                onTap: () => Navigator.of(context).pop('video'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (action == 'photo') {
      final images = await _picker.pickMultiImage();
      if (images.isEmpty) {
        final single = await _picker.pickImage(source: ImageSource.gallery);
        if (single == null) {
          return;
        }
        await _addAndUploadMedia(single, isVideo: false);
        return;
      }
      for (final file in images) {
        await _addAndUploadMedia(file, isVideo: false);
      }
    } else if (action == 'video') {
      final video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video == null) {
        return;
      }
      await _addAndUploadMedia(video, isVideo: true);
    }
  }

  Future<void> _addAndUploadMedia(XFile file, {required bool isVideo}) async {
    final localItem = _MediaItem.local(file: file, isVideo: isVideo);
    setState(() {
      _mediaItems.insert(0, localItem);
    });
    await _uploadMedia(localItem);
  }

  Future<void> _loadMedia() async {
    setState(() {
      _loadingMedia = true;
      _mediaLoadError = null;
    });
    try {
      final userDocId = await _resolveUserDocId();
      if (userDocId == null) {
        setState(() {
          _mediaItems.clear();
          _mediaLoadError = '로그인 정보가 없어 미디어를 불러올 수 없어요.';
        });
        return;
      }
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userDocId)
          .collection('media')
          .orderBy('createdAt', descending: true)
          .get();
      final items = snapshot.docs
          .map((doc) => _MediaItem.fromFirestore(doc.id, doc.data()))
          .whereType<_MediaItem>()
          .toList();
      if (!mounted) {
        return;
      }
      setState(() {
        _mediaItems
          ..clear()
          ..addAll(items);
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _mediaLoadError =
            '미디어를 불러오지 못했어요. (${e.toString().replaceAll('Exception: ', '')})';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingMedia = false;
        });
      }
    }
  }

  Future<void> _uploadMedia(_MediaItem item) async {
    final userDocId = await _resolveUserDocId();
    if (userDocId == null) {
      _showSnack('로그인 정보가 없어 업로드할 수 없어요.');
      return;
    }
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userDocId)
        .collection('media')
        .doc();
    final mediaId = docRef.id;
    final extension = _fileExtension(item.file?.path ?? '') ?? (item.isVideo ? 'mp4' : 'jpg');
    final storagePath = 'users/$userDocId/media/$mediaId.$extension';
    final storageRef = FirebaseStorage.instance.ref(storagePath);

    Uint8List? thumbBytes;
    if (item.isVideo && item.file != null && !kIsWeb) {
      thumbBytes = await VideoThumbnail.thumbnailData(
        video: item.file!.path,
        imageFormat: ImageFormat.JPEG,
        quality: 70,
        maxWidth: 360,
      );
    }
    String? thumbPath;
    if (thumbBytes != null) {
      thumbPath = 'users/$userDocId/media/$mediaId-thumb.jpg';
    }

    try {
      await docRef.set({
        'isVideo': item.isVideo,
        'storagePath': storagePath,
        'thumbnailPath': thumbPath,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'uploading',
      });

      final uploadTask = storageRef.putFile(
        File(item.file!.path),
        SettableMetadata(
          contentType: item.isVideo ? 'video/mp4' : 'image/jpeg',
        ),
      );

      uploadTask.snapshotEvents.listen((snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        setState(() {
          item
            ..uploadProgress = progress
            ..uploading = snapshot.state == TaskState.running;
        });
      });

      await uploadTask;
      final url = await storageRef.getDownloadURL();

      String? thumbUrl;
      if (thumbBytes != null && thumbPath != null) {
        final thumbRef = FirebaseStorage.instance.ref(thumbPath);
        await thumbRef.putData(
          thumbBytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        thumbUrl = await thumbRef.getDownloadURL();
      }

      await docRef.update({
        'url': url,
        'thumbnailUrl': thumbUrl,
        'status': 'ready',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        item
          ..id = mediaId
          ..url = url
          ..thumbnailUrl = thumbUrl
          ..uploading = false
          ..uploadProgress = 1.0
          ..storagePath = storagePath
          ..thumbnailPath = thumbPath;
      });
    } catch (e) {
      setState(() {
        item
          ..uploading = false
          ..uploadFailed = true;
      });
      _showSnack('업로드에 실패했어요. (${e.toString().replaceAll('Exception: ', '')})');
    }
  }

  Future<void> _deleteMediaItem(_MediaItem item) async {
    final userDocId = await _resolveUserDocId();
    if (userDocId == null) {
      _showSnack('로그인 정보가 없어 삭제할 수 없어요.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('삭제할까요?'),
        content: const Text('선택한 미디어를 삭제합니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      if (item.storagePath != null) {
        await FirebaseStorage.instance.ref(item.storagePath!).delete();
      }
      if (item.thumbnailPath != null) {
        await FirebaseStorage.instance.ref(item.thumbnailPath!).delete();
      }
      if (item.id != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userDocId)
            .collection('media')
            .doc(item.id)
            .delete();
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _mediaItems.remove(item);
      });
      _showSnack('삭제되었습니다.');
    } catch (e) {
      _showSnack('삭제에 실패했어요. (${e.toString().replaceAll('Exception: ', '')})');
    }
  }

  Future<void> _openEditSchool(_SchoolRecord record) async {
    final updated = await showModalBottomSheet<_SchoolRecord>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => _AddSchoolSheet(
        initialRecord: record,
        onSave: _saveSchoolFromSheet,
      ),
    );
    if (updated == null) {
      return;
    }
    _showSnack('학교 정보가 수정되었습니다.');
  }

  Future<_SchoolRecord?> _saveSchoolFromSheet(_SchoolRecord record) async {
    final isNew = record.id.isEmpty;
    String? tempId;
    if (isNew) {
      tempId = 'local-${DateTime.now().microsecondsSinceEpoch}';
      final tempRecord = record.copyWith(id: tempId);
      setState(() {
        _schools.add(tempRecord);
        _sortSchools();
      });
    }
    final savedRecord = await _persistSchool(record);
    if (!mounted) {
      return null;
    }
    if (savedRecord == null) {
      if (tempId != null) {
        setState(() {
          _schools.removeWhere((item) => item.id == tempId);
        });
      }
      return null;
    }
    setState(() {
      if (tempId != null) {
        _schools.removeWhere((item) => item.id == tempId);
        _schools.add(savedRecord);
      } else {
        final index = _schools.indexWhere((item) => item.id == savedRecord.id);
        if (index >= 0) {
          _schools[index] = savedRecord;
        }
      }
      _sortSchools();
    });
    return savedRecord;
  }

  Future<void> _deleteSchool(_SchoolRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('삭제할까요?'),
        content: Text('${record.name} 기록을 삭제합니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    final userDocId = await _resolveUserDocId();
    if (userDocId == null) {
      _showSnack('로그인 정보가 없어 삭제할 수 없어요.');
      return;
    }
    if (record.id.isEmpty) {
      _showSnack('저장되지 않은 항목이라 삭제할 수 없어요.');
      return;
    }
    final removedIndex = _schools.indexWhere((item) => item.id == record.id);
    _SchoolRecord? removedRecord;
    if (removedIndex >= 0) {
      removedRecord = _schools[removedIndex];
      setState(() {
        _schools.removeAt(removedIndex);
        _sortSchools();
      });
    }
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userDocId)
          .collection('schools')
          .doc(record.id)
          .delete();
      if (!mounted) {
        return;
      }
      if (removedRecord == null) {
        setState(() {
          _schools.removeWhere((item) => item.id == record.id);
          _sortSchools();
        });
      }
      await _loadSchools();
      _showSnack('학교 기록이 삭제되었습니다.');
    } catch (e) {
      if (mounted && removedRecord != null) {
        setState(() {
          _schools.insert(
            removedIndex.clamp(0, _schools.length),
            removedRecord!,
          );
          _sortSchools();
        });
      }
      _showSnack('삭제에 실패했어요. (${e.toString().replaceAll('Exception: ', '')})');
    }
  }

  Future<void> _loadSchools() async {
    setState(() {
      _loadingSchools = true;
      _schoolLoadError = null;
    });
    try {
      final userDocId = await _resolveUserDocId();
      if (userDocId == null) {
        setState(() {
          _schools.clear();
          _schoolLoadError = '로그인 정보가 없어 학교 기록을 불러올 수 없어요.';
        });
        return;
      }
      if (!_didDebugFirestore) {
        _didDebugFirestore = true;
        await _debugFirestore(userDocId);
      }
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userDocId)
          .collection('schools')
          .orderBy('createdAt', descending: true)
          .get()
          .timeout(const Duration(seconds: 8));
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final matchKeys = data['matchKeys'];
        final record = _SchoolRecord.fromFirestore(doc.id, data);
        if (record == null) {
          continue;
        }
        final schoolKey = _buildSchoolKey(record);
        final computedKeys = _buildSchoolMatchKeys(record, schoolKey);
        final existingKeys = matchKeys is List
            ? matchKeys.map((key) => key.toString()).toSet()
            : <String>{};
        final computedSet = computedKeys.toSet();
        final needsUpdate =
            (computedSet.isNotEmpty && existingKeys.isEmpty) ||
            (computedSet.isNotEmpty &&
                existingKeys.isNotEmpty &&
                (existingKeys.length != computedSet.length ||
                    !existingKeys.containsAll(computedSet))) ||
            (data['schoolKey'] != null && data['schoolKey'] != schoolKey);
        if (needsUpdate || (data['schoolKey'] == null && schoolKey.isNotEmpty)) {
          await doc.reference.set({
            'schoolKey': schoolKey,
            'matchKeys': computedKeys,
            'ownerId': userDocId,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }
      final records = snapshot.docs
          .map((doc) => _SchoolRecord.fromFirestore(doc.id, doc.data()))
          .whereType<_SchoolRecord>()
          .toList();
      if (!mounted) {
        return;
      }
      setState(() {
        _schools
          ..clear()
          ..addAll(records);
        _sortSchools();
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _schoolLoadError = '학교 기록을 불러오지 못했어요. (${e.toString().replaceAll('Exception: ', '')})';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingSchools = false;
        });
      }
    }
  }

  Future<void> _debugFirestore(String userDocId) async {}

  Future<_SchoolRecord?> _persistSchool(_SchoolRecord record) async {
    try {
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser != null) {
        try {
          await authUser.getIdToken();
        } catch (_) {}
      }
      try {
        await FirebaseFirestore.instance.enableNetwork();
      } catch (_) {}
      final userDocId = await _resolveUserDocId();
      if (userDocId == null) {
        _showSnack('로그인 정보가 없어 저장할 수 없어요.');
        return null;
      }
      final schoolKey = _buildSchoolKey(record);
      // Skip local duplicate checks: use Firestore as the source of truth.
      if (schoolKey.isNotEmpty) {
        final dupSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userDocId)
            .collection('schools')
            .where('schoolKey', isEqualTo: schoolKey)
            .limit(1)
            .get();
        if (dupSnapshot.docs.isNotEmpty) {
          final dupId = dupSnapshot.docs.first.id;
          if (dupId != record.id) {
            await _showDuplicateDialog();
            return null;
          }
        }
      }
      final matchKeys = _buildSchoolMatchKeys(record, schoolKey);
      final data = {
        'level': record.level.key,
        'name': record.name,
        'province': record.province,
        'district': record.district,
        'dong': record.dong,
        'schoolCode': record.schoolCode,
        'campusType': record.campusType,
        'grade': record.grade,
        'classNumber': record.classNumber,
        'year': record.year,
        'gradeEntries': record.gradeEntries
            ?.map((entry) => entry.toFirestore())
            .toList(),
        'kindergartenGradYear': record.kindergartenGradYear,
        'universityEntryYear': record.universityEntryYear,
        'major': record.major,
        'schoolKey': schoolKey,
        'matchKeys': matchKeys,
        'ownerId': userDocId,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (record.id.isEmpty) {
        final docRef = await FirebaseFirestore.instance
            .collection('users')
            .doc(userDocId)
            .collection('schools')
            .add({
          ...data,
          'createdAt': FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 8));
        return record.copyWith(id: docRef.id);
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userDocId)
          .collection('schools')
          .doc(record.id)
          .set(data, SetOptions(merge: true))
          .timeout(const Duration(seconds: 8));
      return record;
    } on TimeoutException catch (e) {
      _showSnack('저장 요청이 시간 초과되었습니다. 네트워크/권한을 확인해주세요.');
      return null;
    } on FirebaseException catch (e) {
      _showSnack('저장에 실패했어요. (${e.code})');
      return null;
    } catch (e) {
      _showSnack('학교 저장에 실패했어요. (${e.toString().replaceAll('Exception: ', '')})');
      return null;
    }
  }

  Future<void> _loadNeighborhoods() async {
    setState(() {
      _loadingNeighborhoods = true;
      _neighborhoodLoadError = null;
    });
    try {
      final userDocId = await _resolveUserDocId();
      if (userDocId == null) {
        setState(() {
          _neighborhoods.clear();
          _neighborhoodLoadError = '로그인 정보가 없어 동네 기록을 불러올 수 없어요.';
        });
        return;
      }
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userDocId)
          .collection('neighborhoods')
          .orderBy('startYear', descending: false)
          .get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final record = _NeighborhoodRecord.fromFirestore(doc.id, data);
        if (record == null) {
          continue;
        }
        final matchKey = _buildNeighborhoodMatchKey(record);
        final existingKey = data['matchKey'] as String?;
        final needsUpdate =
            existingKey == null ||
            existingKey.isEmpty ||
            (existingKey != matchKey && matchKey.isNotEmpty);
        if (needsUpdate || data['ownerId'] == null) {
          await doc.reference.set({
            'matchKey': matchKey,
            'ownerId': userDocId,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }
      final records = snapshot.docs
          .map((doc) => _NeighborhoodRecord.fromFirestore(doc.id, doc.data()))
          .whereType<_NeighborhoodRecord>()
          .toList();
      if (!mounted) {
        return;
      }
      setState(() {
        _neighborhoods
          ..clear()
          ..addAll(records);
        _sortNeighborhoods();
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _neighborhoodLoadError =
            '동네 기록을 불러오지 못했어요. (${e.toString().replaceAll('Exception: ', '')})';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingNeighborhoods = false;
        });
      }
    }
  }

  Future<_NeighborhoodRecord?> _persistNeighborhood(
      _NeighborhoodRecord record) async {
    try {
      final userDocId = await _resolveUserDocId();
      if (userDocId == null) {
        _showSnack('로그인 정보가 없어 저장할 수 없어요.');
        return null;
      }
      final matchKey = _buildNeighborhoodMatchKey(record);
      final data = {
        'province': record.province,
        'district': record.district,
        'dong': record.dong,
        'startYear': record.startYear,
        'endYear': record.endYear,
        'note': record.note,
        'favoritePlace': record.favoritePlace,
        'nickname': record.nickname,
        'moveReason': record.moveReason,
        'bestFriend': record.bestFriend,
        'matchKey': matchKey,
        'ownerId': userDocId,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (record.id.isEmpty) {
        final docRef = await FirebaseFirestore.instance
            .collection('users')
            .doc(userDocId)
            .collection('neighborhoods')
            .add({
          ...data,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return record.copyWith(id: docRef.id);
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userDocId)
          .collection('neighborhoods')
          .doc(record.id)
          .set(data, SetOptions(merge: true));
      return record;
    } catch (e) {
      _showSnack('동네 저장에 실패했어요. (${e.toString().replaceAll('Exception: ', '')})');
      return null;
    }
  }

  Future<void> _loadMemories() async {
    setState(() {
      _loadingMemories = true;
      _memoryLoadError = null;
    });
    try {
      final userDocId = await _resolveUserDocId();
      if (userDocId == null) {
        setState(() {
          _memories.clear();
          _memoryLoadError = '로그인 정보가 없어 추억을 불러올 수 없어요.';
        });
        return;
      }
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userDocId)
          .collection('memories')
          .orderBy('date', descending: true)
          .get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final record = _MemoryRecord.fromFirestore(doc.id, data);
        if (record == null) {
          continue;
        }
        final matchKeys = _buildMemoryMatchKeys(record);
        final needsUpdate =
            (data['matchKeys'] is! List || (data['matchKeys'] as List).isEmpty) &&
                matchKeys.isNotEmpty;
        if (needsUpdate || data['ownerId'] == null) {
          await doc.reference.set({
            'matchKeys': matchKeys,
            'ownerId': userDocId,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }
      final records = snapshot.docs
          .map((doc) => _MemoryRecord.fromFirestore(doc.id, doc.data()))
          .whereType<_MemoryRecord>()
          .toList();
      if (!mounted) {
        return;
      }
      setState(() {
        _memories
          ..clear()
          ..addAll(records);
        _sortMemories();
        _initMemorySections();
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _memoryLoadError =
            '추억을 불러오지 못했어요. (${e.toString().replaceAll('Exception: ', '')})';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingMemories = false;
        });
      }
    }
  }

  Future<_MemoryRecord?> _persistMemory(_MemoryRecord record) async {
    try {
      final userDocId = await _resolveUserDocId();
      if (userDocId == null) {
        _showSnack('로그인 정보가 없어 저장할 수 없어요.');
        return null;
      }
      final matchKeys = _buildMemoryMatchKeys(record);
      final data = {
        'title': record.title,
        'content': record.content,
        'date': record.date,
        'tags': record.tags,
        'emotion': record.emotion?.key,
        'timeCapsule': record.timeCapsule,
        'song': record.song,
        'smell': record.smell,
        'weather': record.weather,
        'matchKeys': matchKeys,
        'ownerId': userDocId,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (record.id.isEmpty) {
        final docRef = await FirebaseFirestore.instance
            .collection('users')
            .doc(userDocId)
            .collection('memories')
            .add({
          ...data,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return record.copyWith(id: docRef.id);
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userDocId)
          .collection('memories')
          .doc(record.id)
          .set(data, SetOptions(merge: true));
      return record;
    } catch (e) {
      _showSnack('추억 저장에 실패했어요. (${e.toString().replaceAll('Exception: ', '')})');
      return null;
    }
  }

  Future<String?> _resolveUserDocId() async {
    final prefs = await SharedPreferences.getInstance();
    final provider = prefs.getString('lastProvider');
    final providerId = prefs.getString('lastProviderId');
    if (provider != null && providerId != null) {
      if (provider == 'kakao' || provider == 'naver') {
        return '$provider:$providerId';
      }
    }
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser != null) {
      return authUser.uid;
    }
    if (provider == null || providerId == null) {
      return null;
    }
    return providerId;
  }

  String _normalizeMatchValue(String value) {
    return value.trim().toLowerCase().replaceAll(' ', '').replaceAll('-', '');
  }

  String _normalizeProvince(String value) {
    var normalized = _normalizeMatchValue(value);
    if (normalized.isEmpty) {
      return normalized;
    }
    const suffixes = [
      '특별자치시',
      '특별자치도',
      '광역시',
      '특별시',
      '자치시',
      '자치도',
      '도',
      '시',
    ];
    for (final suffix in suffixes) {
      if (normalized.endsWith(suffix)) {
        normalized = normalized.substring(0, normalized.length - suffix.length);
        break;
      }
    }
    return normalized;
  }

  String _normalizeDistrict(String value) {
    var normalized = _normalizeMatchValue(value);
    if (normalized.isEmpty) {
      return normalized;
    }
    const suffixes = ['특별자치구', '자치구', '구', '군', '시'];
    for (final suffix in suffixes) {
      if (normalized.endsWith(suffix)) {
        normalized = normalized.substring(0, normalized.length - suffix.length);
        break;
      }
    }
    return normalized;
  }

  String _normalizeDong(String value) {
    var normalized = _normalizeMatchValue(value);
    if (normalized.isEmpty) {
      return normalized;
    }
    const suffixes = ['읍', '면', '동', '리'];
    for (final suffix in suffixes) {
      if (normalized.endsWith(suffix)) {
        normalized = normalized.substring(0, normalized.length - suffix.length);
        break;
      }
    }
    return normalized;
  }

  String _buildNeighborhoodMatchKey(_NeighborhoodRecord record) {
    final province = _normalizeProvince(record.province);
    final district = _normalizeDistrict(record.district);
    final dong = _normalizeDong(record.dong);
    return '$province|$district|$dong';
  }

  List<String> _buildMemoryMatchKeys(_MemoryRecord record) {
    final year = record.date.year;
    final keys = <String>[];
    final tags = record.tags?.whereType<String>().toList() ?? [];
    if (tags.isNotEmpty) {
      for (final tag in tags) {
        final normalized = _normalizeMatchValue(tag);
        if (normalized.isNotEmpty) {
          keys.add('$year|$normalized');
        }
      }
      return keys;
    }
    final title = _normalizeMatchValue(record.title);
    if (title.isNotEmpty) {
      keys.add('$year|$title');
    }
    return keys;
  }

  String _buildSchoolKey(_SchoolRecord record) {
    if (record.level == _SchoolLevel.university) {
      final code = record.schoolCode ?? '';
      if (code.isNotEmpty) {
        return '${record.level.key}|$code';
      }
      final campus = record.campusType ?? '';
      return '${record.level.key}|${_normalizeMatchValue(record.name)}|${_normalizeMatchValue(campus)}';
    }
    final parts = [
      record.level.key,
      _normalizeMatchValue(record.name),
      _normalizeProvince(record.province),
      _normalizeDistrict(record.district),
    ];
    return parts.join('|');
  }

  List<String> _buildSchoolMatchKeys(
    _SchoolRecord record,
    String schoolKey,
  ) {
    final keys = <String>[];
    if (record.level == _SchoolLevel.kindergarten) {
      final year = record.kindergartenGradYear;
      if (year != null && year > 0) {
        keys.add('$schoolKey|$year');
      }
      return keys;
    }
    if (record.level == _SchoolLevel.university) {
      final major = _normalizeMatchValue(record.major ?? '');
      final entryYear = record.universityEntryYear;
      if (major.isNotEmpty && entryYear != null && entryYear > 0) {
        keys.add('$schoolKey|$major|$entryYear');
      }
      return keys;
    }
    if (record.gradeEntries != null && record.gradeEntries!.isNotEmpty) {
      final validEntries = record.gradeEntries!
          .where((entry) => entry.year != null && entry.year! > 0)
          .toList();
      if (validEntries.isNotEmpty) {
        validEntries.sort((a, b) => a.grade.compareTo(b.grade));
        final anchor = validEntries.first;
        final anchorGrade = anchor.grade;
        final anchorYear = anchor.year!;
        for (final entry in record.gradeEntries!) {
          if (entry.year == null ||
              entry.classNumber == null ||
              entry.classNumber == '모름') {
            continue;
          }
          final expectedYear = anchorYear + (entry.grade - anchorGrade);
          if (entry.year == expectedYear) {
            keys.add(
              '$schoolKey|${entry.year}|${entry.grade}|${entry.classNumber}',
            );
          }
        }
      } else {
        for (final entry in record.gradeEntries!) {
          if (entry.year != null &&
              entry.classNumber != null &&
              entry.classNumber != '모름') {
            keys.add(
              '$schoolKey|${entry.year}|${entry.grade}|${entry.classNumber}',
            );
          }
        }
      }
    } else if (record.year != null &&
        record.classNumber != null &&
        record.classNumber != '모름') {
      keys.add('$schoolKey|${record.year}|${record.grade}|${record.classNumber}');
    }
    return keys;
  }

  String? _fileExtension(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1) {
      return null;
    }
    final ext = path.substring(dot + 1).toLowerCase();
    return ext.isEmpty ? null : ext;
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showDuplicateDialog() async {
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이미 등록된 학교입니다'),
        content: const Text('같은 학교가 이미 등록되어 있어 추가할 수 없어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _sortSchools() {
    _schools.sort((a, b) {
      final orderA = _schoolOrderIndex(a.level);
      final orderB = _schoolOrderIndex(b.level);
      if (orderA != orderB) {
        return orderA.compareTo(orderB);
      }
      return a.name.compareTo(b.name);
    });
  }

  int _schoolOrderIndex(_SchoolLevel level) {
    switch (level) {
      case _SchoolLevel.kindergarten:
        return 0;
      case _SchoolLevel.elementary:
        return 1;
      case _SchoolLevel.middle:
        return 2;
      case _SchoolLevel.high:
        return 3;
      case _SchoolLevel.university:
        return 4;
    }
  }

  void _sortNeighborhoods() {
    _neighborhoods.sort((a, b) {
      final startCompare = a.startYear.compareTo(b.startYear);
      if (startCompare != 0) {
        return startCompare;
      }
      return a.title.compareTo(b.title);
    });
  }

  void _sortMemories() {
    _memories.sort((a, b) => b.date.compareTo(a.date));
  }

  List<int> get _memoryYears {
    final years = _memories.map((memory) => memory.date.year).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    return years;
  }

  void _initMemorySections() {
    final grouped = _groupMemoriesByMonth(_memories);
    for (final key in grouped.keys) {
      _memorySectionExpanded.putIfAbsent(key, () => _isLatestSection(key, grouped.keys));
    }
  }

  List<Widget> _buildMemorySections() {
    final filtered = _memoryYearFilter == null
        ? _memories
        : _memories
            .where((record) => record.date.year == _memoryYearFilter)
            .toList();
    final grouped = _groupMemoriesByMonth(filtered);
    final keys = grouped.keys.toList();
    return keys
        .map(
          (key) => _MemorySection(
            title: key,
            count: grouped[key]!.length,
            expanded: _memorySectionExpanded[key] ?? false,
            onToggle: () {
              setState(() {
                _memorySectionExpanded[key] = !(_memorySectionExpanded[key] ?? false);
              });
            },
            children: grouped[key]!
                .map(
                  (record) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _MemoryCard(
                      record: record,
                      onEdit: () => _openEditMemory(record),
                      onDelete: () => _deleteMemory(record),
                    ),
                  ),
                )
                .toList(),
          ),
        )
        .toList();
  }

  Map<String, List<_MemoryRecord>> _groupMemoriesByMonth(
      List<_MemoryRecord> records) {
    final Map<String, List<_MemoryRecord>> grouped = {};
    for (final record in records) {
      final key = '${record.date.year}년 ${record.date.month}월';
      grouped.putIfAbsent(key, () => []).add(record);
    }
    return grouped;
  }

  bool _isLatestSection(String key, Iterable<String> keys) {
    if (keys.isEmpty) {
      return true;
    }
    return keys.first == key;
  }
}

class _SchoolHeader extends StatelessWidget {
  const _SchoolHeader({
    required this.onAdd,
  });

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.school_rounded, color: Color(0xFF3A8DFF)),
          const SizedBox(width: 8),
          const Text(
            '다닌 학교들',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF3A8DFF),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: const [
                  Icon(Icons.add, size: 16, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    '추가',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NeighborhoodHeader extends StatelessWidget {
  const _NeighborhoodHeader({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.home_rounded, color: Color(0xFF22C55E)),
          const SizedBox(width: 8),
          const Text(
            '살았던 동네들',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: const [
                  Icon(Icons.add, size: 16, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    '추가',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NeighborhoodCard extends StatefulWidget {
  const _NeighborhoodCard({
    required this.record,
    required this.onEdit,
    required this.onDelete,
  });

  final _NeighborhoodRecord record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_NeighborhoodCard> createState() => _NeighborhoodCardState();
}

class _MemoryHeader extends StatelessWidget {
  const _MemoryHeader({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month_rounded, color: Color(0xFF7C3AED)),
          const SizedBox(width: 8),
          const Text(
            '추억 일기',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: const [
                  Icon(Icons.add, size: 16, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    '추가',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({
    required this.record,
    required this.onEdit,
    required this.onDelete,
  });

  final _MemoryRecord record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (record.emotion != null) ...[
                  Row(
                    children: [
                      Text(
                        record.emotion!.emoji,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        record.emotion!.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: record.emotion!.color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                Text(
                  record.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  record.dateLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8A8A8A),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  record.content,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF3E3E3E)),
                ),
                if (record.timeCapsule != null &&
                    record.timeCapsule!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '타임캡슐: ${record.timeCapsule!}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF7C3AED)),
                  ),
                ],
                if (record.song != null || record.smell != null || record.weather != null)
                  ...[
                    const SizedBox(height: 6),
                    _MemorySenseRow(
                      song: record.song,
                      smell: record.smell,
                      weather: record.weather,
                    ),
                  ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFFBDBDBD)),
            onSelected: (value) {
              if (value == 'edit') {
                onEdit();
              } else if (value == 'delete') {
                onDelete();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'edit',
                child: Text('수정'),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text('삭제'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MemorySection extends StatelessWidget {
  const _MemorySection({
    required this.title,
    required this.count,
    required this.expanded,
    required this.onToggle,
    required this.children,
  });

  final String title;
  final int count;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1E9FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.calendar_month_rounded,
                        color: Color(0xFF7C3AED), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '($count)',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8A8A8A),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF7C3AED),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(children: children),
            ),
        ],
      ),
    );
  }
}

class _MemoryYearFilter extends StatelessWidget {
  const _MemoryYearFilter({
    required this.years,
    required this.selectedYear,
    required this.onSelected,
  });

  final List<int> years;
  final int? selectedYear;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    if (years.isEmpty) {
      return const SizedBox.shrink();
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildChip(
            label: '전체',
            selected: selectedYear == null,
            onTap: () => onSelected(null),
          ),
          ...years.map(
            (year) => _buildChip(
              label: '$year',
              selected: selectedYear == year,
              onTap: () => onSelected(year),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF7C3AED) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? const Color(0xFF7C3AED) : const Color(0xFFE7E2F5),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withOpacity(0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF6D5F9B),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _NeighborhoodCardState extends State<_NeighborhoodCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final hasExtra = (record.favoritePlace != null &&
            record.favoritePlace!.trim().isNotEmpty) ||
        (record.nickname != null && record.nickname!.trim().isNotEmpty) ||
        (record.bestFriend != null && record.bestFriend!.trim().isNotEmpty) ||
        (record.moveReason != null && record.moveReason!.trim().isNotEmpty);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  record.periodLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8A8A8A),
                  ),
                ),
                if (record.note != null && record.note!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    record.note!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF22C55E),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (hasExtra) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _expanded = !_expanded;
                      });
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _expanded ? '접기' : '자세히 보기',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8A8A8A),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _expanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 16,
                          color: const Color(0xFF8A8A8A),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_expanded) ...[
                  if (record.favoritePlace != null &&
                      record.favoritePlace!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '장소: ${record.favoritePlace!}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF8A8A8A)),
                    ),
                  ],
                  if (record.nickname != null &&
                      record.nickname!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '별명: ${record.nickname!}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF8A8A8A)),
                    ),
                  ],
                  if (record.bestFriend != null &&
                      record.bestFriend!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '친구: ${record.bestFriend!}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF8A8A8A)),
                    ),
                  ],
                  if (record.moveReason != null &&
                      record.moveReason!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '이사 이유: ${record.moveReason!}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF8A8A8A)),
                    ),
                  ],
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFFBDBDBD)),
            onSelected: (value) {
              if (value == 'edit') {
                widget.onEdit();
              } else if (value == 'delete') {
                widget.onDelete();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'edit',
                child: Text('수정'),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text('삭제'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddNeighborhoodSheet extends StatefulWidget {
  const _AddNeighborhoodSheet({this.initialRecord});

  final _NeighborhoodRecord? initialRecord;

  @override
  State<_AddNeighborhoodSheet> createState() => _AddNeighborhoodSheetState();
}

class _AddNeighborhoodSheetState extends State<_AddNeighborhoodSheet> {
  _ProvinceOption? _province;
  String? _districtSelected;
  String? _dongSelected;
  String? _presetDistrict;
  String? _presetDong;
  bool _loadingDistricts = false;
  bool _loadingDongs = false;
  List<String> _districtOptions = [];
  List<String> _dongOptions = [];
  final Map<String, List<String>> _districtCache = {};
  final Map<String, List<String>> _dongCache = {};
  String? _regionError;
  List<Map<String, dynamic>>? _allRegionRowsCache;
  int _startYear = DateTime.now().year;
  int _endYear = DateTime.now().year;
  final _noteController = TextEditingController();
  final _placeController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _moveReasonController = TextEditingController();
  final _bestFriendController = TextEditingController();

  static const String _dataGoServiceKey = String.fromEnvironment(
    'DATA_GO_SERVICE_KEY',
    defaultValue:
        '47b77db0f3002b862acb7482d8e2853e94d0e7df70e9fe11ef5cb37c7a36ccd6',
  );

  static const _provinces = [
    _ProvinceOption('서울', '서울특별시'),
    _ProvinceOption('경기도', '경기도'),
    _ProvinceOption('강원도', '강원특별자치도'),
    _ProvinceOption('충청북도', '충청북도'),
    _ProvinceOption('충청남도', '충청남도'),
    _ProvinceOption('전라북도', '전북특별자치도'),
    _ProvinceOption('전라남도', '전라남도'),
    _ProvinceOption('경상북도', '경상북도'),
    _ProvinceOption('경상남도', '경상남도'),
    _ProvinceOption('부산', '부산광역시'),
    _ProvinceOption('대구', '대구광역시'),
    _ProvinceOption('인천', '인천광역시'),
    _ProvinceOption('광주', '광주광역시'),
    _ProvinceOption('대전', '대전광역시'),
    _ProvinceOption('울산', '울산광역시'),
    _ProvinceOption('세종', '세종특별자치시'),
    _ProvinceOption('제주', '제주특별자치도'),
  ];

  @override
  void initState() {
    super.initState();
    final record = widget.initialRecord;
    if (record != null) {
      _startYear = record.startYear;
      _endYear = record.endYear;
      _noteController.text = record.note ?? '';
      _placeController.text = record.favoritePlace ?? '';
      _nicknameController.text = record.nickname ?? '';
      _moveReasonController.text = record.moveReason ?? '';
      _bestFriendController.text = record.bestFriend ?? '';
      _province = _provinces.firstWhere(
        (item) => item.label == record.province,
        orElse: () => _provinces.first,
      );
      _presetDistrict = record.district;
      _presetDong = record.dong;
      final province = _province;
      if (province != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _loadDistricts(province.apiName);
        });
      }
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _placeController.dispose();
    _nicknameController.dispose();
    _moveReasonController.dispose();
    _bestFriendController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '동네 추가',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: '지역',
                    child: Column(
                      children: [
                        DropdownButtonFormField<_ProvinceOption>(
                          value: _province,
                          items: _provinces
                              .map(
                                (province) => DropdownMenuItem(
                                  value: province,
                                  child: Text(province.label),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _province = value;
                              _districtSelected = null;
                              _dongSelected = null;
                              _districtOptions = [];
                              _dongOptions = [];
                              _regionError = null;
                            });
                            if (value != null) {
                              _loadDistricts(value.apiName);
                            }
                          },
                          decoration: _fieldDecoration('시/도 선택'),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _districtOptions.contains(_districtSelected)
                              ? _districtSelected
                              : null,
                          items: _districtOptions
                              .map(
                                (district) => DropdownMenuItem(
                                  value: district,
                                  child: Text(district),
                                ),
                              )
                              .toList(),
                          onChanged: _loadingDistricts
                              ? null
                              : (value) {
                                  setState(() {
                                    _districtSelected = value;
                                    _dongSelected = null;
                                    _dongOptions = [];
                                    _regionError = null;
                                  });
                                  final province = _province;
                                  if (province != null && value != null) {
                                    _loadDongs(province.apiName, value);
                                  }
                                },
                          decoration: _fieldDecoration(
                            _loadingDistricts ? '시/군/구 불러오는 중...' : '시/군/구 선택',
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _dongOptions.contains(_dongSelected)
                              ? _dongSelected
                              : null,
                          items: _dongOptions
                              .map(
                                (dong) => DropdownMenuItem(
                                  value: dong,
                                  child: Text(dong),
                                ),
                              )
                              .toList(),
                          onChanged: _loadingDongs
                              ? null
                              : (value) {
                                  setState(() {
                                    _dongSelected = value;
                                    _regionError = null;
                                  });
                                },
                          decoration: _fieldDecoration(
                            _loadingDongs ? '동/읍/면 불러오는 중...' : '동/읍/면 선택',
                          ),
                        ),
                        const SizedBox(height: 8),
                        _RegionStatus(
                          districts: _districtOptions.length,
                          dongs: _dongOptions.length,
                          loadingDistricts: _loadingDistricts,
                          loadingDongs: _loadingDongs,
                          error: _regionError,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: '기간',
                    child: Row(
                      children: [
                        Expanded(
                          child: _NumberPickerField(
                            label: '시작년도',
                            value: _startYear,
                            max: 0,
                            yearsMode: true,
                            onChanged: (value) {
                              setState(() {
                                _startYear = value;
                                if (_endYear < _startYear) {
                                  _endYear = _startYear;
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _NumberPickerField(
                            label: '끝년도',
                            value: _endYear,
                            max: 0,
                            yearsMode: true,
                            onChanged: (value) {
                              setState(() {
                                _endYear = value;
                                if (_endYear < _startYear) {
                                  _startYear = _endYear;
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: '추억 한 줄 (선택)',
                    child: TextField(
                      controller: _noteController,
                      decoration: _fieldDecoration('예: 어린 시절을 보낸 곳'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: '기억에 남는 장소',
                    child: TextField(
                      controller: _placeController,
                      decoration: _fieldDecoration('예: 공원, 학교, 마트'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: '그 동네에서의 별명',
                    child: TextField(
                      controller: _nicknameController,
                      decoration: _fieldDecoration('예: 떡볶이왕'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: '이사 이유',
                    child: TextField(
                      controller: _moveReasonController,
                      decoration: _fieldDecoration('예: 학교 진학, 직장 이동'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: '가장 친했던 친구',
                    child: TextField(
                      controller: _bestFriendController,
                      decoration: _fieldDecoration('예: 민수, 지영'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF22C55E),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              '저장하기',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              '취소',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _save() {
    if (_province == null ||
        _districtSelected == null ||
        _dongSelected == null) {
      _showError('지역을 선택해주세요.');
      return;
    }
    Navigator.of(context).pop(
      _NeighborhoodRecord(
        id: widget.initialRecord?.id ?? '',
        province: _province!.label,
        district: _districtSelected!,
        dong: _dongSelected!,
        startYear: _startYear,
        endYear: _endYear,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        favoritePlace: _placeController.text.trim().isEmpty
            ? null
            : _placeController.text.trim(),
        nickname: _nicknameController.text.trim().isEmpty
            ? null
            : _nicknameController.text.trim(),
        moveReason: _moveReasonController.text.trim().isEmpty
            ? null
            : _moveReasonController.text.trim(),
        bestFriend: _bestFriendController.text.trim().isEmpty
            ? null
            : _bestFriendController.text.trim(),
      ),
    );
  }

  Future<void> _loadDistricts(String province) async {
    final cached = _districtCache[province];
    if (cached != null && cached.isNotEmpty) {
      setState(() {
        _districtOptions = cached;
        if (_presetDistrict != null && cached.contains(_presetDistrict)) {
          _districtSelected = _presetDistrict;
          _presetDistrict = null;
          final provinceOption = _province;
          if (provinceOption != null && _districtSelected != null) {
            _loadDongs(provinceOption.apiName, _districtSelected!);
          }
        }
      });
      return;
    }
    final globalCached = _globalDistrictCache[province];
    if (globalCached != null && globalCached.isNotEmpty) {
      setState(() {
        _districtOptions = globalCached;
        _districtCache[province] = globalCached;
        if (_presetDistrict != null && globalCached.contains(_presetDistrict)) {
          _districtSelected = _presetDistrict;
          _presetDistrict = null;
          final provinceOption = _province;
          if (provinceOption != null && _districtSelected != null) {
            _loadDongs(provinceOption.apiName, _districtSelected!);
          }
        }
      });
      return;
    }
    setState(() {
      _loadingDistricts = true;
    });
    try {
      if (_globalRegionRows != null && _globalRegionRows!.isNotEmpty) {
        final districts = _globalRegionRows!
            .map((row) => _extractDistrict(row, province))
            .whereType<String>()
            .toSet()
            .toList()
          ..sort();
        if (!mounted) {
          return;
        }
        setState(() {
          _districtOptions = districts;
          if (districts.isNotEmpty) {
            _districtCache[province] = districts;
            _globalDistrictCache[province] = districts;
          }
          if (_presetDistrict != null && districts.contains(_presetDistrict)) {
            _districtSelected = _presetDistrict;
            _presetDistrict = null;
            final provinceOption = _province;
            if (provinceOption != null && _districtSelected != null) {
              _loadDongs(provinceOption.apiName, _districtSelected!);
            }
          }
          if (districts.isEmpty) {
            _regionError = '시/군/구 결과가 없습니다. ($province)';
          }
        });
        return;
      }
      var rows = await _fetchRegionRows(province);
      if (rows.isEmpty) {
        rows = await _fetchAllRows();
      }
      final districts = rows
          .map((row) => _extractDistrict(row, province))
          .whereType<String>()
          .toSet()
          .toList()
        ..sort();
      if (!mounted) {
        return;
      }
      setState(() {
        _districtOptions = districts;
        if (districts.isNotEmpty) {
          _districtCache[province] = districts;
          _globalDistrictCache[province] = districts;
        }
        if (_presetDistrict != null && districts.contains(_presetDistrict)) {
          _districtSelected = _presetDistrict;
          _presetDistrict = null;
          final provinceOption = _province;
          if (provinceOption != null && _districtSelected != null) {
            _loadDongs(provinceOption.apiName, _districtSelected!);
          }
        }
        if (districts.isEmpty) {
          _regionError = '시/군/구 결과가 없습니다. ($province)';
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _regionError = '시/군/구 목록을 불러오지 못했습니다. (${e.toString().replaceAll('Exception: ', '')})';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingDistricts = false;
        });
      }
    }
  }

  Future<void> _loadDongs(String province, String district) async {
    final cacheKey = '$province|$district';
    final cached = _dongCache[cacheKey];
    if (cached != null && cached.isNotEmpty) {
      setState(() {
        _dongOptions = cached;
        if (_presetDong != null && cached.contains(_presetDong)) {
          _dongSelected = _presetDong;
          _presetDong = null;
        }
      });
      return;
    }
    final globalCached = _globalDongCache[cacheKey];
    if (globalCached != null && globalCached.isNotEmpty) {
      setState(() {
        _dongOptions = globalCached;
        _dongCache[cacheKey] = globalCached;
        if (_presetDong != null && globalCached.contains(_presetDong)) {
          _dongSelected = _presetDong;
          _presetDong = null;
        }
      });
      return;
    }
    setState(() {
      _loadingDongs = true;
    });
    try {
      final query = '$province $district';
      if (_globalRegionRows != null && _globalRegionRows!.isNotEmpty) {
        final dongs = _globalRegionRows!
            .map((row) => _extractDong(row, query))
            .whereType<String>()
            .toSet()
            .toList()
          ..sort();
        if (!mounted) {
          return;
        }
        setState(() {
          _dongOptions = dongs;
          if (dongs.isNotEmpty) {
            _dongCache[cacheKey] = dongs;
            _globalDongCache[cacheKey] = dongs;
          }
          if (_presetDong != null && dongs.contains(_presetDong)) {
            _dongSelected = _presetDong;
            _presetDong = null;
          }
          if (dongs.isEmpty) {
            _regionError = '동/읍/면 결과가 없습니다. ($query)';
          }
        });
        return;
      }
      var rows = await _fetchRegionRows(query);
      if (rows.isEmpty) {
        rows = await _fetchAllRows();
      }
      final dongs = rows
          .map((row) => _extractDong(row, query))
          .whereType<String>()
          .toSet()
          .toList()
        ..sort();
      if (!mounted) {
        return;
      }
      setState(() {
        _dongOptions = dongs;
        if (dongs.isNotEmpty) {
          _dongCache[cacheKey] = dongs;
          _globalDongCache[cacheKey] = dongs;
        }
        if (_presetDong != null && dongs.contains(_presetDong)) {
          _dongSelected = _presetDong;
          _presetDong = null;
        }
        if (dongs.isEmpty) {
          _regionError = '동/읍/면 결과가 없습니다. ($query)';
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _regionError = '동/읍/면 목록을 불러오지 못했습니다. (${e.toString().replaceAll('Exception: ', '')})';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingDongs = false;
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchRegionRows(String query) async {
    if (_dataGoServiceKey.isEmpty) {
      throw Exception('ServiceKey missing');
    }
    final uri = Uri.parse(
      'https://apis.data.go.kr/1741000/StanReginCd/getStanReginCdList',
    ).replace(
      queryParameters: {
        'ServiceKey': _dataGoServiceKey,
        'serviceKey': _dataGoServiceKey,
        'pageNo': '1',
        'numOfRows': '10000',
        'type': 'json',
        'locatadd_nm': query,
      },
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final apiError = _extractApiError(decoded);
    if (apiError != null) {
      throw Exception(apiError);
    }
    return _extractRows(decoded);
  }

  Future<List<Map<String, dynamic>>> _fetchAllRows() async {
    final cached = _allRegionRowsCache;
    if (cached != null) {
      return cached;
    }
    if (_globalRegionRows != null) {
      _allRegionRowsCache = _globalRegionRows;
      return _globalRegionRows!;
    }
    if (_globalRegionRowsFuture != null) {
      final rows = await _globalRegionRowsFuture!;
      _allRegionRowsCache = rows;
      return rows;
    }
    _globalRegionRowsFuture = () async {
      final allRows = <Map<String, dynamic>>[];
      var page = 1;
      const pageSize = 1000;
      while (page <= 60) {
        final uri = Uri.parse(
          'https://apis.data.go.kr/1741000/StanReginCd/getStanReginCdList',
        ).replace(
          queryParameters: {
            'ServiceKey': _dataGoServiceKey,
            'serviceKey': _dataGoServiceKey,
            'pageNo': '$page',
            'numOfRows': '$pageSize',
            'type': 'json',
          },
        );
        final response = await http.get(uri);
        if (response.statusCode != 200) {
          break;
        }
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final apiError = _extractApiError(decoded);
        if (apiError != null) {
          break;
        }
        final rows = _extractRows(decoded);
        if (rows.isEmpty) {
          break;
        }
        allRows.addAll(rows);
        if (rows.length < pageSize) {
          break;
        }
        page += 1;
      }
      _globalRegionRows = allRows;
      return allRows;
    }();
    final rows = await _globalRegionRowsFuture!;
    _allRegionRowsCache = rows;
    _globalRegionRowsFuture = null;
    return rows;
  }

  List<Map<String, dynamic>> _extractRows(dynamic decoded) {
    if (decoded is! Map) {
      return [];
    }
    final root = decoded['StanReginCd'];
    if (root is List) {
      for (final item in root) {
        if (item is Map && item['row'] is List) {
          return (item['row'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
      return [];
    }
    if (root is Map && root['row'] is List) {
      return (root['row'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  String? _extractApiError(dynamic decoded) {
    if (decoded is! Map) {
      return null;
    }
    final root = decoded['StanReginCd'];
    if (root is List) {
      for (final item in root) {
        final error = _extractApiErrorFromItem(item);
        if (error != null) {
          return error;
        }
      }
      return null;
    }
    if (root is Map) {
      return _extractApiErrorFromItem(root);
    }
    return null;
  }

  String? _extractApiErrorFromItem(Map item) {
    if (item['head'] is! List) {
      return null;
    }
    final head = item['head'] as List;
    if (head.isEmpty || head.first is! Map) {
      return null;
    }
    final map = head.first as Map;
    final resultCode = map['RESULT']?['CODE'] ?? map['resultCode'];
    final resultMsg = map['RESULT']?['MESSAGE'] ?? map['resultMsg'];
    if (resultCode != null && resultCode.toString() != '00') {
      return 'API 오류: $resultMsg ($resultCode)';
    }
    return null;
  }

  String? _extractDistrict(Map<String, dynamic> row, String province) {
    final full = row['locatadd_nm'];
    if (full is! String) {
      return null;
    }
    if (!full.startsWith(province)) {
      return null;
    }
    final parts = full.split(' ');
    if (parts.length < 2) {
      return null;
    }
    return parts[1].trim().isEmpty ? null : parts[1].trim();
  }

  String? _extractDong(Map<String, dynamic> row, String prefix) {
    final full = row['locatadd_nm'];
    if (full is! String) {
      return null;
    }
    if (!full.startsWith(prefix)) {
      return null;
    }
    final parts = full.split(' ');
    if (parts.length < 3) {
      return null;
    }
    return parts[2].trim().isEmpty ? null : parts[2].trim();
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE7E2F5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE7E2F5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF22C55E), width: 1.2),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _AddMemorySheet extends StatefulWidget {
  const _AddMemorySheet({this.initialRecord});

  final _MemoryRecord? initialRecord;

  @override
  State<_AddMemorySheet> createState() => _AddMemorySheetState();
}

class _AddMemorySheetState extends State<_AddMemorySheet> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagsController = TextEditingController();
  final _timeCapsuleController = TextEditingController();
  final _songController = TextEditingController();
  final _smellController = TextEditingController();
  final _weatherController = TextEditingController();
  _EmotionPreset _emotion = _EmotionPreset.happy;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final record = widget.initialRecord;
    if (record != null) {
      _titleController.text = record.title;
      _contentController.text = record.content;
      _selectedDate = record.date;
      _tagsController.text = record.tags.join(', ');
      _timeCapsuleController.text = record.timeCapsule ?? '';
      _songController.text = record.song ?? '';
      _smellController.text = record.smell ?? '';
      _weatherController.text = record.weather ?? '';
      _emotion = record.emotion ?? _EmotionPreset.happy;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    _timeCapsuleController.dispose();
    _songController.dispose();
    _smellController.dispose();
    _weatherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '추억 추가',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: '제목',
                    child: TextField(
                      controller: _titleController,
                      decoration: _fieldDecoration('예: 첫 졸업식'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: '날짜',
                    child: InkWell(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: _fieldDecoration('날짜 선택'),
                        child: Row(
                          children: [
                            const Icon(Icons.event_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text(_formatDate(_selectedDate)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: '내용',
                    child: TextField(
                      controller: _contentController,
                      maxLines: 4,
                      decoration: _fieldDecoration('그날의 기억을 적어보세요'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: '그날의 감정',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _EmotionPreset.values
                          .map(
                            (preset) => ChoiceChip(
                              label: Text('${preset.emoji} ${preset.label}'),
                              selected: _emotion == preset,
                              selectedColor: preset.color.withOpacity(0.2),
                              onSelected: (_) {
                                setState(() {
                                  _emotion = preset;
                                });
                              },
                              labelStyle: TextStyle(
                                color: _emotion == preset
                                    ? preset.color
                                    : const Color(0xFF8A8A8A),
                                fontWeight: FontWeight.w600,
                              ),
                              shape: StadiumBorder(
                                side: BorderSide(
                                  color: _emotion == preset
                                      ? preset.color
                                      : const Color(0xFFE0E0E0),
                                ),
                              ),
                              backgroundColor: Colors.white,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: '한 줄 타임캡슐 질문',
                    child: TextField(
                      controller: _timeCapsuleController,
                      decoration: _fieldDecoration('예: 그날 꼭 전하고 싶은 한 문장'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: '감각 기록',
                    child: Column(
                      children: [
                        TextField(
                          controller: _songController,
                          decoration: _fieldDecoration('그날의 노래'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _smellController,
                          decoration: _fieldDecoration('그날의 냄새'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _weatherController,
                          decoration: _fieldDecoration('그날의 날씨'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: '태그 (선택)',
                    child: TextField(
                      controller: _tagsController,
                      decoration: _fieldDecoration('예: 가족, 여행, 학교'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7C3AED),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              '저장하기',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              '취소',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _save() {
    if (_titleController.text.trim().isEmpty ||
        _contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목과 내용을 입력해주세요.')),
      );
      return;
    }
    final tags = _tagsController.text
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
    Navigator.of(context).pop(
      _MemoryRecord(
        id: widget.initialRecord?.id ?? '',
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        date: _selectedDate,
        tags: tags,
        emotion: _emotion,
        timeCapsule: _timeCapsuleController.text.trim().isEmpty
            ? null
            : _timeCapsuleController.text.trim(),
        song: _songController.text.trim().isEmpty ? null : _songController.text.trim(),
        smell: _smellController.text.trim().isEmpty ? null : _smellController.text.trim(),
        weather:
            _weatherController.text.trim().isEmpty ? null : _weatherController.text.trim(),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE7E2F5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE7E2F5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.2),
      ),
    );
  }
}

class _RecordTab extends StatelessWidget {
  const _RecordTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFFFF7A3D) : const Color(0xFF8A8A8A);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFFFF0E6) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFFFF7A3D)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF9B9B9B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.background,
    required this.color,
  });

  final String label;
  final Color background;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _AddSchoolSheet extends StatefulWidget {
  const _AddSchoolSheet({
    this.initialRecord,
    required this.onSave,
  });

  final _SchoolRecord? initialRecord;
  final Future<_SchoolRecord?> Function(_SchoolRecord record) onSave;

  @override
  State<_AddSchoolSheet> createState() => _AddSchoolSheetState();
}

class _AddSchoolSheetState extends State<_AddSchoolSheet> {
  _SchoolLevel _level = _SchoolLevel.elementary;
  _ProvinceOption? _province;
  String? _districtSelected;
  String? _dongSelected;
  String? _presetDistrict;
  String? _presetDong;
  bool _loadingDistricts = false;
  bool _loadingDongs = false;
  List<String> _districtOptions = [];
  List<String> _dongOptions = [];
  final Map<String, List<String>> _districtCache = {};
  final Map<String, List<String>> _dongCache = {};
  String? _regionError;
  List<Map<String, dynamic>>? _allRegionRowsCache;
  final _schoolController = TextEditingController();
  final _majorController = TextEditingController();
  List<_GradeEntry> _gradeEntries = [];
  int _kindergartenGradYear = DateTime.now().year;
  int _universityEntryYear = DateTime.now().year;
  bool _loadingSchoolSearch = false;
  String? _schoolSearchError;
  List<_NeisSchoolItem> _schoolSearchResults = [];
  String? _selectedSchoolCode;
  Timer? _schoolSearchDebounce;
  bool _loadingUniversitySearch = false;
  String? _universitySearchError;
  List<_UniversityItem> _universitySearchResults = [];
  String? _selectedCampusType;
  Timer? _universitySearchDebounce;
  int? _academySurveyYear;
  bool _saving = false;

  static const String _dataGoServiceKey = String.fromEnvironment(
    'DATA_GO_SERVICE_KEY',
    defaultValue:
        '47b77db0f3002b862acb7482d8e2853e94d0e7df70e9fe11ef5cb37c7a36ccd6',
  );

  static const String _neisApiKey = String.fromEnvironment(
    'NEIS_API_KEY',
    defaultValue: '711645312e0e45eaaf91f72e1487baaa',
  );

  static const String _academyInfoApiKey = String.fromEnvironment(
    'ACADEMYINFO_API_KEY',
    defaultValue: '47b77db0f3002b862acb7482d8e2853e94d0e7df70e9fe11ef5cb37c7a36ccd6',
  );

  static const _provinces = [
    _ProvinceOption('서울', '서울특별시'),
    _ProvinceOption('경기도', '경기도'),
    _ProvinceOption('강원도', '강원특별자치도'),
    _ProvinceOption('충청북도', '충청북도'),
    _ProvinceOption('충청남도', '충청남도'),
    _ProvinceOption('전라북도', '전북특별자치도'),
    _ProvinceOption('전라남도', '전라남도'),
    _ProvinceOption('경상북도', '경상북도'),
    _ProvinceOption('경상남도', '경상남도'),
    _ProvinceOption('부산', '부산광역시'),
    _ProvinceOption('대구', '대구광역시'),
    _ProvinceOption('인천', '인천광역시'),
    _ProvinceOption('광주', '광주광역시'),
    _ProvinceOption('대전', '대전광역시'),
    _ProvinceOption('울산', '울산광역시'),
    _ProvinceOption('세종', '세종특별자치시'),
    _ProvinceOption('제주', '제주특별자치도'),
  ];

  @override
  void initState() {
    super.initState();
    final record = widget.initialRecord;
    if (record == null) {
      _gradeEntries = List.generate(
        6,
        (index) => _GradeEntry(
          grade: index + 1,
          classNumber: 1,
          year: DateTime.now().year + index - 5,
        ),
      );
      return;
    }
    _level = record.level;
    _schoolController.text = record.name;
    _selectedSchoolCode = record.schoolCode;
    _majorController.text = record.major ?? '';
    _gradeEntries = record.gradeEntries ?? [];
    _kindergartenGradYear = record.kindergartenGradYear ?? DateTime.now().year;
    _universityEntryYear = record.universityEntryYear ?? DateTime.now().year;
    _province = _provinces.firstWhere(
      (item) => item.label == record.province,
      orElse: () => _provinces.first,
    );
    _presetDistrict = record.district;
    _presetDong = record.dong;
    final province = _province;
    if (province != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadDistricts(province.apiName);
      });
    }
  }

  @override
  void dispose() {
    _schoolController.dispose();
    _majorController.dispose();
    _schoolSearchDebounce?.cancel();
    _universitySearchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isElementary = _level == _SchoolLevel.elementary;
    final isMiddle = _level == _SchoolLevel.middle;
    final isHigh = _level == _SchoolLevel.high;
    final isUniversity = _level == _SchoolLevel.university;
    final isKindergarten = _level == _SchoolLevel.kindergarten;
    final isNeisSupported = isElementary || isMiddle || isHigh;

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '학교 추가',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: '학교 종류',
                    child: DropdownButtonFormField<_SchoolLevel>(
                      value: _level,
                      items: _SchoolLevel.values
                          .map(
                            (level) => DropdownMenuItem(
                              value: level,
                              child: Text(level.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _level = value;
                          _schoolSearchResults = [];
                          _schoolSearchError = null;
                          _selectedSchoolCode = null;
                          _universitySearchResults = [];
                          _universitySearchError = null;
                          _selectedCampusType = null;
                          if (_level == _SchoolLevel.elementary ||
                              _level == _SchoolLevel.middle ||
                              _level == _SchoolLevel.high) {
                            final count = _level == _SchoolLevel.elementary ? 6 : 3;
                            _gradeEntries = List.generate(
                              count,
                              (index) => _GradeEntry(
                                grade: index + 1,
                                classNumber: 1,
                                year: DateTime.now().year + index - (count - 1),
                              ),
                            );
                          } else {
                            _gradeEntries = [];
                          }
                        });
                      },
                      decoration: _fieldDecoration('학교 종류 선택'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!isUniversity) ...[
                    _SectionCard(
                      title: '지역',
                      child: Column(
                        children: [
                          DropdownButtonFormField<_ProvinceOption>(
                            value: _province,
                            items: _provinces
                                .map(
                                  (province) => DropdownMenuItem(
                                    value: province,
                                    child: Text(province.label),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _province = value;
                                _districtSelected = null;
                                _dongSelected = null;
                                _districtOptions = [];
                                _dongOptions = [];
                                _regionError = null;
                                _schoolSearchResults = [];
                                _schoolSearchError = null;
                                _selectedSchoolCode = null;
                              });
                              if (value != null) {
                                _loadDistricts(value.apiName);
                              }
                            },
                            decoration: _fieldDecoration('시/도 선택'),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _districtOptions.contains(_districtSelected)
                                ? _districtSelected
                                : null,
                            items: _districtOptions
                                .map(
                                  (district) => DropdownMenuItem(
                                    value: district,
                                    child: Text(district),
                                  ),
                                )
                                .toList(),
                            onChanged: _loadingDistricts
                                ? null
                                : (value) {
                                    setState(() {
                                      _districtSelected = value;
                                      _dongSelected = null;
                                      _dongOptions = [];
                                      _regionError = null;
                                      _schoolSearchResults = [];
                                      _schoolSearchError = null;
                                      _selectedSchoolCode = null;
                                    });
                                    final province = _province;
                                    if (province != null && value != null) {
                                      _loadDongs(province.apiName, value);
                                    }
                                  },
                            decoration: _fieldDecoration(
                              _loadingDistricts
                                  ? '시/군/구 불러오는 중...'
                                  : '시/군/구 선택',
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _dongOptions.contains(_dongSelected)
                                ? _dongSelected
                                : null,
                            items: _dongOptions
                                .map(
                                  (dong) => DropdownMenuItem(
                                    value: dong,
                                    child: Text(dong),
                                  ),
                                )
                                .toList(),
                            onChanged: _loadingDongs
                                ? null
                                : (value) {
                                    setState(() {
                                      _dongSelected = value;
                                      _regionError = null;
                                      _schoolSearchResults = [];
                                      _schoolSearchError = null;
                                      _selectedSchoolCode = null;
                                    });
                                  },
                            decoration: _fieldDecoration(
                              _loadingDongs ? '동/읍/면 불러오는 중...' : '동/읍/면 선택',
                            ),
                          ),
                          const SizedBox(height: 8),
                          _RegionStatus(
                            districts: _districtOptions.length,
                            dongs: _dongOptions.length,
                            loadingDistricts: _loadingDistricts,
                            loadingDongs: _loadingDongs,
                            error: _regionError,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _SectionCard(
                    title: _schoolInfoTitle,
                    child: Column(
                      children: [
                        if (isUniversity) ...[
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _schoolController,
                                  decoration: _fieldDecoration('대학교 이름 검색'),
                                  textInputAction: TextInputAction.search,
                                  onSubmitted: (_) => _searchUniversities(),
                                  onChanged: _onUniversityQueryChanged,
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 44,
                                child: ElevatedButton(
                                  onPressed: _loadingUniversitySearch
                                      ? null
                                      : _searchUniversities,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF22C55E),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _loadingUniversitySearch
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                          ),
                                        )
                                      : const Text(
                                          '조회',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                          if (_universitySearchError != null) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _universitySearchError!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFE11D48),
                                ),
                              ),
                            ),
                          ],
                          if (_universitySearchResults.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              constraints: const BoxConstraints(maxHeight: 220),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: const Color(0xFFE7E2F5)),
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: _universitySearchResults.length,
                                separatorBuilder: (_, __) => const Divider(
                                  height: 1,
                                  color: Color(0xFFEDEDED),
                                ),
                                itemBuilder: (context, index) {
                                  final item = _universitySearchResults[index];
                                  return ListTile(
                                    dense: true,
                                    title: Text(
                                      item.name,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: [
                                            if (item.campusType.isNotEmpty)
                                              _Badge(
                                                label: item.campusType,
                                                background:
                                                    const Color(0xFFFDE68A),
                                                color: const Color(0xFF92400E),
                                              ),
                                            if (item.address.isNotEmpty)
                                              _Badge(
                                                label: item.address,
                                                background:
                                                    const Color(0xFFE0F2FE),
                                                color: const Color(0xFF0369A1),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _schoolController.text = item.name;
                                        _universitySearchResults = [];
                                        _selectedSchoolCode = item.schoolId;
                                        _selectedCampusType = item.campusType;
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ] else if (isNeisSupported) ...[
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _schoolController,
                                  decoration: _fieldDecoration('학교 이름 검색'),
                                  textInputAction: TextInputAction.search,
                                  onSubmitted: (_) => _searchSchools(),
                                  onChanged: _onSchoolQueryChanged,
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 44,
                                child: ElevatedButton(
                                  onPressed:
                                      _loadingSchoolSearch ? null : _searchSchools,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF22C55E),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _loadingSchoolSearch
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                          ),
                                        )
                                      : const Text(
                                          '조회',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                          if (_schoolSearchError != null) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _schoolSearchError!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFE11D48),
                                ),
                              ),
                            ),
                          ],
                          if (_schoolSearchResults.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              constraints: const BoxConstraints(maxHeight: 220),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: const Color(0xFFE7E2F5)),
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: _schoolSearchResults.length,
                                separatorBuilder: (_, __) => const Divider(
                                  height: 1,
                                  color: Color(0xFFEDEDED),
                                ),
                                itemBuilder: (context, index) {
                                  final item = _schoolSearchResults[index];
                                  return ListTile(
                                    dense: true,
                                    title: Text(
                                      item.name,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: [
                                            _Badge(
                                              label: item.kind.isEmpty
                                                  ? '학교'
                                                  : item.kind,
                                              background: const Color(0xFFFEE2E2),
                                              color: const Color(0xFFB91C1C),
                                            ),
                                            if (item.address.isNotEmpty)
                                              _Badge(
                                                label: item.address,
                                                background:
                                                    const Color(0xFFE0F2FE),
                                                color: const Color(0xFF0369A1),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _schoolController.text = item.name;
                                        _schoolSearchResults = [];
                                        _selectedSchoolCode = item.code;
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ] else ...[
                          TextField(
                            controller: _schoolController,
                            decoration: _fieldDecoration(_schoolNameHint),
                          ),
                        ],
                  if (isElementary || isMiddle || isHigh) ...[
                    const SizedBox(height: 10),
                    Column(
                            children: _gradeEntries
                                .map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _GradeRow(
                                key: ValueKey(
                                  'grade-row-${entry.grade}-${entry.classNumber ?? -1}-${entry.year}',
                                ),
                                entry: entry,
                                maxClass: 20,
                                maxGrade: _gradeEntries.isNotEmpty
                                    ? _gradeEntries.last.grade
                                    : entry.grade,
                                onChanged: (updated) {
                                  setState(() {
                                    _gradeEntries = _gradeEntries
                                        .map((entry) => entry.grade == updated.grade
                                            ? updated
                                            : entry)
                                        .toList();
                                  });
                                },
                              ),
                            ),
                          )
                                .toList(),
                          ),
                        ],
                        if (isKindergarten) ...[
                          const SizedBox(height: 10),
                          _NumberPickerField(
                            label: '졸업년도',
                            value: _kindergartenGradYear,
                            max: 0,
                            yearsMode: true,
                            yearSuffix: ' 2월',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            onChanged: (value) {
                              setState(() {
                                _kindergartenGradYear = value;
                              });
                            },
                          ),
                        ],
                        if (isUniversity) ...[
                          const SizedBox(height: 10),
                          TextField(
                            controller: _majorController,
                            decoration: _fieldDecoration('학과 입력'),
                          ),
                          const SizedBox(height: 10),
                          _NumberPickerField(
                            label: '학번(입학년도)',
                            value: _universityEntryYear,
                            max: 0,
                            yearsMode: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            onChanged: (value) {
                              setState(() {
                                _universityEntryYear = value;
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _saving ? null : _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF6A3D),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    '저장하기',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving
                                ? null
                                : () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              '취소',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    if ((_level != _SchoolLevel.university) &&
        (_province == null ||
            _districtSelected == null ||
            _dongSelected == null)) {
      _showError('학교 종류와 지역을 입력해주세요.');
      return;
    }
    if (_schoolController.text.trim().isEmpty) {
      _showError('학교 이름을 입력해주세요.');
      return;
    }
    if ((_level == _SchoolLevel.elementary || _level == _SchoolLevel.middle || _level == _SchoolLevel.high) &&
        _gradeEntries.any((entry) => entry.year <= 0)) {
      _showError('학년별 년도를 모두 선택해주세요.');
      return;
    }
    if (_level == _SchoolLevel.elementary || _level == _SchoolLevel.middle || _level == _SchoolLevel.high) {
      final expected = _level == _SchoolLevel.elementary ? 6 : 3;
      if (_gradeEntries.length != expected) {
        _showError('학년 정보를 모두 입력해주세요.');
        return;
      }
    }
    if (_level == _SchoolLevel.university &&
        _majorController.text.trim().isEmpty) {
      _showError('학과를 입력해주세요.');
      return;
    }

    final record = _SchoolRecord(
      id: widget.initialRecord?.id ?? '',
      level: _level,
      province: _level == _SchoolLevel.university ? '' : _province!.label,
      district: _level == _SchoolLevel.university ? '' : (_districtSelected ?? ''),
      dong: _level == _SchoolLevel.university ? '' : (_dongSelected ?? ''),
      name: _schoolController.text.trim(),
      schoolCode: _selectedSchoolCode,
      campusType: _selectedCampusType,
      grade: null,
      classNumber: null,
      year: null,
      gradeEntries: _level == _SchoolLevel.elementary ||
              _level == _SchoolLevel.middle ||
              _level == _SchoolLevel.high
          ? List<_GradeEntry>.from(_gradeEntries)
          : null,
      kindergartenGradYear: _level == _SchoolLevel.kindergarten
          ? _kindergartenGradYear
          : null,
      universityEntryYear:
          _level == _SchoolLevel.university ? _universityEntryYear : null,
      major: _level == _SchoolLevel.university
          ? _majorController.text.trim()
          : null,
    );
    setState(() {
      _saving = true;
    });
    try {
      final saved = await widget
          .onSave(record)
          .timeout(const Duration(seconds: 12));
      if (!mounted) {
        return;
      }
      if (saved != null) {
        Navigator.of(context).pop(saved);
      }
    } on TimeoutException {
      if (mounted) {
        _showError('저장에 시간이 오래 걸리고 있어요. 네트워크 상태를 확인해주세요.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _onSchoolQueryChanged(String value) {
    _selectedSchoolCode = null;
    _schoolSearchDebounce?.cancel();
    _schoolSearchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) {
        return;
      }
      if (value.trim().length < 2) {
        setState(() {
          _schoolSearchResults = [];
          _schoolSearchError = null;
        });
        return;
      }
      _searchSchools();
    });
  }

  void _onUniversityQueryChanged(String value) {
    _selectedSchoolCode = null;
    _selectedCampusType = null;
    _universitySearchDebounce?.cancel();
    _universitySearchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) {
        return;
      }
      if (value.trim().length < 2) {
        setState(() {
          _universitySearchResults = [];
          _universitySearchError = null;
        });
        return;
      }
      _searchUniversities();
    });
  }

  Future<void> _searchSchools() async {
    if (_level != _SchoolLevel.elementary &&
        _level != _SchoolLevel.middle &&
        _level != _SchoolLevel.high) {
      return;
    }
    if (_province == null ||
        _districtSelected == null ||
        _dongSelected == null) {
      _showError('학교 조회 전에 지역을 먼저 선택해주세요.');
      return;
    }
    final query = _schoolController.text.trim();
    if (query.isEmpty) {
      _showError('학교 이름을 입력해주세요.');
      return;
    }
    setState(() {
      _loadingSchoolSearch = true;
      _schoolSearchError = null;
      _schoolSearchResults = [];
    });
    try {
      final results = await _fetchNeisSchools(query);
      if (!mounted) {
        return;
      }
      final provinceName = _province!.apiName;
      final district = _districtSelected!;
      final dong = _dongSelected!;
      final districtFiltered = results.where((item) {
        if (!_matchesSchoolLevel(item.kind)) {
          return false;
        }
        final address = item.address;
        final location = item.location;
        final hasProvince = address.contains(provinceName) ||
            location == provinceName ||
            location == _province!.label;
        if (!hasProvince) {
          return false;
        }
        if (!address.contains(district)) {
          return false;
        }
        return true;
      }).toList();
      final dongFiltered = dong.isEmpty
          ? districtFiltered
          : districtFiltered
              .where((item) => item.address.contains(dong))
              .toList();
      setState(() {
        final chosen = dongFiltered.isNotEmpty ? dongFiltered : districtFiltered;
        _schoolSearchResults = chosen.take(30).toList();
        if (_schoolSearchResults.isEmpty) {
          _schoolSearchError = '해당 지역의 학교가 없습니다.';
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _schoolSearchError =
              '학교 조회에 실패했습니다. (${e.toString().replaceAll('Exception: ', '')})';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingSchoolSearch = false;
        });
      }
    }
  }

  Future<void> _searchUniversities() async {
    if (_level != _SchoolLevel.university) {
      return;
    }
    final query = _schoolController.text.trim();
    if (query.isEmpty) {
      _showError('대학교 이름을 입력해주세요.');
      return;
    }
    setState(() {
      _loadingUniversitySearch = true;
      _universitySearchError = null;
      _universitySearchResults = [];
    });
    try {
      final results = await _fetchUniversitySchools(query);
      if (!mounted) {
        return;
      }
      setState(() {
        _universitySearchResults = results.take(30).toList();
        if (_universitySearchResults.isEmpty) {
          _universitySearchError = '검색 결과가 없습니다.';
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _universitySearchError =
              '대학교 조회에 실패했습니다. (${e.toString().replaceAll('Exception: ', '')})';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingUniversitySearch = false;
        });
      }
    }
  }

  bool _matchesSchoolLevel(String kind) {
    switch (_level) {
      case _SchoolLevel.elementary:
        return kind.contains('초등학교');
      case _SchoolLevel.middle:
        return kind.contains('중학교');
      case _SchoolLevel.high:
        return kind.contains('고등학교');
      case _SchoolLevel.kindergarten:
      case _SchoolLevel.university:
        return false;
    }
  }

  Future<List<_UniversityItem>> _fetchUniversitySchools(String query) async {
    if (_academyInfoApiKey.isEmpty) {
      throw Exception('AcademyInfo API key missing');
    }
    final current = DateTime.now().year;
    final candidates = <int>[
      if (_academySurveyYear != null) _academySurveyYear!,
      current,
      current - 1,
      current - 2,
      2023,
    ].toSet().toList();
    for (final year in candidates) {
      final response = await _fetchUniversityResponse(query, year);
      if (response.resultCode == '00') {
        _academySurveyYear = year;
        return response.items;
      }
    }
    final last = await _fetchUniversityResponse(query, current);
    throw Exception(last.resultMsg.isNotEmpty ? last.resultMsg : 'API 오류');
  }

  Future<_AcademyResponse> _fetchUniversityResponse(
    String query,
    int year,
  ) async {
    final endpoints = [
      'http://openapi.academyinfo.go.kr/openapi/service/rest/SchoolInfoService/getSchoolInfo',
      'http://www.academyinfo.go.kr/openapi/service/rest/SchoolInfoService/getSchoolInfo',
      'https://www.academyinfo.go.kr/openapi/service/rest/SchoolInfoService/getSchoolInfo',
    ];
    _AcademyResponse? lastResponse;
    final key = _academyInfoApiKey.trim();
    final encodedKey = Uri.encodeQueryComponent(key);
    final encodedQuery = Uri.encodeQueryComponent(query);
    final keyParams = ['serviceKey', 'ServiceKey'];
    final keyValues = [key, encodedKey].toSet().toList();
    for (final baseUrl in endpoints) {
      try {
        for (final keyParam in keyParams) {
          for (final keyValue in keyValues) {
            final uri = Uri.parse(
              '$baseUrl?$keyParam=$keyValue&svyYr=$year&pageNo=1&numOfRows=200&schlKrnNm=$encodedQuery',
            );
            final response = await http.get(uri);
            if (response.statusCode != 200) {
              continue;
            }
            final parsed = _parseUniversityResponse(
              utf8.decode(response.bodyBytes),
            );
            lastResponse = parsed;
            if (parsed.resultCode == '00') {
              return parsed;
            }
          }
        }
      } catch (_) {
        continue;
      }
    }
    if (lastResponse != null) {
      return lastResponse!;
    }
    throw Exception('API 오류');
  }

  _AcademyResponse _parseUniversityResponse(String xmlText) {
    final doc = XmlDocument.parse(xmlText);
    final resultCode = _xmlFirstText(doc, 'resultCode') ?? '';
    final resultMsg = _xmlFirstText(doc, 'resultMsg') ?? '';
    final totalCountText = _xmlFirstText(doc, 'totalCount') ?? '0';
    final totalCount = int.tryParse(totalCountText) ?? 0;
    final items = <_UniversityItem>[];
    for (final item in doc.findAllElements('item')) {
      final name = _xmlFirstText(item, 'schlNm') ??
          _xmlFirstText(item, 'schlKrnNm') ??
          '';
      if (name.trim().isEmpty) {
        continue;
      }
      final campusType = _xmlFirstText(item, 'psbsDivNm') ?? '';
      final division = _xmlFirstText(item, 'schlDivNm') ?? '';
      final address = _xmlFirstText(item, 'postNoAdrs') ?? '';
      final schoolId = _xmlFirstText(item, 'schlId') ?? '';
      items.add(
        _UniversityItem(
          name: name,
          campusType: campusType,
          division: division,
          address: address,
          schoolId: schoolId,
        ),
      );
    }
    return _AcademyResponse(
      resultCode: resultCode,
      resultMsg: resultMsg,
      totalCount: totalCount,
      items: items,
    );
  }

  String? _xmlFirstText(XmlNode node, String tag) {
    final iterator = node.findAllElements(tag).iterator;
    if (!iterator.moveNext()) {
      return null;
    }
    final element = iterator.current;
    final text = element.innerText.trim();
    return text.isEmpty ? null : text;
  }

  Future<List<_NeisSchoolItem>> _fetchNeisSchools(String query) async {
    if (_neisApiKey.isEmpty) {
      throw Exception('NEIS API key missing');
    }
    final uri = Uri.parse('https://open.neis.go.kr/hub/schoolInfo').replace(
      queryParameters: {
        'KEY': _neisApiKey,
        'Type': 'json',
        'pIndex': '1',
        'pSize': '200',
        'SCHUL_NM': query,
        if (_province != null) 'LCTN_SC_NM': _province!.apiName,
      },
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final apiError = _extractNeisApiError(decoded);
    if (apiError != null) {
      throw Exception(apiError);
    }
    final rows = _extractNeisRows(decoded);
    return rows.map(_mapNeisRow).whereType<_NeisSchoolItem>().toList();
  }

  List<Map<String, dynamic>> _extractNeisRows(dynamic decoded) {
    if (decoded is! Map) {
      return [];
    }
    final root = decoded['schoolInfo'];
    if (root is List) {
      for (final item in root) {
        if (item is Map && item['row'] is List) {
          return (item['row'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    }
    return [];
  }

  String? _extractNeisApiError(dynamic decoded) {
    if (decoded is! Map) {
      return null;
    }
    final root = decoded['schoolInfo'];
    if (root is! List) {
      return null;
    }
    for (final item in root) {
      if (item is Map && item['head'] is List) {
        final head = item['head'] as List;
        for (final entry in head) {
          if (entry is Map && entry['RESULT'] is Map) {
            final result = entry['RESULT'] as Map;
            final code = result['CODE']?.toString();
            final message = result['MESSAGE']?.toString();
            if (code != null && code != 'INFO-000') {
              return 'API 오류: $message ($code)';
            }
          }
        }
      }
    }
    return null;
  }

  _NeisSchoolItem? _mapNeisRow(Map<String, dynamic> row) {
    final name = row['SCHUL_NM']?.toString().trim();
    if (name == null || name.isEmpty) {
      return null;
    }
    final code = row['SD_SCHUL_CODE']?.toString().trim() ?? '';
    final address = _firstNonEmptyString([
      row['ORG_RDNMA'],
      row['ORG_RDNDA'],
      row['ORG_ADR'],
      row['ORG_RDNMA'],
    ]);
    final location = row['LCTN_SC_NM']?.toString().trim() ?? '';
    final kind = row['SCHUL_KND_SC_NM']?.toString().trim() ?? '';
    return _NeisSchoolItem(
      name: name,
      address: address,
      location: location,
      kind: kind,
      code: code,
    );
  }

  String _firstNonEmptyString(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }
    return '';
  }

  Future<void> _loadDistricts(String province) async {
    final cached = _districtCache[province];
    if (cached != null && cached.isNotEmpty) {
      setState(() {
        _districtOptions = cached;
        if (_presetDistrict != null && cached.contains(_presetDistrict)) {
          _districtSelected = _presetDistrict;
          _presetDistrict = null;
          final provinceOption = _province;
          if (provinceOption != null && _districtSelected != null) {
            _loadDongs(provinceOption.apiName, _districtSelected!);
          }
        }
      });
      return;
    }
    final globalCached = _globalDistrictCache[province];
    if (globalCached != null && globalCached.isNotEmpty) {
      setState(() {
        _districtOptions = globalCached;
        _districtCache[province] = globalCached;
        if (_presetDistrict != null && globalCached.contains(_presetDistrict)) {
          _districtSelected = _presetDistrict;
          _presetDistrict = null;
          final provinceOption = _province;
          if (provinceOption != null && _districtSelected != null) {
            _loadDongs(provinceOption.apiName, _districtSelected!);
          }
        }
      });
      return;
    }
    setState(() {
      _loadingDistricts = true;
    });
    try {
      if (_globalRegionRows != null && _globalRegionRows!.isNotEmpty) {
        final districts = _globalRegionRows!
            .map((row) => _extractDistrict(row, province))
            .whereType<String>()
            .toSet()
            .toList()
          ..sort();
        if (!mounted) {
          return;
        }
        setState(() {
          _districtOptions = districts;
          if (districts.isNotEmpty) {
            _districtCache[province] = districts;
            _globalDistrictCache[province] = districts;
          }
          if (_presetDistrict != null && districts.contains(_presetDistrict)) {
            _districtSelected = _presetDistrict;
            _presetDistrict = null;
            final provinceOption = _province;
            if (provinceOption != null && _districtSelected != null) {
              _loadDongs(provinceOption.apiName, _districtSelected!);
            }
          }
          if (districts.isEmpty) {
            _regionError = '시/군/구 결과가 없습니다. ($province)';
          }
        });
        return;
      }
      var rows = await _fetchRegionRows(province);
      if (rows.isEmpty) {
        rows = await _fetchAllRows();
      }
      final districts = rows
          .map((row) => _extractDistrict(row, province))
          .whereType<String>()
          .toSet()
          .toList()
        ..sort();
      if (!mounted) {
        return;
      }
      setState(() {
        _districtOptions = districts;
        if (districts.isNotEmpty) {
          _districtCache[province] = districts;
          _globalDistrictCache[province] = districts;
        }
        if (_presetDistrict != null && districts.contains(_presetDistrict)) {
          _districtSelected = _presetDistrict;
          _presetDistrict = null;
          final provinceOption = _province;
          if (provinceOption != null && _districtSelected != null) {
            _loadDongs(provinceOption.apiName, _districtSelected!);
          }
        }
        if (districts.isEmpty) {
          _regionError = '시/군/구 결과가 없습니다. ($province)';
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _regionError = '시/군/구 목록을 불러오지 못했습니다. (${e.toString().replaceAll('Exception: ', '')})';
        });
        _showError(_regionError!);
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingDistricts = false;
        });
      }
    }
  }

  Future<void> _loadDongs(String province, String district) async {
    final cacheKey = '$province|$district';
    final cached = _dongCache[cacheKey];
    if (cached != null && cached.isNotEmpty) {
      setState(() {
        _dongOptions = cached;
        if (_presetDong != null && cached.contains(_presetDong)) {
          _dongSelected = _presetDong;
          _presetDong = null;
        }
      });
      return;
    }
    final globalCached = _globalDongCache[cacheKey];
    if (globalCached != null && globalCached.isNotEmpty) {
      setState(() {
        _dongOptions = globalCached;
        _dongCache[cacheKey] = globalCached;
        if (_presetDong != null && globalCached.contains(_presetDong)) {
          _dongSelected = _presetDong;
          _presetDong = null;
        }
      });
      return;
    }
    setState(() {
      _loadingDongs = true;
    });
    try {
      final query = '$province $district';
      if (_globalRegionRows != null && _globalRegionRows!.isNotEmpty) {
        final dongs = _globalRegionRows!
            .map((row) => _extractDong(row, query))
            .whereType<String>()
            .toSet()
            .toList()
          ..sort();
        if (!mounted) {
          return;
        }
        setState(() {
          _dongOptions = dongs;
          if (dongs.isNotEmpty) {
            _dongCache[cacheKey] = dongs;
            _globalDongCache[cacheKey] = dongs;
          }
          if (_presetDong != null && dongs.contains(_presetDong)) {
            _dongSelected = _presetDong;
            _presetDong = null;
          }
          if (dongs.isEmpty) {
            _regionError = '동/읍/면 결과가 없습니다. ($query)';
          }
        });
        return;
      }
      var rows = await _fetchRegionRows(query);
      if (rows.isEmpty) {
        rows = await _fetchAllRows();
      }
      final dongs = rows
          .map((row) => _extractDong(row, query))
          .whereType<String>()
          .toSet()
          .toList()
        ..sort();
      if (!mounted) {
        return;
      }
      setState(() {
        _dongOptions = dongs;
        if (dongs.isNotEmpty) {
          _dongCache[cacheKey] = dongs;
          _globalDongCache[cacheKey] = dongs;
        }
        if (_presetDong != null && dongs.contains(_presetDong)) {
          _dongSelected = _presetDong;
          _presetDong = null;
        }
        if (dongs.isEmpty) {
          _regionError = '동/읍/면 결과가 없습니다. ($query)';
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _regionError = '동/읍/면 목록을 불러오지 못했습니다. (${e.toString().replaceAll('Exception: ', '')})';
        });
        _showError(_regionError!);
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingDongs = false;
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchRegionRows(String query) async {
    if (_dataGoServiceKey.isEmpty) {
      throw Exception('ServiceKey missing');
    }
    final uri = Uri.parse(
      'https://apis.data.go.kr/1741000/StanReginCd/getStanReginCdList',
    ).replace(
      queryParameters: {
        'ServiceKey': _dataGoServiceKey,
        'serviceKey': _dataGoServiceKey,
        'pageNo': '1',
        'numOfRows': '10000',
        'type': 'json',
        'locatadd_nm': query,
      },
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final apiError = _extractApiError(decoded);
    if (apiError != null) {
      throw Exception(apiError);
    }
    return _extractRows(decoded);
  }

  Future<List<Map<String, dynamic>>> _fetchAllRows() async {
    final cached = _allRegionRowsCache;
    if (cached != null) {
      return cached;
    }
    if (_globalRegionRows != null) {
      _allRegionRowsCache = _globalRegionRows;
      return _globalRegionRows!;
    }
    if (_globalRegionRowsFuture != null) {
      final rows = await _globalRegionRowsFuture!;
      _allRegionRowsCache = rows;
      return rows;
    }
    _globalRegionRowsFuture = () async {
      final allRows = <Map<String, dynamic>>[];
      var page = 1;
      const pageSize = 1000;
      while (page <= 60) {
        final uri = Uri.parse(
          'https://apis.data.go.kr/1741000/StanReginCd/getStanReginCdList',
        ).replace(
          queryParameters: {
            'ServiceKey': _dataGoServiceKey,
            'serviceKey': _dataGoServiceKey,
            'pageNo': '$page',
            'numOfRows': '$pageSize',
            'type': 'json',
          },
        );
        final response = await http.get(uri);
        if (response.statusCode != 200) {
          break;
        }
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final apiError = _extractApiError(decoded);
        if (apiError != null) {
          throw Exception(apiError);
        }
        final rows = _extractRows(decoded);
        if (rows.isEmpty) {
          break;
        }
        allRows.addAll(rows);
        if (rows.length < pageSize) {
          break;
        }
        page += 1;
      }
      _globalRegionRows = allRows;
      return allRows;
    }();
    final rows = await _globalRegionRowsFuture!;
    _allRegionRowsCache = rows;
    _globalRegionRowsFuture = null;
    return rows;
  }

  List<Map<String, dynamic>> _extractRows(dynamic decoded) {
    if (decoded is! Map) {
      return [];
    }
    final root = decoded['StanReginCd'];
    if (root is List) {
      for (final item in root) {
        if (item is Map && item['row'] is List) {
          return (item['row'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
      return [];
    }
    if (root is Map && root['row'] is List) {
      return (root['row'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  String? _extractApiError(dynamic decoded) {
    if (decoded is! Map) {
      return null;
    }
    final root = decoded['StanReginCd'];
    if (root is List) {
      for (final item in root) {
        final error = _extractApiErrorFromItem(item);
        if (error != null) {
          return error;
        }
      }
      return null;
    }
    if (root is Map) {
      return _extractApiErrorFromItem(root);
    }
    return null;
  }

  String? _extractApiErrorFromItem(Map item) {
    if (item['head'] is! List) {
      return null;
    }
    final head = item['head'] as List;
    if (head.isEmpty || head.first is! Map) {
      return null;
    }
    final map = head.first as Map;
    final resultCode = map['RESULT']?['CODE'] ?? map['resultCode'];
    final resultMsg = map['RESULT']?['MESSAGE'] ?? map['resultMsg'];
    if (resultCode != null && resultCode.toString() != '00') {
      return 'API 오류: $resultMsg ($resultCode)';
    }
    return null;
  }

  String? _extractDistrict(Map<String, dynamic> row, String province) {
    final full = row['locatadd_nm'];
    if (full is! String) {
      return null;
    }
    if (!full.startsWith(province)) {
      return null;
    }
    final parts = full.split(' ');
    if (parts.length < 2) {
      return null;
    }
    return parts[1].trim().isEmpty ? null : parts[1].trim();
  }

  String? _extractDong(Map<String, dynamic> row, String prefix) {
    final full = row['locatadd_nm'];
    if (full is! String) {
      return null;
    }
    if (!full.startsWith(prefix)) {
      return null;
    }
    final parts = full.split(' ');
    if (parts.length < 3) {
      return null;
    }
    return parts[2].trim().isEmpty ? null : parts[2].trim();
  }

  String get _schoolInfoTitle {
    switch (_level) {
      case _SchoolLevel.kindergarten:
        return '유치원 정보';
      case _SchoolLevel.elementary:
        return '초등학교 정보';
      case _SchoolLevel.middle:
        return '중학교 정보';
      case _SchoolLevel.high:
        return '고등학교 정보';
      case _SchoolLevel.university:
        return '대학교 정보';
    }
  }

  String get _schoolNameHint {
    switch (_level) {
      case _SchoolLevel.kindergarten:
        return '유치원 이름 입력';
      case _SchoolLevel.elementary:
        return '초등학교 이름 입력';
      case _SchoolLevel.middle:
        return '중학교 이름 입력';
      case _SchoolLevel.high:
        return '고등학교 이름 입력';
      case _SchoolLevel.university:
        return '대학교 이름 입력';
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE7E2F5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE7E2F5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFBFA7FF), width: 1.2),
      ),
    );
  }
}

class _NumberPickerField extends StatelessWidget {
  const _NumberPickerField({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
    this.yearsMode = false,
    this.allowZero = false,
    this.yearSuffix = '',
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 6,
    ),
  });

  final String label;
  final int value;
  final int max;
  final ValueChanged<int> onChanged;
  final bool yearsMode;
  final bool allowZero;
  final String yearSuffix;
  final EdgeInsets contentPadding;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE7E2F5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE7E2F5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFBFA7FF), width: 1.2),
        ),
        isDense: true,
        contentPadding: contentPadding,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isDense: true,
          isExpanded: true,
          items: yearsMode
              ? _yearItems(yearSuffix)
              : List.generate(
                  max,
                  (index) => DropdownMenuItem(
                    value: allowZero ? index : index + 1,
                    child: Text('${allowZero ? index : index + 1}'),
                  ),
                ),
          onChanged: (next) {
            if (next == null) {
              return;
            }
            onChanged(next);
          },
        ),
      ),
    );
  }

  List<DropdownMenuItem<int>> _yearItems(String suffix) {
    final current = DateTime.now().year;
    final start = current - 80;
    return List.generate(
      81,
      (index) {
        final year = start + index;
        final label = suffix.isEmpty ? '$year' : '$year년$suffix';
        return DropdownMenuItem(
          value: year,
          child: Text(label),
        );
      },
    ).reversed.toList();
  }
}


class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0EAFB)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2F1650).withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6D5F9B),
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _RegionStatus extends StatelessWidget {
  const _RegionStatus({
    required this.districts,
    required this.dongs,
    required this.loadingDistricts,
    required this.loadingDongs,
    required this.error,
  });

  final int districts;
  final int dongs;
  final bool loadingDistricts;
  final bool loadingDongs;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final status = error ??
        '시/군/구 $districts개, 동/읍/면 $dongs개'
            '${loadingDistricts ? ' · 시/군/구 로딩중' : ''}'
            '${loadingDongs ? ' · 동/읍/면 로딩중' : ''}';
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          color: error == null ? const Color(0xFF9B9B9B) : const Color(0xFFE53935),
          fontWeight: error == null ? FontWeight.w500 : FontWeight.w700,
        ),
      ),
    );
  }
}

class _SchoolCard extends StatelessWidget {
  const _SchoolCard({
    required this.record,
    required this.onEdit,
    required this.onDelete,
  });

  final _SchoolRecord record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: record.level.tint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: record.level.assetPath == null
                ? Icon(record.level.icon, color: record.level.iconColor)
                : SvgPicture.asset(
                    record.level.assetPath!,
                    colorFilter: ColorFilter.mode(
                      record.level.iconColor,
                      BlendMode.srcIn,
                    ),
                    width: 18,
                    height: 14,
                    fit: BoxFit.contain,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  record.subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8A8A8A),
                  ),
                ),
                if (record.footer.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  if (record.level == _SchoolLevel.kindergarten &&
                      record.kindergartenGradYear != null)
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF3A8DFF),
                          fontWeight: FontWeight.w600,
                        ),
                        children: [
                          TextSpan(text: '${record.kindergartenGradYear}년 '),
                          const TextSpan(
                            text: '2월',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const TextSpan(text: ' 졸업'),
                        ],
                      ),
                    )
                  else
                    Text(
                      record.footer,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF3A8DFF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFFBDBDBD)),
            onSelected: (value) {
              if (value == 'edit') {
                onEdit();
              } else if (value == 'delete') {
                onDelete();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'edit',
                child: Text('수정'),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text('삭제'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _SchoolLevel {
  kindergarten('유치원', 'kindergarten', Icons.child_care_rounded, Color(0xFFFFF4F7), Color(0xFFFF7AA2)),
  elementary('초등학교', 'elementary', Icons.account_balance_rounded, Color(0xFFEFF7FF), Color(0xFF3A8DFF)),
  middle('중학교', 'middle', Icons.menu_book_rounded, Color(0xFFEAFBF1), Color(0xFF22C55E)),
  high('고등학교', 'high', Icons.school_rounded, Color(0xFFF1F1FF), Color(0xFF6D5BD0)),
  university('대학교', 'university', Icons.apartment_rounded, Color(0xFFFFF3E9), Color(0xFFFF7A3D));

  const _SchoolLevel(this.label, this.key, this.icon, this.tint, this.iconColor,
      {this.assetPath});

  final String label;
  final String key;
  final IconData icon;
  final Color tint;
  final Color iconColor;
  final String? assetPath;

  static _SchoolLevel? fromKey(String? key) {
    if (key == null) {
      return null;
    }
    for (final level in _SchoolLevel.values) {
      if (level.key == key) {
        return level;
      }
    }
    return null;
  }
}

class _SchoolRecord {
  _SchoolRecord({
    required this.id,
    required this.level,
    required this.province,
    required this.district,
    required this.dong,
    required this.name,
    this.schoolCode,
    this.campusType,
    this.grade,
    this.classNumber,
    this.year,
    this.gradeEntries,
    this.kindergartenGradYear,
    this.universityEntryYear,
    this.major,
  });

  final String id;
  final _SchoolLevel level;
  final String province;
  final String district;
  final String dong;
  final String name;
  final String? schoolCode;
  final String? campusType;
  final int? grade;
  final int? classNumber;
  final int? year;
  final List<_GradeEntry>? gradeEntries;
  final int? kindergartenGradYear;
  final int? universityEntryYear;
  final String? major;

  _SchoolRecord copyWith({
    String? id,
    _SchoolLevel? level,
    String? province,
    String? district,
    String? dong,
    String? name,
    String? schoolCode,
    String? campusType,
    int? grade,
    int? classNumber,
    int? year,
    List<_GradeEntry>? gradeEntries,
    int? kindergartenGradYear,
    int? universityEntryYear,
    String? major,
  }) {
    return _SchoolRecord(
      id: id ?? this.id,
      level: level ?? this.level,
      province: province ?? this.province,
      district: district ?? this.district,
      dong: dong ?? this.dong,
      name: name ?? this.name,
      schoolCode: schoolCode ?? this.schoolCode,
      campusType: campusType ?? this.campusType,
      grade: grade ?? this.grade,
      classNumber: classNumber ?? this.classNumber,
      year: year ?? this.year,
      gradeEntries: gradeEntries ?? this.gradeEntries,
      kindergartenGradYear: kindergartenGradYear ?? this.kindergartenGradYear,
      universityEntryYear: universityEntryYear ?? this.universityEntryYear,
      major: major ?? this.major,
    );
  }

  static _SchoolRecord? fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final level = _SchoolLevel.fromKey(data['level'] as String?);
    if (level == null) {
      return null;
    }
    final name = data['name'] as String?;
    final province = data['province'] as String?;
    final district = data['district'] as String?;
    final dong = data['dong'] as String?;
    final schoolCode = data['schoolCode'] as String?;
    final campusType = data['campusType'] as String?;
    if (name == null || province == null || district == null || dong == null) {
      return null;
    }
    return _SchoolRecord(
      id: id,
      level: level,
      name: name,
      province: province,
      district: district,
      dong: dong,
      schoolCode: schoolCode,
      campusType: campusType,
      grade: _parseFlexibleInt(data['grade']),
      classNumber: _parseFlexibleInt(data['classNumber']),
      year: _parseFlexibleInt(data['year']),
      gradeEntries: _GradeEntry.fromFirestoreList(data['gradeEntries']),
      kindergartenGradYear: _parseFlexibleInt(data['kindergartenGradYear']),
      universityEntryYear: _parseFlexibleInt(data['universityEntryYear']),
      major: data['major'] as String?,
    );
  }

  static int? _parseFlexibleInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toInt();
    }
    final text = value.toString().trim();
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return null;
    }
    return int.tryParse(digits);
  }

  String get locationLabel {
    final parts = [province, district, dong].where((value) => value.isNotEmpty);
    return parts.join(' ');
  }

  String get subtitle {
    final location = locationLabel;
    if (location.isEmpty) {
      return level.label;
    }
    return '$location · ${level.label}';
  }

  String get footer {
    if (level == _SchoolLevel.university) {
      final entry = universityEntryYear != null ? '${universityEntryYear}학번' : '';
      if ((major ?? '').isNotEmpty && entry.isNotEmpty) {
        return '${major!} · $entry';
      }
      return (major ?? '').isNotEmpty ? major! : entry;
    }
    if (level == _SchoolLevel.kindergarten) {
      return kindergartenGradYear != null ? '${kindergartenGradYear}년 졸업' : '';
    }
    if (level == _SchoolLevel.elementary ||
        level == _SchoolLevel.middle ||
        level == _SchoolLevel.high) {
      final year = graduationYear;
      return year != null ? '${year}년 2월 졸업' : '';
    }
    if (gradeEntries != null && gradeEntries!.isNotEmpty) {
      final range = '${gradeEntries!.first.grade}~${gradeEntries!.last.grade}학년';
      return '$range 기록';
    }
    if (grade != null && classNumber != null) {
      if (year != null) {
        return '$grade학년 $classNumber반 · ${year}년';
      }
      return '$grade학년 $classNumber반';
    }
    return '';
  }

  int? get graduationYear {
    if (level == _SchoolLevel.kindergarten) {
      return kindergartenGradYear;
    }
    if (level == _SchoolLevel.university) {
      return null;
    }
    if (gradeEntries != null && gradeEntries!.isNotEmpty) {
      final expected = level == _SchoolLevel.elementary ? 6 : 3;
      final lastGradeYear = gradeEntries!
          .where((entry) => entry.grade == expected)
          .map((entry) => entry.year)
          .whereType<int>()
          .where((year) => year > 0)
          .toList();
      if (lastGradeYear.isNotEmpty) {
        return lastGradeYear.first + 1;
      }
      final fallbackYears = gradeEntries!
          .map((entry) => entry.year)
          .whereType<int>()
          .where((year) => year > 0)
          .toList();
      if (fallbackYears.isNotEmpty) {
        return fallbackYears.reduce((a, b) => a > b ? a : b) + 1;
      }
    }
    if (year != null && grade != null) {
      final expected = level == _SchoolLevel.elementary ? 6 : 3;
      if (grade! >= 1 && grade! <= expected) {
        return year! + (expected - grade!) + 1;
      }
    }
    return null;
  }

}

class _NeisSchoolItem {
  _NeisSchoolItem({
    required this.name,
    required this.address,
    required this.location,
    required this.kind,
    required this.code,
  });

  final String name;
  final String address;
  final String location;
  final String kind;
  final String code;
}

class _UniversityItem {
  _UniversityItem({
    required this.name,
    required this.campusType,
    required this.division,
    required this.address,
    required this.schoolId,
  });

  final String name;
  final String campusType;
  final String division;
  final String address;
  final String schoolId;
}

class _AcademyResponse {
  _AcademyResponse({
    required this.resultCode,
    required this.resultMsg,
    required this.totalCount,
    required this.items,
  });

  final String resultCode;
  final String resultMsg;
  final int totalCount;
  final List<_UniversityItem> items;
}

class _NeighborhoodRecord {
  _NeighborhoodRecord({
    required this.id,
    required this.province,
    required this.district,
    required this.dong,
    required this.startYear,
    required this.endYear,
    this.note,
    this.favoritePlace,
    this.nickname,
    this.moveReason,
    this.bestFriend,
  });

  final String id;
  final String province;
  final String district;
  final String dong;
  final int startYear;
  final int endYear;
  final String? note;
  final String? favoritePlace;
  final String? nickname;
  final String? moveReason;
  final String? bestFriend;

  String get title {
    final parts = [province, district, dong].where((value) => value.isNotEmpty);
    return parts.join(' ');
  }

  String get periodLabel => '$startYear-$endYear';

  _NeighborhoodRecord copyWith({
    String? id,
    String? province,
    String? district,
    String? dong,
    int? startYear,
    int? endYear,
    String? note,
    String? favoritePlace,
    String? nickname,
    String? moveReason,
    String? bestFriend,
  }) {
    return _NeighborhoodRecord(
      id: id ?? this.id,
      province: province ?? this.province,
      district: district ?? this.district,
      dong: dong ?? this.dong,
      startYear: startYear ?? this.startYear,
      endYear: endYear ?? this.endYear,
      note: note ?? this.note,
      favoritePlace: favoritePlace ?? this.favoritePlace,
      nickname: nickname ?? this.nickname,
      moveReason: moveReason ?? this.moveReason,
      bestFriend: bestFriend ?? this.bestFriend,
    );
  }

  static _NeighborhoodRecord? fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final province = data['province'] as String?;
    final district = data['district'] as String?;
    final dong = data['dong'] as String?;
    final startYear = (data['startYear'] as num?)?.toInt();
    final endYear = (data['endYear'] as num?)?.toInt();
    if (province == null ||
        district == null ||
        dong == null ||
        startYear == null ||
        endYear == null) {
      return null;
    }
    return _NeighborhoodRecord(
      id: id,
      province: province,
      district: district,
      dong: dong,
      startYear: startYear,
      endYear: endYear,
      note: data['note'] as String?,
      favoritePlace: data['favoritePlace'] as String?,
      nickname: data['nickname'] as String?,
      moveReason: data['moveReason'] as String?,
      bestFriend: data['bestFriend'] as String?,
    );
  }
}

class _MemoryRecord {
  _MemoryRecord({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    required this.tags,
    this.emotion,
    this.timeCapsule,
    this.song,
    this.smell,
    this.weather,
  });

  final String id;
  final String title;
  final String content;
  final DateTime date;
  final List<String> tags;
  final _EmotionPreset? emotion;
  final String? timeCapsule;
  final String? song;
  final String? smell;
  final String? weather;

  String get dateLabel {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  _MemoryRecord copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? date,
    List<String>? tags,
    _EmotionPreset? emotion,
    String? timeCapsule,
    String? song,
    String? smell,
    String? weather,
  }) {
    return _MemoryRecord(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      date: date ?? this.date,
      tags: tags ?? this.tags,
      emotion: emotion ?? this.emotion,
      timeCapsule: timeCapsule ?? this.timeCapsule,
      song: song ?? this.song,
      smell: smell ?? this.smell,
      weather: weather ?? this.weather,
    );
  }

  static _MemoryRecord? fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final title = data['title'] as String?;
    final content = data['content'] as String?;
    final rawDate = data['date'];
    DateTime? date;
    if (rawDate is Timestamp) {
      date = rawDate.toDate();
    } else if (rawDate is String) {
      date = DateTime.tryParse(rawDate);
    }
    if (title == null || content == null || date == null) {
      return null;
    }
    final tags = (data['tags'] as List?)
            ?.whereType<String>()
            .toList() ??
        <String>[];
    final emotionKey = data['emotion'] as String?;
    final emotion = _EmotionPreset.fromKey(emotionKey);
    return _MemoryRecord(
      id: id,
      title: title,
      content: content,
      date: date,
      tags: tags,
      emotion: emotion,
      timeCapsule: data['timeCapsule'] as String?,
      song: data['song'] as String?,
      smell: data['smell'] as String?,
      weather: data['weather'] as String?,
    );
  }
}

class _MemorySenseRow extends StatelessWidget {
  const _MemorySenseRow({this.song, this.smell, this.weather});

  final String? song;
  final String? smell;
  final String? weather;

  @override
  Widget build(BuildContext context) {
    final items = <String>[];
    if (song != null && song!.trim().isNotEmpty) {
      items.add('🎵 ${song!}');
    }
    if (smell != null && smell!.trim().isNotEmpty) {
      items.add('🌿 ${smell!}');
    }
    if (weather != null && weather!.trim().isNotEmpty) {
      items.add('☁️ ${weather!}');
    }
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: items
          .map(
            (item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF2EEFF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                item,
                style: const TextStyle(fontSize: 11, color: Color(0xFF6B4DD6)),
              ),
            ),
          )
          .toList(),
    );
  }
}

enum _EmotionPreset {
  happy('happy', '행복', '😊', Color(0xFFFFB74D)),
  touched('touched', '감동', '🥹', Color(0xFFFF8A80)),
  excited('excited', '설렘', '✨', Color(0xFFBA68C8)),
  nervous('nervous', '긴장', '😳', Color(0xFF64B5F6)),
  calm('calm', '평온', '🌿', Color(0xFF81C784)),
  sad('sad', '그리움', '🌧️', Color(0xFF90A4AE));

  const _EmotionPreset(this.key, this.label, this.emoji, this.color);

  final String key;
  final String label;
  final String emoji;
  final Color color;

  static _EmotionPreset? fromKey(String? key) {
    if (key == null) {
      return null;
    }
    for (final preset in _EmotionPreset.values) {
      if (preset.key == key) {
        return preset;
      }
    }
    return null;
  }
}

class _ProvinceOption {
  const _ProvinceOption(this.label, this.apiName);

  final String label;
  final String apiName;
}

class _MediaItem {
  _MediaItem({
    required this.isVideo,
    this.file,
    this.id,
    this.url,
    this.thumbnailUrl,
    this.storagePath,
    this.thumbnailPath,
    this.uploading = false,
    this.uploadFailed = false,
    this.uploadProgress = 0,
  });

  factory _MediaItem.local({required XFile file, required bool isVideo}) {
    return _MediaItem(
      file: file,
      isVideo: isVideo,
      uploading: true,
      uploadProgress: 0,
    );
  }

  factory _MediaItem.fromFirestore(String id, Map<String, dynamic> data) {
    return _MediaItem(
      id: id,
      isVideo: data['isVideo'] == true,
      url: data['url'] as String?,
      thumbnailUrl: data['thumbnailUrl'] as String?,
      storagePath: data['storagePath'] as String?,
      thumbnailPath: data['thumbnailPath'] as String?,
      uploading: false,
      uploadProgress: 1.0,
    );
  }

  final XFile? file;
  final bool isVideo;
  String? id;
  String? url;
  String? thumbnailUrl;
  String? storagePath;
  String? thumbnailPath;
  bool uploading;
  bool uploadFailed;
  double uploadProgress;
}

class _PhotoTab extends StatelessWidget {
  const _PhotoTab({
    required this.items,
    required this.onUploadTap,
    required this.onFileSelectTap,
    required this.loading,
    required this.error,
    required this.onDeleteTap,
  });

  final List<_MediaItem> items;
  final VoidCallback onUploadTap;
  final VoidCallback onFileSelectTap;
  final bool loading;
  final String? error;
  final ValueChanged<_MediaItem> onDeleteTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PhotoHeader(onUploadTap: onUploadTap),
        const SizedBox(height: 16),
        _UploadCard(onTap: onFileSelectTap),
        if (loading)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: _EmptyHint(
              icon: Icons.hourglass_bottom_rounded,
              title: '사진을 불러오는 중이에요',
              subtitle: '잠시만 기다려주세요',
            ),
          )
        else if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: _EmptyHint(
              icon: Icons.error_outline_rounded,
              title: '사진을 불러오지 못했어요',
              subtitle: error!,
            ),
          )
        else if (items.isNotEmpty) ...[
          const SizedBox(height: 16),
          _MediaGrid(items: items, onDeleteTap: onDeleteTap),
        ],
      ],
    );
  }
}

class _PhotoHeader extends StatelessWidget {
  const _PhotoHeader({required this.onUploadTap});

  final VoidCallback onUploadTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFFFEEF4),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.photo_camera_rounded, color: Color(0xFFFF4D88)),
        ),
        const SizedBox(width: 10),
        const Text(
          '사진 & 동영상',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: onUploadTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF4D88),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            elevation: 0,
          ),
          icon: const Icon(Icons.add, size: 18, color: Colors.white),
          label: const Text(
            '업로드',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _UploadCard extends StatelessWidget {
  const _UploadCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _DashedBorderBox(
      borderRadius: 20,
      dashWidth: 8,
      dashGap: 6,
      color: const Color(0xFFFFB4CC),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEEF4),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.photo_camera_rounded,
                  color: Color(0xFFFF4D88), size: 28),
            ),
            const SizedBox(height: 14),
            const Text(
              '사진과 동영상을 업로드하세요',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              '소중한 추억들을 사진과 동영상으로 보관해보세요',
              style: TextStyle(fontSize: 12, color: Color(0xFF8A8A8A)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4D88),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text(
                '파일 선택하기',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaGrid extends StatelessWidget {
  const _MediaGrid({required this.items, required this.onDeleteTap});

  final List<_MediaItem> items;
  final ValueChanged<_MediaItem> onDeleteTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            color: const Color(0xFFF7F7F7),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _MediaPreview(item: item),
                if (item.isVideo)
                  const Align(
                    alignment: Alignment.center,
                    child: Icon(Icons.play_circle_fill_rounded,
                        color: Colors.white, size: 36),
                  ),
                if (item.uploading)
                  Container(
                    color: Colors.black.withOpacity(0.45),
                    child: Center(
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          value: item.uploadProgress > 0 && item.uploadProgress < 1
                              ? item.uploadProgress
                              : null,
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                  ),
                if (item.uploadFailed)
                  Container(
                    color: Colors.black.withOpacity(0.4),
                    child: const Center(
                      child: Icon(Icons.error_outline_rounded,
                          color: Colors.white, size: 32),
                    ),
                  ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () => onDeleteTap(item),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MediaPreview extends StatelessWidget {
  const _MediaPreview({required this.item});

  final _MediaItem item;

  @override
  Widget build(BuildContext context) {
    if (item.isVideo) {
      if (item.thumbnailUrl != null) {
        return Image.network(item.thumbnailUrl!, fit: BoxFit.cover);
      }
      if (item.file != null && !kIsWeb) {
        return Image.file(File(item.file!.path), fit: BoxFit.cover);
      }
      return const SizedBox.shrink();
    }
    if (item.url != null) {
      return Image.network(item.url!, fit: BoxFit.cover);
    }
    if (item.file == null) {
      return const SizedBox.shrink();
    }
    if (kIsWeb) {
      return Image.network(item.file!.path, fit: BoxFit.cover);
    }
    return Image.file(File(item.file!.path), fit: BoxFit.cover);
  }
}

class _DashedBorderBox extends StatelessWidget {
  const _DashedBorderBox({
    required this.child,
    required this.color,
    this.borderRadius = 16,
    this.dashWidth = 6,
    this.dashGap = 4,
  });

  final Widget child;
  final Color color;
  final double borderRadius;
  final double dashWidth;
  final double dashGap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: color,
        radius: borderRadius,
        dashWidth: dashWidth,
        dashGap: dashGap,
      ),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.dashWidth,
    required this.dashGap,
  });

  final Color color;
  final double radius;
  final double dashWidth;
  final double dashGap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) {
      return;
    }
    final metric = metrics.first;
    double distance = 0;
    while (distance < metric.length) {
      final length = dashWidth;
      final next = distance + length;
      canvas.drawPath(metric.extractPath(distance, next), paint);
      distance = next + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.dashGap != dashGap;
  }
}

class _GradeEntry {
  _GradeEntry({
    required this.grade,
    required this.year,
    this.classNumber,
  });

  final int grade;
  final int year;
  final int? classNumber;

  _GradeEntry copyWith({
    int? grade,
    int? year,
    int? classNumber,
    bool clearClassNumber = false,
  }) {
    return _GradeEntry(
      grade: grade ?? this.grade,
      year: year ?? this.year,
      classNumber: clearClassNumber ? null : (classNumber ?? this.classNumber),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'grade': grade,
      'year': year,
      'classNumber': classNumber,
    };
  }

  static List<_GradeEntry>? fromFirestoreList(dynamic value) {
    if (value is! List) {
      return null;
    }
    final entries = value
        .whereType<Map>()
        .map((entry) {
          final grade = (entry['grade'] as num?)?.toInt();
          final year = (entry['year'] as num?)?.toInt();
          if (grade == null || year == null) {
            return null;
          }
          return _GradeEntry(
            grade: grade,
            year: year,
            classNumber: (entry['classNumber'] as num?)?.toInt(),
          );
        })
        .whereType<_GradeEntry>()
        .toList();
    if (entries.isEmpty) {
      return null;
    }
    entries.sort((a, b) => a.grade.compareTo(b.grade));
    return entries;
  }
}

class _GradeRow extends StatelessWidget {
  const _GradeRow({
    super.key,
    required this.entry,
    required this.maxClass,
    required this.maxGrade,
    required this.onChanged,
  });

  final _GradeEntry entry;
  final int maxClass;
  final int maxGrade;
  final ValueChanged<_GradeEntry> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F7FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDE6FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 56,
                child: Text(
                  '${entry.grade}학년',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    key: ValueKey(
                      'grade-${entry.grade}-class-${entry.classNumber ?? -1}',
                    ),
                    value: entry.classNumber?.toString() ?? 'unknown',
                    isDense: true,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String>(
                        value: 'unknown',
                        child: Text('모름'),
                      ),
                      ...List.generate(
                        maxClass,
                        (index) => DropdownMenuItem<String>(
                          value: '${index + 1}',
                          child: Text('${index + 1}반'),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      onChanged(
                        entry.copyWith(
                          classNumber:
                              value == 'unknown' ? null : int.parse(value),
                          clearClassNumber: value == 'unknown',
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: entry.year,
                    isDense: true,
                    isExpanded: true,
                    items: _yearItems(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      onChanged(entry.copyWith(year: value));
                    },
                  ),
                ),
              ),
            ],
          ),
          if (entry.year != null && entry.grade == maxGrade) ...[
            const SizedBox(height: 6),
            Text(
              _graduationHint(entry.year!),
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<DropdownMenuItem<int>> _yearItems() {
    final current = DateTime.now().year;
    final start = current - 80;
    return List.generate(
      81,
      (index) {
        final year = start + index;
        return DropdownMenuItem(
          value: year,
          child: Text('$year년'),
        );
      },
    ).reversed.toList();
  }

  String _graduationHint(int lastYear) {
    final gradYear = lastYear + 1;
    return '${gradYear}년 2월 졸업';
  }
}
