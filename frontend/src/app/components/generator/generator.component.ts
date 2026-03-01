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
  
  // Form fields
  jobDescription = '';
  companyName = '';
  role = '';

  // Results
  result: GenerateResponse | null = null;
  error: string | null = null;

  // Loading state
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

  // Tabs
  activeTab: 'summary' | 'skills' | 'projects' | 'cover' = 'summary';

  // Backend health
  backendOnline = false;

  constructor(private apiService: ApiService) {}

  ngOnInit() {
    this.checkBackendHealth();
  }

  checkBackendHealth() {
    this.apiService.checkHealth().subscribe({
      next: () => { this.backendOnline = true; },
      error: () => { this.backendOnline = false; }
    });
  }

  get isFormValid(): boolean {
    return this.jobDescription.trim().length > 20 && this.companyName.trim().length > 0;
  }

  get charCount(): number {
    return this.jobDescription.length;
  }

  startLoading() {
    this.currentLoadingIndex = 0;
    this.loadingProgress = 0;
    
    // Cycle loading messages
    this.loadingInterval = setInterval(() => {
      if (this.currentLoadingIndex < this.loadingMessages.length - 1) {
        this.currentLoadingIndex++;
      }
    }, 3500);

    // Progress bar
    this.progressInterval = setInterval(() => {
      if (this.loadingProgress < 90) {
        this.loadingProgress += Math.random() * 3;
      }
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

  copyText(text: string) {
    navigator.clipboard.writeText(text).then(() => {
      // Brief feedback handled by CSS
    });
  }

  openFile(url: string | null) {
    if (url) window.open(url, '_blank');
  }

  get currentLoading(): LoadingMessage {
    return this.loadingMessages[this.currentLoadingIndex];
  }
}
