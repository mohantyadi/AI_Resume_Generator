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

@Injectable({
  providedIn: 'root'
})
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
