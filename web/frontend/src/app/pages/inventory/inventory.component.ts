import { CommonModule } from '@angular/common';
import { Component, OnInit } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { CatalogService } from '../../core/catalog.service';
import { InventoryService } from '../../core/inventory.service';
import { Category, Product, InventoryAlert } from '../../models/catalog.model';
import { PurchaseOrder, Supplier } from '../../models/inventory.model';

@Component({
  selector: 'app-inventory',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './inventory.component.html',
  styleUrl: './inventory.component.scss'
})
export class InventoryComponent implements OnInit {
  activeTab: 'stock' | 'purchase' | 'suppliers' | 'alerts' = 'stock';

  products: Product[] = [];
  categories: Category[] = [];
  purchaseOrders: PurchaseOrder[] = [];
  suppliers: Supplier[] = [];
  alerts: { nearExpiry: InventoryAlert[]; lowStock: InventoryAlert[] } = {
    nearExpiry: [],
    lowStock: []
  };

  searchTerm = '';
  selectedCategoryId: string | null = null;

  constructor(private catalog: CatalogService, private inventory: InventoryService) {}

  ngOnInit(): void {
    this.loadStock();
    this.loadPurchaseOrders();
    this.loadSuppliers();
    this.loadAlerts();
  }

  loadStock(): void {
    this.catalog.getProducts(true).subscribe({
      next: (data) => (this.products = data),
      error: () => (this.products = [])
    });
    this.catalog.getCategories().subscribe({
      next: (data) => (this.categories = data),
      error: () => (this.categories = [])
    });
  }

  loadPurchaseOrders(): void {
    this.inventory.getPurchaseOrders().subscribe({
      next: (data) => (this.purchaseOrders = data),
      error: () => (this.purchaseOrders = [])
    });
  }

  loadSuppliers(): void {
    this.inventory.getSuppliers().subscribe({
      next: (data) => (this.suppliers = data),
      error: () => (this.suppliers = [])
    });
  }

  loadAlerts(): void {
    this.inventory.getAlerts().subscribe({
      next: (data) => (this.alerts = data),
      error: () => (this.alerts = { nearExpiry: [], lowStock: [] })
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
      return matchesQuery && matchesCategory;
    });
  }

  formatCurrency(value: number | undefined | null): string {
    return new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(value || 0);
  }

  statusLabel(product: Product): string {
    const stock = product.total_quantity ?? 0;
    const min = product.min_stock_level ?? 0;
    if (stock <= 0) return 'Hết hàng';
    if (min > 0 && stock <= min) return 'Sắp hết';
    return 'Còn hàng';
  }

  statusClass(product: Product): string {
    const stock = product.total_quantity ?? 0;
    const min = product.min_stock_level ?? 0;
    if (stock <= 0) return 'out-of-stock';
    if (min > 0 && stock <= min) return 'low-stock';
    return 'in-stock';
  }
}
