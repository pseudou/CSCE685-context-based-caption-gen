# Architecture Overview: Context-Based Caption Generation

## System Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                           User Interface                            │
│  (app/views/users/show.html.erb)                                   │
└────────────┬────────────────────────────────────────┬───────────────┘
             │                                        │
             │ Upload PPTX ("Launch analysis")        │ Download DOCX
             │                                        │
             ▼                                        ▼
┌────────────────────────┐               ┌────────────────────────────┐
│ WorkspaceController    │               │ WorkspaceController        │
│ #upload                │               │ #download_analysis_report  │
└──────────┬─────────────┘               └────────────────────────────┘
           │
           │ 1. Extract slide images
           ▼
┌──────────────────────────────┐
│ PptImageExtractor            │
│ - Extracts slide images      │
│ - Returns: SlideImage[]      │
└──────────┬───────────────────┘
           │
           │ 2. Analyze each slide image
           ▼
┌──────────────────────────────┐
│ GeminiSlideAnalyst           │
│ - Rolling context window     │
│ - Calls Gemini API           │
│ - Returns: SlideInsight[]    │
└──────────┬───────────────────┘
           │
           │ SlideInsight {
           │   slide_number: int
           │   image_name: string
           │   title: string
           │   analysis: string
           │ }
           │
           │ 3. Generate DOCX
           ▼
┌──────────────────────────────┐
│ DocxReportGenerator          │
│ - Converts insights to DOCX  │
│ - Saves to tmp/reports/      │
└──────────┬───────────────────┘
           │
           │ 4. Store paths
           ▼
┌──────────────────────────────┐
│ Session + tmp/analysis JSON  │
│ - analysis_json_path         │
│ - analysis_report_path       │
└──────────────────────────────┘
```

## Component Details

### 1. PptImageExtractor
- **Input:** Uploaded PPTX file
- **Process:**
  - Opens PPTX as ZIP archive
  - Extracts slide images
- **Output:** Array of SlideImage objects

### 2. GeminiSlideAnalyst
- **Input:** Array of SlideImage objects
- **Process:**
  - For each slide image:
    - Generate a concise title
    - Generate a 2-3 sentence analysis
  - Maintain a rolling context window of prior slide titles
- **Output:** Array of SlideInsight objects

### 3. DocxReportGenerator
- **Input:** Array of SlideInsight objects
- **Process:**
  - Create HTML
  - Convert HTML to DOCX (htmltoword)
  - Save to tmp/
- **Output:** File path to generated DOCX

## Data Structures

### SlideImage (Struct)
```ruby
{
  slide_number: Integer,
  image_name: String,
  mime_type: String,
  binary: String
}
```

### SlideInsight (Struct)
```ruby
{
  slide_number: Integer,
  image_name: String,
  title: String,
  analysis: String
}
```

## Environment Configuration

```bash
GEMINI_API_KEY=<your_key>              # Required
GEMINI_MODEL=gemini-2.5-flash-lite     # Optional
GEMINI_CONTEXT_WINDOW=4                # Optional
```
