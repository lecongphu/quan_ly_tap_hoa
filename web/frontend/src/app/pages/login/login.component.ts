import { CommonModule } from '@angular/common';
import { Component, OnInit } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router } from '@angular/router';
import { AuthService } from '../../core/auth.service';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './login.component.html',
  styleUrl: './login.component.scss'
})
export class LoginComponent implements OnInit {
  readonly appName = 'Quản lý Tạp hóa';
  readonly version = '1.0.0';

  hidePassword = true;
  isLoading = false;
  errorMessage = '';

  form = this.fb.group({
    email: ['', [Validators.required, Validators.email]],
    password: ['', [Validators.required, Validators.minLength(6)]]
  });

  constructor(private fb: FormBuilder, private auth: AuthService, private router: Router) {}

  ngOnInit(): void {
    if (this.auth.isAuthenticated) {
      this.router.navigateByUrl('/');
    }
  }

  submit(): void {
    this.errorMessage = '';
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }

    const { email, password } = this.form.value;
    if (!email || !password) return;

    this.isLoading = true;
    this.auth.login(email, password).subscribe({
      next: () => {
        this.isLoading = false;
        this.router.navigateByUrl('/');
      },
      error: (err) => {
        this.isLoading = false;
        this.errorMessage = err?.error?.message || 'Đăng nhập thất bại.';
      }
    });
  }
}
