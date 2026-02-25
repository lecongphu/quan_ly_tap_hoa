import { HttpErrorResponse, HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { catchError, throwError } from 'rxjs';
import { AuthService } from './auth.service';
import { StoreContextService } from './store-context.service';

export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const authService = inject(AuthService);
  const router = inject(Router);
  const token = authService.token;
  const storeContext = inject(StoreContextService);
  const activeStoreId = storeContext.getActiveStoreId();

  const headers: Record<string, string> = {};
  if (token) headers['Authorization'] = `Bearer ${token}`;
  if (activeStoreId) headers['x-store-id'] = activeStoreId;

  const authReq = Object.keys(headers).length
    ? req.clone({ setHeaders: headers })
    : req;

  return next(authReq).pipe(
    catchError((error: HttpErrorResponse) => {
      if (error.status === 401) {
        authService.clearSession();
        router.navigateByUrl('/login');
      }
      return throwError(() => error);
    })
  );
};