import { CanActivateFn, Router } from '@angular/router';
import { inject } from '@angular/core';
import { AuthService } from './auth.service';

export const authGuard: CanActivateFn = async () => {
  const auth = inject(AuthService);
  const router = inject(Router);

  if (await auth.hasActiveSession()) {
    return true;
  }

  return router.parseUrl('/login');
};

export const loginRedirectGuard: CanActivateFn = async () => {
  const auth = inject(AuthService);
  const router = inject(Router);

  if (await auth.hasActiveSession()) {
    return router.parseUrl('/');
  }

  return true;
};
