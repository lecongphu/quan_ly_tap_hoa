import { CommonModule } from '@angular/common';
import { Component, OnInit } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { CatalogService } from '../../core/catalog.service';
import { Category, Product } from '../../models/catalog.model';

interface OpenFoodFactsProduct {
  product_name?: string;
  product_name_vi?: string;
  generic_name?: string;
  generic_name_vi?: string;
  quantity?: string;
  brands?: string;
}

interface OpenFoodFactsLookupResponse {
  status?: number;
  product?: OpenFoodFactsProduct;
}

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
  isBarcodeLookupLoading = false;
  barcodeLookupMessage = '';
  barcodeLookupError = false;
  private barcodeLookupRequestId = 0;

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
    this.barcodeLookupRequestId += 1;
    this.resetBarcodeLookupState();
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
    this.barcodeLookupRequestId += 1;
    this.resetBarcodeLookupState();
  }

  lookupProductByBarcode(): void {
    const barcode = this.normalizeBarcode(this.formData.barcode ?? '');
    this.formData.barcode = barcode;
    if (!barcode) {
      this.setBarcodeLookupMessage('Vui lòng nhập hoặc quét mã vạch.', true);
      return;
    }

    const duplicateProduct = this.findDuplicateBarcodeProduct(barcode);
    if (duplicateProduct) {
      this.setBarcodeLookupMessage(
        `Mã vạch đã tồn tại ở sản phẩm "${duplicateProduct.name}".`,
        true
      );
      return;
    }

    const requestId = ++this.barcodeLookupRequestId;
    this.isBarcodeLookupLoading = true;
    this.setBarcodeLookupMessage('', false);

    const endpoint = `https://world.openfoodfacts.org/api/v2/product/${encodeURIComponent(
      barcode
    )}.json?fields=product_name,product_name_vi,generic_name,generic_name_vi,quantity,brands`;

    fetch(endpoint, {
      method: 'GET',
      headers: {
        Accept: 'application/json'
      }
    })
      .then(async (response) => {
        if (!response.ok) {
          throw new Error(`Lookup failed with status ${response.status}`);
        }
        return (await response.json()) as OpenFoodFactsLookupResponse;
      })
      .then((result) => {
        if (requestId !== this.barcodeLookupRequestId) return;

        const product = result.product;
        if (result.status !== 1 || !product) {
          this.setBarcodeLookupMessage('Không tìm thấy thông tin hàng hóa cho mã vạch này.', true);
          return;
        }

        const resolvedName =
          product.product_name_vi?.trim() ||
          product.product_name?.trim() ||
          product.generic_name_vi?.trim() ||
          product.generic_name?.trim() ||
          '';

        if (!resolvedName) {
          this.setBarcodeLookupMessage('Đã tìm thấy mã vạch nhưng chưa có tên sản phẩm.', true);
          return;
        }

        this.formData.name = resolvedName;

        const shouldUpdateUnit = !this.formData.unit || this.formData.unit === 'sp';
        const suggestedUnit = this.suggestUnitFromQuantity(product.quantity);
        if (shouldUpdateUnit && suggestedUnit) {
          this.formData.unit = suggestedUnit;
        }

        const detailParts = [product.brands?.trim(), product.quantity?.trim()].filter(
          (value): value is string => !!value
        );
        const detailText = detailParts.length ? ` (${detailParts.join(' - ')})` : '';
        this.setBarcodeLookupMessage(`Đã điền thông tin từ mã vạch${detailText}.`, false);
      })
      .catch(() => {
        if (requestId !== this.barcodeLookupRequestId) return;
        this.setBarcodeLookupMessage('Không thể tra cứu mã vạch. Vui lòng thử lại.', true);
      })
      .finally(() => {
        if (requestId !== this.barcodeLookupRequestId) return;
        this.isBarcodeLookupLoading = false;
      });
  }

  saveProduct(): void {
    if (!this.formData.name || !this.formData.unit) return;
    const barcode = this.normalizeBarcode(this.formData.barcode ?? '');
    this.formData.barcode = barcode;
    const duplicateProduct = this.findDuplicateBarcodeProduct(barcode);
    if (duplicateProduct) {
      window.alert(`Mã vạch "${barcode}" đã được dùng cho sản phẩm "${duplicateProduct.name}".`);
      return;
    }

    const payload = {
      name: this.formData.name,
      barcode: barcode || null,
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

  private resetBarcodeLookupState(): void {
    this.isBarcodeLookupLoading = false;
    this.barcodeLookupMessage = '';
    this.barcodeLookupError = false;
  }

  private setBarcodeLookupMessage(message: string, isError: boolean): void {
    this.barcodeLookupMessage = message;
    this.barcodeLookupError = isError;
  }

  private findDuplicateBarcodeProduct(barcode: string): Product | null {
    if (!barcode) return null;
    const normalizedBarcode = this.normalizeBarcode(barcode);
    return (
      this.products.find(
        (product) =>
          this.normalizeBarcode(product.barcode ?? '') === normalizedBarcode &&
          product.id !== this.editingProduct?.id
      ) ?? null
    );
  }

  private suggestUnitFromQuantity(quantity?: string): string | null {
    const value = quantity?.toLowerCase().trim();
    if (!value) return null;
    if (/(ml|\bl\b|lit)/.test(value)) return 'chai';
    if (/(kg|\bg\b|gram)/.test(value)) return 'goi';
    if (/(lon|can)/.test(value)) return 'lon';
    if (/(chai|bottle)/.test(value)) return 'chai';
    return null;
  }

  private normalizeBarcode(barcode: string): string {
    return barcode.replace(/\s+/g, '').trim();
  }
}
