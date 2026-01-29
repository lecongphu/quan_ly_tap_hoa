import { CommonModule } from '@angular/common';
import { Component, OnInit } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Location } from '@angular/common';
import { Router } from '@angular/router';
import { DebtService } from '../../core/debt.service';
import { Customer } from '../../models/customer.model';

@Component({
  selector: 'app-customers',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './customers.component.html',
  styleUrl: './customers.component.scss'
})
export class CustomersComponent implements OnInit {
  customers: Customer[] = [];
  searchTerm = '';
  showOnlyActive = false;
  showForm = false;
  editingCustomer: Customer | null = null;

  customerForm: Partial<Customer> = {
    name: '',
    phone: '',
    address: '',
    debt_limit: 0,
    is_active: true
  };

  constructor(
    private debt: DebtService,
    private router: Router,
    private location: Location
  ) {}

  ngOnInit(): void {
    this.loadCustomers();
  }

  loadCustomers(): void {
    this.debt.getCustomers(false, true).subscribe({
      next: (data) => (this.customers = data),
      error: () => (this.customers = [])
    });
  }

  get filteredCustomers(): Customer[] {
    const query = this.searchTerm.toLowerCase().trim();
    return this.customers.filter((customer) => {
      const matchesQuery =
        !query ||
        customer.name.toLowerCase().includes(query) ||
        (customer.phone ?? '').includes(query);
      const matchesActive = !this.showOnlyActive || customer.is_active !== false;
      return matchesQuery && matchesActive;
    });
  }

  get activeCount(): number {
    return this.customers.filter((customer) => customer.is_active !== false).length;
  }

  get inactiveCount(): number {
    return this.customers.filter((customer) => customer.is_active === false).length;
  }

  goBack(): void {
    this.location.back();
  }

  goHome(): void {
    this.router.navigateByUrl('/');
  }

  openForm(customer?: Customer): void {
    this.editingCustomer = customer ?? null;
    this.customerForm = customer
      ? {
          name: customer.name,
          phone: customer.phone ?? '',
          address: customer.address ?? '',
          debt_limit: customer.debt_limit ?? 0,
          is_active: customer.is_active ?? true
        }
      : {
          name: '',
          phone: '',
          address: '',
          debt_limit: 0,
          is_active: true
        };
    this.showForm = true;
  }

  closeForm(): void {
    this.showForm = false;
  }

  saveCustomer(): void {
    if (!this.customerForm.name) return;

    const payload = {
      name: this.customerForm.name,
      phone: this.customerForm.phone || null,
      address: this.customerForm.address || null,
      debt_limit: Number(this.customerForm.debt_limit || 0),
      is_active: this.customerForm.is_active ?? true
    };

    const request = this.editingCustomer
      ? this.debt.updateCustomer(this.editingCustomer.id, payload)
      : this.debt.createCustomer(payload);

    request.subscribe({
      next: () => {
        this.showForm = false;
        this.loadCustomers();
      },
      error: (err) => window.alert(err?.error?.message || 'Không thể lưu khách hàng.')
    });
  }

  deleteCustomer(customer: Customer): void {
    if (!confirm(`Xóa khách hàng "${customer.name}"?`)) return;
    this.debt.deleteCustomer(customer.id).subscribe({
      next: () => this.loadCustomers(),
      error: (err) => window.alert(err?.error?.message || 'Không thể xóa.')
    });
  }

  formatCurrency(value: number | undefined | null): string {
    return new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(value || 0);
  }
}
