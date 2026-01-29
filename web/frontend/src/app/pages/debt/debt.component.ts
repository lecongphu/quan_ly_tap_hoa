import { CommonModule } from '@angular/common';
import { Component, OnInit } from '@angular/core';
import { Router } from '@angular/router';
import { Location } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { DebtService } from '../../core/debt.service';
import { Customer, CustomerSale, DebtLine, DebtPayment } from '../../models/customer.model';

@Component({
  selector: 'app-debt',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './debt.component.html',
  styleUrl: './debt.component.scss'
})
export class DebtComponent implements OnInit {
  customers: Customer[] = [];
  searchTerm = '';
  showOnlyDebt = false;
  activeTab: 'customers' | 'debt' = 'customers';
  showPaymentForm = false;
  showDetail = false;
  showDebtLineForm = false;
  selectedCustomer: Customer | null = null;
  editingPayment: DebtPayment | null = null;
  editingDebtLine: DebtLine | null = null;
  detailTab: 'lines' | 'sales' | 'payments' = 'lines';
  salesHistory: CustomerSale[] = [];
  paymentHistory: DebtPayment[] = [];
  debtLines: DebtLine[] = [];
  isHistoryLoading = false;

  paymentForm = {
    amount: 0,
    payment_method: 'cash' as 'cash' | 'transfer',
    notes: ''
  };

  debtLineForm = {
    amount: 0,
    purchase_date: '',
    due_date: '',
    notes: ''
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
    this.debt.getCustomers(this.showOnlyDebt).subscribe({
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
      if (this.showOnlyDebt) {
        return matchesQuery && (customer.current_debt ?? 0) > 0;
      }
      return matchesQuery;
    });
  }

  get totalDebt(): number {
    return this.filteredCustomers.reduce(
      (sum, customer) => sum + (customer.current_debt ?? 0),
      0
    );
  }

  toggleDebtFilter(): void {
    this.showOnlyDebt = !this.showOnlyDebt;
    this.activeTab = this.showOnlyDebt ? 'debt' : 'customers';
    this.loadCustomers();
  }

  setTab(tab: 'customers' | 'debt'): void {
    this.activeTab = tab;
    this.showOnlyDebt = tab === 'debt';
    this.loadCustomers();
  }

  goBack(): void {
    this.location.back();
  }

  goHome(): void {
    this.router.navigateByUrl('/');
  }

  openPaymentForm(customer: Customer, payment?: DebtPayment): void {
    this.showDetail = false;
    this.selectedCustomer = customer;
    this.editingPayment = payment ?? null;
    this.paymentForm = payment
      ? {
          amount: payment.amount,
          payment_method: payment.payment_method as 'cash' | 'transfer',
          notes: payment.notes ?? ''
        }
      : {
          amount: 0,
          payment_method: 'cash',
          notes: ''
        };
    this.showPaymentForm = true;
  }

  openDetail(customer: Customer): void {
    this.showPaymentForm = false;
    this.selectedCustomer = customer;
    this.detailTab = 'lines';
    this.showDetail = true;
    this.loadHistory();
    this.loadDebtLines();
  }

  closeDetail(): void {
    this.showDetail = false;
    this.showDebtLineForm = false;
    this.editingDebtLine = null;
    this.salesHistory = [];
    this.paymentHistory = [];
    this.debtLines = [];
    this.isHistoryLoading = false;
    this.selectedCustomer = null;
  }

  setDetailTabExtended(tab: 'lines' | 'sales' | 'payments'): void {
    this.detailTab = tab;
  }

  loadHistory(): void {
    if (!this.selectedCustomer) return;
    this.isHistoryLoading = true;
    this.debt.getCustomerHistory(this.selectedCustomer.id).subscribe({
      next: (data) => {
        this.salesHistory = data.sales ?? [];
        this.paymentHistory = data.payments ?? [];
        this.isHistoryLoading = false;
      },
      error: (err) => {
        this.isHistoryLoading = false;
        window.alert(err?.error?.message || 'Không thể tải lịch sử khách hàng.');
      }
    });
  }

  loadDebtLines(): void {
    if (!this.selectedCustomer) return;
    this.debt.getDebtLines(this.selectedCustomer.id).subscribe({
      next: (data) => {
        this.debtLines = data ?? [];
      },
      error: (err) => {
        window.alert(err?.error?.message || 'Không thể tải dòng nợ.');
      }
    });
  }

  closePaymentForm(): void {
    this.showPaymentForm = false;
    this.selectedCustomer = null;
    this.editingPayment = null;
  }

  openDebtLineForm(customer: Customer, line?: DebtLine): void {
    this.showPaymentForm = false;
    this.selectedCustomer = customer;
    this.editingDebtLine = line ?? null;
    this.debtLineForm = line
      ? {
          amount: line.final_amount,
          purchase_date: this.toInputDate(line.created_at),
          due_date: this.toInputDate(line.due_date),
          notes: line.notes ?? ''
        }
      : {
          amount: 0,
          purchase_date: '',
          due_date: '',
          notes: ''
        };
    this.showDebtLineForm = true;
  }

  closeDebtLineForm(): void {
    this.showDebtLineForm = false;
    this.editingDebtLine = null;
    this.debtLineForm = {
      amount: 0,
      purchase_date: '',
      due_date: '',
      notes: ''
    };
    if (!this.showDetail && !this.showPaymentForm) {
      this.selectedCustomer = null;
    }
  }

  saveDebtLine(): void {
    if (!this.selectedCustomer) return;
    const amount = Number(this.debtLineForm.amount || 0);
    if (amount <= 0) {
      window.alert('Số tiền nợ không hợp lệ.');
      return;
    }

    const payload = {
      amount,
      purchase_date: this.debtLineForm.purchase_date || null,
      due_date: this.debtLineForm.due_date || null,
      notes: this.debtLineForm.notes?.trim() || null
    };

    const request = this.editingDebtLine
      ? this.debt.updateDebtLine(this.editingDebtLine.id, payload)
      : this.debt.createDebtLine(this.selectedCustomer.id, payload);

    request.subscribe({
      next: () => {
        this.showDebtLineForm = false;
        this.editingDebtLine = null;
        this.loadCustomers();
        if (this.showDetail) {
          this.loadDebtLines();
          this.loadHistory();
        } else {
          this.selectedCustomer = null;
        }
      },
      error: (err) => window.alert(err?.error?.message || 'Không thể lưu dòng nợ.')
    });
  }

  editDebtLine(line: DebtLine): void {
    if (!this.selectedCustomer) return;
    this.openDebtLineForm(this.selectedCustomer, line);
  }

  deleteDebtLine(line: DebtLine): void {
    if (!this.canEditDebtLine(line)) return;
    if (!confirm('Xóa dòng nợ này?')) return;
    this.debt.deleteDebtLine(line.id).subscribe({
      next: () => {
        this.loadCustomers();
        if (this.showDetail) {
          this.loadDebtLines();
          this.loadHistory();
        }
      },
      error: (err) => window.alert(err?.error?.message || 'Không thể xóa dòng nợ.')
    });
  }

  canEditDebtLine(line: DebtLine): boolean {
    return !(line.items?.length > 0);
  }

  confirmPayment(): void {
    if (!this.selectedCustomer) return;
    const amount = Number(this.paymentForm.amount || 0);
    const availableDebt =
      (this.selectedCustomer.current_debt || 0) + (this.editingPayment?.amount || 0);
    if (amount <= 0 || amount > availableDebt) {
      window.alert('Số tiền không hợp lệ.');
      return;
    }

    const payload = {
      amount,
      payment_method: this.paymentForm.payment_method,
      notes: this.paymentForm.notes || null
    };

    const request = this.editingPayment
      ? this.debt.updatePayment(this.editingPayment.id, payload)
      : this.debt.recordPayment({
          customer_id: this.selectedCustomer.id,
          ...payload
        });

    request.subscribe({
      next: () => {
        this.showPaymentForm = false;
        this.selectedCustomer = null;
        this.editingPayment = null;
        this.loadCustomers();
      },
      error: (err) =>
        window.alert(err?.error?.message || 'Không thể ghi nhận thanh toán.')
    });
  }

  editPayment(payment: DebtPayment): void {
    if (!this.selectedCustomer) return;
    this.openPaymentForm(this.selectedCustomer, payment);
  }

  deletePayment(payment: DebtPayment): void {
    if (!confirm('Xóa phiếu thu nợ này?')) return;
    this.debt.deletePayment(payment.id).subscribe({
      next: () => {
        this.loadCustomers();
        this.loadHistory();
      },
      error: (err) => window.alert(err?.error?.message || 'Không thể xóa phiếu thu.')
    });
  }

  setQuickAmount(amount: number): void {
    this.paymentForm.amount = Math.floor(amount);
  }

  private toInputDate(value?: string | null): string {
    if (!value) return '';
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return '';
    return date.toISOString().slice(0, 10);
  }

  formatCurrency(value: number | undefined | null): string {
    return new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(value || 0);
  }
}
