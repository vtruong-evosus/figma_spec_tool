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
    // Try multiple approaches from most minimal to slightly more detailed
    
    // Approach 1: Ultra-minimal (just the node structure)
    try {
      final minimalUrl = Uri.parse('$baseUrl/files/$fileKey/nodes?ids=$nodeId');
      final response = await http.get(minimalUrl, headers: {
        'X-Figma-Token': token,
      });

      if (response.statusCode == 200) {
        // Very strict size limit for nodes
        if (response.bodyBytes.length > 100 * 1024) { // 100KB limit
          throw Exception('Node still too large (${(response.bodyBytes.length / 1024).toStringAsFixed(1)}KB). This node contains too much data.');
        }

        final data = jsonDecode(response.body);
        return data;
      } else {
        throw Exception('API call failed with status ${response.statusCode}');
      }
    } catch (e) {
      // Approach 2: Slightly more detailed but still minimal
      try {
        final detailedUrl = Uri.parse('$baseUrl/files/$fileKey/nodes?ids=$nodeId&depth=1');
        
        final response = await http.get(detailedUrl, headers: {
          'X-Figma-Token': token,
        });

        if (response.statusCode == 200) {
          if (response.bodyBytes.length > 200 * 1024) { // 200KB limit
            throw Exception('Node still too large (${(response.bodyBytes.length / 1024).toStringAsFixed(1)}KB). This node contains too much data.');
          }

          final data = jsonDecode(response.body);
          return data;
        } else {
          throw Exception('Detailed API call failed with status ${response.statusCode}');
        }
      } catch (e2) {
        throw Exception('Both minimal approaches failed. Node $nodeId is too complex for this tool. Last error: $e2');
      }
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

  // Complete specs extraction following the proper Figma API pattern
  Future<Map<String, dynamic>> fetchCompleteSpecs(String fileKey, String nodeId) async {
    final headers = {'X-Figma-Token': token};
    
    
    // Step 1: Fetch the node and its descendants
    final nodeUrl = Uri.parse('$baseUrl/files/$fileKey/nodes?ids=$nodeId');
    final nodeResponse = await http.get(nodeUrl, headers: headers);
    
    if (nodeResponse.statusCode != 200) {
      throw Exception('Failed to fetch node: ${nodeResponse.statusCode}');
    }
    
    final nodeData = jsonDecode(nodeResponse.body);
    
    // Step 2: Fetch all styles used in file
    final stylesUrl = Uri.parse('$baseUrl/files/$fileKey/styles');
    final stylesResponse = await http.get(stylesUrl, headers: headers);
    final stylesData = jsonDecode(stylesResponse.body);
    
    // Step 3: Fetch variables (optional)
    Map<String, dynamic> variablesData = {};
    try {
      final varsUrl = Uri.parse('$baseUrl/files/$fileKey/variables');
      final varsResponse = await http.get(varsUrl, headers: headers);
      variablesData = jsonDecode(varsResponse.body);
    } catch (e) {
      // Variables not available, continue with empty data
    }
    
    return {
      'node': nodeData,
      'styles': stylesData,
      'variables': variablesData,
    };
  }
}
