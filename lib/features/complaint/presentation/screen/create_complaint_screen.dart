import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../bloc/complaint_bloc.dart';
import '../../bloc/complaint_event.dart';
import '../../bloc/complaint_state.dart';
import '../../data/model/complaint_response.dart';

class CreateComplaintScreen extends StatelessWidget {
  const CreateComplaintScreen({super.key, required this.empId});

  final int empId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ComplaintBloc>(
      create: (_) => sl<ComplaintBloc>()..add(const FetchComplaintLookup()),
      child: _CreateComplaintView(empId: empId),
    );
  }
}

class _CreateComplaintView extends StatefulWidget {
  const _CreateComplaintView({required this.empId});

  final int empId;

  @override
  State<_CreateComplaintView> createState() => _CreateComplaintViewState();
}

class _CreateComplaintViewState extends State<_CreateComplaintView> {
  static const _tripTypes = ['Login', 'Logout'];

  String _tripType = _tripTypes.first;
  ComplaintLookupItem? _selectedComplaintType;
  List<ComplaintLookupItem> _lookupItems = const [];
  DateTime? _tripDate;
  final _detailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  String _displayDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$mm/$dd/${d.year}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tripDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1A6B3C),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _tripDate = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_tripDate == null) {
      AppSnackbar.warning(context, 'Please select a trip date.');
      return;
    }
    if (_selectedComplaintType == null) {
      AppSnackbar.warning(context, 'Please select a complaint type.');
      return;
    }

    context.read<ComplaintBloc>().add(
          SubmitComplaint(
            empId: widget.empId,
            tripType: _tripType == 'Login' ? 1 : 2,
            tripDate: _formatDate(_tripDate!),
            complaintType: _selectedComplaintType!.complaintType,
            complaintDetail: _detailController.text.trim(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ComplaintBloc, ComplaintState>(
      listener: (context, state) {
        if (state is ComplaintLookupLoaded) {
          setState(() {
            _lookupItems = state.items;
            if (_selectedComplaintType == null && state.items.isNotEmpty) {
              _selectedComplaintType = state.items.first;
            }
          });
        } else if (state is ComplaintSubmitSuccess) {
          AppSnackbar.success(context, 'Complaint submitted successfully.');
          Navigator.pop(context);
        } else if (state is ComplaintSubmitError) {
          AppSnackbar.error(context, state.message);
        }
      },
      builder: (context, state) {
        final isSubmitting = state is ComplaintSubmitting;
        final isLookupLoading = state is ComplaintLookupLoading;

        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F4),
          appBar: AppBar(
            backgroundColor: const Color(0xFFF5F5F4),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back,
                  color: Color(0xFF1A6B3C), size: 24),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Raise Complaint',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A6B3C),
              ),
            ),
          ),
          body: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FieldLabel('TRIP TYPE'),
                      const SizedBox(height: 8),
                      _DropdownField<String>(
                        value: _tripType,
                        items: _tripTypes,
                        itemLabel: (v) => v,
                        onChanged: (v) =>
                            setState(() => _tripType = v ?? _tripType),
                      ),
                      const SizedBox(height: 24),
                      _FieldLabel('TRIP DATE'),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          height: 56,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEEEEE),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _tripDate != null
                                      ? _displayDate(_tripDate!)
                                      : 'mm/dd/yyyy',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: _tripDate != null
                                        ? const Color(0xFF1A1A1A)
                                        : const Color(0xFF9AA0A6),
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 22,
                                color: Color(0xFF1A6B3C),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _FieldLabel('COMPLAINT TYPE'),
                      const SizedBox(height: 8),
                      if (isLookupLoading)
                        Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEEEEE),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF1A6B3C)),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Loading...',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF9AA0A6),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        _DropdownField<ComplaintLookupItem>(
                          value: _selectedComplaintType,
                          items: _lookupItems,
                          itemLabel: (v) => v.complainName,
                          onChanged: (v) =>
                              setState(() => _selectedComplaintType = v),
                        ),
                      const SizedBox(height: 24),
                      _FieldLabel('COMPLAINT DETAIL'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _detailController,
                        maxLines: 6,
                        style: const TextStyle(
                            fontSize: 14, color: Color(0xFF1A1A1A)),
                        decoration: InputDecoration(
                          hintText: 'Enter complaint details...',
                          hintStyle: const TextStyle(
                            color: Color(0xFF1A6B3C),
                            fontSize: 14,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFEEEEEE),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter complaint details.';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A5C38),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          const Color(0xFF1A5C38).withValues(alpha: 0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      elevation: 0,
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Submit',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Color(0xFF6B7280),
        letterSpacing: 0.8,
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final void Function(T?) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFEEEEEE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down,
              color: Color(0xFF1A6B3C)),
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF1A1A1A),
          ),
          items: items
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(itemLabel(item)),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
