# AI Resume & Cover Letter Generator

A production-ready full-stack application that uses Grok (xAI API) to generate tailored resumes and cover letters from job descriptions, then compiles them into professional PDFs using LaTeX.

---

## 🚀 Tech Stack

**Frontend**
- Angular 17
- TypeScript

**Backend**
- Node.js
- Express.js

**AI**
- Grok (xAI API)

**PDF Engine**
- LaTeX (latexmk / pdflatex)

---

## ✨ Features

- Paste a job description → AI generates tailored resume + cover letter
- Dynamic LaTeX template injection
- Automatic PDF compilation via latexmk
- Organized output folder per company
- REST API architecture
- Clean ATS-friendly templates

---

## 🧠 How It Works

1. User submits job description (Angular frontend)
2. Backend sends structured prompt to Grok (xAI API)
3. AI returns optimized resume + cover letter content
4. Backend injects content into LaTeX templates
5. `latexmk` compiles PDFs
6. PDFs are stored in `backend/outputs/{company_name}/`

---

## 📂 Output Structure

backend/outputs/
└── {company_name}/
    ├── resume.tex
    ├── resume.pdf
    ├── cover_letter.tex
    └── cover_letter.pdf

---

## ⚙️ Requirements

- Node.js 18+
- npm 9+
- Grok (xAI) API key
- LaTeX distribution installed and available in system PATH

### Ubuntu / WSL
```bash
sudo apt install texlive-full
```

### macOS
```bash
brew install --cask mactex
```

### Windows
Install MiKTeX:
https://miktex.org/download

> The application works on any operating system as long as LaTeX is installed and accessible via command line.

---

## 🔐 Environment Setup

Inside the backend folder:

```bash
cp .env.example .env
```

Add your API key:

```
GROQ_API_KEY=your_api_key_here
```

---

## ▶️ Quick Start

### Option 1 – Setup Script

```bash
chmod +x setup.sh
./setup.sh
```

### Option 2 – Manual Setup

### Backend

```bash
cd backend
npm install
npm start
```

### Frontend

```bash
cd frontend
npm install
npm start
```

Frontend runs at:
http://localhost:4200

Backend runs at:
http://localhost:3000

---

## 📡 API Endpoints

POST `/api/generate`  
Generate resume + cover letter

GET `/api/health`  
Health check

GET `/outputs/{company}/resume.pdf`  
Download generated resume

GET `/outputs/{company}/cover_letter.pdf`  
Download generated cover letter

---

## 🏗 Architecture Overview

Angular Client  
        ↓  
Express REST API  
        ↓  
Grok (xAI API)  
        ↓  
LaTeX Template Injection  
        ↓  
latexmk Compilation  
        ↓  
PDF Output Storage  

---

## 🔮 Future Improvements

- Multiple resume themes
- Resume version management
- Authentication system
- Docker containerization
- Cloud deployment (AWS / GCP)
- Live demo hosting

---

## 👨‍💻 Author

Aditya Mohanty  
Full Stack Developer  
