import 'dart:convert';
import 'package:http/http.dart' as http;

class FigmaApiService {
  final String baseUrl = "https://api.figma.com/v1";
  final String token;

  FigmaApiService(this.token);

  Future<Map<String, dynamic>> getFile(String fileKey) async {
    final url = Uri.parse('$baseUrl/files/$fileKey');
    final response = await http.get(url, headers: {
      'X-Figma-Token': token,
    });

    if (response.statusCode == 200) {
      try {
        // Check response size to prevent memory issues
        if (response.bodyBytes.length > 10 * 1024 * 1024) { // 10MB limit
          throw Exception('File too large (${(response.bodyBytes.length / 1024 / 1024).toStringAsFixed(1)}MB). Please try a specific node or smaller file.');
        }
        
        return jsonDecode(response.body);
      } catch (e) {
        if (e is FormatException) {
          throw Exception('Invalid JSON response from Figma API. The file may be too large or corrupted.');
        }
        rethrow;
      }
    } else {
      throw Exception('Failed to load Figma file: ${response.statusCode} - ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getNode(String fileKey, String nodeId) async {
    final url = Uri.parse('$baseUrl/files/$fileKey/nodes?ids=$nodeId');
    final response = await http.get(url, headers: {
      'X-Figma-Token': token,
    });

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load node: ${response.statusCode} - ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getStyles(String fileKey) async {
    final url = Uri.parse('$baseUrl/files/$fileKey/styles');
    final response = await http.get(url, headers: {
      'X-Figma-Token': token,
    });

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load styles: ${response.statusCode} - ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getStyle(String styleKey) async {
    final url = Uri.parse('$baseUrl/styles/$styleKey');
    final response = await http.get(url, headers: {
        'X-Figma-Token': token,
      });

      if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load style: ${response.statusCode} - ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getVariables(String fileKey) async {
    final url = Uri.parse('$baseUrl/files/$fileKey/variables');
    final response = await http.get(url, headers: {
      'X-Figma-Token': token,
    });

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
      } else {
      throw Exception('Failed to load variables: ${response.statusCode} - ${response.body}');
    }
      }
        
  // New method to get file with variables (for design system data)
  Future<Map<String, dynamic>> getFileWithVariables(String fileKey) async {
    final url = Uri.parse('$baseUrl/files/$fileKey');
    final response = await http.get(url, headers: {
          'X-Figma-Token': token,
        });

        if (response.statusCode == 200) {
      try {
        // Check response size to prevent memory issues
        if (response.bodyBytes.length > 5 * 1024 * 1024) { // 5MB limit
          throw Exception('File too large (${(response.bodyBytes.length / 1024 / 1024).toStringAsFixed(1)}MB). Please try a specific node or smaller file.');
        }
        
        return jsonDecode(response.body);
      } catch (e) {
        if (e is FormatException) {
          throw Exception('Invalid JSON response from Figma API. The file may be too large or corrupted.');
        }
        rethrow;
      }
        } else {
      throw Exception('Failed to load Figma file: ${response.statusCode} - ${response.body}');
    }
  }

  // Ultra-minimal API approach for code generation
  Future<Map<String, dynamic>> fetchNodeData(String fileKey, String nodeId) async {
    final headers = {'X-Figma-Token': token};
    
    try {
      // ONLY fetch the specific node - everything Cursor needs is here
      print('Fetching node data...');
      final nodeUrl = Uri.parse('$baseUrl/files/$fileKey/nodes?ids=$nodeId');
      final nodeResponse = await http.get(nodeUrl, headers: headers);
      
      if (nodeResponse.statusCode == 200 && nodeResponse.body.isNotEmpty) {
        try {
          final nodeData = jsonDecode(nodeResponse.body);
          print('Node data fetched successfully');
          return nodeData;
        } catch (e) {
          print('Failed to parse node response: $e');
          throw Exception('Invalid JSON response from Figma API');
        }
      } else {
        throw Exception('Failed to load node: ${nodeResponse.statusCode} - ${nodeResponse.body}');
      }
    } catch (e) {
      throw Exception('Failed to fetch node data: $e');
    }
  }
}