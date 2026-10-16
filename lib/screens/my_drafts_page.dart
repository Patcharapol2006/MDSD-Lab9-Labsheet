import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../database/app_database.dart';
import '../repositories/listing_draft_repository.dart';
import '../models/item.dart';
import '../repositories/item_repository_firestore.dart';

class MyDraftsPage extends StatefulWidget {
  final ListingDraftRepository repository;

  const MyDraftsPage({super.key, required this.repository});

  @override
  State<MyDraftsPage> createState() => _MyDraftsPageState();
}

class _MyDraftsPageState extends State<MyDraftsPage> {
  late Future<List<ListingDraftRow>> _draftsFuture;
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _draftsFuture = widget.repository.getAllDrafts();
  }

  Future<void> _deleteDraft(int id) async {
    try {
      await widget.repository.deleteDraft(id);
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ลบร่างประกาศแล้ว')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ลบร่างประกาศไม่สำเร็จ: $error')),
      );
    }
  }

  Future<double?> _askPrice() async {
    return showDialog<double>(
      context: context,
      builder: (_) => const _PriceDialog(),
    );
  }

  Future<void> _postDraft(ListingDraftRow draft) async {
    if (_isPosting) return;
    final price = await _askPrice();
    if (price == null || !mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณาเข้าสู่ระบบก่อนโพสต์สินค้า')));
      return;
    }
    setState(() => _isPosting = true);
    try {
      final item = Item(
        id: 0,
        title: draft.title,
        category: draft.category,
        description: draft.description,
        price: price,
        // The image stays on this device; uploading it requires Firebase Storage.
        imageUrl: draft.imagePath,
        sellerId: user.uid,
      );
      await ItemRepositoryFirestore().postItem(item);
      await widget.repository.deleteDraft(draft.id);
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('โพสต์ข้อมูลแล้ว รูปภาพเก็บไว้ในเครื่องนี้')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('โพสต์ข้อมูลไม่สำเร็จ: $error')));
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${twoDigits(local.day)}/${twoDigits(local.month)}/${local.year} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ร่างประกาศของฉัน')),
      body: Stack(children: [FutureBuilder<List<ListingDraftRow>>(
        future: _draftsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('โหลดร่างประกาศไม่สำเร็จ: ${snapshot.error}'));
          }
          final drafts = snapshot.data ?? [];
          if (drafts.isEmpty) {
            return const Center(child: Text('ยังไม่มีร่างประกาศที่บันทึกไว้'));
          }
          return ListView.builder(
            itemCount: drafts.length,
            itemBuilder: (context, index) {
              final draft = drafts[index];
              return ListTile(
                title: Text(draft.title),
                subtitle: Text(
                  'หมวดหมู่: ${draft.category}\n'
                  'แก้ไขล่าสุด: ${_formatDateTime(draft.updatedAt)}',
                ),
                isThreeLine: true,
                trailing: Wrap(children: [
                  TextButton.icon(onPressed: _isPosting ? null : () => _postDraft(draft), icon: const Icon(Icons.publish), label: const Text('โพสต์ขายจริง')),
                  IconButton(
                    tooltip: 'ลบร่างประกาศ', icon: const Icon(Icons.delete_outline),
                    onPressed: _isPosting ? null : () => _deleteDraft(draft.id),
                  ),
                ],
                ),
              );
            },
          );
        },
      ), if (_isPosting) const Positioned.fill(child: ColoredBox(color: Color(0x66000000), child: Center(child: Card(child: Padding(padding: EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 12), Text('กำลังโพสต์ข้อมูลสินค้า...')]))))))]),
    );
  }
}

class _PriceDialog extends StatefulWidget {
  const _PriceDialog();

  @override
  State<_PriceDialog> createState() => _PriceDialogState();
}

class _PriceDialogState extends State<_PriceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(double.parse(_priceController.text.trim()));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('กำหนดราคาสินค้า'),
        content: Form(
          key: _formKey,
          child: TextFormField(
            controller: _priceController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'ราคา (บาท)'),
            validator: (value) {
              final price = double.tryParse(value?.trim() ?? '');
              return price == null || price <= 0
                  ? 'กรุณากรอกราคามากกว่า 0'
                  : null;
            },
            onFieldSubmitted: (_) => _submit(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(onPressed: _submit, child: const Text('ยืนยัน')),
        ],
      );
}
