import { CommonModule } from '@angular/common';
import { Component, OnInit } from '@angular/core';
import { Router } from '@angular/router';
import { Location } from '@angular/common';
import { FormsModule } from '@angular/forms';
import * as XLSX from 'xlsx';
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
  selectedYear: number | null = null;
  availableYears: number[] = [];
  showDuplicateOnly = false;

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
    this.selectedYear = null;
    this.availableYears = [];
    this.showDuplicateOnly = false;
    this.showDetail = true;
    this.loadHistory(this.selectedYear);
    this.loadDebtLines(this.selectedYear);
  }

  closeDetail(): void {
    this.showDetail = false;
    this.showDebtLineForm = false;
    this.editingDebtLine = null;
    this.salesHistory = [];
    this.paymentHistory = [];
    this.debtLines = [];
    this.isHistoryLoading = false;
    this.selectedYear = null;
    this.availableYears = [];
    this.showDuplicateOnly = false;
    this.selectedCustomer = null;
  }

  setDetailTabExtended(tab: 'lines' | 'sales' | 'payments'): void {
    this.detailTab = tab;
  }

  onYearChange(year: number | null): void {
    this.selectedYear = year;
    if (!this.selectedCustomer) return;
    this.loadHistory(year);
    this.loadDebtLines(year, this.showDuplicateOnly);
  }

  toggleDuplicateOnly(): void {
    if (!this.selectedCustomer) return;
    this.loadDebtLines(this.selectedYear, this.showDuplicateOnly);
  }

  loadHistory(year: number | null = null): void {
    if (!this.selectedCustomer) return;
    this.isHistoryLoading = true;
    this.debt.getCustomerHistory(this.selectedCustomer.id, 20, year).subscribe({
      next: (data) => {
        this.salesHistory = data.sales ?? [];
        this.paymentHistory = data.payments ?? [];
        this.updateAvailableYears();
        this.isHistoryLoading = false;
      },
      error: (err) => {
        this.isHistoryLoading = false;
        window.alert(err?.error?.message || 'Không thể tải lịch sử khách hàng.');
      }
    });
  }

  loadDebtLines(year: number | null = null, duplicateOnly = false): void {
    if (!this.selectedCustomer) return;
    this.debt.getDebtLines(this.selectedCustomer.id, year, duplicateOnly).subscribe({
      next: (data) => {
        this.debtLines = data ?? [];
        this.updateAvailableYears();
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
          this.loadDebtLines(this.selectedYear, this.showDuplicateOnly);
          this.loadHistory(this.selectedYear);
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
        this.loadDebtLines(this.selectedYear, this.showDuplicateOnly);
        this.loadHistory(this.selectedYear);
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
        this.loadHistory(this.selectedYear);
      },
      error: (err) => window.alert(err?.error?.message || 'Không thể xóa phiếu thu.')
    });
  }

  setQuickAmount(amount: number): void {
    this.paymentForm.amount = Math.floor(amount);
  }

  get filteredDebtLines(): DebtLine[] {
    return this.applyYearFilter(this.debtLines, (line) => line.created_at);
  }

  get filteredSalesHistory(): CustomerSale[] {
    return this.applyYearFilter(this.salesHistory, (sale) => sale.created_at);
  }

  get filteredPaymentHistory(): DebtPayment[] {
    return this.applyYearFilter(this.paymentHistory, (payment) => payment.created_at);
  }

  exportDebtLinesToExcel(): void {
    if (!this.selectedCustomer) return;
    const lines = this.filteredDebtLines;
    if (!lines.length) {
      window.alert('Không có dòng nợ để xuất.');
      return;
    }

    const rows = lines.map((line, index) => ({
      STT: index + 1,
      'Mã hóa đơn': line.invoice_number || '-',
      'Ngày mua': this.toExcelDate(line.created_at),
      'Hẹn trả': this.toExcelDate(line.due_date),
      'Số tiền': line.final_amount ?? 0,
      'Ghi chú': line.notes ?? '',
      'Loại': line.items?.length ? 'Hóa đơn' : 'Nợ nhập tay',
      'Sản phẩm':
        line.items?.length
          ? line.items
              .map((item) => `${item.product_name} (${item.quantity} ${item.unit})`)
              .join('; ')
          : ''
    }));

    const worksheet = XLSX.utils.json_to_sheet(rows, { cellDates: true });
    this.applySheetFormatting(
      worksheet,
      [6, 16, 18, 12, 14, 24, 12, 40],
      [4],
      [2, 3]
    );
    const workbook = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(workbook, worksheet, 'DongNo');

    const safeName = this.selectedCustomer.name
      .trim()
      .replace(/[^\p{L}\p{N}\s_-]/gu, '')
      .replace(/\s+/g, '_')
      .slice(0, 32);
    const fileName = `dong_no_${safeName || 'khach'}_${this.formatDateStamp()}.xlsx`;
    XLSX.writeFile(workbook, fileName);
  }

  exportSalesToExcel(): void {
    if (!this.selectedCustomer) return;
    const sales = this.filteredSalesHistory;
    if (!sales.length) {
      window.alert('Không có hóa đơn để xuất.');
      return;
    }

    const rows = sales.map((sale, index) => ({
      STT: index + 1,
      'Mã hóa đơn': sale.invoice_number || '-',
      Ngày: this.toExcelDate(sale.created_at),
      Tổng: sale.total_amount ?? 0,
      'Giảm giá': sale.discount_amount ?? 0,
      'Thành tiền': sale.final_amount ?? 0,
      'Hẹn trả': this.toExcelDate(sale.due_date),
      'Thanh toán': sale.payment_method ?? ''
    }));

    const worksheet = XLSX.utils.json_to_sheet(rows, { cellDates: true });
    this.applySheetFormatting(
      worksheet,
      [6, 16, 18, 14, 14, 14, 12, 14],
      [3, 4, 5],
      [2, 6]
    );
    const workbook = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(workbook, worksheet, 'HoaDon');

    const safeName = this.selectedCustomer.name
      .trim()
      .replace(/[^\p{L}\p{N}\s_-]/gu, '')
      .replace(/\s+/g, '_')
      .slice(0, 32);
    const fileName = `hoa_don_${safeName || 'khach'}_${this.formatDateStamp()}.xlsx`;
    XLSX.writeFile(workbook, fileName);
  }

  exportPaymentsToExcel(): void {
    if (!this.selectedCustomer) return;
    const payments = this.filteredPaymentHistory;
    if (!payments.length) {
      window.alert('Không có thanh toán để xuất.');
      return;
    }

    const rows = payments.map((payment, index) => ({
      STT: index + 1,
      Ngày: this.toExcelDate(payment.created_at),
      'Số tiền': payment.amount ?? 0,
      'Phương thức': payment.payment_method ?? '',
      'Ghi chú': payment.notes ?? ''
    }));

    const worksheet = XLSX.utils.json_to_sheet(rows, { cellDates: true });
    this.applySheetFormatting(worksheet, [6, 18, 14, 14, 24], [2], [1]);
    const workbook = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(workbook, worksheet, 'ThanhToan');

    const safeName = this.selectedCustomer.name
      .trim()
      .replace(/[^\p{L}\p{N}\s_-]/gu, '')
      .replace(/\s+/g, '_')
      .slice(0, 32);
    const fileName = `thanh_toan_${safeName || 'khach'}_${this.formatDateStamp()}.xlsx`;
    XLSX.writeFile(workbook, fileName);
  }

  private toInputDate(value?: string | null): string {
    if (!value) return '';
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return '';
    return date.toISOString().slice(0, 10);
  }

  private applySheetFormatting(
    worksheet: XLSX.WorkSheet,
    columnWidths: number[],
    moneyColumns: number[],
    dateColumns: number[] = []
  ): void {
    worksheet['!cols'] = columnWidths.map((wch) => ({ wch }));
    if (!worksheet['!ref']) return;
    const range = XLSX.utils.decode_range(worksheet['!ref']);
    for (let row = range.s.r + 1; row <= range.e.r; row += 1) {
      for (const col of dateColumns) {
        const cellRef = XLSX.utils.encode_cell({ r: row, c: col });
        const cell = worksheet[cellRef];
        if (!cell) continue;
        if (cell.v instanceof Date) {
          cell.t = 'd';
        }
        cell.z = 'dd/mm/yyyy';
      }
      for (const col of moneyColumns) {
        const cellRef = XLSX.utils.encode_cell({ r: row, c: col });
        const cell = worksheet[cellRef];
        if (!cell) continue;
        cell.t = 'n';
        cell.z = '#,##0';
      }
    }
  }

  private toExcelDate(value?: string | null): Date | null {
    if (!value) return null;
    if (/^\\d{4}-\\d{2}-\\d{2}$/.test(value)) {
      const [year, month, day] = value.split('-').map(Number);
      return new Date(year, month - 1, day);
    }
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return null;
    return date;
  }

  private applyYearFilter<T>(
    items: T[],
    getDate: (item: T) => string | null | undefined
  ): T[] {
    if (!this.selectedYear) return items;
    return items.filter((item) => this.getYearValue(getDate(item)) === this.selectedYear);
  }

  private updateAvailableYears(): void {
    if (this.availableYears.length) return;
    const years = new Set<number>();
    const collect = (value?: string | null) => {
      const year = this.getYearValue(value);
      if (year) years.add(year);
    };
    this.debtLines.forEach((line) => collect(line.created_at));
    this.salesHistory.forEach((sale) => collect(sale.created_at));
    this.paymentHistory.forEach((payment) => collect(payment.created_at));
    this.availableYears = Array.from(years).sort((a, b) => b - a);
    if (this.selectedYear && !years.has(this.selectedYear)) {
      this.selectedYear = null;
    }
  }

  private getYearValue(value?: string | null): number | null {
    if (!value) return null;
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return null;
    return date.getFullYear();
  }

  private formatDateValue(value?: string | null): string {
    if (!value) return '-';
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return '-';
    return new Intl.DateTimeFormat('vi-VN', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric'
    }).format(date);
  }

  private formatDateTimeValue(value?: string | null): string {
    if (!value) return '-';
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return '-';
    return new Intl.DateTimeFormat('vi-VN', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    }).format(date);
  }

  private formatDateStamp(): string {
    const now = new Date();
    const yyyy = now.getFullYear();
    const mm = String(now.getMonth() + 1).padStart(2, '0');
    const dd = String(now.getDate()).padStart(2, '0');
    return `${yyyy}${mm}${dd}`;
  }

  formatCurrency(value: number | undefined | null): string {
    return new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(value || 0);
  }
}
