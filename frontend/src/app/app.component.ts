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
