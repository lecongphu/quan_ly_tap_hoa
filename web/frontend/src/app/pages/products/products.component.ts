import { CommonModule } from '@angular/common';
import { Component, OnInit } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { CatalogService } from '../../core/catalog.service';
import { Category, Product } from '../../models/catalog.model';

@Component({
  selector: 'app-products',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './products.component.html',
  styleUrl: './products.component.scss'
})
export class ProductsComponent implements OnInit {
  products: Product[] = [];
  categories: Category[] = [];
  searchTerm = '';
  selectedCategoryId: string | null = null;

  showForm = false;
  editingProduct: Product | null = null;

  formData: Partial<Product> = {
    name: '',
    barcode: '',
    unit: 'sp',
    min_stock_level: 0,
    is_active: true
  };

  constructor(private catalog: CatalogService) {}

  ngOnInit(): void {
    this.loadData();
  }

  get totalActive(): number {
    return this.products.filter((product) => product.is_active).length;
  }

  get totalInactive(): number {
    return this.products.length - this.totalActive;
  }

  loadData(): void {
    this.catalog.getProducts(true).subscribe({
      next: (data) => (this.products = data),
      error: () => (this.products = [])
    });
    this.catalog.getCategories().subscribe({
      next: (data) => (this.categories = data),
      error: () => (this.categories = [])
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

  openForm(product?: Product): void {
    this.editingProduct = product ?? null;
    this.formData = product
      ? { ...product }
      : {
          name: '',
          barcode: '',
          unit: 'sp',
          min_stock_level: 0,
          is_active: true
        };
    this.showForm = true;
  }

  closeForm(): void {
    this.showForm = false;
  }

  saveProduct(): void {
    if (!this.formData.name || !this.formData.unit) return;

    const payload = {
      name: this.formData.name,
      barcode: this.formData.barcode || null,
      unit: this.formData.unit,
      category_id: this.formData.category_id || null,
      min_stock_level: Number(this.formData.min_stock_level || 0),
      is_active: this.formData.is_active ?? true
    };

    const request = this.editingProduct
      ? this.catalog.updateProduct(this.editingProduct.id, payload)
      : this.catalog.createProduct(payload);

    request.subscribe({
      next: () => {
        this.showForm = false;
        this.loadData();
      },
      error: (err) => {
        window.alert(err?.error?.message || 'Không thể lưu sản phẩm.');
      }
    });
  }

  deleteProduct(product: Product): void {
    if (!confirm(`Xóa sản phẩm "${product.name}"?`)) return;
    this.catalog.deleteProduct(product.id).subscribe({
      next: () => this.loadData(),
      error: (err) => window.alert(err?.error?.message || 'Không thể xóa.')
    });
  }

  formatCurrency(value: number | undefined | null): string {
    return new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(value || 0);
  }
}
