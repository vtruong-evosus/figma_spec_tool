class FigmaParser {
  static List<Map<String, dynamic>> extractTextStyles(Map<String, dynamic> file) {
    final styles = <Map<String, dynamic>>[];
    final styleMap = file['styles'] ?? {};
    styleMap.forEach((key, value) {
      if (value['styleType'] == 'TEXT') {
        styles.add({
          'name': value['name'],
          'type': value['styleType'],
          'description': value['description'] ?? '',
          'key': key,
          'fontFamily': value['style']?['fontFamily'] ?? 'Unknown',
          'fontSize': value['style']?['fontSize'] ?? 'Unknown',
          'fontWeight': value['style']?['fontWeight'] ?? 'Unknown',
          'lineHeight': value['style']?['lineHeightPx'] ?? 'Unknown',
          'letterSpacing': value['style']?['letterSpacing'] ?? 'Unknown',
          'textAlign': value['style']?['textAlignHorizontal'] ?? 'Unknown',
          'textDecoration': value['style']?['textDecoration'] ?? 'Unknown',
          'textCase': value['style']?['textCase'] ?? 'ORIGINAL',
          'textAutoResize': value['style']?['textAutoResize'] ?? 'NONE',
        });
      }
    });
    return styles;
  }

  // Enhanced method to extract typography from actual text nodes
  static List<Map<String, dynamic>> extractTypographyFromNodes(Map<String, dynamic> file) {
    final typography = <Map<String, dynamic>>[];
    
    void parseNode(Map<String, dynamic> node, String parentPath, [int depth = 0]) {
      if (node['type'] == 'TEXT') {
        final style = node['style'];
        final characters = node['characters'] ?? '';
        final textAutoResize = node['textAutoResize'] ?? 'NONE';
        final textAlignHorizontal = node['textAlignHorizontal'] ?? 'LEFT';
        final textAlignVertical = node['textAlignVertical'] ?? 'TOP';
        
        
        
        // Detect ellipses/truncation
        final hasEllipses = _detectEllipses(characters, node);
        
        typography.add({
          'name': node['name'] ?? 'Unnamed Text',
          'type': 'TEXT',
          'path': parentPath,
          'characters': characters,
          'hasEllipses': hasEllipses['hasEllipses'],
          'ellipsesType': hasEllipses['type'],
          'ellipsesPosition': hasEllipses['position'],
          'fontFamily': style?['fontFamily'] ?? 'Unknown',
          'fontSize': style?['fontSize'] ?? 'Unknown',
          'fontWeight': style?['fontWeight'] ?? 'Unknown',
          'lineHeight': style?['lineHeightPx'] ?? 'Unknown',
          'letterSpacing': style?['letterSpacing'] ?? 'Unknown',
          'textAlignHorizontal': textAlignHorizontal,
          'textAlignVertical': textAlignVertical,
          'textAutoResize': textAutoResize,
          'textCase': style?['textCase'] ?? 'ORIGINAL',
          'textDecoration': style?['textDecoration'] ?? 'NONE',
          'maxLines': node['maxLines'],
          'textStyleId': node['styleId'],
          'fills': node['fills'],
          'constraints': node['constraints'],
          'layoutAlign': node['layoutAlign'],
          'layoutGrow': node['layoutGrow'],
          'layoutSizingHorizontal': node['layoutSizingHorizontal'],
          'layoutSizingVertical': node['layoutSizingVertical'],
        });
      }
      
      if (node['children'] != null) {
        final currentPath = parentPath.isEmpty ? node['name'] : '$parentPath > ${node['name']}';
        for (var child in node['children']) {
          parseNode(child as Map<String, dynamic>, currentPath, depth + 1);
        }
      } else {
      }
    }

    parseNode(file['document'] as Map<String, dynamic>, '', 0);
    return typography;
  }

  // Helper method to detect ellipses patterns
  static Map<String, dynamic> _detectEllipses(String text, Map<String, dynamic> node) {
    final result = {
      'hasEllipses': false,
      'type': 'none',
      'position': 'none',
    };
    
    if (text.isEmpty) return result;
    
    // Check for explicit ellipses patterns
    if (text.contains('...')) {
      result['hasEllipses'] = true;
      result['type'] = 'explicit';
      
      if (text.endsWith('...')) {
        result['position'] = 'end';
      } else if (text.startsWith('...')) {
        result['position'] = 'start';
      } else if (text.contains('...')) {
        result['position'] = 'middle';
      }
    }
    
    // Check for text truncation indicators
    if (text.contains('…')) {
      result['hasEllipses'] = true;
      result['type'] = 'unicode_ellipsis';
      
      if (text.endsWith('…')) {
        result['position'] = 'end';
      } else if (text.startsWith('…')) {
        result['position'] = 'start';
      } else if (text.contains('…')) {
        result['position'] = 'middle';
      }
    }
    
    // Check for text that might be truncated based on length and container constraints
    final maxLines = node['maxLines'];
    
    // If text has maxLines constraint and is long, it might be truncated
    if (maxLines != null && text.length > 50) {
      result['hasEllipses'] = true;
      result['type'] = 'constrained';
      result['position'] = 'end';
    }
    
    // Check for text that appears to be cut off (common patterns)
    final suspiciousPatterns = [
      RegExp(r'long\s+long\s+long\.{3,}$'), // "long long long..." pattern
      RegExp(r'\.{3,}$'), // Multiple dots at end
      RegExp(r'[a-zA-Z]+\s+[a-zA-Z]+\s+[a-zA-Z]+\.{2,}$'), // Word word word.. pattern
    ];
    
    for (var pattern in suspiciousPatterns) {
      if (pattern.hasMatch(text)) {
        result['hasEllipses'] = true;
        result['type'] = 'pattern_detected';
        result['position'] = 'end';
        break;
      }
    }
    
    return result;
  }

  static List<Map<String, dynamic>> extractColors(Map<String, dynamic> file) {
    final colors = <Map<String, dynamic>>[];
    final Set<String> processedColors = <String>{};
    
    void parseNode(Map node, String parentPath) {
      if (node['fills'] != null) {
        for (var fill in node['fills']) {
          if (fill['type'] == 'SOLID') {
            final c = fill['color'];
            final hex = _rgbToHex(
              (c['r'] * 255).round(),
              (c['g'] * 255).round(),
              (c['b'] * 255).round(),
            );
            
            // Avoid duplicates by using hex as key
            final colorKey = '${hex}_${node['name']}';
            if (!processedColors.contains(colorKey)) {
              processedColors.add(colorKey);
              colors.add({
                'name': node['name'],
                'path': parentPath,
                'r': (c['r'] * 255).round(),
                'g': (c['g'] * 255).round(),
                'b': (c['b'] * 255).round(),
                'a': c['a'] ?? 1.0,
                'hex': hex,
                'opacity': fill['opacity'] ?? 1.0,
                'blendMode': fill['blendMode'] ?? 'NORMAL',
              });
            }
          } else if (fill['type'] == 'GRADIENT_LINEAR' || fill['type'] == 'GRADIENT_RADIAL') {
            // Handle gradient fills
            final gradientKey = 'gradient_${node['name']}_$parentPath';
            if (!processedColors.contains(gradientKey)) {
              processedColors.add(gradientKey);
              colors.add({
                'name': '${node['name']} (Gradient)',
                'path': parentPath,
                'type': fill['type'],
                'gradientStops': fill['gradientStops']?.map((stop) => {
                  'color': stop['color'],
                  'position': stop['position'],
                }).toList(),
                'gradientTransform': fill['gradientTransform'],
              });
            }
          }
        }
      }
      
      if (node['children'] != null) {
        final currentPath = parentPath.isEmpty ? node['name'] : '$parentPath > ${node['name']}';
        for (var child in node['children']) {
          parseNode(child, currentPath);
        }
      }
    }

    parseNode(file['document'], '');
    return colors;
  }

  static List<Map<String, dynamic>> extractComponents(Map<String, dynamic> file) {
    final components = <Map<String, dynamic>>[];
    
    void parseNode(Map node, String parentPath, int depth) {
      if (node['type'] == 'COMPONENT' || node['type'] == 'COMPONENT_SET') {
        final componentData = {
          'name': node['name'],
          'type': node['type'],
          'id': node['id'],
          'description': node['description'] ?? '',
          'width': node['absoluteBoundingBox']?['width'],
          'height': node['absoluteBoundingBox']?['height'],
          'path': parentPath,
          'depth': depth,
          'constraints': node['constraints'],
          'layoutMode': node['layoutMode'],
          'primaryAxisAlignItems': node['primaryAxisAlignItems'],
          'counterAxisAlignItems': node['counterAxisAlignItems'],
          'paddingLeft': node['paddingLeft'],
          'paddingRight': node['paddingRight'],
          'paddingTop': node['paddingTop'],
          'paddingBottom': node['paddingBottom'],
          'itemSpacing': node['itemSpacing'],
          'children': <Map<String, dynamic>>[],
        };

        // Extract nested components
        if (node['children'] != null) {
          for (var child in node['children']) {
            if (child['type'] == 'COMPONENT' || child['type'] == 'COMPONENT_SET') {
              componentData['children'].add({
                'name': child['name'],
                'type': child['type'],
                'id': child['id'],
                'width': child['absoluteBoundingBox']?['width'],
                'height': child['absoluteBoundingBox']?['height'],
              });
            }
          }
        }

        // Handle component variants
        if (node['type'] == 'COMPONENT_SET' && node['children'] != null) {
          componentData['variants'] = node['children'].map<Map<String, dynamic>>((variant) => {
            'name': variant['name'],
            'id': variant['id'],
            'description': variant['description'] ?? '',
            'width': variant['absoluteBoundingBox']?['width'],
            'height': variant['absoluteBoundingBox']?['height'],
            'variantProperties': variant['variantProperties'] ?? {},
          }).toList();
        }

        components.add(componentData);
      }
      
      if (node['children'] != null) {
        final currentPath = parentPath.isEmpty ? node['name'] : '$parentPath > ${node['name']}';
        for (var child in node['children']) {
          parseNode(child, currentPath, depth + 1);
        }
      }
    }

    parseNode(file['document'], '', 0);
    return components;
  }

  static List<Map<String, dynamic>> extractLayoutSpecs(Map<String, dynamic> file) {
    final layouts = <Map<String, dynamic>>[];
    
    void parseNode(Map node, String parentPath, int depth) {
      // Capture ALL nodes, not just those with bounding boxes
      final layoutData = {
        'name': node['name'] ?? 'Unnamed Element',
        'type': node['type'] ?? 'UNKNOWN',
        'path': parentPath,
        'depth': depth,
        'constraints': node['constraints'],
        'layoutMode': node['layoutMode'],
        'primaryAxisAlignItems': node['primaryAxisAlignItems'],
        'counterAxisAlignItems': node['counterAxisAlignItems'],
        'paddingLeft': node['paddingLeft'],
        'paddingRight': node['paddingRight'],
        'paddingTop': node['paddingTop'],
        'paddingBottom': node['paddingBottom'],
        'itemSpacing': node['itemSpacing'],
        'scrollBehavior': node['scrollBehavior'],
        'overflowDirection': node['overflowDirection'],
        'maxHeight': node['maxHeight'],
        'minHeight': node['minHeight'],
        'maxWidth': node['maxWidth'],
        'minWidth': node['minWidth'],
        'blendMode': node['blendMode'],
        'clipsContent': node['clipsContent'],
        'visible': node['visible'] ?? true,
        'locked': node['locked'] ?? false,
        'children': <Map<String, dynamic>>[],
      };
      
      // Add bounding box if available
      if (node['absoluteBoundingBox'] != null) {
        final bbox = node['absoluteBoundingBox'];
        layoutData['x'] = bbox['x'];
        layoutData['y'] = bbox['y'];
        layoutData['width'] = bbox['width'];
        layoutData['height'] = bbox['height'];
      }
      
      // Add render bounds if available
      if (node['absoluteRenderBounds'] != null) {
        final renderBounds = node['absoluteRenderBounds'];
        layoutData['renderX'] = renderBounds['x'];
        layoutData['renderY'] = renderBounds['y'];
        layoutData['renderWidth'] = renderBounds['width'];
        layoutData['renderHeight'] = renderBounds['height'];
      }
      
      // Add text properties if it's a text node
      if (node['type'] == 'TEXT') {
        layoutData['textContent'] = node['characters'] ?? '';
        layoutData['textStyle'] = node['style'];
        layoutData['textAlignHorizontal'] = node['textAlignHorizontal'];
        layoutData['textAlignVertical'] = node['textAlignVertical'];
        layoutData['textAutoResize'] = node['textAutoResize'];
      }
      
      // Add instance properties if it's a component instance
      if (node['type'] == 'INSTANCE') {
        layoutData['componentId'] = node['componentId'];
        layoutData['componentProperties'] = node['componentProperties'];
        layoutData['overrides'] = node['overrides'];
      }
      
      // Add effects if present
      if (node['effects'] != null && node['effects'].isNotEmpty) {
        layoutData['effects'] = node['effects'];
      }
      
      // Add fills if present
      if (node['fills'] != null && node['fills'].isNotEmpty) {
        layoutData['fills'] = node['fills'];
      }
      
      // Add strokes if present
      if (node['strokes'] != null && node['strokes'].isNotEmpty) {
        layoutData['strokes'] = node['strokes'];
      }
      
      // Add corner radius if present
      if (node['rectangleCornerRadii'] != null) {
        layoutData['cornerRadius'] = node['rectangleCornerRadii'];
      }
      
      // Add nested layout information
      if (node['children'] != null && node['children'].isNotEmpty) {
        layoutData['children'] = node['children'].map<Map<String, dynamic>>((child) => {
          'name': child['name'],
          'type': child['type'],
          'x': child['absoluteBoundingBox']?['x'],
          'y': child['absoluteBoundingBox']?['y'],
          'width': child['absoluteBoundingBox']?['width'],
          'height': child['absoluteBoundingBox']?['height'],
        }).toList();
      }

      // Add ALL nodes, not just those with bounding boxes
      layouts.add(layoutData);
      
      if (node['children'] != null) {
        final currentPath = parentPath.isEmpty ? node['name'] : '$parentPath > ${node['name']}';
        for (var child in node['children']) {
          parseNode(child, currentPath, depth + 1);
        }
      }
    }

    parseNode(file['document'], '', 0);
    return layouts;
  }

  // New method to extract design tokens with better nesting support
  static List<Map<String, dynamic>> extractDesignTokens(Map<String, dynamic> file) {
    final tokens = <Map<String, dynamic>>[];
    
    void parseNode(Map node, String parentPath, int depth) {
      // Extract color tokens
      if (node['fills'] != null) {
        for (var fill in node['fills']) {
          if (fill['type'] == 'SOLID') {
            final c = fill['color'];
            tokens.add({
              'name': node['name'],
              'type': 'color',
              'path': parentPath,
              'depth': depth,
              'value': {
                'r': (c['r'] * 255).round(),
                'g': (c['g'] * 255).round(),
                'b': (c['b'] * 255).round(),
                'a': c['a'] ?? 1.0,
                'hex': _rgbToHex(
                  (c['r'] * 255).round(),
                  (c['g'] * 255).round(),
                  (c['b'] * 255).round(),
                ),
              },
            });
          }
        }
      }

      // Extract spacing tokens
      if (node['paddingLeft'] != null || node['paddingRight'] != null || 
          node['paddingTop'] != null || node['paddingBottom'] != null) {
        tokens.add({
          'name': '${node['name']} Padding',
          'type': 'spacing',
          'path': parentPath,
          'depth': depth,
          'value': {
            'left': node['paddingLeft'],
            'right': node['paddingRight'],
            'top': node['paddingTop'],
            'bottom': node['paddingBottom'],
          },
        });
      }

      // Extract typography tokens
      if (node['style'] != null) {
        tokens.add({
          'name': '${node['name']} Typography',
          'type': 'typography',
          'path': parentPath,
          'depth': depth,
          'value': {
            'fontFamily': node['style']['fontFamily'],
            'fontSize': node['style']['fontSize'],
            'fontWeight': node['style']['fontWeight'],
            'lineHeight': node['style']['lineHeightPx'],
            'letterSpacing': node['style']['letterSpacing'],
          },
        });
      }

      // Extract border radius tokens
      if (node['cornerRadius'] != null) {
        tokens.add({
          'name': '${node['name']} Border Radius',
          'type': 'borderRadius',
          'path': parentPath,
          'depth': depth,
          'value': node['cornerRadius'],
        });
      }

      if (node['children'] != null) {
        final currentPath = parentPath.isEmpty ? node['name'] : '$parentPath > ${node['name']}';
        for (var child in node['children']) {
          parseNode(child, currentPath, depth + 1);
        }
      }
    }

    parseNode(file['document'], '', 0);
    return tokens;
  }

  // Method to extract typography with style resolution
  static List<Map<String, dynamic>> extractTypographyWithStyles(Map<String, dynamic> file) {
    final typography = <Map<String, dynamic>>[];
    final stylesData = file['stylesData'];
    
    if (stylesData == null || stylesData['meta']?['styles'] == null) {
      return typography;
    }
    
    // Create a map of style keys to style names
    final styleMap = <String, String>{};
    for (final style in stylesData['meta']['styles']) {
      if (style['style_type'] == 'TEXT') {
        styleMap[style['key']] = style['name'];
      }
    }
    
    // Now traverse the document to find TEXT nodes
    void parseNode(Map<String, dynamic> node, String parentPath, [int depth = 0]) {
      if (node['type'] == 'TEXT') {
        final style = node['style'];
        final characters = node['characters'] ?? '';
        final textStyleId = style?['textStyleId'];
        
        
        // Resolve the style name
        String styleName = 'Unknown Style';
        if (textStyleId != null && styleMap.containsKey(textStyleId)) {
          styleName = styleMap[textStyleId]!;
        }
        
        // Detect ellipses/truncation
        final hasEllipses = _detectEllipses(characters, node);
        
        typography.add({
          'name': node['name'] ?? 'Unnamed Text',
          'type': 'TEXT',
          'path': parentPath,
          'characters': characters,
          'hasEllipses': hasEllipses['hasEllipses'],
          'ellipsesType': hasEllipses['type'],
          'ellipsesPosition': hasEllipses['position'],
          'styleName': styleName,
          'textStyleId': textStyleId,
          'fontFamily': style?['fontFamily'] ?? 'Unknown',
          'fontSize': style?['fontSize'] ?? 'Unknown',
          'fontWeight': style?['fontWeight'] ?? 'Unknown',
          'lineHeight': style?['lineHeightPx'] ?? 'Unknown',
          'letterSpacing': style?['letterSpacing'] ?? 'Unknown',
          'textAlignHorizontal': node['textAlignHorizontal'] ?? 'LEFT',
          'textAlignVertical': node['textAlignVertical'] ?? 'TOP',
          'textAutoResize': node['textAutoResize'] ?? 'NONE',
          'textCase': style?['textCase'] ?? 'ORIGINAL',
          'textDecoration': style?['textDecoration'] ?? 'NONE',
          'maxLines': node['maxLines'],
          'fills': node['fills'],
          'constraints': node['constraints'],
          'layoutAlign': node['layoutAlign'],
          'layoutGrow': node['layoutGrow'],
          'layoutSizingHorizontal': node['layoutSizingHorizontal'],
          'layoutSizingVertical': node['layoutSizingVertical'],
        });
      }
      
      if (node['children'] != null) {
        final currentPath = parentPath.isEmpty ? node['name'] : '$parentPath > ${node['name']}';
        for (var child in node['children']) {
          parseNode(child as Map<String, dynamic>, currentPath, depth + 1);
        }
      }
    }
    
    parseNode(file['document'] as Map<String, dynamic>, '', 0);
    return typography;
  }

  // Method to extract typography from variables and styles
  static List<Map<String, dynamic>> extractTypographyFromVariables(Map<String, dynamic> file) {
    final typography = <Map<String, dynamic>>[];
    
    // Check for bound variables
    if (file['boundVariables'] != null) {
      for (var variable in file['boundVariables'].values) {
        if (variable['type'] == 'STRING') {
        }
      }
    }
    
    // Check for variables in the document
    if (file['variables'] != null) {
      for (var variable in file['variables'].values) {
        if (variable['resolvedType'] == 'STRING') {
          typography.add({
            'name': 'Variable: ${variable['name']}',
            'type': 'VARIABLE',
            'path': 'Variables',
            'characters': variable['valuesByMode']?.values?.first?.toString() ?? '',
            'hasEllipses': _detectEllipses(variable['valuesByMode']?.values?.first?.toString() ?? '', {}).values.first,
            'ellipsesType': 'variable',
            'ellipsesPosition': 'unknown',
            'fontFamily': 'Variable',
            'fontSize': 'Variable',
            'fontWeight': 'Variable',
            'lineHeight': 'Variable',
            'letterSpacing': 'Variable',
            'textAlignHorizontal': 'Variable',
            'textAlignVertical': 'Variable',
            'textAutoResize': 'Variable',
            'textCase': 'Variable',
            'textDecoration': 'Variable',
            'isVariable': true,
            'variableId': variable['id'],
            'variableName': variable['name'],
          });
        }
      }
    }
    
    return typography;
  }

  // Alternative method to extract typography from layout specs
  static List<Map<String, dynamic>> extractTypographyFromLayouts(List<Map<String, dynamic>> layouts) {
    final typography = <Map<String, dynamic>>[];
    
    for (final layout in layouts) {
      if (layout['type'] == 'TEXT' && layout['textContent'] != null && layout['textContent'].isNotEmpty) {
        final textContent = layout['textContent'] as String;
        final textStyle = layout['textStyle'];
        
        // Detect ellipses/truncation
        final hasEllipses = _detectEllipses(textContent, layout);
        
        typography.add({
          'name': layout['name'] ?? 'Unnamed Text',
          'type': 'TEXT',
          'path': layout['path'] ?? '',
          'characters': textContent,
          'hasEllipses': hasEllipses['hasEllipses'],
          'ellipsesType': hasEllipses['type'],
          'ellipsesPosition': hasEllipses['position'],
          'fontFamily': textStyle?['fontFamily'] ?? 'Unknown',
          'fontSize': textStyle?['fontSize'] ?? 'Unknown',
          'fontWeight': textStyle?['fontWeight'] ?? 'Unknown',
          'lineHeight': textStyle?['lineHeightPx'] ?? 'Unknown',
          'letterSpacing': textStyle?['letterSpacing'] ?? 'Unknown',
          'textAlignHorizontal': layout['textAlignHorizontal'] ?? 'LEFT',
          'textAlignVertical': layout['textAlignVertical'] ?? 'TOP',
          'textAutoResize': layout['textAutoResize'] ?? 'NONE',
          'textCase': textStyle?['textCase'] ?? 'ORIGINAL',
          'textDecoration': textStyle?['textDecoration'] ?? 'NONE',
          'maxLines': layout['maxLines'],
          'textStyleId': textStyle?['styleId'],
          'fills': layout['fills'],
          'constraints': layout['constraints'],
          'layoutAlign': layout['layoutAlign'],
          'layoutGrow': layout['layoutGrow'],
          'layoutSizingHorizontal': layout['layoutSizingHorizontal'],
          'layoutSizingVertical': layout['layoutSizingVertical'],
        });
      }
    }
    
    return typography;
  }

  static String _rgbToHex(int r, int g, int b) {
    return '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}';
  }
}
