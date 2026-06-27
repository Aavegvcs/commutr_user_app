Map<String, dynamic> _unwrapItemsPayload(Map<String, dynamic> json) {
  final items = json['items'];
  if (items is List && items.isNotEmpty && items.first is Map) {
    return Map<String, dynamic>.from(items.first as Map);
  }
  return json;
}

class AddressChangeItem {
  final String? profileUpdateId;
  final int? id;
  final int? empId;
  final int? locCode;
  final String? locationName;
  final String? city;
  final String? pin;
  final String? state;
  final int? stateCode;
  final String? address;
  final String? effectivedate;

  /// Approval state of the address-change request:
  /// `'A'` approved, `'R'` rejected, `null`/other → under review.
  final String? actionType;

  /// Remark provided by the approver when a request is rejected.
  final String? rejectionRemark;

  const AddressChangeItem({
    this.profileUpdateId,
    this.id,
    this.empId,
    this.locCode,
    this.locationName,
    this.city,
    this.pin,
    this.state,
    this.stateCode,
    this.address,
    this.effectivedate,
    this.actionType,
    this.rejectionRemark,
  });

  factory AddressChangeItem.fromJson(Map<String, dynamic> json) {
    final data = _unwrapItemsPayload(json);
    return AddressChangeItem(
      profileUpdateId: data['profileUpdate_Id']?.toString(),
      id: _readInt(data, ['id', 'Id']),
      empId: _readInt(data, ['empID', 'empId', 'EmpID']),
      locCode: _readInt(data, ['locCode', 'LocCode']),
      locationName: _readString(data, ['locationName', 'LocationName']),
      city: _readString(data, ['city', 'City']),
      pin: _readString(data, ['pin', 'Pin']),
      state: _readString(data, ['state', 'State']),
      stateCode: _readInt(data, ['stateCode', 'StateCode']),
      address: _readString(data, ['address', 'Address']),
      effectivedate: _readString(data, ['effectivedate', 'effectiveDate']),
      actionType: _readString(data, ['actionType', 'ActionType']),
      rejectionRemark:
          _readString(data, ['rejection_Remark', 'rejectionRemark']),
    );
  }
}

class AddressChangeResponse {
  final List<AddressChangeItem> items;
  final int? totalCount;

  const AddressChangeResponse({
    required this.items,
    this.totalCount,
  });

  factory AddressChangeResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = <AddressChangeItem>[];
    if (rawItems is List) {
      for (final entry in rawItems) {
        if (entry is Map) {
          items.add(
            AddressChangeItem.fromJson(Map<String, dynamic>.from(entry)),
          );
        }
      }
    }
    return AddressChangeResponse(
      items: items,
      totalCount: _readInt(json, ['totalCount', 'TotalCount']),
    );
  }

  AddressChangeItem? get firstItem => items.isEmpty ? null : items.first;
}

int? _readInt(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is num) return value.toInt();
    if (value is String && value.trim().isNotEmpty) {
      return int.tryParse(value.trim());
    }
  }
  return null;
}

String? _readString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return null;
}
