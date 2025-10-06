# Figma Spec Tool

A Flutter application that extracts design specifications from Figma files using the Figma API.

## 🚀 Features

- **Dynamic URL Input**: Enter any Figma URL to extract specs from any file
- **Color Extraction**: Extracts all colors with RGB and hex values
- **Text Styles**: Extracts typography information including font family, size, weight, and line height
- **Components**: Lists all Figma components and component sets
- **Layout Specs**: Shows positioning and sizing information for all elements
- **Specific Node Support**: Can target specific nodes within a Figma file
- **Modern UI**: Clean, Material Design 3 interface with loading states and error handling
- **URL Parsing**: Automatically extracts file keys and node IDs from Figma URLs

## 📋 Prerequisites

- Flutter SDK (3.8.1 or higher)
- Figma Personal Access Token
- Access to the Figma file you want to analyze

## 🛠️ Setup Instructions

### Step 1: Get Your Figma Personal Access Token

1. Go to [Figma Developer Settings](https://www.figma.com/developers/api#access-tokens)
2. Click "Generate new token"
3. Give it a descriptive name (e.g., "Figma Spec Tool")
4. Copy the generated token

### Step 2: Configure Your Figma Token

1. Open `lib/config.dart`
2. Replace `YOUR_PERSONAL_ACCESS_TOKEN` with your actual Figma token

**Note**: The app now supports dynamic URL input, so you don't need to hardcode file keys or node IDs!

### Step 3: Run the Application

```bash
# Navigate to project directory
cd /path/to/figma_spec_tool

# Get dependencies
flutter pub get

# Run the app
flutter run
```

## 🎯 Usage

1. **Launch the app**: You'll see a welcome screen with a URL input field
2. **Enter Figma URL**: Paste any Figma design URL (supports both `/design/` and `/file/` formats)
3. **Extract specs**: Click "Extract Specs" to analyze the file
4. **View extracted data**: Browse through colors, text styles, components, and layout specs
5. **Load different files**: Use the home button to load a different Figma file
6. **Refresh data**: Use the refresh button to reload specs from the current file
7. **Error handling**: Clear error messages guide you if something goes wrong

### Supported URL Formats

- `https://www.figma.com/design/[file-key]/[file-name]`
- `https://www.figma.com/file/[file-key]/[file-name]`
- URLs with `node-id` parameters for specific elements
- URLs with additional query parameters (they'll be ignored)

## 📱 What You'll See

### Colors Section 🎨
- Color swatches with visual representation
- RGB values
- Hex color codes
- Color names

### Text Styles Section 🔤
- Typography names
- Font family information
- Font size (in pixels)
- Font weight
- Line height
- Descriptions (if available)

### Components Section 🧩
- Component names
- Component types (COMPONENT or COMPONENT_SET)
- Dimensions (width × height)
- Descriptions (if available)

### Layout Specs Section 📐
- Element names
- Element types
- Position coordinates (x, y)
- Dimensions (width × height)

## 🔧 Technical Details

### Architecture
- **API Service**: Handles Figma API communication
- **Parser**: Extracts and processes design data
- **UI**: Material Design 3 interface with proper state management

### Key Files
- `lib/main.dart`: Main application and UI with URL input functionality
- `lib/services/figma_api_service.dart`: Figma API integration
- `lib/utils/figma_parser.dart`: Data extraction logic
- `lib/utils/figma_url_parser.dart`: URL parsing utility
- `lib/config.dart`: Configuration settings (token only)

### API Endpoints Used
- `GET /v1/files/{file_key}`: Get entire file data
- `GET /v1/files/{file_key}/nodes?ids={node_id}`: Get specific node data

## 🐛 Troubleshooting

### Common Issues

1. **"Failed to load Figma file" error**
   - Check your Figma token is correct
   - Verify the file key is accurate
   - Ensure you have access to the Figma file

2. **Empty results**
   - The file might not have the expected design elements
   - Try targeting a specific node instead of the entire file
   - Check if the file has published styles/components

3. **Network errors**
   - Check your internet connection
   - Verify Figma API is accessible
   - Try refreshing the data

### Debug Tips

- Use the refresh button to reload data
- Check the console for detailed error messages
- Verify your Figma token permissions
- Test with a simpler Figma file first

## 🚀 Future Enhancements

- Export specs to various formats (JSON, CSS, etc.)
- Support for more design tokens
- Batch processing of multiple files
- Integration with design systems
- Real-time updates when Figma files change

## 📄 License

This project is for educational and development purposes.

---

**Happy designing! 🎨**