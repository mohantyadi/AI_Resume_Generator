# AI Resume & Cover Letter Generator

A production-ready full-stack application that uses GPT-4o to generate tailored resumes and cover letters from job descriptions, then compiles them to professional PDFs using LaTeX.

## Tech Stack

- **Frontend**: Angular 17
- **Backend**: Node.js + Express
- **AI**: OpenAI GPT-4o
- **PDF**: LaTeX (latexmk / pdflatex)

## Features

- Paste a job description → AI generates tailored resume sections + cover letter
- LaTeX templates filled with AI content
- PDFs compiled via latexmk
- Output saved to `backend/outputs/{company_name}/`

## Quick Start

```bash
chmod +x setup.sh
./setup.sh
```

Or manually:

### 1. Backend
```bash
cd backend
cp .env.example .env
# Edit .env and add your OPENAI_API_KEY
npm install
npm start
```

### 2. Frontend
```bash
cd frontend
npm install
npm start
```

## Requirements

- Node.js 18+
- npm 9+
- LaTeX: `sudo apt-get install texlive-full` (Ubuntu) or `brew install --cask mactex` (Mac)
- OpenAI API key

## API Endpoints

- `POST /api/generate` - Generate resume + cover letter
- `GET /api/health` - Health check
- `GET /outputs/{company}/resume.pdf` - Download resume PDF
- `GET /outputs/{company}/cover_letter.pdf` - Download cover letter PDF

## Output Structure

```
backend/outputs/
└── {company_name}/
    ├── resume.tex
    ├── resume.pdf
    ├── cover_letter.tex
    └── cover_letter.pdf
```

## ZIP the project

```bash
zip -r ai-resume-generator.zip . --exclude="*/node_modules/*" --exclude="*/.git/*" --exclude="*/dist/*" --exclude="*/outputs/*"
```
