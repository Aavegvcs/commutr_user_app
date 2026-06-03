import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const _kMapsApiKey = 'AIzaSyCWbmCiquOta1iF6um7_5_NFh6YM5wPL30';

class PlaceSuggestion {
  final String placeId;
  final String mainText;
  final String secondaryText;

  const PlaceSuggestion({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
  });
}

class PlaceResult {
  final double lat;
  final double lng;
  final String formattedAddress;

  const PlaceResult({
    required this.lat,
    required this.lng,
    required this.formattedAddress,
  });
}

class PlaceAutocompleteScreen extends StatefulWidget {
  const PlaceAutocompleteScreen({super.key});

  @override
  State<PlaceAutocompleteScreen> createState() =>
      _PlaceAutocompleteScreenState();
}

class _PlaceAutocompleteScreenState extends State<PlaceAutocompleteScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<PlaceSuggestion> _suggestions = [];
  bool _isLoading = false;
  Timer? _debounce;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _errorMsg = null;
        _isLoading = false;
      });
      return;
    }
    setState(() => _isLoading = true);
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _fetchSuggestions(value.trim());
    });
  }

  Future<void> _fetchSuggestions(String input) async {
    try {
      final uri = Uri.https('maps.googleapis.com', '/maps/api/place/autocomplete/json', {
        'input': input,
        'key': _kMapsApiKey,
        'language': 'en',
      });
      final response = await http.get(uri);
      if (!mounted) return;

      if (response.statusCode != 200) {
        setState(() {
          _errorMsg = 'Failed to fetch suggestions';
          _isLoading = false;
        });
        return;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final status = data['status'] as String?;

      if (status != 'OK' && status != 'ZERO_RESULTS') {
        setState(() {
          _errorMsg = data['error_message'] as String? ?? 'Error: $status';
          _isLoading = false;
        });
        return;
      }

      final predictions = (data['predictions'] as List? ?? []);
      setState(() {
        _errorMsg = null;
        _isLoading = false;
        _suggestions = predictions.map((p) {
          final structured = p['structured_formatting'] as Map<String, dynamic>? ?? {};
          return PlaceSuggestion(
            placeId: p['place_id'] as String? ?? '',
            mainText: structured['main_text'] as String? ?? p['description'] as String? ?? '',
            secondaryText: structured['secondary_text'] as String? ?? '',
          );
        }).toList();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMsg = 'Network error. Check your connection.';
        _isLoading = false;
      });
    }
  }

  Future<void> _onSuggestionTapped(PlaceSuggestion suggestion) async {
    setState(() => _isLoading = true);
    try {
      final uri = Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {
        'place_id': suggestion.placeId,
        'fields': 'geometry,formatted_address',
        'key': _kMapsApiKey,
      });
      final response = await http.get(uri);
      if (!mounted) return;

      if (response.statusCode != 200) {
        setState(() {
          _errorMsg = 'Failed to get place details';
          _isLoading = false;
        });
        return;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final result = data['result'] as Map<String, dynamic>?;
      final location = result?['geometry']?['location'] as Map<String, dynamic>?;

      if (location == null) {
        setState(() {
          _errorMsg = 'Could not get location for this place';
          _isLoading = false;
        });
        return;
      }

      final lat = (location['lat'] as num).toDouble();
      final lng = (location['lng'] as num).toDouble();
      final address = result?['formatted_address'] as String? ??
          '${suggestion.mainText}, ${suggestion.secondaryText}';

      if (!mounted) return;
      Navigator.pop(context, PlaceResult(lat: lat, lng: lng, formattedAddress: address));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMsg = 'Network error. Check your connection.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: _onSearchChanged,
          style: const TextStyle(fontSize: 15, color: Colors.black87),
          decoration: InputDecoration(
            hintText: 'Search for a place…',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
            border: InputBorder.none,
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                    onPressed: () {
                      _controller.clear();
                      _onSearchChanged('');
                    },
                  )
                : null,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (_errorMsg != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _errorMsg!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red.shade600, fontSize: 14),
          ),
        ),
      );
    }

    if (_suggestions.isEmpty && _controller.text.isNotEmpty) {
      return Center(
        child: Text(
          'No results found',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        ),
      );
    }

    return ListView.separated(
      itemCount: _suggestions.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, indent: 56, color: Colors.grey.shade100),
      itemBuilder: (context, index) {
        final s = _suggestions[index];
        return ListTile(
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF1A73E8).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on_outlined,
              color: Color(0xFF1A73E8),
              size: 18,
            ),
          ),
          title: Text(
            s.mainText,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: s.secondaryText.isNotEmpty
              ? Text(
                  s.secondaryText,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          onTap: () => _onSuggestionTapped(s),
        );
      },
    );
  }
}
