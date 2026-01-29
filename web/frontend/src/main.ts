import { registerLocaleData } from '@angular/common';
import localeVi from '@angular/common/locales/vi';
import { bootstrapApplication } from '@angular/platform-browser';
import { appConfig } from './app/app.config';
import { AppComponent } from './app/app.component';

registerLocaleData(localeVi);

bootstrapApplication(AppComponent, appConfig)
  .catch((err) => console.error(err));