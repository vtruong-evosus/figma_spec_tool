import 'package:flutter_dotenv/flutter_dotenv.dart';

// Configuration file for Figma API
// Environment variables are loaded from .env file
// Copy .env.example to .env and add your actual values

String get figmaToken => dotenv.env['FIGMA_TOKEN'] ?? '';
String get figmaFileKey => dotenv.env['FIGMA_FILE_KEY'] ?? '6OoAD2dZFiVFYY22Fjb7vi';
String get figmaNodeId => dotenv.env['FIGMA_NODE_ID'] ?? '14339-216969';
