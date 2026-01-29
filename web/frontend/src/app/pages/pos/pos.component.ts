import { CommonModule } from '@angular/common';
import { Component, OnInit } from '@angular/core';
import { FormsModule, ReactiveFormsModule, FormBuilder, Validators } from '@angular/forms';
import { CatalogService } from '../../core/catalog.service';
import { PosService } from '../../core/pos.service';
import { Category, Product } from '../../models/catalog.model';
import { CartItem } from '../../models/cart.model';
import { Customer } from '../../models/customer.model';

@Component({
  selector: 'app-pos',
  standalone: true,
  imports: [CommonModule, FormsModule, ReactiveFormsModule],
  templateUrl: './pos.component.html',
  styleUrl: './pos.component.scss'
})
export class PosComponent implements OnInit {
  products: Product[] = [];
  categories: Category[] = [];
  customers: Customer[] = [];

  searchTerm = '';
  selectedStockStatus: 'all' | 'in_stock' | 'low_stock' | 'out_of_stock' = 'all';
  selectedCategoryId: string | null = null;

  cart: CartItem[] = [];

  showPaymentDialog = false;
  isCheckingOut = false;

  paymentForm = this.fb.group({
    customer_id: [''],
    payment_method: ['cash', Validators.required],
    due_date: [''],
    notes: [''],
    discount_amount: [0]
  });

  constructor(
    private catalog: CatalogService,
    private posService: PosService,
    private fb: FormBuilder
  ) {}

  ngOnInit(): void {
    this.loadData();
  }

  loadData(): void {
    this.catalog.getProducts().subscribe({
      next: (data) => (this.products = data),
      error: () => (this.products = [])
    });
    this.catalog.getCategories().subscribe({
      next: (data) => (this.categories = data),
      error: () => (this.categories = [])
    });
    this.posService.getCustomers().subscribe({
      next: (data) => (this.customers = data),
      error: () => (this.customers = [])
    });
  }

  get filteredProducts(): Product[] {
    const query = this.searchTerm.toLowerCase().trim();
    return this.products.filter((product) => {
      const matchesQuery =
        !query ||
        product.name.toLowerCase().includes(query) ||
        (product.barcode ?? '').toLowerCase().includes(query);
      const matchesCategory =
        !this.selectedCategoryId || product.category_id === this.selectedCategoryId;
      const matchesStock = (() => {
        const stock = product.total_quantity ?? 0;
        const minStock = product.min_stock_level ?? 0;
        if (this.selectedStockStatus === 'in_stock') return stock > minStock;
        if (this.selectedStockStatus === 'low_stock') return stock > 0 && stock <= minStock;
        if (this.selectedStockStatus === 'out_of_stock') return stock <= 0;
        return true;
      })();
      return matchesQuery && matchesCategory && matchesStock;
    });
  }

  get inStockCount(): number {
    return this.products.filter((p) => (p.total_quantity ?? 0) > 0).length;
  }

  get lowStockCount(): number {
    return this.products.filter((p) => {
      const stock = p.total_quantity ?? 0;
      const min = p.min_stock_level ?? 0;
      return stock > 0 && min > 0 && stock <= min;
    }).length;
  }

  get outOfStockCount(): number {
    return this.products.filter((p) => (p.total_quantity ?? 0) <= 0).length;
  }

  get subtotal(): number {
    return this.cart.reduce((sum, item) => sum + item.unit_price * item.quantity, 0);
  }

  get discountAmount(): number {
    return Number(this.paymentForm.value.discount_amount || 0);
  }

  get finalAmount(): number {
    return this.subtotal - this.discountAmount;
  }

  addProduct(product: Product): void {
    if ((product.total_quantity ?? 0) <= 0) return;
    const existing = this.cart.find((item) => item.product.id === product.id);
    const price = (product.avg_cost_price ?? 0) * 1.3;
    if (existing) {
      existing.quantity += 1;
    } else {
      this.cart.push({
        product,
        quantity: 1,
        unit_price: price
      });
    }
  }

  updateQuantity(item: CartItem, delta: number): void {
    item.quantity += delta;
    if (item.quantity <= 0) {
      this.removeItem(item);
    }
  }

  removeItem(item: CartItem): void {
    this.cart = this.cart.filter((entry) => entry !== item);
  }

  openCheckout(): void {
    if (!this.cart.length) {
      window.alert('Giỏ hàng trống.');
      return;
    }
    this.showPaymentDialog = true;
  }

  closeCheckout(): void {
    this.showPaymentDialog = false;
  }

  confirmCheckout(): void {
    if (this.paymentForm.invalid) return;

    const payload = {
      customer_id: this.paymentForm.value.customer_id || null,
      payment_method: this.paymentForm.value.payment_method as 'cash' | 'transfer' | 'debt',
      discount_amount: Number(this.paymentForm.value.discount_amount || 0),
      due_date:
        this.paymentForm.value.payment_method === 'debt'
          ? (this.paymentForm.value.due_date || null)
          : null,
      notes: this.paymentForm.value.notes || null,
      items: this.cart.map((item) => ({
        product_id: item.product.id,
        quantity: item.quantity,
        unit_price: item.unit_price
      }))
    };

    this.isCheckingOut = true;
    this.posService.checkout(payload).subscribe({
      next: () => {
        this.isCheckingOut = false;
        this.cart = [];
        this.paymentForm.reset({ payment_method: 'cash', discount_amount: 0, due_date: '' });
        this.showPaymentDialog = false;
        this.loadData();
        window.alert('Bán hàng thành công!');
      },
      error: (err) => {
        this.isCheckingOut = false;
        window.alert(err?.error?.message || 'Không thể hoàn tất thanh toán.');
      }
    });
  }

  formatCurrency(value: number): string {
    return new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(value);
  }

  statusLabel(product: Product): string {
    const stock = product.total_quantity ?? 0;
    const min = product.min_stock_level ?? 0;
    if (stock <= 0) return 'Hết hàng';
    if (min > 0 && stock <= min) return 'Sắp hết';
    return 'Còn hàng';
  }

  statusColor(product: Product): string {
    const stock = product.total_quantity ?? 0;
    const min = product.min_stock_level ?? 0;
    if (stock <= 0) return '#ef4444';
    if (min > 0 && stock <= min) return '#f59e0b';
    return '#22c55e';
  }
}
