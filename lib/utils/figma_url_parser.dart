class FigmaUrlParser {
  static Map<String, String?> parseFigmaUrl(String url) {
    try {
      // Handle different Figma URL formats
      // Format 1: https://www.figma.com/design/6OoAD2dZFiVFYY22Fjb7vi/LOU-Service?node-id=14339-216969&t=WEWdFgXVNgEl3pRQ-0
      // Format 2: https://www.figma.com/file/6OoAD2dZFiVFYY22Fjb7vi/LOU-Service?node-id=14339-216969&t=WEWdFgXVNgEl3pRQ-0
      // Format 3: https://www.figma.com/design/6OoAD2dZFiVFYY22Fjb7vi/LOU-Service
      
      final uri = Uri.parse(url);
      
      // Extract file key from path
      final pathSegments = uri.pathSegments;
      String? fileKey;
      
      if (pathSegments.length >= 2) {
        // Look for 'design' or 'file' in the path
        if (pathSegments.contains('design') || pathSegments.contains('file')) {
          final designIndex = pathSegments.indexOf('design');
          final fileIndex = pathSegments.indexOf('file');
          final targetIndex = designIndex != -1 ? designIndex : fileIndex;
          
          if (targetIndex != -1 && targetIndex + 1 < pathSegments.length) {
            fileKey = pathSegments[targetIndex + 1];
          }
        } else {
          // Fallback: assume first segment after domain is file key
          fileKey = pathSegments.first;
        }
      }
      
      // Extract node ID from query parameters
      String? nodeId = uri.queryParameters['node-id'];
      
      return {
        'fileKey': fileKey,
        'nodeId': nodeId,
        'url': url,
      };
    } catch (e) {
      return {
        'fileKey': null,
        'nodeId': null,
        'url': url,
        'error': e.toString(),
      };
    }
  }
  
  static bool isValidFigmaUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.contains('figma.com') && 
             (uri.path.contains('design') || uri.path.contains('file'));
    } catch (e) {
      return false;
    }
  }
}
