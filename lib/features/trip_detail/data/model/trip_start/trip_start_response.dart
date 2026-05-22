class TripResponse {
  final int? errorCode;
  final String? dBResponse;
  final List<DaySchedule>? result;

  const TripResponse({
    this.errorCode,
    this.dBResponse,
    this.result,
  });

  factory TripResponse.fromJson(Map<String, dynamic> json) {
    return TripResponse(
      errorCode: json['errorCode'] as int?,
      dBResponse: json['dB_Response'] as String?,
      result: (json['result'] as List?)
          ?.map((e) => DaySchedule.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (errorCode != null) 'errorCode': errorCode,
      if (dBResponse != null) 'dB_Response': dBResponse,
      if (result != null) 'result': result!.map((e) => e.toJson()).toList(),
    };
  }

  /// Parse root-level JSON array
  static List<TripResponse> fromJsonList(List json) {
    return json
        .map((e) => TripResponse.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  String toString() => 'TripResponse(errorCode: $errorCode, '
      'dBResponse: $dBResponse, result: $result)';
}

class DaySchedule {
  final String? dayName;
  final List<TripData>? data;

  const DaySchedule({
    this.dayName,
    this.data,
  });

  factory DaySchedule.fromJson(Map<String, dynamic> json) {
    return DaySchedule(
      dayName: json['DayName'] as String?,
      data: (json['data'] as List?)
          ?.map((e) => TripData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (dayName != null) 'DayName': dayName,
      if (data != null) 'data': data!.map((e) => e.toJson()).toList(),
    };
  }

  @override
  String toString() =>
      'DaySchedule(dayName: $dayName, data: $data)';
}

class TripData {
  final int?    tripID;
  final String? tripDate;
  final String? triptype;
  final String? otp;
  final String? pickShift;
  final int?    empID;
  final String? employeeID;
  final String? userName;
  final String? userAddress;
  final String? officeAddress;
  final String? tripLocation;
  final String? pickTime;
  final String? tripStatusName;
  final int?    tripStatusCode;
  final String? vehicleInfo;
  final int?    flapNo;
  final bool?   isBoarded;
  final bool?   isDeBoarded;
  final int?    paxCount;
  final int?    paxorder;
  final int?    reachedHomeReq;
  final int?    isReached;
  final String? userAppIVRNumber;

  const TripData({
    this.tripID,
    this.tripDate,
    this.triptype,
    this.otp,
    this.pickShift,
    this.empID,
    this.employeeID,
    this.userName,
    this.userAddress,
    this.officeAddress,
    this.tripLocation,
    this.pickTime,
    this.tripStatusName,
    this.tripStatusCode,
    this.vehicleInfo,
    this.flapNo,
    this.isBoarded,
    this.isDeBoarded,
    this.paxCount,
    this.paxorder,
    this.reachedHomeReq,
    this.isReached,
    this.userAppIVRNumber,
  });

  factory TripData.fromJson(Map<String, dynamic> json) {
    return TripData(
      tripID:          json['TripID']          as int?,
      tripDate:        json['TripDate']        as String?,
      triptype:        json['Triptype']        as String?,
      otp:             json['OTP']             as String?,
      pickShift:       json['PickShift']       as String?,
      empID:           json['EMPID']           as int?,
      employeeID:      json['EmployeeID']      as String?,
      userName:        json['UserName']        as String?,
      userAddress:     json['UserAddress']     as String?,
      officeAddress:   json['OfficeAddress']   as String?,
      tripLocation:    json['TripLocation']    as String?,
      pickTime:        json['PickTime']        as String?,
      tripStatusName:  json['TripStatusName']  as String?,
      tripStatusCode:  json['TripStatusCode']  as int?,
      vehicleInfo:     json['VehicleInfo']     as String?,
      flapNo:          json['FlapNo']          as int?,
      isBoarded:       json['IsBoarded']       as bool?,
      isDeBoarded:     json['IsDeBoarded']     as bool?,
      paxCount:        json['PaxCount']        as int?,
      paxorder:        json['Paxorder']        as int?,
      reachedHomeReq:  json['ReachedHomeReq']  as int?,
      isReached:       json['IsReached']       as int?,
      userAppIVRNumber:json['UserAppIVRNumber'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (tripID != null)           'TripID':          tripID,
      if (tripDate != null)         'TripDate':        tripDate,
      if (triptype != null)         'Triptype':        triptype,
      if (otp != null)              'OTP':             otp,
      if (pickShift != null)        'PickShift':       pickShift,
      if (empID != null)            'EMPID':           empID,
      if (employeeID != null)       'EmployeeID':      employeeID,
      if (userName != null)         'UserName':        userName,
      if (userAddress != null)      'UserAddress':     userAddress,
      if (officeAddress != null)    'OfficeAddress':   officeAddress,
      if (tripLocation != null)     'TripLocation':    tripLocation,
      if (pickTime != null)         'PickTime':        pickTime,
      if (tripStatusName != null)   'TripStatusName':  tripStatusName,
      if (tripStatusCode != null)   'TripStatusCode':  tripStatusCode,
      if (vehicleInfo != null)      'VehicleInfo':     vehicleInfo,
      if (flapNo != null)           'FlapNo':          flapNo,
      if (isBoarded != null)        'IsBoarded':       isBoarded,
      if (isDeBoarded != null)      'IsDeBoarded':     isDeBoarded,
      if (paxCount != null)         'PaxCount':        paxCount,
      if (paxorder != null)         'Paxorder':        paxorder,
      if (reachedHomeReq != null)   'ReachedHomeReq':  reachedHomeReq,
      if (isReached != null)        'IsReached':       isReached,
      if (userAppIVRNumber != null) 'UserAppIVRNumber': userAppIVRNumber,
    };
  }

  @override
  String toString() => 'TripData(tripID: $tripID, userName: $userName, '
      'tripDate: $tripDate, tripStatusName: $tripStatusName)';
}