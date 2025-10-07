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
        });
      }
    });
    return styles;
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

  // Enhanced method to extract design tokens with semantic names and variables
  static List<Map<String, dynamic>> extractDesignTokens(Map<String, dynamic> file) {
    final tokens = <Map<String, dynamic>>[];
    final variables = file['variables'] ?? {};
    final styles = file['styles'] ?? {};
    
    void parseNode(Map node, String parentPath, int depth) {
      // Extract color tokens with semantic references
      if (node['fills'] != null) {
        for (var fill in node['fills']) {
          if (fill['type'] == 'SOLID') {
            final c = fill['color'];
            final tokenData = {
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
            };
            
            // Check for variable references
            if (fill['boundVariables'] != null) {
              tokenData['variableReferences'] = fill['boundVariables'];
              tokenData['semanticName'] = _extractVariableName(fill['boundVariables'], variables);
            }
            
            // Check for style references
            if (node['styles'] != null && node['styles']['fill'] != null) {
              final styleKey = node['styles']['fill'];
              if (styles[styleKey] != null) {
                tokenData['styleReference'] = styles[styleKey]['name'];
                tokenData['styleDescription'] = styles[styleKey]['description'] ?? '';
              }
            }
            
            tokens.add(tokenData);
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

      // Extract typography tokens with semantic references
      if (node['style'] != null) {
        final tokenData = {
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
            'textAlign': node['style']['textAlignHorizontal'],
            'textDecoration': node['style']['textDecoration'],
          },
        };
        
        // Check for variable references in typography
        if (node['boundVariables'] != null) {
          tokenData['variableReferences'] = node['boundVariables'];
          tokenData['semanticName'] = _extractVariableName(node['boundVariables'], variables);
        }
        
        // Check for style references
        if (node['styles'] != null && node['styles']['text'] != null) {
          final styleKey = node['styles']['text'];
          if (styles[styleKey] != null) {
            tokenData['styleReference'] = styles[styleKey]['name'];
            tokenData['styleDescription'] = styles[styleKey]['description'] ?? '';
          }
        }
        
        tokens.add(tokenData);
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

  static String _rgbToHex(int r, int g, int b) {
    return '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}';
  }
  
  // Extract semantic variable names from bound variables
  static String _extractVariableName(Map<String, dynamic> boundVariables, Map<String, dynamic> variables) {
    for (var key in boundVariables.keys) {
      final variableId = boundVariables[key]['id'];
      if (variables[variableId] != null) {
        return variables[variableId]['name'] ?? 'Unknown Variable';
      }
    }
    return 'Unknown Variable';
  }
  
  // Extract Figma Variables (Design System Tokens)
  static List<Map<String, dynamic>> extractFigmaVariables(Map<String, dynamic> file) {
    final variables = <Map<String, dynamic>>[];
    final figmaVariables = file['variables'] ?? {};
    
    figmaVariables.forEach((key, variable) {
      variables.add({
        'id': key,
        'name': variable['name'],
        'description': variable['description'] ?? '',
        'type': variable['resolvedType'],
        'value': variable['valuesByMode'],
        'hiddenFromPublishing': variable['hiddenFromPublishing'] ?? false,
        'scopes': variable['scopes'] ?? [],
        'codeSyntax': variable['codeSyntax'] ?? {},
      });
    });
    
    return variables;
  }
  
  // Extract Component Properties and Variants
  static List<Map<String, dynamic>> extractComponentProperties(Map<String, dynamic> file) {
    final properties = <Map<String, dynamic>>[];
    
    void parseNode(Map node, String parentPath, int depth) {
      if (node['type'] == 'COMPONENT' || node['type'] == 'COMPONENT_SET') {
        final componentData = {
          'name': node['name'],
          'type': node['type'],
          'id': node['id'],
          'description': node['description'] ?? '',
          'path': parentPath,
          'depth': depth,
          'width': node['absoluteBoundingBox']?['width'],
          'height': node['absoluteBoundingBox']?['height'],
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
        
        // Extract component properties
        if (node['componentPropertyDefinitions'] != null) {
          componentData['properties'] = node['componentPropertyDefinitions'];
        }
        
        // Extract variant properties for component sets
        if (node['type'] == 'COMPONENT_SET' && node['children'] != null) {
          componentData['variants'] = node['children'].map<Map<String, dynamic>>((variant) => {
            'name': variant['name'],
            'id': variant['id'],
            'description': variant['description'] ?? '',
            'width': variant['absoluteBoundingBox']?['width'],
            'height': variant['absoluteBoundingBox']?['height'],
            'variantProperties': variant['variantProperties'] ?? {},
            'boundVariables': variant['boundVariables'] ?? {},
          }).toList();
        }
        
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
                'variantProperties': child['variantProperties'] ?? {},
                'boundVariables': child['boundVariables'] ?? {},
              });
            }
          }
        }
        
        properties.add(componentData);
      }
      
      if (node['children'] != null) {
        final currentPath = parentPath.isEmpty ? node['name'] : '$parentPath > ${node['name']}';
        for (var child in node['children']) {
          parseNode(child, currentPath, depth + 1);
        }
      }
    }
    
    parseNode(file['document'], '', 0);
    return properties;
  }
}
