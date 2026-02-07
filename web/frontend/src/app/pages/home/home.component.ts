import { CommonModule } from '@angular/common';
import { Component } from '@angular/core';
import { Router, RouterModule } from '@angular/router';
import { AuthService } from '../../core/auth.service';

interface QuickAction {
  title: string;
  subtitle: string;
  icon: string;
  color: string;
  route: string;
}

@Component({
  selector: 'app-home',
  standalone: true,
  imports: [CommonModule, RouterModule],
  templateUrl: './home.component.html',
  styleUrl: './home.component.scss'
})
export class HomeComponent {
  quickActions: QuickAction[] = [
    {
      title: 'Bán hàng',
      subtitle: 'Tạo đơn nhanh với POS',
      icon: 'point_of_sale',
      color: '#2563eb',
      route: '/pos'
    },
    {
      title: 'Sản phẩm',
      subtitle: 'Quản lý danh mục hàng hóa',
      icon: 'category',
      color: '#0ea5e9',
      route: '/products'
    },
    {
      title: 'Khách hàng',
      subtitle: 'Quản lý thông tin khách hàng',
      icon: 'groups',
      color: '#0f766e',
      route: '/customers'
    },
    {
      title: 'Kho hàng',
      subtitle: 'Theo dõi tồn kho & nhập hàng',
      icon: 'inventory_2',
      color: '#16a34a',
      route: '/inventory'
    },
    {
      title: 'Công nợ',
      subtitle: 'Quản lý thu chi & đối soát',
      icon: 'account_balance_wallet',
      color: '#f97316',
      route: '/debt'
    },
    {
      title: 'Báo cáo',
      subtitle: 'Xem tổng hợp doanh thu & tồn kho',
      icon: 'analytics',
      color: '#9333ea',
      route: '/reports'
    }
  ];

  constructor(private auth: AuthService, private router: Router) {}

  logout(): void {
    this.auth.logout().subscribe({
      next: () => this.router.navigateByUrl('/login'),
      error: () => {
        this.auth.clearSession();
        this.router.navigateByUrl('/login');
      }
    });
  }
}
