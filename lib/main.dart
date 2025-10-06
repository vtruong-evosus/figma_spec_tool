import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/figma_api_service.dart';
import 'utils/figma_parser.dart';
import 'utils/figma_url_parser.dart';
import 'config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final FigmaApiService api = FigmaApiService(figmaToken);
  final TextEditingController urlController = TextEditingController();
  
  String fileKey = figmaFileKey;
  String? nodeId = figmaNodeId;
  
  List<Map<String, dynamic>> colors = [];
  List<Map<String, dynamic>> textStyles = [];
  List<Map<String, dynamic>> components = [];
  List<Map<String, dynamic>> layouts = [];
  List<Map<String, dynamic>> designTokens = [];
  
  // Checklist state
  Map<String, bool> checklistItems = {};
  
  bool isLoading = false;
  String? errorMessage;
  bool showUrlInput = true;

  Future<void> loadSpecs() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      Map<String, dynamic> data;
      
        // Always try to use specific node first - avoid full file due to size
        if (nodeId != null && nodeId!.isNotEmpty) {
          try {
            final nodeResponse = await api.getNode(fileKey, nodeId!);
            // Check if the node exists in the response
            if (nodeResponse['nodes'] != null) {
              // Try both formats: with dash (from URL) and with colon (from API)
              String? actualNodeId;
              if (nodeResponse['nodes'][nodeId!] != null) {
                actualNodeId = nodeId!;
              } else {
                // Convert dash to colon format
                final colonFormat = nodeId!.replaceAll('-', ':');
                if (nodeResponse['nodes'][colonFormat] != null) {
                  actualNodeId = colonFormat;
                }
              }
              
              if (actualNodeId != null) {
                if (nodeResponse['nodes'][actualNodeId]['document'] != null) {
                  data = nodeResponse['nodes'][actualNodeId]['document'];
                } else {
                  throw Exception('Node $actualNodeId found but has no document data. Node structure: ${nodeResponse['nodes'][actualNodeId].keys}');
                }
              } else {
                throw Exception('Node $nodeId not found in response. Available nodes: ${nodeResponse['nodes'].keys}');
              }
            } else {
              throw Exception('No nodes found in response. Response structure: ${nodeResponse.keys}');
            }
          } catch (nodeError) {
            throw Exception('Could not load specific node: $nodeError');
          }
        } else {
          // No node ID provided - this is not recommended for large files
          throw Exception('Please use a URL with a specific node-id parameter to target just one component. The full file is too large.');
        }
      
      // The node data might be directly the document or nested under 'document'
      Map<String, dynamic> documentData;
      if (data['document'] != null) {
        documentData = data['document'];
      } else {
        // Node data is directly the document
        documentData = data;
      }
      
      // Use the correct document data for parsing
      final parseData = {
        'document': documentData,
        'styles': data['styles'] ?? {},
        'components': data['components'] ?? {},
        'componentSets': data['componentSets'] ?? {},
      };
      
      setState(() {
        try {
          colors = FigmaParser.extractColors(parseData);
        } catch (e) {
          colors = [];
        }
        
        try {
          textStyles = FigmaParser.extractTextStyles(parseData);
        } catch (e) {
          textStyles = [];
        }
        
        try {
          components = FigmaParser.extractComponents(parseData);
        } catch (e) {
          components = [];
        }
        
        try {
          layouts = FigmaParser.extractLayoutSpecs(parseData);
        } catch (e) {
          layouts = [];
        }
        
        try {
          designTokens = FigmaParser.extractDesignTokens(parseData);
        } catch (e) {
          designTokens = [];
        }
        
        isLoading = false;
        showUrlInput = false;
        
        // Initialize checklist items
        _initializeChecklist();
      });
      
    } catch (e) {
      setState(() {
        // Provide more helpful error messages
        if (e.toString().contains('403')) {
          errorMessage = 'Access denied. Please check your Figma token and file permissions.';
        } else if (e.toString().contains('404')) {
          errorMessage = 'File or node not found. Please check the URL and try again.';
        } else if (e.toString().contains('NoSuchMethodError')) {
          errorMessage = 'Error parsing Figma data. The file structure may be different than expected.';
        } else {
          errorMessage = 'Error loading Figma file: ${e.toString()}';
        }
        isLoading = false;
      });
    }
  }

  void parseAndLoadUrl() {
    final url = urlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        errorMessage = 'Please enter a Figma URL';
      });
      return;
    }

    if (!FigmaUrlParser.isValidFigmaUrl(url)) {
      setState(() {
        errorMessage = 'Please enter a valid Figma URL';
      });
      return;
    }

    final parsed = FigmaUrlParser.parseFigmaUrl(url);
    if (parsed['fileKey'] == null) {
      setState(() {
        errorMessage = 'Could not extract file key from URL';
      });
      return;
    }

    setState(() {
      fileKey = parsed['fileKey']!;
      nodeId = parsed['nodeId'];
      errorMessage = null;
    });

    loadSpecs();
  }

  void resetToUrlInput() {
    setState(() {
      showUrlInput = true;
      colors.clear();
      textStyles.clear();
      components.clear();
      layouts.clear();
      designTokens.clear();
      checklistItems.clear();
      errorMessage = null;
      urlController.clear();
    });
  }

  void _initializeChecklist() {
    checklistItems.clear();
    
    // Add checklist items based on extracted data
    if (colors.isNotEmpty) {
      checklistItems['Colors extracted'] = false;
      checklistItems['Colors reviewed'] = false;
    }
    
    if (textStyles.isNotEmpty) {
      checklistItems['Text styles extracted'] = false;
      checklistItems['Typography reviewed'] = false;
    }
    
    if (components.isNotEmpty) {
      checklistItems['Components extracted'] = false;
      checklistItems['Components reviewed'] = false;
    }
    
    if (layouts.isNotEmpty) {
      checklistItems['Layout specs extracted'] = false;
      checklistItems['Spacing reviewed'] = false;
    }
    
    if (designTokens.isNotEmpty) {
      checklistItems['Design tokens extracted'] = false;
      checklistItems['Design system reviewed'] = false;
    }
    
    // General UX checklist items
    checklistItems['Design specs extracted'] = false;
    checklistItems['UI components identified'] = false;
    checklistItems['Color palette documented'] = false;
    checklistItems['Typography system documented'] = false;
    checklistItems['Spacing system documented'] = false;
    checklistItems['Component library reviewed'] = false;
    checklistItems['Design tokens documented'] = false;
    checklistItems['Accessibility considerations noted'] = false;
    checklistItems['Responsive behavior documented'] = false;
    checklistItems['Interaction states documented'] = false;
  }


  @override
  void initState() {
    super.initState();
    // Start with empty URL field - let user enter their own URL
    urlController.text = '';
  }

  @override
  void dispose() {
    urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Figma Spec Tool',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Figma Spec Tool'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          actions: [
            if (!showUrlInput)
              IconButton(
                icon: const Icon(Icons.home),
                onPressed: resetToUrlInput,
                tooltip: 'Start Over',
              ),
            if (!showUrlInput)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: loadSpecs,
                tooltip: 'Refresh Current Specs',
              ),
            if (!showUrlInput)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'start_over') {
                    resetToUrlInput();
                  } else if (value == 'copy_url') {
                    _copyCurrentUrl();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'start_over',
                    child: ListTile(
                      leading: Icon(Icons.restart_alt),
                      title: Text('Start Over'),
                      subtitle: Text('Load a different Figma file'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'copy_url',
                    child: ListTile(
                      leading: Icon(Icons.link),
                      title: Text('Copy Current URL'),
                      subtitle: Text('Copy the current Figma URL'),
                    ),
                  ),
                ],
            ),
          ],
        ),
        body: showUrlInput
            ? _buildUrlInputScreen()
            : isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading Figma file',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          errorMessage!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: loadSpecs,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                    : _buildSpecsListView(),
      ),
    );
  }

  Widget _buildSpecsListView() {
    return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
          // Header with copy all button
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.content_copy, size: 32, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Design Specifications',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Copy and paste these specs for your development team',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _copyAllSpecs,
                    icon: const Icon(Icons.copy_all, size: 18),
                    label: const Text('Copy All'),
                  ),
                ],
              ),
            ),
                        ),
                        const SizedBox(height: 24),
          
          // Summary card
          Card(
            color: Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📊 Extraction Summary',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Colors: ${colors.length} | Text Styles: ${textStyles.length} | Components: ${components.length} | Layouts: ${layouts.length} | Design Tokens: ${designTokens.length}'),
                  const SizedBox(height: 4),
                  Text('Total nested elements found: ${colors.length + textStyles.length + components.length + layouts.length + designTokens.length}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Checklist progress card
          Card(
            color: Colors.green[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.checklist, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        'Checklist Progress',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: checklistItems.isNotEmpty ? () {
                              setState(() {
                                checklistItems.updateAll((key, value) => true);
                              });
                            } : null,
                            icon: const Icon(Icons.check_box, size: 16),
                            label: const Text('Check All'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: checklistItems.isNotEmpty ? () {
                              setState(() {
                                checklistItems.updateAll((key, value) => false);
                              });
                            } : null,
                            icon: const Icon(Icons.check_box_outline_blank, size: 16),
                            label: const Text('Clear All'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              backgroundColor: Colors.grey[600],
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Checked items: ${checklistItems.values.where((checked) => checked).length} / ${checklistItems.length}'),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: checklistItems.isEmpty ? 0.0 : checklistItems.values.where((checked) => checked).length / checklistItems.length,
                    backgroundColor: Colors.grey[300],
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Specs sections
          _buildSpecsSection('🎨 Colors', colors, _buildColorSpec),
          const SizedBox(height: 24),
          _buildSpecsSection('🔤 Text Styles', textStyles, _buildTextStyleSpec),
          const SizedBox(height: 24),
          _buildSpecsSection('🧩 Components', components, _buildComponentSpec),
          const SizedBox(height: 24),
          _buildSpecsSection('📐 Layout Specs', layouts, _buildLayoutSpec),
          const SizedBox(height: 24),
          _buildSpecsSection('🎯 Design Tokens', designTokens, _buildDesignTokenSpec),
        ],
      ),
    );
  }

  Widget _buildSpecsSection(String title, List<Map<String, dynamic>> items, List<Map<String, dynamic>> Function(Map<String, dynamic>) specBuilder) {
    if (items.isEmpty) return const SizedBox.shrink();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _copySectionSpecs(title, items, (item) => specBuilder(item).map((e) => e['text']).join('\n')),
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final itemKey = '${title}_${index}';
                  final isChecked = checklistItems[itemKey] ?? false;
                  final specItems = specBuilder(item);
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Main item header with checkbox
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: isChecked,
                              onChanged: (bool? value) {
                                setState(() {
                                  checklistItems[itemKey] = value ?? false;
                                  // If checking main item, check all sub-items
                                  if (value == true) {
                                    for (int i = 0; i < specItems.length; i++) {
                                      checklistItems['${itemKey}_sub_$i'] = true;
                                    }
                                  } else {
                                    // If unchecking main item, uncheck all sub-items
                                    for (int i = 0; i < specItems.length; i++) {
                                      checklistItems['${itemKey}_sub_$i'] = false;
                                    }
                                  }
                                });
                              },
                              activeColor: Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item['name'] ?? 'Unnamed',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  decoration: isChecked ? TextDecoration.lineThrough : null,
                                  color: isChecked ? Colors.grey[600] : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Individual checklist items
                        Padding(
                          padding: const EdgeInsets.only(left: 40),
                          child: Column(
                            children: specItems.asMap().entries.map((specEntry) {
                              final specIndex = specEntry.key;
                              final specItem = specEntry.value;
                              final subItemKey = '${itemKey}_sub_$specIndex';
                              final isSubChecked = checklistItems[subItemKey] ?? false;
                              
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Checkbox(
                                      value: isSubChecked,
                                      onChanged: (bool? value) {
                                        setState(() {
                                          checklistItems[subItemKey] = value ?? false;
                                          // Check if all sub-items are checked to update main item
                                          final allSubChecked = specItems.asMap().entries.every((e) => 
                                            checklistItems['${itemKey}_sub_${e.key}'] == true);
                                          checklistItems[itemKey] = allSubChecked;
                                        });
                                      },
                                      activeColor: Colors.green,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        specItem['text'],
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 12,
                                          decoration: isSubChecked ? TextDecoration.lineThrough : null,
                                          color: isSubChecked ? Colors.grey[600] : null,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _buildColorSpec(Map<String, dynamic> color) {
    final hex = '#${color['hex']}';
    final rgb = 'rgb(${color['r']}, ${color['g']}, ${color['b']})';
    final rgba = 'rgba(${color['r']}, ${color['g']}, ${color['b']}, ${color['a']})';
    final opacity = color['opacity'] != null ? ' (${(color['opacity'] * 100).round()}% opacity)' : '';
    final path = (color['path']?.isNotEmpty ?? false) ? ' [${color['path']}]' : '';
    
    return [
      {'text': 'Hex: $hex', 'type': 'hex'},
      {'text': 'RGB: $rgb', 'type': 'rgb'},
      {'text': 'RGBA: $rgba$opacity', 'type': 'rgba'},
      {'text': 'Blend Mode: ${color['blendMode'] ?? 'NORMAL'}', 'type': 'blend_mode'},
    ];
  }

  List<Map<String, dynamic>> _buildTextStyleSpec(Map<String, dynamic> style) {
    final fontSize = style['fontSize'] != null ? '${style['fontSize']}px' : 'Unknown';
    final fontWeight = style['fontWeight'] != null ? '${style['fontWeight']}' : 'Unknown';
    final fontFamily = style['fontFamily'] != null ? style['fontFamily'] : 'Unknown';
    final lineHeight = style['lineHeight'] != null ? '${style['lineHeight']}px' : 'Auto';
    final letterSpacing = style['letterSpacing'] != null ? '${style['letterSpacing']}px' : 'Normal';
    final textAlign = style['textAlign'] != null ? style['textAlign'] : 'Left';
    
    return [
      {'text': 'Font Family: $fontFamily', 'type': 'font_family'},
      {'text': 'Font Size: $fontSize', 'type': 'font_size'},
      {'text': 'Font Weight: $fontWeight', 'type': 'font_weight'},
      {'text': 'Line Height: $lineHeight', 'type': 'line_height'},
      {'text': 'Letter Spacing: $letterSpacing', 'type': 'letter_spacing'},
      {'text': 'Text Align: $textAlign', 'type': 'text_align'},
      {'text': 'Description: ${style['description'] ?? 'No description'}', 'type': 'description'},
    ];
  }

  List<Map<String, dynamic>> _buildComponentSpec(Map<String, dynamic> component) {
    final width = component['width'] != null ? '${component['width']}px' : 'Auto';
    final height = component['height'] != null ? '${component['height']}px' : 'Auto';
    final layoutMode = component['layoutMode'] != null ? component['layoutMode'] : 'None';
    final path = (component['path']?.isNotEmpty ?? false) ? ' [${component['path']}]' : '';
    
    List<Map<String, dynamic>> specItems = [
      {'text': 'Type: ${component['type']}', 'type': 'type'},
      {'text': 'Dimensions: ${width} × ${height}', 'type': 'dimensions'},
      {'text': 'Layout Mode: $layoutMode', 'type': 'layout_mode'},
    ];
    
    if (component['description'] != null && component['description'].isNotEmpty) {
      specItems.add({'text': 'Description: ${component['description']}', 'type': 'description'});
    }
    
    if (component['variants'] != null && component['variants'].isNotEmpty) {
      specItems.add({'text': 'Variants: ${component['variants'].length}', 'type': 'variants_count'});
      for (var variant in component['variants']) {
        specItems.add({'text': '  - ${variant['name']}', 'type': 'variant'});
      }
    }
    
    if (component['children'] != null && component['children'].isNotEmpty) {
      specItems.add({'text': 'Nested Components: ${component['children'].length}', 'type': 'children_count'});
      for (var child in component['children']) {
        specItems.add({'text': '  - ${child['name']} (${child['type']})', 'type': 'child'});
      }
    }
    
    return specItems;
  }

  List<Map<String, dynamic>> _buildLayoutSpec(Map<String, dynamic> layout) {
    final width = layout['width'] != null ? '${layout['width']}px' : 'Auto';
    final height = layout['height'] != null ? '${layout['height']}px' : 'Auto';
    final x = layout['x'] != null ? '${layout['x']}px' : '0';
    final y = layout['y'] != null ? '${layout['y']}px' : '0';
    final layoutMode = layout['layoutMode'] != null ? layout['layoutMode'] : 'None';
    final path = (layout['path']?.isNotEmpty ?? false) ? ' [${layout['path']}]' : '';
    final depth = layout['depth'] != null ? ' (Depth: ${layout['depth']})' : '';
    final visible = layout['visible'] == false ? ' [HIDDEN]' : '';
    final locked = layout['locked'] == true ? ' [LOCKED]' : '';
    
    List<Map<String, dynamic>> specItems = [
      {'text': 'Type: ${layout['type']}', 'type': 'type'},
    ];
    
    if (layout['width'] != null && layout['height'] != null) {
      specItems.add({'text': 'Position: ($x, $y)', 'type': 'position'});
      specItems.add({'text': 'Dimensions: ${width} × ${height}', 'type': 'dimensions'});
    }
    
    if (layout['layoutMode'] != null) {
      specItems.add({'text': 'Layout Mode: $layoutMode', 'type': 'layout_mode'});
    }
    
    // Text-specific properties
    if (layout['type'] == 'TEXT') {
      if (layout['textContent'] != null && layout['textContent'].isNotEmpty) {
        specItems.add({'text': 'Text: "${layout['textContent']}"', 'type': 'text_content'});
      }
      if (layout['textAlignHorizontal'] != null) {
        specItems.add({'text': 'Text Align: ${layout['textAlignHorizontal']}', 'type': 'text_align'});
      }
      if (layout['textAutoResize'] != null) {
        specItems.add({'text': 'Auto Resize: ${layout['textAutoResize']}', 'type': 'auto_resize'});
      }
    }
    
    // Instance-specific properties
    if (layout['type'] == 'INSTANCE') {
      if (layout['componentId'] != null) {
        specItems.add({'text': 'Component ID: ${layout['componentId']}', 'type': 'component_id'});
      }
      if (layout['componentProperties'] != null && layout['componentProperties'].isNotEmpty) {
        specItems.add({'text': 'Properties: ${layout['componentProperties']}', 'type': 'properties'});
      }
    }
    
    // Layout properties
    if (layout['paddingLeft'] != null || layout['paddingRight'] != null || 
        layout['paddingTop'] != null || layout['paddingBottom'] != null) {
      specItems.add({'text': 'Padding: L:${layout['paddingLeft'] ?? 0} R:${layout['paddingRight'] ?? 0} T:${layout['paddingTop'] ?? 0} B:${layout['paddingBottom'] ?? 0}', 'type': 'padding'});
    }
    
    if (layout['itemSpacing'] != null) {
      specItems.add({'text': 'Item Spacing: ${layout['itemSpacing']}px', 'type': 'item_spacing'});
    }
    
    if (layout['constraints'] != null) {
      specItems.add({'text': 'Constraints: ${layout['constraints']}', 'type': 'constraints'});
    }
    
    if (layout['scrollBehavior'] != null) {
      specItems.add({'text': 'Scroll Behavior: ${layout['scrollBehavior']}', 'type': 'scroll_behavior'});
    }
    
    if (layout['blendMode'] != null) {
      specItems.add({'text': 'Blend Mode: ${layout['blendMode']}', 'type': 'blend_mode'});
    }
    
    if (layout['clipsContent'] != null) {
      specItems.add({'text': 'Clips Content: ${layout['clipsContent']}', 'type': 'clips_content'});
    }
    
    if (layout['overflowDirection'] != null) {
      specItems.add({'text': 'Overflow Direction: ${layout['overflowDirection']}', 'type': 'overflow_direction'});
    }
    
    if (layout['maxHeight'] != null) {
      specItems.add({'text': 'Max Height: ${layout['maxHeight']}px', 'type': 'max_height'});
    }
    
    if (layout['minHeight'] != null) {
      specItems.add({'text': 'Min Height: ${layout['minHeight']}px', 'type': 'min_height'});
    }
    
    if (layout['maxWidth'] != null) {
      specItems.add({'text': 'Max Width: ${layout['maxWidth']}px', 'type': 'max_width'});
    }
    
    if (layout['minWidth'] != null) {
      specItems.add({'text': 'Min Width: ${layout['minWidth']}px', 'type': 'min_width'});
    }
    
    if (layout['cornerRadius'] != null) {
      specItems.add({'text': 'Corner Radius: ${layout['cornerRadius']}', 'type': 'corner_radius'});
    }
    
    if (layout['children'] != null && layout['children'].isNotEmpty) {
      specItems.add({'text': 'Nested Elements: ${layout['children'].length}', 'type': 'children_count'});
      for (var child in layout['children']) {
        specItems.add({'text': '  - ${child['name']} (${child['type']}) ${child['width']}×${child['height']}', 'type': 'child'});
      }
    }
    
    return specItems;
  }

  List<Map<String, dynamic>> _buildDesignTokenSpec(Map<String, dynamic> token) {
    final value = token['value'] ?? 'Unknown';
    final type = token['type'] ?? 'Unknown';
    final path = token['path'] != null && token['path'].isNotEmpty ? ' [${token['path']}]' : '';
    
    return [
      {'text': 'Value: $value', 'type': 'value'},
      {'text': 'Type: $type', 'type': 'type'},
      {'text': 'Depth: ${token['depth'] ?? 0}', 'type': 'depth'},
    ];
  }

  void _copyAllSpecs() {
    final allSpecs = StringBuffer();
    
    // Header
    allSpecs.writeln('FIGMA DESIGN SPECIFICATIONS');
    allSpecs.writeln('Generated: ${DateTime.now().toString().split(' ')[0]}');
    allSpecs.writeln('=' * 50);
    allSpecs.writeln();
    
    if (colors.isNotEmpty) {
      allSpecs.writeln('🎨 COLOR PALETTE');
      allSpecs.writeln('─' * 30);
      for (final color in colors) {
        allSpecs.writeln('• ${color['name']}${color['path'] != null && color['path'].isNotEmpty ? ' [${color['path']}]' : ''}');
        for (final spec in _buildColorSpec(color)) {
          allSpecs.writeln('  ${spec['text']}');
        }
        allSpecs.writeln();
      }
    }
    
    if (textStyles.isNotEmpty) {
      allSpecs.writeln('🔤 TYPOGRAPHY SYSTEM');
      allSpecs.writeln('─' * 30);
      for (final style in textStyles) {
        allSpecs.writeln('• ${style['name']}');
        for (final spec in _buildTextStyleSpec(style)) {
          allSpecs.writeln('  ${spec['text']}');
        }
        allSpecs.writeln();
      }
    }
    
    if (components.isNotEmpty) {
      allSpecs.writeln('🧩 COMPONENT LIBRARY');
      allSpecs.writeln('─' * 30);
      for (final component in components) {
        allSpecs.writeln('• ${component['name']}${component['path'] != null && component['path'].isNotEmpty ? ' [${component['path']}]' : ''}');
        for (final spec in _buildComponentSpec(component)) {
          allSpecs.writeln('  ${spec['text']}');
        }
        allSpecs.writeln();
      }
    }
    
    if (layouts.isNotEmpty) {
      allSpecs.writeln('📐 LAYOUT SPECIFICATIONS');
      allSpecs.writeln('─' * 30);
      for (final layout in layouts) {
        allSpecs.writeln('• ${layout['name']}${layout['path'] != null && layout['path'].isNotEmpty ? ' [${layout['path']}]' : ''}');
        for (final spec in _buildLayoutSpec(layout)) {
          allSpecs.writeln('  ${spec['text']}');
        }
        allSpecs.writeln();
      }
    }
    
    if (designTokens.isNotEmpty) {
      allSpecs.writeln('🎯 DESIGN TOKENS');
      allSpecs.writeln('─' * 30);
      for (final token in designTokens) {
        allSpecs.writeln('• ${token['name']}${token['path'] != null && token['path'].isNotEmpty ? ' [${token['path']}]' : ''}');
        for (final spec in _buildDesignTokenSpec(token)) {
          allSpecs.writeln('  ${spec['text']}');
        }
        allSpecs.writeln();
      }
    }
    
    // Footer
    allSpecs.writeln('=' * 50);
    allSpecs.writeln('Generated by Figma Spec Tool');
    
    Clipboard.setData(ClipboardData(text: allSpecs.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All specs copied to clipboard!')),
    );
  }

  void _copySectionSpecs(String title, List<Map<String, dynamic>> items, String Function(Map<String, dynamic>) specBuilder) {
    final specs = items.map((item) => specBuilder(item)).join('\n');
    Clipboard.setData(ClipboardData(text: specs));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title specs copied to clipboard!')),
    );
  }

  void _copyCurrentUrl() {
    final currentUrl = urlController.text.isNotEmpty 
        ? urlController.text 
        : 'https://www.figma.com/design/$fileKey/LOU-Service?node-id=$nodeId';
    
    Clipboard.setData(ClipboardData(text: currentUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Current Figma URL copied to clipboard!')),
    );
  }


  Widget _buildUrlInputScreen() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.design_services,
            size: 80,
            color: Colors.blue,
                        ),
                        const SizedBox(height: 24),
          Text(
            'Figma Spec Tool',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Extract design specifications from any Figma link',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextField(
            controller: urlController,
            decoration: const InputDecoration(
              labelText: 'Figma URL',
              hintText: 'https://www.figma.com/design/...',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.link),
              helperText: 'Paste any Figma design URL here',
            ),
            keyboardType: TextInputType.url,
            onSubmitted: (_) => parseAndLoadUrl(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : parseAndLoadUrl,
              icon: isLoading 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.analytics),
              label: Text(isLoading ? 'Loading...' : 'Extract Specs'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                border: Border.all(color: Colors.red[200]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      errorMessage!,
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
                        const SizedBox(height: 24),
          Text(
            'Supported URL formats:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '• https://www.figma.com/design/[file-key]/[file-name]\n'
            '• https://www.figma.com/file/[file-key]/[file-name]\n'
            '• URLs with node-id parameters for specific elements',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.left,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              border: Border.all(color: Colors.blue[200]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue[700], size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Large File Tip',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'For large Figma files, use URLs with specific node-id parameters to extract specs from just that component or page.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[700],
                  ),
                        ),
                      ],
                    ),
                  ),
        ],
      ),
    );
  }

  Widget _buildSection(
    String title,
    List<Map<String, dynamic>> items,
    Widget Function(Map<String, dynamic>) itemBuilder,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Text(
            'No items found',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          )
        else
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: itemBuilder(item),
              )),
      ],
    );
  }

  Widget _buildColorItem(Map<String, dynamic> color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Color.fromRGBO(
                color['r'],
                color['g'],
                color['b'],
                color['a'] ?? 1.0,
              ),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey[400]!),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  color['name'] ?? 'Unnamed',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (color['path'] != null && color['path'].isNotEmpty)
                  Text(
                    'Path: ${color['path']}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                ),
                Text('RGB: ${color['r']}, ${color['g']}, ${color['b']}'),
                Text('Hex: ${color['hex']}'),
                if (color['opacity'] != null && color['opacity'] != 1.0)
                  Text('Opacity: ${color['opacity']}'),
                if (color['type'] != null)
                  Text('Type: ${color['type']}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextStyleItem(Map<String, dynamic> style) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.text_fields, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  style['name'] ?? 'Unnamed',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (style['fontFamily'] != 'Unknown')
                  Text('Font: ${style['fontFamily']}'),
                if (style['fontSize'] != 'Unknown')
                  Text('Size: ${style['fontSize']}px'),
                if (style['fontWeight'] != 'Unknown')
                  Text('Weight: ${style['fontWeight']}'),
                if (style['lineHeight'] != 'Unknown')
                  Text('Line Height: ${style['lineHeight']}px'),
                if (style['description'] != null && style['description'].isNotEmpty)
                  Text(
                    style['description'],
                    style: TextStyle(color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComponentItem(Map<String, dynamic> component) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
        children: [
          const Icon(Icons.widgets, color: Colors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  component['name'] ?? 'Unnamed',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (component['path'] != null && component['path'].isNotEmpty)
                      Text(
                        'Path: ${component['path']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                ),
                Text('Type: ${component['type']}'),
                if (component['width'] != null && component['height'] != null)
                  Text('Size: ${component['width']} × ${component['height']}'),
                    if (component['layoutMode'] != null)
                      Text('Layout: ${component['layoutMode']}'),
                if (component['description'] != null && component['description'].isNotEmpty)
                  Text(
                    component['description'],
                    style: TextStyle(color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
            ],
          ),
          if (component['variants'] != null && component['variants'].isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Variants:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            ...component['variants'].map<Widget>((variant) => Padding(
              padding: const EdgeInsets.only(left: 16, top: 4),
              child: Text(
                '• ${variant['name']} (${variant['width']} × ${variant['height']})',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            )),
          ],
          if (component['children'] != null && component['children'].isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Nested Components:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            ...component['children'].map<Widget>((child) => Padding(
              padding: const EdgeInsets.only(left: 16, top: 4),
              child: Text(
                '• ${child['name']} (${child['type']})',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildLayoutItem(Map<String, dynamic> layout) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.crop_free, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  layout['name'] ?? 'Unnamed',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Type: ${layout['type']}'),
                Text('Position: (${layout['x']}, ${layout['y']})'),
                Text('Size: ${layout['width']} × ${layout['height']}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesignTokenItem(Map<String, dynamic> token) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getTokenIcon(token['type']),
                color: _getTokenColor(token['type']),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      token['name'] ?? 'Unnamed',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (token['path'] != null && token['path'].isNotEmpty)
                      Text(
                        'Path: ${token['path']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    Text('Type: ${token['type']}'),
                    if (token['depth'] != null)
                      Text('Depth: ${token['depth']}'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Value: ${_formatTokenValue(token['value'])}',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTokenIcon(String type) {
    switch (type) {
      case 'color':
        return Icons.palette;
      case 'spacing':
        return Icons.space_bar;
      case 'typography':
        return Icons.text_fields;
      case 'borderRadius':
        return Icons.crop_free;
      default:
        return Icons.style;
    }
  }

  Color _getTokenColor(String type) {
    switch (type) {
      case 'color':
        return Colors.purple;
      case 'spacing':
        return Colors.blue;
      case 'typography':
        return Colors.orange;
      case 'borderRadius':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatTokenValue(dynamic value) {
    if (value == null) return 'null';
    if (value is Map) {
      return value.entries.map((e) => '${e.key}: ${e.value}').join(', ');
    }
    return value.toString();
  }
}