require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });

const express = require('express');
const router = express.Router();
const path = require('path');
const fs = require('fs');
const { execSync } = require('child_process');
const Groq = require('groq-sdk');

const openai = new Groq({ apiKey: process.env.GROQ_API_KEY });

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
    .replace(/&/g, '\\&')
    .replace(/%/g, '\\%')
    .replace(/\$/g, '\\$')
    .replace(/#/g, '\\#')
    .replace(/_/g, '\\_')
    .replace(/~/g, '\\textasciitilde{}')
    .replace(/\^/g, '\\textasciicircum{}')
    .replace(/</g, '\\textless{}')
    .replace(/>/g, '\\textgreater{}');
}

function formatSkillsAsLatex(skillsStr) {
  if (!skillsStr) return '';
  const lines = skillsStr.split('\n').map(s => s.trim()).filter(Boolean);
  return lines.map(line => {
    const colonIdx = line.indexOf(':');
    if (colonIdx !== -1) {
      const category = line.substring(0, colonIdx).trim();
      const values = line.substring(colonIdx + 1).trim();
      return `\\textbf{${escapeLatex(category)}}{: ${escapeLatex(values)}}`;
    }
    return escapeLatex(line);
  }).join(' \\\\\n');
}

function formatProjectsAsLatex(projectsStr) {
  if (!projectsStr) return '';
  const projects = projectsStr.split(/\n\n+/).map(p => p.trim()).filter(Boolean);

  return projects.map(project => {
    const nameMatch = project.match(/^([^:]+):/);
    const techMatch = project.match(/[Tt]echnolog(?:y|ies)[:\s]+([^\n.]+)/);
    const name = nameMatch ? nameMatch[1].trim() : 'Project';
    const tech = techMatch ? techMatch[1].trim() : '';

    let desc = project
      .replace(/^[^:]+:/, '')
      .replace(/[Tt]echnolog(?:y|ies)[:\s]+[^\n.]+\.?/, '')
      .trim();

    const bullets = desc
      .split(/\.\s+/)
      .map(s => s.trim())
      .filter(s => s.length > 10)
      .slice(0, 3);

    const techLabel = tech ? ` $|$ \\emph{${escapeLatex(tech)}}` : '';
    const heading = `\\resumeProjectHeading\n{\\textbf{${escapeLatex(name)}}${techLabel}}{2024--2025}`;
    const items = bullets.map(b => `  \\resumeItem{${escapeLatex(b)}.}`).join('\n');

    return `${heading}\n\\resumeItemListStart\n${items}\n\\resumeItemListEnd`;
  }).join('\n\n');
}

async function generateAIContent(jobDescription, companyName, role) {
  const prompt = `You are an expert resume writer for Aditya Mohanty, a Full Stack Developer.
Based on the job description below, generate tailored resume content.

Job Description:
${jobDescription}

Company: ${companyName}
Role: ${role || 'Full Stack Developer'}

You MUST return ONLY a raw JSON object. No markdown. No backticks. No explanation. Just the JSON.

{
  "summary": "A 3-sentence professional summary for Aditya tailored to this role. Single line only, no line breaks.",
  "skills": "Languages: JavaScript, TypeScript, Java, SQL, HTML5, CSS3\nBackend: Node.js, Express.js, Spring Boot, RESTful APIs, Microservices\nFrontend: Angular, React.js, Bootstrap\nDatabases: SQL Server, MySQL, MongoDB\nCloud and DevOps: AWS, Docker, CI/CD Pipelines\nConcepts: Data Structures, Algorithms, Distributed Systems, Networking\nAI and Emerging Tech: AI Basics, Agentic AI, API Integration, Prompt Engineering\nTools: Git, Azure DevOps, Agile/Scrum",
  "projects": "TrailSync Activity Tracking Platform: Built distributed backend services to handle user activity data with scalable architecture. Implemented efficient data ingestion and optimized queries for high performance. Technologies: Angular, Node.js, Express.js, MongoDB.\n\nAI Travel Itinerary Planner: Built AI-driven backend services integrating external APIs for intelligent recommendations. Designed workflow-based processing simulating agentic AI systems for dynamic user inputs. Technologies: Angular, Node.js, MongoDB, OpenAI API.\n\nPersonal Finance Manager: Developed secure and scalable application with JWT authentication and role-based access control. Used Docker and CI/CD pipelines for automated deployment and cloud scalability. Technologies: MEAN Stack, AWS.",
  "coverLetter": "Single paragraph cover letter body, no line breaks, no salutation, no signature."
}

Rules:
- No newlines inside any string value except the skills field which uses literal backslash-n
- No special characters: no ampersand, no percent, no dollar sign, no hash
- summary must be one single line
- coverLetter must be one single paragraph, one single line
- Return ONLY the JSON, nothing else`;

  const response = await openai.chat.completions.create({
    model: 'llama-3.3-70b-versatile',
    messages: [
      {
        role: 'system',
        content: 'You are a JSON generator. You output ONLY valid raw JSON objects. No markdown, no backticks, no explanation, no extra text before or after the JSON.'
      },
      {
        role: 'user',
        content: prompt
      }
    ],
    temperature: 0.3
  });

  const raw = response.choices[0].message.content.trim();

  // Strip markdown code blocks if present
  const stripped = raw
    .replace(/^```json\s*/i, '')
    .replace(/^```\s*/i, '')
    .replace(/```\s*$/i, '')
    .trim();

  // Extract the JSON object
  const jsonMatch = stripped.match(/\{[\s\S]*\}/);
  const jsonStr = jsonMatch ? jsonMatch[0] : stripped;

  // Clean control characters
  const cleaned = jsonStr
    .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/g, '')
    .replace(/\t/g, ' ');

  // Parse safely
  try {
    return JSON.parse(cleaned);
  } catch (e) {
    // Last resort: manually extract each field
    console.warn('⚠️ JSON.parse failed, extracting fields manually...');

    const extract = (field) => {
      const match = cleaned.match(new RegExp(`"${field}"\\s*:\\s*"((?:[^"\\\\]|\\\\.)*)"`));
      return match ? match[1].replace(/\\n/g, '\n') : '';
    };

    return {
      summary:     extract('summary'),
      skills:      extract('skills'),
      projects:    extract('projects'),
      coverLetter: extract('coverLetter')
    };
  }
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
    execSync(
      `latexmk -pdf -interaction=nonstopmode -output-directory="${outputDir}" "${texFilePath}"`,
      { timeout: 60000, stdio: 'pipe' }
    );
  } catch (err) {
    try {
      execSync(
        `pdflatex -interaction=nonstopmode -output-directory="${outputDir}" "${texFilePath}"`,
        { timeout: 60000, stdio: 'pipe' }
      );
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
    console.log(`\n🤖 Generating for ${companyName} — ${role || 'Full Stack Developer'}`);
    const aiContent = await generateAIContent(jobDescription, companyName, role);

    const sanitizedCompany = sanitizeFileName(companyName);
    const outputDir = path.join(__dirname, '..', 'outputs', sanitizedCompany);
    if (!fs.existsSync(outputDir)) fs.mkdirSync(outputDir, { recursive: true });

    const resumeTemplatePath = path.join(__dirname, '..', 'templates', 'resume.tex');
    const coverTemplatePath  = path.join(__dirname, '..', 'templates', 'cover_letter.tex');

    const resumeTex = fillTemplate(resumeTemplatePath, {
      SUMMARY:  escapeLatex(aiContent.summary),
      SKILLS:   formatSkillsAsLatex(aiContent.skills),
      PROJECTS: formatProjectsAsLatex(aiContent.projects),
      COMPANY:  escapeLatex(companyName),
      ROLE:     escapeLatex(role || 'Full Stack Developer')
    });

    const coverTex = fillTemplate(coverTemplatePath, {
      COMPANY: escapeLatex(companyName),
      ROLE:    escapeLatex(role || 'Full Stack Developer'),
      BODY:    escapeLatex(aiContent.coverLetter || '')
    });

    const resumeTexPath = path.join(outputDir, 'resume.tex');
    const coverTexPath  = path.join(outputDir, 'cover_letter.tex');
    fs.writeFileSync(resumeTexPath, resumeTex);
    fs.writeFileSync(coverTexPath, coverTex);

    let resumePdfGenerated = false;
    let coverPdfGenerated  = false;
    let compilationWarning = null;

    try {
      compileLaTeX(resumeTexPath, outputDir);
      resumePdfGenerated = fs.existsSync(path.join(outputDir, 'resume.pdf'));
      if (resumePdfGenerated) console.log('✅ resume.pdf generated');
    } catch (e) {
      compilationWarning = e.message;
      console.warn('⚠️  Resume PDF failed:', e.message);
    }

    try {
      compileLaTeX(coverTexPath, outputDir);
      coverPdfGenerated = fs.existsSync(path.join(outputDir, 'cover_letter.pdf'));
      if (coverPdfGenerated) console.log('✅ cover_letter.pdf generated');
    } catch (e) {
      if (!compilationWarning) compilationWarning = e.message;
      console.warn('⚠️  Cover letter PDF failed:', e.message);
    }

    cleanAuxFiles(outputDir);

    const baseUrl = `${req.protocol}://${req.get('host')}`;

    res.json({
      success: true,
      aiContent,
      outputDir: `outputs/${sanitizedCompany}/`,
      files: {
        resumeTex:  `${baseUrl}/outputs/${sanitizedCompany}/resume.tex`,
        coverTex:   `${baseUrl}/outputs/${sanitizedCompany}/cover_letter.tex`,
        resumePdf:  resumePdfGenerated ? `${baseUrl}/outputs/${sanitizedCompany}/resume.pdf`       : null,
        coverPdf:   coverPdfGenerated  ? `${baseUrl}/outputs/${sanitizedCompany}/cover_letter.pdf` : null
      },
      pdfGenerated: resumePdfGenerated || coverPdfGenerated,
      warning: compilationWarning
    });

  } catch (error) {
    console.error('❌ Error:', error);
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