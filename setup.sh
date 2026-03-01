#!/bin/bash

# ============================================================
# AI Resume & Cover Letter Generator - Complete Setup Script
# ============================================================

set -e  # Exit on any error

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo ""
echo -e "${BLUE}${BOLD}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}${BOLD}║   AI Resume & Cover Letter Generator       ║${NC}"
echo -e "${BLUE}${BOLD}║   Full Stack Setup Script                  ║${NC}"
echo -e "${BLUE}${BOLD}╚════════════════════════════════════════════╝${NC}"
echo ""

# ============================================================
# SECTION 1: Prerequisites Check
# ============================================================
echo -e "${CYAN}${BOLD}[1/6] Checking Prerequisites...${NC}"

# Node.js
if ! command -v node &>/dev/null; then
  echo -e "${RED}✗ Node.js not found. Please install Node.js 18+: https://nodejs.org${NC}"
  exit 1
fi
NODE_VER=$(node -v)
echo -e "${GREEN}✓ Node.js: ${NODE_VER}${NC}"

# npm
if ! command -v npm &>/dev/null; then
  echo -e "${RED}✗ npm not found${NC}"
  exit 1
fi
echo -e "${GREEN}✓ npm: $(npm -v)${NC}"

# LaTeX
LATEX_AVAILABLE=false
if command -v latexmk &>/dev/null; then
  echo -e "${GREEN}✓ latexmk available (PDF compilation enabled)${NC}"
  LATEX_AVAILABLE=true
elif command -v pdflatex &>/dev/null; then
  echo -e "${GREEN}✓ pdflatex available (PDF compilation enabled)${NC}"
  LATEX_AVAILABLE=true
else
  echo -e "${YELLOW}⚠ LaTeX not found. PDF compilation will be skipped.${NC}"
  echo -e "${YELLOW}  Install: sudo apt-get install texlive-full (Ubuntu)${NC}"
  echo -e "${YELLOW}           brew install --cask mactex (macOS)${NC}"
fi

# ============================================================
# SECTION 2: Create Folder Structure
# ============================================================
echo ""
echo -e "${CYAN}${BOLD}[2/6] Creating Folder Structure...${NC}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

mkdir -p backend/routes
mkdir -p backend/templates
mkdir -p backend/outputs
mkdir -p frontend/src/app/components/generator
mkdir -p frontend/src/app/services
mkdir -p frontend/src/environments
mkdir -p frontend/src/assets

echo -e "${GREEN}✓ Folder structure created${NC}"

# ============================================================
# SECTION 3: Write All Files
# ============================================================
echo ""
echo -e "${CYAN}${BOLD}[3/6] Writing All Project Files...${NC}"

# ---- backend/package.json ----
cat > backend/package.json << 'PKGJSON'
{
  "name": "ai-resume-generator-backend",
  "version": "1.0.0",
  "description": "AI Resume & Cover Letter Generator Backend",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "cors": "^2.8.5",
    "dotenv": "^16.3.1",
    "express": "^4.18.2",
    "openai": "^4.28.0",
    "uuid": "^9.0.0"
  },
  "devDependencies": {
    "nodemon": "^3.0.3"
  }
}
PKGJSON

# ---- backend/.env ----
if [ ! -f backend/.env ]; then
  cat > backend/.env << 'ENVFILE'
OPENAI_API_KEY=your_openai_api_key_here
PORT=3000
NODE_ENV=development
ENVFILE
  echo -e "${YELLOW}  ⚠ Created backend/.env — please add your OPENAI_API_KEY${NC}"
else
  echo -e "${GREEN}  ✓ backend/.env already exists, skipping${NC}"
fi

# ---- backend/server.js ----
cat > backend/server.js << 'SERVERJS'
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs');

const generateRouter = require('./routes/generate');

const app = express();
const PORT = process.env.PORT || 3000;

const outputsDir = path.join(__dirname, 'outputs');
if (!fs.existsSync(outputsDir)) {
  fs.mkdirSync(outputsDir, { recursive: true });
}

app.use(cors({
  origin: ['http://localhost:4200', 'http://localhost:4201'],
  methods: ['GET', 'POST'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
app.use('/outputs', express.static(path.join(__dirname, 'outputs')));

app.use('/api/generate', generateRouter);

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(500).json({
    error: err.message || 'Internal server error',
    details: process.env.NODE_ENV === 'development' ? err.stack : undefined
  });
});

app.listen(PORT, () => {
  console.log(`✅ Server running on http://localhost:${PORT}`);
  console.log(`📁 Outputs directory: ${outputsDir}`);
});

module.exports = app;
SERVERJS

# ---- backend/routes/generate.js ----
cat > backend/routes/generate.js << 'GENERATEJS'
const express = require('express');
const router = express.Router();
const path = require('path');
const fs = require('fs');
const { execSync } = require('child_process');
const OpenAI = require('openai');

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

function sanitizeFileName(name) {
  return name
    .replace(/[^a-zA-Z0-9_\-\s]/g, '')
    .replace(/\s+/g, '_')
    .toLowerCase()
    .substring(0, 50);
}

function escapeLatex(str) {
  if (!str) return '';
  return str
    .replace(/\\/g, '\\textbackslash{}')
    .replace(/&/g, '\\&')
    .replace(/%/g, '\\%')
    .replace(/\$/g, '\\$')
    .replace(/#/g, '\\#')
    .replace(/_/g, '\\_')
    .replace(/\{/g, '\\{')
    .replace(/\}/g, '\\}')
    .replace(/~/g, '\\textasciitilde{}')
    .replace(/\^/g, '\\textasciicircum{}')
    .replace(/</g, '\\textless{}')
    .replace(/>/g, '\\textgreater{}');
}

async function generateAIContent(jobDescription, companyName, role) {
  const prompt = `You are an expert resume and cover letter writer. Based on the job description below, generate professional resume sections and a cover letter.

Job Description:
${jobDescription}

Company: ${companyName}
Role: ${role || 'Not specified'}

Return a JSON object with EXACTLY these fields (no markdown, pure JSON):
{
  "summary": "A compelling 2-3 sentence professional summary tailored to this role.",
  "skills": "A comma-separated list of 10-15 relevant technical and soft skills.",
  "projects": "2-3 relevant project descriptions. Format: 'Project Name: description. Technologies: tech1, tech2.' Separate with double newline.",
  "coverLetter": "A professional 3-paragraph cover letter body (no salutation or closing). First: enthusiasm for company. Second: 2-3 achievements. Third: forward-looking statement."
}

Make content specific, quantified, and tailored. Avoid LaTeX special characters like &, $, %, #, _ in the text.`;

  const response = await openai.chat.completions.create({
    model: 'gpt-4o',
    messages: [
      { role: 'system', content: 'You are a professional resume writer. Always return valid JSON only, no markdown.' },
      { role: 'user', content: prompt }
    ],
    temperature: 0.7,
    response_format: { type: 'json_object' }
  });

  return JSON.parse(response.choices[0].message.content);
}

function fillTemplate(templatePath, replacements) {
  let template = fs.readFileSync(templatePath, 'utf8');
  for (const [key, value] of Object.entries(replacements)) {
    const regex = new RegExp(`\\{\\{${key}\\}\\}`, 'g');
    template = template.replace(regex, value);
  }
  return template;
}

function compileLaTeX(texFilePath, outputDir) {
  try {
    execSync(`latexmk -pdf -interaction=nonstopmode -output-directory="${outputDir}" "${texFilePath}"`, { timeout: 60000, stdio: 'pipe' });
    return true;
  } catch (err) {
    try {
      execSync(`pdflatex -interaction=nonstopmode -output-directory="${outputDir}" "${texFilePath}"`, { timeout: 60000, stdio: 'pipe' });
      return true;
    } catch (err2) {
      throw new Error('LaTeX compilation failed. Install latexmk or pdflatex.\n' + err.message);
    }
  }
}

function cleanAuxFiles(dir) {
  const extensions = ['.aux', '.log', '.out', '.fls', '.fdb_latexmk', '.toc', '.synctex.gz'];
  try {
    fs.readdirSync(dir).forEach(file => {
      if (extensions.some(ext => file.endsWith(ext))) {
        fs.unlinkSync(path.join(dir, file));
      }
    });
  } catch (e) {}
}

router.post('/', async (req, res) => {
  const { jobDescription, companyName, role } = req.body;

  if (!jobDescription || !companyName) {
    return res.status(400).json({ error: 'jobDescription and companyName are required' });
  }

  try {
    console.log(`🤖 Generating AI content for ${companyName}...`);
    const aiContent = await generateAIContent(jobDescription, companyName, role);

    const sanitizedCompany = sanitizeFileName(companyName);
    const outputDir = path.join(__dirname, '..', 'outputs', sanitizedCompany);
    if (!fs.existsSync(outputDir)) fs.mkdirSync(outputDir, { recursive: true });

    const resumeTemplatePath = path.join(__dirname, '..', 'templates', 'resume.tex');
    const coverTemplatePath = path.join(__dirname, '..', 'templates', 'cover_letter.tex');

    const resumeTex = fillTemplate(resumeTemplatePath, {
      SUMMARY: escapeLatex(aiContent.summary),
      SKILLS: escapeLatex(aiContent.skills),
      PROJECTS: escapeLatex(aiContent.projects),
      COMPANY: escapeLatex(companyName),
      ROLE: escapeLatex(role || 'Software Engineer')
    });

    const coverTex = fillTemplate(coverTemplatePath, {
      COMPANY: escapeLatex(companyName),
      ROLE: escapeLatex(role || 'Software Engineer'),
      BODY: escapeLatex(aiContent.coverLetter)
    });

    const resumeTexPath = path.join(outputDir, 'resume.tex');
    const coverTexPath = path.join(outputDir, 'cover_letter.tex');
    fs.writeFileSync(resumeTexPath, resumeTex);
    fs.writeFileSync(coverTexPath, coverTex);

    let resumePdfGenerated = false;
    let coverPdfGenerated = false;
    let compilationWarning = null;

    try {
      console.log('📄 Compiling resume PDF...');
      compileLaTeX(resumeTexPath, outputDir);
      resumePdfGenerated = fs.existsSync(path.join(outputDir, 'resume.pdf'));
    } catch (e) {
      compilationWarning = e.message;
      console.warn('⚠️ Resume PDF compilation failed:', e.message);
    }

    try {
      console.log('📄 Compiling cover letter PDF...');
      compileLaTeX(coverTexPath, outputDir);
      coverPdfGenerated = fs.existsSync(path.join(outputDir, 'cover_letter.pdf'));
    } catch (e) {
      if (!compilationWarning) compilationWarning = e.message;
    }

    cleanAuxFiles(outputDir);

    const baseUrl = `${req.protocol}://${req.get('host')}`;

    res.json({
      success: true,
      aiContent,
      outputDir: `outputs/${sanitizedCompany}/`,
      files: {
        resumeTex: `${baseUrl}/outputs/${sanitizedCompany}/resume.tex`,
        coverTex: `${baseUrl}/outputs/${sanitizedCompany}/cover_letter.tex`,
        resumePdf: resumePdfGenerated ? `${baseUrl}/outputs/${sanitizedCompany}/resume.pdf` : null,
        coverPdf: coverPdfGenerated ? `${baseUrl}/outputs/${sanitizedCompany}/cover_letter.pdf` : null
      },
      pdfGenerated: resumePdfGenerated || coverPdfGenerated,
      warning: compilationWarning
    });
  } catch (error) {
    console.error('Generation error:', error);
    res.status(500).json({ error: error.message || 'Failed to generate documents' });
  }
});

router.get('/status/:company', (req, res) => {
  const sanitized = sanitizeFileName(req.params.company);
  const outputDir = path.join(__dirname, '..', 'outputs', sanitized);
  if (!fs.existsSync(outputDir)) return res.json({ exists: false });
  const files = fs.readdirSync(outputDir);
  res.json({
    exists: true,
    files: files.map(f => ({
      name: f,
      size: fs.statSync(path.join(outputDir, f)).size,
      url: `${req.protocol}://${req.get('host')}/outputs/${sanitized}/${f}`
    }))
  });
});

module.exports = router;
GENERATEJS

# ---- backend/templates/resume.tex ----
cat > backend/templates/resume.tex << 'RESUMETEX'
\documentclass[11pt,a4paper]{article}
\usepackage[margin=0.75in]{geometry}
\usepackage[T1]{fontenc}
\usepackage[utf8]{inputenc}
\usepackage{hyperref}
\usepackage{xcolor}
\usepackage{titlesec}
\usepackage{enumitem}
\usepackage{parskip}
\usepackage{array}
\usepackage{tabularx}
\usepackage{fancyhdr}

\definecolor{primary}{RGB}{30, 64, 175}
\definecolor{secondary}{RGB}{71, 85, 105}
\definecolor{accent}{RGB}{14, 165, 233}
\definecolor{lightgray}{RGB}{248, 250, 252}
\definecolor{darkgray}{RGB}{30, 41, 59}
\definecolor{border}{RGB}{203, 213, 225}

\hypersetup{colorlinks=true,linkcolor=primary,urlcolor=primary}

\pagestyle{fancy}
\fancyhf{}
\renewcommand{\headrulewidth}{0pt}
\fancyfoot[C]{\small\color{secondary}Generated for {{COMPANY}} -- {{ROLE}} Position}
\fancyfoot[R]{\small\color{secondary}\thepage}

\titleformat{\section}{\color{primary}\large\bfseries}{}{0em}{}[\color{accent}\titlerule[1pt]]
\titlespacing{\section}{0pt}{12pt}{6pt}

\begin{document}

\begin{center}
  {\Huge\bfseries\color{darkgray} Alex Johnson}\\[4pt]
  {\large\color{secondary} Senior Software Engineer}\\[4pt]
  \small\color{secondary} alex.johnson@email.com $\bullet$ linkedin.com/in/alexjohnson $\bullet$ github.com/alexjohnson
\end{center}

\vspace{4pt}
\noindent\color{border}\rule{\linewidth}{0.5pt}
\vspace{2pt}

\begin{center}
  \colorbox{lightgray}{%
    \parbox{0.95\linewidth}{%
      \centering\small\color{secondary}
      \textbf{Applying for:} {{ROLE}} at \textbf{{{COMPANY}}}
    }%
  }
\end{center}

\vspace{6pt}

\section{Professional Summary}
{{SUMMARY}}

\section{Technical Skills}
\noindent\begin{tabularx}{\linewidth}{>{\bfseries\color{secondary}\small}l X}
Skills & \small\color{darkgray}{{SKILLS}}
\end{tabularx}

\section{Professional Experience}

\textbf{\color{primary}Senior Software Engineer} \hfill \textcolor{secondary}{Jan 2022 -- Present}\\
\textit{\color{secondary}TechCorp Solutions, San Francisco, CA}
\begin{itemize}[leftmargin=*, itemsep=2pt, topsep=4pt]
  \small
  \item Led development of microservices architecture serving 2M+ daily active users
  \item Reduced API response time by 40\% through caching strategies and query optimization
  \item Mentored team of 5 junior engineers; conducted code reviews and technical interviews
  \item Implemented CI/CD pipelines reducing deployment time from 2 hours to 15 minutes
\end{itemize}

\vspace{6pt}
\textbf{\color{primary}Software Engineer} \hfill \textcolor{secondary}{Jun 2019 -- Dec 2021}\\
\textit{\color{secondary}StartupXYZ, New York, NY}
\begin{itemize}[leftmargin=*, itemsep=2pt, topsep=4pt]
  \small
  \item Built RESTful APIs and GraphQL endpoints consumed by web and mobile clients
  \item Migrated legacy monolith to containerized microservices using Docker and Kubernetes
  \item Improved test coverage from 45\% to 90\% across critical business logic
\end{itemize}

\section{Key Projects}
{{PROJECTS}}

\section{Education}
\textbf{\color{primary}Bachelor of Science in Computer Science} \hfill \textcolor{secondary}{2015 -- 2019}\\
\textit{\color{secondary}University of California, Berkeley}\\
\small GPA: 3.8/4.0 $\bullet$ Dean's List $\bullet$ ACM Student Chapter Member

\section{Certifications}
\begin{itemize}[leftmargin=*, itemsep=2pt, topsep=4pt]
  \small
  \item \textbf{AWS Certified Solutions Architect} -- Amazon Web Services, 2023
  \item \textbf{Certified Kubernetes Administrator (CKA)} -- CNCF, 2022
  \item \textbf{Google Cloud Professional Data Engineer} -- Google, 2021
\end{itemize}

\vspace{4pt}
\noindent\color{border}\rule{\linewidth}{0.5pt}
\begin{center}
  \tiny\color{secondary}Resume tailored for {{COMPANY}} using AI assistance
\end{center}

\end{document}
RESUMETEX

# ---- backend/templates/cover_letter.tex ----
cat > backend/templates/cover_letter.tex << 'COVERTEX'
\documentclass[11pt,a4paper]{article}
\usepackage[margin=1in]{geometry}
\usepackage[T1]{fontenc}
\usepackage[utf8]{inputenc}
\usepackage{hyperref}
\usepackage{xcolor}
\usepackage{parskip}
\usepackage{fancyhdr}

\definecolor{primary}{RGB}{30, 64, 175}
\definecolor{secondary}{RGB}{71, 85, 105}
\definecolor{darkgray}{RGB}{30, 41, 59}
\definecolor{border}{RGB}{203, 213, 225}

\hypersetup{colorlinks=true,urlcolor=primary}
\setlength{\parindent}{0pt}
\setlength{\parskip}{12pt}

\pagestyle{fancy}
\fancyhf{}
\renewcommand{\headrulewidth}{0pt}
\fancyfoot[C]{\small\color{secondary}Cover letter for {{ROLE}} at {{COMPANY}}}

\begin{document}

\begin{flushright}
  {\Large\bfseries\color{darkgray} Alex Johnson}\\
  {\small\color{secondary} Senior Software Engineer}\\[4pt]
  {\small\color{secondary} alex.johnson@email.com}\\
  {\small\color{secondary} +1 (555) 123-4567}\\
  {\small\color{secondary} San Francisco, CA}\\
  {\small\color{secondary} linkedin.com/in/alexjohnson}
\end{flushright}

\noindent\color{border}\rule{\linewidth}{1pt}
\vspace{4pt}

{\small\color{secondary}\today}

\vspace{8pt}

\textbf{\color{darkgray}Hiring Manager}\\
\textbf{\color{primary}{{COMPANY}}}\\
\textit{\color{secondary}{{ROLE}} Position}

\vspace{8pt}

\noindent\color{border}\rule{\linewidth}{0.5pt}

\vspace{6pt}

\textbf{Dear Hiring Manager,}

\vspace{4pt}

{{BODY}}

\vspace{16pt}

\noindent Sincerely,

\vspace{20pt}

\noindent{\bfseries\color{darkgray} Alex Johnson}\\
{\color{secondary} Senior Software Engineer}\\
{\small\color{secondary} alex.johnson@email.com $\bullet$ +1 (555) 123-4567}

\vspace{8pt}
\noindent\color{border}\rule{\linewidth}{0.5pt}
\begin{center}
  \tiny\color{secondary} Cover letter tailored for {{ROLE}} at {{COMPANY}} using AI assistance
\end{center}

\end{document}
COVERTEX

echo -e "${GREEN}  ✓ Backend files written${NC}"

# ---- frontend/package.json ----
cat > frontend/package.json << 'FPKG'
{
  "name": "ai-resume-generator-frontend",
  "version": "1.0.0",
  "scripts": {
    "ng": "ng",
    "start": "ng serve --port 4200",
    "build": "ng build",
    "watch": "ng build --watch --configuration development",
    "test": "ng test"
  },
  "private": true,
  "dependencies": {
    "@angular/animations": "^17.3.0",
    "@angular/common": "^17.3.0",
    "@angular/compiler": "^17.3.0",
    "@angular/core": "^17.3.0",
    "@angular/forms": "^17.3.0",
    "@angular/platform-browser": "^17.3.0",
    "@angular/platform-browser-dynamic": "^17.3.0",
    "@angular/router": "^17.3.0",
    "rxjs": "~7.8.0",
    "tslib": "^2.6.2",
    "zone.js": "~0.14.3"
  },
  "devDependencies": {
    "@angular-devkit/build-angular": "^17.3.0",
    "@angular/cli": "^17.3.0",
    "@angular/compiler-cli": "^17.3.0",
    "@types/node": "^18.19.0",
    "typescript": "~5.4.2"
  }
}
FPKG

# ---- frontend/tsconfig.json ----
cat > frontend/tsconfig.json << 'TSCONFIG'
{
  "compileOnSave": false,
  "compilerOptions": {
    "outDir": "./dist/out-tsc",
    "forceConsistentCasingInFileNames": true,
    "strict": true,
    "noImplicitOverride": true,
    "noPropertyAccessFromIndexSignature": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "skipLibCheck": true,
    "esModuleInterop": true,
    "sourceMap": true,
    "declaration": false,
    "downlevelIteration": true,
    "experimentalDecorators": true,
    "moduleResolution": "bundler",
    "importHelpers": true,
    "target": "ES2022",
    "module": "ES2022",
    "useDefineForClassFields": false,
    "lib": ["ES2022", "dom"]
  },
  "angularCompilerOptions": {
    "enableI18nLegacyMessageIdFormat": false,
    "strictInjectionParameters": true,
    "strictInputAccessModifiers": true,
    "strictTemplates": true
  }
}
TSCONFIG

# ---- frontend/tsconfig.app.json ----
cat > frontend/tsconfig.app.json << 'TSCAPP'
{
  "extends": "./tsconfig.json",
  "compilerOptions": {
    "outDir": "./out-tsc/app",
    "types": []
  },
  "files": ["src/main.ts"],
  "include": ["src/**/*.d.ts"]
}
TSCAPP

# ---- frontend/angular.json ----
cat > frontend/angular.json << 'ANGULARJSON'
{
  "$schema": "./node_modules/@angular/cli/lib/config/schema.json",
  "version": 1,
  "newProjectRoot": "projects",
  "projects": {
    "ai-resume-generator": {
      "projectType": "application",
      "schematics": {
        "@schematics/angular:component": { "style": "scss" }
      },
      "root": "",
      "sourceRoot": "src",
      "prefix": "app",
      "architect": {
        "build": {
          "builder": "@angular-devkit/build-angular:application",
          "options": {
            "outputPath": "dist/ai-resume-generator",
            "index": "src/index.html",
            "browser": "src/main.ts",
            "polyfills": ["zone.js"],
            "tsConfig": "tsconfig.app.json",
            "assets": ["src/favicon.ico", "src/assets"],
            "styles": ["src/styles.scss"],
            "scripts": []
          },
          "configurations": {
            "production": {
              "budgets": [
                { "type": "initial", "maximumWarning": "500kb", "maximumError": "1mb" },
                { "type": "anyComponentStyle", "maximumWarning": "2kb", "maximumError": "4kb" }
              ],
              "outputHashing": "all"
            },
            "development": {
              "optimization": false,
              "extractLicenses": false,
              "sourceMap": true
            }
          },
          "defaultConfiguration": "production"
        },
        "serve": {
          "builder": "@angular-devkit/build-angular:dev-server",
          "configurations": {
            "production": { "buildTarget": "ai-resume-generator:build:production" },
            "development": { "buildTarget": "ai-resume-generator:build:development" }
          },
          "defaultConfiguration": "development"
        }
      }
    }
  }
}
ANGULARJSON

# ---- frontend/src/index.html ----
cat > frontend/src/index.html << 'INDEXHTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>AI Resume Generator</title>
  <base href="/">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <link rel="icon" type="image/x-icon" href="favicon.ico">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Syne:wght@400;500;600;700;800&family=DM+Mono:ital,wght@0,300;0,400;0,500;1,300&family=DM+Sans:ital,opsz,wght@0,9..40,300;0,9..40,400;0,9..40,500;1,9..40,300&display=swap" rel="stylesheet">
</head>
<body>
  <app-root></app-root>
</body>
</html>
INDEXHTML

# ---- frontend/src/styles.scss ----
cat > frontend/src/styles.scss << 'GLOBALSCSS'
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

:root {
  --ink: #0f172a;
  --ink-light: #334155;
  --ink-muted: #64748b;
  --paper: #f8fafc;
  --blue-deep: #1e3a8a;
  --blue-mid: #1d4ed8;
  --blue-bright: #3b82f6;
  --blue-pale: #dbeafe;
  --border: #e2e8f0;
  --font-display: 'Syne', sans-serif;
  --font-mono: 'DM Mono', monospace;
  --font-body: 'DM Sans', sans-serif;
}

html { scroll-behavior: smooth; }

body {
  font-family: var(--font-body);
  background: var(--paper);
  color: var(--ink);
  line-height: 1.6;
  font-size: 15px;
  min-height: 100vh;
  -webkit-font-smoothing: antialiased;
}

::-webkit-scrollbar { width: 6px; }
::-webkit-scrollbar-track { background: #f1f5f9; }
::-webkit-scrollbar-thumb { background: #cbd5e1; border-radius: 3px; }
::selection { background: #dbeafe; color: #1e3a8a; }
GLOBALSCSS

# ---- frontend/src/main.ts ----
cat > frontend/src/main.ts << 'MAINTS'
import { bootstrapApplication } from '@angular/platform-browser';
import { provideHttpClient } from '@angular/common/http';
import { provideRouter } from '@angular/router';
import { provideAnimations } from '@angular/platform-browser/animations';
import { AppComponent } from './app/app.component';
import { routes } from './app/app.routes';

bootstrapApplication(AppComponent, {
  providers: [
    provideHttpClient(),
    provideRouter(routes),
    provideAnimations()
  ]
}).catch(err => console.error(err));
MAINTS

# ---- frontend/src/app/app.routes.ts ----
cat > frontend/src/app/app.routes.ts << 'APPROUTES'
import { Routes } from '@angular/router';
export const routes: Routes = [];
APPROUTES

# ---- frontend/src/app/app.component.ts ----
cat > frontend/src/app/app.component.ts << 'APPCOMP'
import { Component } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { GeneratorComponent } from './components/generator/generator.component';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [RouterOutlet, GeneratorComponent],
  template: `<app-generator></app-generator>`
})
export class AppComponent {}
APPCOMP

# ---- frontend/src/environments/environment.ts ----
cat > frontend/src/environments/environment.ts << 'ENVTS'
export const environment = {
  production: false,
  apiUrl: 'http://localhost:3000/api'
};
ENVTS

# ---- frontend/src/environments/environment.prod.ts ----
cat > frontend/src/environments/environment.prod.ts << 'ENVPROD'
export const environment = {
  production: true,
  apiUrl: 'http://localhost:3000/api'
};
ENVPROD

# ---- frontend/src/app/services/api.service.ts ----
cat > frontend/src/app/services/api.service.ts << 'APISERV'
import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';

export interface GenerateRequest {
  jobDescription: string;
  companyName: string;
  role?: string;
}

export interface GenerateResponse {
  success: boolean;
  aiContent: {
    summary: string;
    skills: string;
    projects: string;
    coverLetter: string;
  };
  outputDir: string;
  files: {
    resumeTex: string;
    coverTex: string;
    resumePdf: string | null;
    coverPdf: string | null;
  };
  pdfGenerated: boolean;
  warning?: string;
}

@Injectable({ providedIn: 'root' })
export class ApiService {
  private apiUrl = environment.apiUrl;

  constructor(private http: HttpClient) {}

  generate(request: GenerateRequest): Observable<GenerateResponse> {
    return this.http.post<GenerateResponse>(`${this.apiUrl}/generate`, request);
  }

  checkHealth(): Observable<{ status: string; timestamp: string }> {
    return this.http.get<{ status: string; timestamp: string }>(`${this.apiUrl}/health`);
  }
}
APISERV

# ---- frontend/src/app/components/generator/generator.component.ts ----
cat > frontend/src/app/components/generator/generator.component.ts << 'GENCOMP'
import { Component, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpClientModule } from '@angular/common/http';
import { ApiService, GenerateResponse } from '../../services/api.service';

type Step = 'form' | 'loading' | 'result';

interface LoadingMessage {
  icon: string;
  text: string;
}

@Component({
  selector: 'app-generator',
  standalone: true,
  imports: [CommonModule, FormsModule, HttpClientModule],
  templateUrl: './generator.component.html',
  styleUrls: ['./generator.component.scss']
})
export class GeneratorComponent implements OnInit {
  step = signal<Step>('form');

  jobDescription = '';
  companyName = '';
  role = '';

  result: GenerateResponse | null = null;
  error: string | null = null;

  loadingMessages: LoadingMessage[] = [
    { icon: '🤖', text: 'Analyzing job description...' },
    { icon: '✨', text: 'Generating AI content...' },
    { icon: '📝', text: 'Crafting your resume...' },
    { icon: '💌', text: 'Writing cover letter...' },
    { icon: '⚙️', text: 'Compiling LaTeX documents...' },
    { icon: '📄', text: 'Generating PDFs...' },
  ];
  currentLoadingIndex = 0;
  loadingInterval: any;
  loadingProgress = 0;
  progressInterval: any;

  activeTab: 'summary' | 'skills' | 'projects' | 'cover' = 'summary';
  backendOnline = false;

  constructor(private apiService: ApiService) {}

  ngOnInit() { this.checkBackendHealth(); }

  checkBackendHealth() {
    this.apiService.checkHealth().subscribe({
      next: () => { this.backendOnline = true; },
      error: () => { this.backendOnline = false; }
    });
  }

  get isFormValid(): boolean {
    return this.jobDescription.trim().length > 20 && this.companyName.trim().length > 0;
  }

  get charCount(): number { return this.jobDescription.length; }

  startLoading() {
    this.currentLoadingIndex = 0;
    this.loadingProgress = 0;
    this.loadingInterval = setInterval(() => {
      if (this.currentLoadingIndex < this.loadingMessages.length - 1) this.currentLoadingIndex++;
    }, 3500);
    this.progressInterval = setInterval(() => {
      if (this.loadingProgress < 90) this.loadingProgress += Math.random() * 3;
    }, 300);
  }

  stopLoading() {
    clearInterval(this.loadingInterval);
    clearInterval(this.progressInterval);
    this.loadingProgress = 100;
  }

  async onGenerate() {
    if (!this.isFormValid) return;
    this.error = null;
    this.step.set('loading');
    this.startLoading();

    this.apiService.generate({
      jobDescription: this.jobDescription,
      companyName: this.companyName,
      role: this.role
    }).subscribe({
      next: (response) => {
        this.stopLoading();
        setTimeout(() => {
          this.result = response;
          this.step.set('result');
          this.activeTab = 'summary';
        }, 600);
      },
      error: (err) => {
        this.stopLoading();
        this.error = err.error?.error || err.message || 'Something went wrong. Please try again.';
        this.step.set('form');
      }
    });
  }

  onReset() {
    this.step.set('form');
    this.result = null;
    this.error = null;
    this.jobDescription = '';
    this.companyName = '';
    this.role = '';
  }

  copyText(text: string) { navigator.clipboard.writeText(text); }
  openFile(url: string | null) { if (url) window.open(url, '_blank'); }
  get currentLoading(): LoadingMessage { return this.loadingMessages[this.currentLoadingIndex]; }
}
GENCOMP

# ---- generator.component.html ----
cat > frontend/src/app/components/generator/generator.component.html << 'GENHTML'
<div class="app-shell">
  <header class="header">
    <div class="header-inner">
      <div class="logo">
        <div class="logo-mark"><span class="logo-icon">◈</span></div>
        <div class="logo-text">
          <span class="logo-name">ResumeAI</span>
          <span class="logo-tag">LaTeX PDF Generator</span>
        </div>
      </div>
      <div class="header-status">
        <span class="status-dot" [class.online]="backendOnline" [class.offline]="!backendOnline"></span>
        <span class="status-label">{{ backendOnline ? 'API Online' : 'API Offline' }}</span>
      </div>
    </div>
  </header>

  <main class="main">

    <!-- FORM -->
    <div class="step-form" *ngIf="step() === 'form'">
      <div class="page-hero">
        <div class="hero-badge">Powered by GPT-4o + LaTeX</div>
        <h1 class="hero-title">Craft Your <em>Perfect</em><br>Application</h1>
        <p class="hero-sub">Paste a job description. AI generates tailored resume sections and a cover letter, then compiles them to professional LaTeX PDFs.</p>
      </div>

      <div class="error-banner" *ngIf="error">
        <span class="error-icon">⚠</span>
        <span class="error-text">{{ error }}</span>
        <button class="error-close" (click)="error = null">✕</button>
      </div>

      <div class="form-card">
        <div class="form-grid">
          <div class="field-group full-width">
            <label class="field-label" for="jobDesc">
              <span class="label-text">Job Description</span>
              <span class="label-required">Required</span>
              <span class="char-count" [class.warn]="charCount > 3000">{{ charCount }}</span>
            </label>
            <div class="textarea-wrapper">
              <textarea id="jobDesc" class="field-textarea" [(ngModel)]="jobDescription"
                placeholder="Paste the full job description here..." rows="10" maxlength="6000"></textarea>
              <div class="textarea-corner"></div>
            </div>
            <p class="field-hint">Tip: Include the full posting for best AI tailoring.</p>
          </div>

          <div class="field-group">
            <label class="field-label" for="company">
              <span class="label-text">Company Name</span>
              <span class="label-required">Required</span>
            </label>
            <div class="input-wrapper">
              <span class="input-icon">🏢</span>
              <input id="company" class="field-input" type="text" [(ngModel)]="companyName"
                placeholder="e.g. Google, Stripe, OpenAI" maxlength="100" />
            </div>
          </div>

          <div class="field-group">
            <label class="field-label" for="role">
              <span class="label-text">Role / Job Title</span>
              <span class="label-optional">Optional</span>
            </label>
            <div class="input-wrapper">
              <span class="input-icon">💼</span>
              <input id="role" class="field-input" type="text" [(ngModel)]="role"
                placeholder="e.g. Senior Software Engineer" maxlength="100" />
            </div>
          </div>
        </div>

        <div class="form-footer">
          <div class="form-info">
            <div class="info-item"><span class="info-icon">🤖</span><span>GPT-4o analyzes your JD</span></div>
            <div class="info-item"><span class="info-icon">📄</span><span>LaTeX PDF generation</span></div>
            <div class="info-item"><span class="info-icon">⚡</span><span>~15 seconds</span></div>
          </div>
          <button class="btn-generate" [disabled]="!isFormValid" (click)="onGenerate()">
            <span class="btn-icon">✦</span>
            <span class="btn-text">Generate Documents</span>
            <span class="btn-arrow">→</span>
          </button>
        </div>
      </div>

      <div class="features">
        <div class="feature-card">
          <div class="feature-icon">🧠</div>
          <h3>AI-Tailored Content</h3>
          <p>GPT-4o reads the job posting and writes a summary, skills list, and project highlights matched to the role.</p>
        </div>
        <div class="feature-card">
          <div class="feature-icon">📐</div>
          <h3>Professional LaTeX</h3>
          <p>Content fills beautifully typeset LaTeX templates and compiles to pixel-perfect PDFs via latexmk.</p>
        </div>
        <div class="feature-card">
          <div class="feature-icon">💌</div>
          <h3>Cover Letter</h3>
          <p>A personalized cover letter addressing the specific company and role, ready to customize and send.</p>
        </div>
      </div>
    </div>

    <!-- LOADING -->
    <div class="step-loading" *ngIf="step() === 'loading'">
      <div class="loading-card">
        <div class="loading-orb">
          <div class="orb-ring orb-ring-1"></div>
          <div class="orb-ring orb-ring-2"></div>
          <div class="orb-ring orb-ring-3"></div>
          <div class="orb-core"><span class="orb-icon">{{ currentLoading.icon }}</span></div>
        </div>
        <div class="loading-content">
          <h2 class="loading-title">Crafting Your Application</h2>
          <p class="loading-message">{{ currentLoading.text }}</p>
          <div class="progress-track">
            <div class="progress-bar" [style.width.%]="loadingProgress"></div>
          </div>
          <div class="progress-label">{{ loadingProgress | number:'1.0-0' }}%</div>
          <div class="loading-steps">
            <div class="loading-step" *ngFor="let msg of loadingMessages; let i = index"
              [class.active]="i === currentLoadingIndex" [class.done]="i < currentLoadingIndex">
              <span class="step-dot"></span>
              <span class="step-text">{{ msg.text }}</span>
            </div>
          </div>
        </div>
        <div class="loading-for">
          <span>Generating for</span>
          <strong>{{ companyName }}</strong>
          <span *ngIf="role">· {{ role }}</span>
        </div>
      </div>
    </div>

    <!-- RESULT -->
    <div class="step-result" *ngIf="step() === 'result' && result">
      <div class="result-header">
        <div class="result-badge success">✓ Documents Generated</div>
        <h2 class="result-title">Your Application is Ready</h2>
        <p class="result-sub">AI-tailored content for <strong>{{ companyName }}</strong><span *ngIf="role"> · {{ role }}</span></p>
      </div>

      <div class="download-row">
        <div class="download-card" [class.available]="result.files.resumePdf">
          <div class="download-icon">📄</div>
          <div class="download-info">
            <h3>Resume</h3>
            <p>{{ result.files.resumePdf ? 'PDF compiled successfully' : 'LaTeX source available' }}</p>
          </div>
          <div class="download-actions">
            <button class="btn-download primary" *ngIf="result.files.resumePdf" (click)="openFile(result.files.resumePdf)">↓ Download PDF</button>
            <button class="btn-download secondary" (click)="openFile(result.files.resumeTex)">↓ .tex Source</button>
          </div>
        </div>

        <div class="download-card" [class.available]="result.files.coverPdf">
          <div class="download-icon">💌</div>
          <div class="download-info">
            <h3>Cover Letter</h3>
            <p>{{ result.files.coverPdf ? 'PDF compiled successfully' : 'LaTeX source available' }}</p>
          </div>
          <div class="download-actions">
            <button class="btn-download primary" *ngIf="result.files.coverPdf" (click)="openFile(result.files.coverPdf)">↓ Download PDF</button>
            <button class="btn-download secondary" (click)="openFile(result.files.coverTex)">↓ .tex Source</button>
          </div>
        </div>
      </div>

      <div class="warning-banner" *ngIf="result.warning && !result.pdfGenerated">
        <span class="warning-icon">⚠</span>
        <div>
          <strong>PDF Compilation Unavailable</strong>
          <p>LaTeX is not installed. Download the .tex files and compile with: <code>latexmk -pdf resume.tex</code></p>
          <p class="warning-install">Install: <code>sudo apt-get install texlive-full</code> or <code>brew install --cask mactex</code></p>
        </div>
      </div>

      <div class="content-section">
        <div class="section-header">
          <h3>AI-Generated Content</h3>
          <p>Review and customize before using</p>
        </div>
        <div class="tabs">
          <button class="tab" [class.active]="activeTab === 'summary'" (click)="activeTab = 'summary'">Summary</button>
          <button class="tab" [class.active]="activeTab === 'skills'" (click)="activeTab = 'skills'">Skills</button>
          <button class="tab" [class.active]="activeTab === 'projects'" (click)="activeTab = 'projects'">Projects</button>
          <button class="tab" [class.active]="activeTab === 'cover'" (click)="activeTab = 'cover'">Cover Letter</button>
        </div>
        <div class="tab-content">
          <div class="content-block" *ngIf="activeTab === 'summary'">
            <div class="content-label">
              <span>Professional Summary</span>
              <button class="btn-copy" (click)="copyText(result.aiContent.summary)">Copy ⧉</button>
            </div>
            <div class="content-text">{{ result.aiContent.summary }}</div>
          </div>
          <div class="content-block" *ngIf="activeTab === 'skills'">
            <div class="content-label">
              <span>Technical Skills</span>
              <button class="btn-copy" (click)="copyText(result.aiContent.skills)">Copy ⧉</button>
            </div>
            <div class="skills-chips">
              <span class="skill-chip" *ngFor="let skill of result.aiContent.skills.split(',')">{{ skill.trim() }}</span>
            </div>
            <div class="content-text mono">{{ result.aiContent.skills }}</div>
          </div>
          <div class="content-block" *ngIf="activeTab === 'projects'">
            <div class="content-label">
              <span>Key Projects</span>
              <button class="btn-copy" (click)="copyText(result.aiContent.projects)">Copy ⧉</button>
            </div>
            <div class="content-text">{{ result.aiContent.projects }}</div>
          </div>
          <div class="content-block" *ngIf="activeTab === 'cover'">
            <div class="content-label">
              <span>Cover Letter Body</span>
              <button class="btn-copy" (click)="copyText(result.aiContent.coverLetter)">Copy ⧉</button>
            </div>
            <div class="content-text">{{ result.aiContent.coverLetter }}</div>
          </div>
        </div>
      </div>

      <div class="output-info">
        <span class="output-icon">📁</span>
        <code>backend/{{ result.outputDir }}</code>
      </div>

      <div class="result-actions">
        <button class="btn-new" (click)="onReset()">← Generate for Another Role</button>
      </div>
    </div>

  </main>

  <footer class="footer">
    <div class="footer-inner">
      <span>Built with Angular + Node.js + GPT-4o + LaTeX</span>
      <span class="footer-sep">·</span>
      <span>Outputs saved to <code>backend/outputs/</code></span>
    </div>
  </footer>
</div>
GENHTML

# ---- generator.component.scss ----
cat > frontend/src/app/components/generator/generator.component.scss << 'GENSCSS'
.app-shell { min-height: 100vh; display: flex; flex-direction: column; background: #f8fafc; background-image: radial-gradient(circle at 20% 10%, rgba(30,64,175,0.04) 0%, transparent 50%), radial-gradient(circle at 80% 90%, rgba(14,165,233,0.04) 0%, transparent 50%); }
.header { position: sticky; top: 0; z-index: 100; background: rgba(255,255,255,0.88); backdrop-filter: blur(12px); border-bottom: 1px solid #e2e8f0; }
.header-inner { max-width: 1100px; margin: 0 auto; padding: 0 24px; height: 64px; display: flex; align-items: center; justify-content: space-between; }
.logo { display: flex; align-items: center; gap: 12px; }
.logo-mark { width: 38px; height: 38px; background: #1e3a8a; border-radius: 10px; display: flex; align-items: center; justify-content: center; }
.logo-icon { color: #60a5fa; font-size: 18px; }
.logo-name { font-family: 'Syne', sans-serif; font-size: 18px; font-weight: 700; color: #0f172a; letter-spacing: -0.5px; }
.logo-tag { display: block; font-size: 10px; font-family: 'DM Mono', monospace; color: #64748b; letter-spacing: 0.5px; text-transform: uppercase; }
.header-status { display: flex; align-items: center; gap: 6px; }
.status-dot { width: 8px; height: 8px; border-radius: 50%; &.online { background: #10b981; box-shadow: 0 0 0 3px rgba(16,185,129,0.15); } &.offline { background: #ef4444; box-shadow: 0 0 0 3px rgba(239,68,68,0.15); } }
.status-label { font-size: 12px; font-family: 'DM Mono', monospace; color: #64748b; }
.main { flex: 1; max-width: 900px; width: 100%; margin: 0 auto; padding: 40px 24px 60px; }
.page-hero { text-align: center; margin-bottom: 36px; animation: fadeSlideIn 0.5s ease both; }
.hero-badge { display: inline-flex; align-items: center; gap: 6px; font-size: 11px; font-family: 'DM Mono', monospace; font-weight: 500; color: #1d4ed8; background: #dbeafe; border: 1px solid #bfdbfe; border-radius: 100px; padding: 4px 14px; margin-bottom: 16px; letter-spacing: 0.5px; text-transform: uppercase; }
.hero-title { font-family: 'Syne', sans-serif; font-size: clamp(32px,5vw,52px); font-weight: 800; color: #0f172a; line-height: 1.1; letter-spacing: -1.5px; margin-bottom: 16px; em { font-style: normal; color: #1d4ed8; } }
.hero-sub { font-size: 16px; color: #64748b; max-width: 560px; margin: 0 auto; line-height: 1.7; }
.error-banner { display: flex; align-items: center; gap: 12px; background: #fee2e2; border: 1px solid #fca5a5; border-radius: 10px; padding: 12px 16px; margin-bottom: 24px; .error-icon { font-size: 18px; } .error-text { flex: 1; font-size: 14px; color: #991b1b; } .error-close { background: none; border: none; cursor: pointer; color: #991b1b; font-size: 14px; padding: 2px 6px; border-radius: 4px; &:hover { background: rgba(239,68,68,0.1); } } }
.form-card { background: white; border: 1px solid #e2e8f0; border-radius: 16px; padding: 32px; box-shadow: 0 4px 24px rgba(0,0,0,0.06); animation: fadeSlideIn 0.5s 0.1s ease both; margin-bottom: 32px; }
.form-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; margin-bottom: 28px; .full-width { grid-column: 1 / -1; } @media (max-width: 600px) { grid-template-columns: 1fr; .full-width { grid-column: 1; } } }
.field-label { display: flex; align-items: center; gap: 8px; margin-bottom: 8px; }
.label-text { font-size: 13px; font-weight: 600; color: #334155; font-family: 'Syne', sans-serif; }
.label-required { font-size: 10px; font-family: 'DM Mono', monospace; background: #fee2e2; color: #ef4444; padding: 2px 6px; border-radius: 4px; font-weight: 500; }
.label-optional { font-size: 10px; font-family: 'DM Mono', monospace; background: #f1f5f9; color: #94a3b8; padding: 2px 6px; border-radius: 4px; }
.char-count { margin-left: auto; font-size: 11px; font-family: 'DM Mono', monospace; color: #94a3b8; &.warn { color: #f59e0b; } }
.textarea-wrapper { position: relative; }
.field-textarea { width: 100%; padding: 14px 16px; font-family: 'DM Sans', sans-serif; font-size: 14px; line-height: 1.6; color: #0f172a; background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 10px; resize: vertical; transition: border-color 0.2s, box-shadow 0.2s; outline: none; &:focus { border-color: #3b82f6; box-shadow: 0 0 0 3px rgba(59,130,246,0.1); background: white; } &::placeholder { color: #94a3b8; } }
.textarea-corner { position: absolute; bottom: 8px; right: 8px; width: 10px; height: 10px; border-right: 2px solid #cbd5e1; border-bottom: 2px solid #cbd5e1; border-radius: 0 0 3px 0; pointer-events: none; }
.field-hint { font-size: 11px; color: #94a3b8; margin-top: 6px; font-style: italic; }
.input-wrapper { position: relative; display: flex; align-items: center; }
.input-icon { position: absolute; left: 12px; font-size: 16px; pointer-events: none; }
.field-input { width: 100%; padding: 12px 14px 12px 40px; font-family: 'DM Sans', sans-serif; font-size: 14px; color: #0f172a; background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 10px; transition: border-color 0.2s, box-shadow 0.2s; outline: none; &:focus { border-color: #3b82f6; box-shadow: 0 0 0 3px rgba(59,130,246,0.1); background: white; } &::placeholder { color: #94a3b8; } }
.form-footer { display: flex; align-items: center; justify-content: space-between; gap: 20px; padding-top: 24px; border-top: 1px solid #f1f5f9; @media (max-width: 640px) { flex-direction: column; align-items: stretch; } }
.form-info { display: flex; gap: 16px; flex-wrap: wrap; }
.info-item { display: flex; align-items: center; gap: 5px; font-size: 12px; color: #64748b; .info-icon { font-size: 14px; } }
.btn-generate { display: flex; align-items: center; gap: 8px; padding: 13px 28px; background: #1e3a8a; color: white; border: none; border-radius: 10px; font-family: 'Syne', sans-serif; font-size: 15px; font-weight: 700; cursor: pointer; transition: all 0.2s; white-space: nowrap; letter-spacing: -0.3px; .btn-icon { font-size: 12px; } .btn-arrow { font-size: 18px; transition: transform 0.2s; } &:hover:not(:disabled) { background: #1d4ed8; box-shadow: 0 6px 20px rgba(30,58,138,0.35); transform: translateY(-1px); .btn-arrow { transform: translateX(3px); } } &:disabled { opacity: 0.4; cursor: not-allowed; } }
.features { display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px; animation: fadeSlideIn 0.5s 0.2s ease both; @media (max-width: 700px) { grid-template-columns: 1fr; } }
.feature-card { background: white; border: 1px solid #e2e8f0; border-radius: 12px; padding: 20px; transition: transform 0.2s, box-shadow 0.2s; &:hover { transform: translateY(-2px); box-shadow: 0 8px 24px rgba(0,0,0,0.08); } .feature-icon { font-size: 24px; margin-bottom: 10px; } h3 { font-family: 'Syne', sans-serif; font-size: 14px; font-weight: 700; color: #1e3a8a; margin-bottom: 6px; } p { font-size: 13px; color: #64748b; line-height: 1.5; } }
.step-loading { display: flex; align-items: center; justify-content: center; min-height: 60vh; animation: fadeSlideIn 0.4s ease both; }
.loading-card { background: white; border: 1px solid #e2e8f0; border-radius: 20px; padding: 48px 40px; width: 100%; max-width: 500px; box-shadow: 0 12px 48px rgba(0,0,0,0.08); display: flex; flex-direction: column; align-items: center; gap: 32px; }
.loading-orb { position: relative; width: 100px; height: 100px; display: flex; align-items: center; justify-content: center; }
.orb-ring { position: absolute; border-radius: 50%; border: 2px solid transparent; animation: spin linear infinite; &.orb-ring-1 { inset: 0; border-top-color: #1d4ed8; border-right-color: #1d4ed8; animation-duration: 1.2s; } &.orb-ring-2 { inset: 10px; border-bottom-color: #3b82f6; border-left-color: #3b82f6; animation-duration: 1.8s; animation-direction: reverse; } &.orb-ring-3 { inset: 20px; border-top-color: #93c5fd; animation-duration: 2.4s; } }
.orb-core { position: absolute; inset: 30px; background: #1e3a8a; border-radius: 50%; display: flex; align-items: center; justify-content: center; }
.orb-icon { font-size: 20px; animation: pulse 1.5s ease infinite; }
.loading-content { width: 100%; text-align: center; }
.loading-title { font-family: 'Syne', sans-serif; font-size: 22px; font-weight: 800; color: #0f172a; margin-bottom: 8px; letter-spacing: -0.5px; }
.loading-message { font-size: 14px; color: #64748b; margin-bottom: 20px; min-height: 20px; }
.progress-track { height: 4px; background: #f1f5f9; border-radius: 2px; overflow: hidden; margin-bottom: 6px; }
.progress-bar { height: 100%; background: linear-gradient(90deg, #1d4ed8, #3b82f6); border-radius: 2px; transition: width 0.5s cubic-bezier(0.4,0,0.2,1); }
.progress-label { font-size: 11px; font-family: 'DM Mono', monospace; color: #94a3b8; text-align: right; margin-bottom: 20px; }
.loading-steps { display: flex; flex-direction: column; gap: 8px; text-align: left; }
.loading-step { display: flex; align-items: center; gap: 10px; opacity: 0.3; transition: opacity 0.3s; &.active { opacity: 1; } &.done { opacity: 0.6; } }
.step-dot { width: 6px; height: 6px; border-radius: 50%; background: #cbd5e1; flex-shrink: 0; transition: background 0.3s; .active & { background: #1d4ed8; box-shadow: 0 0 0 3px rgba(29,78,216,0.15); } .done & { background: #10b981; } }
.step-text { font-size: 13px; color: #334155; .active & { font-weight: 600; color: #1e3a8a; } .done & { color: #64748b; } }
.loading-for { font-size: 13px; color: #94a3b8; display: flex; gap: 6px; align-items: center; strong { color: #1e3a8a; } }
.step-result { animation: fadeSlideIn 0.5s ease both; }
.result-header { text-align: center; margin-bottom: 32px; }
.result-badge { display: inline-flex; align-items: center; gap: 6px; font-size: 11px; font-family: 'DM Mono', monospace; font-weight: 500; letter-spacing: 0.5px; text-transform: uppercase; border-radius: 100px; padding: 4px 14px; margin-bottom: 12px; &.success { color: #065f46; background: #d1fae5; border: 1px solid #6ee7b7; } }
.result-title { font-family: 'Syne', sans-serif; font-size: 32px; font-weight: 800; color: #0f172a; letter-spacing: -1px; margin-bottom: 8px; }
.result-sub { font-size: 15px; color: #64748b; strong { color: #1e3a8a; } }
.download-row { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin-bottom: 20px; @media (max-width: 640px) { grid-template-columns: 1fr; } }
.download-card { background: white; border: 1.5px solid #e2e8f0; border-radius: 14px; padding: 22px; display: flex; flex-direction: column; gap: 12px; transition: box-shadow 0.2s; &.available { border-color: #bfdbfe; background: linear-gradient(135deg, white 0%, #eff6ff 100%); } &:hover { box-shadow: 0 6px 20px rgba(0,0,0,0.08); } .download-icon { font-size: 32px; } h3 { font-family: 'Syne', sans-serif; font-size: 16px; font-weight: 700; color: #0f172a; } p { font-size: 13px; color: #64748b; margin-top: 2px; } }
.download-actions { display: flex; gap: 8px; flex-wrap: wrap; margin-top: 4px; }
.btn-download { padding: 8px 16px; border-radius: 8px; font-size: 13px; font-weight: 600; cursor: pointer; border: 1.5px solid; transition: all 0.2s; font-family: 'Syne', sans-serif; &.primary { background: #1e3a8a; color: white; border-color: #1e3a8a; &:hover { background: #1d4ed8; box-shadow: 0 4px 12px rgba(30,58,138,0.3); } } &.secondary { background: transparent; color: #1e3a8a; border-color: #bfdbfe; &:hover { background: #eff6ff; } } }
.warning-banner { display: flex; gap: 12px; background: #fffbeb; border: 1px solid #fde68a; border-radius: 10px; padding: 16px; margin-bottom: 20px; .warning-icon { font-size: 20px; flex-shrink: 0; } strong { font-size: 14px; color: #92400e; display: block; margin-bottom: 4px; } p { font-size: 13px; color: #78350f; line-height: 1.5; } code { background: rgba(0,0,0,0.07); padding: 1px 5px; border-radius: 4px; font-family: 'DM Mono', monospace; font-size: 12px; } }
.content-section { background: white; border: 1px solid #e2e8f0; border-radius: 14px; overflow: hidden; margin-bottom: 16px; }
.section-header { padding: 20px 24px 0; h3 { font-family: 'Syne', sans-serif; font-size: 16px; font-weight: 700; color: #0f172a; margin-bottom: 2px; } p { font-size: 12px; color: #94a3b8; } }
.tabs { display: flex; gap: 2px; padding: 16px 24px 0; border-bottom: 1px solid #f1f5f9; }
.tab { padding: 8px 16px; font-family: 'Syne', sans-serif; font-size: 13px; font-weight: 600; color: #94a3b8; background: none; border: none; border-radius: 6px 6px 0 0; cursor: pointer; transition: all 0.15s; position: relative; bottom: -1px; &:hover { color: #1e3a8a; background: #eff6ff; } &.active { color: #1e3a8a; background: white; border: 1px solid #e2e8f0; border-bottom-color: white; } }
.tab-content { padding: 24px; }
.content-label { display: flex; align-items: center; justify-content: space-between; margin-bottom: 12px; span { font-size: 12px; font-family: 'DM Mono', monospace; font-weight: 500; color: #64748b; text-transform: uppercase; letter-spacing: 0.5px; } }
.btn-copy { font-size: 12px; font-family: 'DM Mono', monospace; color: #3b82f6; background: #eff6ff; border: 1px solid #bfdbfe; border-radius: 6px; padding: 4px 10px; cursor: pointer; transition: all 0.15s; &:hover { background: #dbeafe; } &:active { transform: scale(0.96); } }
.content-text { font-size: 14px; color: #334155; line-height: 1.7; white-space: pre-wrap; background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: 16px; font-family: 'DM Sans', sans-serif; &.mono { font-family: 'DM Mono', monospace; font-size: 13px; margin-top: 12px; } }
.skills-chips { display: flex; flex-wrap: wrap; gap: 6px; margin-bottom: 12px; }
.skill-chip { font-size: 12px; font-family: 'DM Mono', monospace; color: #1d4ed8; background: #dbeafe; border: 1px solid #bfdbfe; border-radius: 100px; padding: 4px 12px; }
.output-info { display: flex; align-items: center; gap: 8px; font-size: 13px; color: #64748b; margin-bottom: 20px; padding: 10px 16px; background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; .output-icon { font-size: 16px; } code { font-family: 'DM Mono', monospace; font-size: 12px; color: #1e3a8a; } }
.result-actions { display: flex; justify-content: center; }
.btn-new { padding: 12px 24px; background: transparent; color: #1e3a8a; border: 1.5px solid #bfdbfe; border-radius: 10px; font-family: 'Syne', sans-serif; font-size: 14px; font-weight: 700; cursor: pointer; transition: all 0.2s; &:hover { background: #eff6ff; border-color: #93c5fd; } }
.footer { background: white; border-top: 1px solid #e2e8f0; padding: 16px 24px; }
.footer-inner { max-width: 1100px; margin: 0 auto; display: flex; align-items: center; gap: 8px; font-size: 12px; color: #94a3b8; justify-content: center; code { font-family: 'DM Mono', monospace; } .footer-sep { color: #e2e8f0; } }
@keyframes fadeSlideIn { from { opacity: 0; transform: translateY(16px); } to { opacity: 1; transform: translateY(0); } }
@keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.5; } }
@keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
GENSCSS

# Favicon placeholder
echo "" > frontend/src/favicon.ico

echo -e "${GREEN}  ✓ Frontend files written${NC}"

# ============================================================
# SECTION 4: Install Dependencies
# ============================================================
echo ""
echo -e "${CYAN}${BOLD}[4/6] Installing Dependencies...${NC}"

echo -e "${BLUE}  → Installing backend dependencies...${NC}"
cd backend
npm install --silent
cd ..
echo -e "${GREEN}  ✓ Backend dependencies installed${NC}"

echo -e "${BLUE}  → Installing frontend dependencies (this may take 2-3 minutes)...${NC}"
cd frontend
npm install --silent
cd ..
echo -e "${GREEN}  ✓ Frontend dependencies installed${NC}"

# ============================================================
# SECTION 5: Verify Setup
# ============================================================
echo ""
echo -e "${CYAN}${BOLD}[5/6] Verifying Setup...${NC}"

# Check backend
if [ -f "backend/node_modules/.package-lock.json" ] || [ -d "backend/node_modules/express" ]; then
  echo -e "${GREEN}  ✓ Backend node_modules OK${NC}"
else
  echo -e "${YELLOW}  ⚠ Backend node_modules may not be complete${NC}"
fi

# Check frontend
if [ -d "frontend/node_modules/@angular" ]; then
  echo -e "${GREEN}  ✓ Frontend node_modules OK${NC}"
else
  echo -e "${YELLOW}  ⚠ Frontend node_modules may not be complete${NC}"
fi

# Check .env
if grep -q "your_openai_api_key_here" backend/.env 2>/dev/null; then
  echo -e "${YELLOW}  ⚠ IMPORTANT: Please set your OPENAI_API_KEY in backend/.env${NC}"
fi

# ============================================================
# SECTION 6: Done
# ============================================================
echo ""
echo -e "${CYAN}${BOLD}[6/6] Setup Complete!${NC}"
echo ""
echo -e "${GREEN}${BOLD}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║   🎉 Setup completed successfully!             ║${NC}"
echo -e "${GREEN}${BOLD}╚════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BOLD}NEXT STEPS:${NC}"
echo ""
echo -e "  ${YELLOW}1. Add your OpenAI API key:${NC}"
echo -e "     ${BLUE}nano backend/.env${NC}"
echo -e "     Set: OPENAI_API_KEY=sk-..."
echo ""
echo -e "  ${YELLOW}2. Start the backend:${NC}"
echo -e "     ${BLUE}cd backend && npm start${NC}"
echo -e "     → Runs on http://localhost:3000"
echo ""
echo -e "  ${YELLOW}3. Start the frontend (in a new terminal):${NC}"
echo -e "     ${BLUE}cd frontend && npm start${NC}"
echo -e "     → Opens at http://localhost:4200"
echo ""
if [ "$LATEX_AVAILABLE" = false ]; then
  echo -e "  ${YELLOW}4. Install LaTeX for PDF compilation:${NC}"
  echo -e "     Ubuntu: ${BLUE}sudo apt-get install texlive-full${NC}"
  echo -e "     macOS:  ${BLUE}brew install --cask mactex${NC}"
  echo ""
fi
echo -e "  ${YELLOW}ZIP the project:${NC}"
echo -e "     ${BLUE}zip -r ai-resume-generator.zip . --exclude='*/node_modules/*' --exclude='*/.git/*' --exclude='*/dist/*' --exclude='*/outputs/*'${NC}"
echo ""
echo -e "${BOLD}Output files will be saved to:${NC}"
echo -e "  ${BLUE}backend/outputs/{company_name}/resume.pdf${NC}"
echo -e "  ${BLUE}backend/outputs/{company_name}/cover_letter.pdf${NC}"
echo ""
