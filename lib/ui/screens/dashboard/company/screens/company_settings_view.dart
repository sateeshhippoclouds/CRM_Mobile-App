import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:stacked/stacked.dart';

import 'company_settings_viewmodel.dart';
import 'crm_widgets.dart';

class CompanySettingsView extends StatelessWidget {
  const CompanySettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<CompanySettingsViewModel>.reactive(
      viewModelBuilder: () => CompanySettingsViewModel(),
      onViewModelReady: (m) => m.init(),
      builder: (context, model, _) {
        return Scaffold(
          backgroundColor: kCrmBg,
          appBar: crmAppBar('Settings'),
          body: model.isBusy
              ? const Center(
                  child: CircularProgressIndicator(color: kCrmBlue))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _LogoCard(model: model),
                    const SizedBox(height: 16),
                    _BankCard(model: model),
                    const SizedBox(height: 16),
                    _ImageCard(
                      title: 'Digital Signature',
                      field: 'digisign',
                      imageUrl: model.digisignUrl,
                      model: model,
                    ),
                    const SizedBox(height: 16),
                    _ImageCard(
                      title: 'Letterhead',
                      field: 'letterhead',
                      imageUrl: model.letterheadUrl,
                      model: model,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
        );
      },
    );
  }
}

// ── Company Logo Card ─────────────────────────────────────────────────────────

class _LogoCard extends StatefulWidget {
  const _LogoCard({required this.model});
  final CompanySettingsViewModel model;

  @override
  State<_LogoCard> createState() => _LogoCardState();
}

class _LogoCardState extends State<_LogoCard> {
  File? _picked;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xfile =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (xfile != null) setState(() => _picked = File(xfile.path));
  }

  Future<void> _upload() async {
    if (_picked == null) return;
    final err = await widget.model.uploadFile('logo', _picked!);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Upload failed: $err')));
    } else {
      setState(() => _picked = null);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logo uploaded successfully')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final uploading = model.isUploading('logo');
    return _SettingsCard(
      title: 'Company Logo',
      child: Column(
        children: [
          Container(
            width: double.infinity,
            height: 160,
            decoration: BoxDecoration(
              color: const Color(0xffF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xffE5E7EB)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _picked != null
                  ? Image.file(_picked!, fit: BoxFit.contain)
                  : model.logoUrl != null
                      ? CachedNetworkImage(
                          imageUrl: model.logoUrl!,
                          fit: BoxFit.contain,
                          placeholder: (_, __) => const Center(
                              child: CircularProgressIndicator(
                                  color: kCrmBlue, strokeWidth: 2)),
                          errorWidget: (_, __, ___) => const _EmptyImageHint(
                              icon: Icons.business_rounded,
                              text: 'No logo uploaded'),
                        )
                      : const _EmptyImageHint(
                          icon: Icons.business_rounded,
                          text: 'No logo uploaded'),
            ),
          ),
          const SizedBox(height: 16),
          _UploadButtons(
            onSelect: uploading ? null : _pickImage,
            onUpload: (_picked == null || uploading) ? null : _upload,
            uploading: uploading,
          ),
        ],
      ),
    );
  }
}

// ── Bank Account Card ─────────────────────────────────────────────────────────

class _BankCard extends StatelessWidget {
  const _BankCard({required this.model});
  final CompanySettingsViewModel model;

  @override
  Widget build(BuildContext context) {
    final b = model.bank;
    return _SettingsCard(
      title: 'Bank Account Details',
      trailing: IconButton(
        icon: const Icon(Icons.edit_rounded, color: kCrmBlue, size: 20),
        tooltip: 'Edit',
        onPressed: () => _showEditDialog(context),
      ),
      child: Column(
        children: [
          _BankField('Account Holder Name',
              b['accountholdername']?.toString() ?? '—'),
          _BankField(
              'Account Number', b['accountnumber']?.toString() ?? '—'),
          _BankField('IFSC Code', b['ifsccode']?.toString() ?? '—'),
          _BankField('Bank Name', b['bankname']?.toString() ?? '—'),
          _BankField('Branch Name', b['branchname']?.toString() ?? '—'),
          _BankField(
              'Branch Address', b['branchaddress']?.toString() ?? '—'),
          _BankField('MICR Code', b['micrcode']?.toString() ?? '—'),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _BankEditDialog(model: model),
    );
  }
}

class _BankField extends StatelessWidget {
  const _BankField(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              const TextStyle(fontSize: 12, color: Color(0xff6B7280)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xffE5E7EB))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xffE5E7EB))),
          filled: true,
          fillColor: const Color(0xffF9FAFB),
        ),
        child: Text(value,
            style: const TextStyle(fontSize: 14, color: Color(0xff374151))),
      ),
    );
  }
}

// ── Bank Edit Dialog ──────────────────────────────────────────────────────────

class _BankEditDialog extends StatefulWidget {
  const _BankEditDialog({required this.model});
  final CompanySettingsViewModel model;

  @override
  State<_BankEditDialog> createState() => _BankEditDialogState();
}

class _BankEditDialogState extends State<_BankEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _holderCtrl;
  late final TextEditingController _accountCtrl;
  late final TextEditingController _ifscCtrl;
  late final TextEditingController _bankNameCtrl;
  late final TextEditingController _branchNameCtrl;
  late final TextEditingController _branchAddrCtrl;
  late final TextEditingController _micrCtrl;

  @override
  void initState() {
    super.initState();
    final b = widget.model.bank;
    _holderCtrl =
        TextEditingController(text: b['accountholdername']?.toString() ?? '');
    _accountCtrl =
        TextEditingController(text: b['accountnumber']?.toString() ?? '');
    _ifscCtrl =
        TextEditingController(text: b['ifsccode']?.toString() ?? '');
    _bankNameCtrl =
        TextEditingController(text: b['bankname']?.toString() ?? '');
    _branchNameCtrl =
        TextEditingController(text: b['branchname']?.toString() ?? '');
    _branchAddrCtrl =
        TextEditingController(text: b['branchaddress']?.toString() ?? '');
    _micrCtrl =
        TextEditingController(text: b['micrcode']?.toString() ?? '');
  }

  @override
  void dispose() {
    _holderCtrl.dispose();
    _accountCtrl.dispose();
    _ifscCtrl.dispose();
    _bankNameCtrl.dispose();
    _branchNameCtrl.dispose();
    _branchAddrCtrl.dispose();
    _micrCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final err = await widget.model.saveBankDetails({
      'accountholdername': _holderCtrl.text.trim(),
      'accountnumber': _accountCtrl.text.trim(),
      'ifsccode': _ifscCtrl.text.trim(),
      'bankname': _bankNameCtrl.text.trim(),
      'branchname': _branchNameCtrl.text.trim(),
      'branchaddress': _branchAddrCtrl.text.trim(),
      'micrcode': _micrCtrl.text.trim(),
    });
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Save failed: $err')));
    } else {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bank details saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final saving = widget.model.bankSaving;
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 8, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Bank Account Details',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: saving ? null : () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _BankTF(
                        ctrl: _holderCtrl,
                        label: 'Account Holder Name'),
                    _BankTF(
                        ctrl: _accountCtrl, label: 'Account Number'),
                    _BankTF(ctrl: _ifscCtrl, label: 'IFSC Code'),
                    _BankTF(ctrl: _bankNameCtrl, label: 'Bank Name'),
                    _BankTF(ctrl: _branchNameCtrl, label: 'Branch Name'),
                    _BankTF(
                        ctrl: _branchAddrCtrl,
                        label: 'Branch Address'),
                    _BankTF(ctrl: _micrCtrl, label: 'MICR Code'),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                    onPressed:
                        saving ? null : () => Navigator.pop(context),
                    child: const Text('CANCEL')),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: kCrmBlue,
                      foregroundColor: Colors.white),
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('SAVE'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BankTF extends StatelessWidget {
  const _BankTF({required this.ctrl, required this.label});
  final TextEditingController ctrl;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              const TextStyle(fontSize: 13, color: Color(0xff6B7280)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xffE5E7EB))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xffE5E7EB))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: kCrmBlue)),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}

// ── Generic Image Card (Signature / Letterhead) ───────────────────────────────

class _ImageCard extends StatefulWidget {
  const _ImageCard({
    required this.title,
    required this.field,
    required this.imageUrl,
    required this.model,
  });
  final String title;
  final String field;
  final String? imageUrl;
  final CompanySettingsViewModel model;

  @override
  State<_ImageCard> createState() => _ImageCardState();
}

class _ImageCardState extends State<_ImageCard> {
  File? _picked;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xfile =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (xfile != null) setState(() => _picked = File(xfile.path));
  }

  Future<void> _upload() async {
    if (_picked == null) return;
    final err = await widget.model.uploadFile(widget.field, _picked!);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Upload failed: $err')));
    } else {
      setState(() => _picked = null);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.title} uploaded successfully')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uploading = widget.model.isUploading(widget.field);
    final hasImage = _picked != null || widget.imageUrl != null;
    return _SettingsCard(
      title: widget.title,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: hasImage
                  ? const Color(0xffF9FAFB)
                  : const Color(0xffF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xffE5E7EB)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _picked != null
                  ? Image.file(_picked!, fit: BoxFit.contain)
                  : widget.imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: widget.imageUrl!,
                          fit: BoxFit.contain,
                          placeholder: (_, __) => const Center(
                              child: CircularProgressIndicator(
                                  color: kCrmBlue, strokeWidth: 2)),
                          errorWidget: (_, __, ___) => _EmptyImageHint(
                              icon: _iconFor(widget.field),
                              text: 'No ${widget.title.toLowerCase()} uploaded'),
                        )
                      : _EmptyImageHint(
                          icon: _iconFor(widget.field),
                          text:
                              'No ${widget.title.toLowerCase()} uploaded'),
            ),
          ),
          const SizedBox(height: 16),
          _UploadButtons(
            onSelect: uploading ? null : _pickImage,
            onUpload: (_picked == null || uploading) ? null : _upload,
            uploading: uploading,
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String field) {
    if (field == 'digisign') return Icons.draw_rounded;
    if (field == 'letterhead') return Icons.description_rounded;
    return Icons.image_rounded;
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.child,
    this.trailing,
  });
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          const Divider(height: 24, thickness: 0.8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _UploadButtons extends StatelessWidget {
  const _UploadButtons({
    required this.onSelect,
    required this.onUpload,
    required this.uploading,
  });
  final VoidCallback? onSelect;
  final VoidCallback? onUpload;
  final bool uploading;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: onSelect,
          icon: const Icon(Icons.photo_library_rounded, size: 16),
          label: const Text('Select Image'),
          style: OutlinedButton.styleFrom(
            foregroundColor: kCrmBlue,
            side: const BorderSide(color: kCrmBlue),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: onUpload,
          icon: uploading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.upload_rounded, size: 16),
          label: const Text('Upload'),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                onUpload == null ? const Color(0xffD1D5DB) : kCrmBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
      ],
    );
  }
}

class _EmptyImageHint extends StatelessWidget {
  const _EmptyImageHint({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: const Color(0xffD1D5DB)),
          const SizedBox(height: 8),
          Text(text,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xff9CA3AF))),
        ],
      ),
    );
  }
}
