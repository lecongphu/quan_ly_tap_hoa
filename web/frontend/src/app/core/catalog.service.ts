import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { ApiService } from './api.service';
import { Category, Product } from '../models/catalog.model';

@Injectable({
  providedIn: 'root'
})
export class CatalogService {
  constructor(private api: ApiService) {}

  getCategories(): Observable<Category[]> {
    return this.api.get<Category[]>('/catalog/categories');
  }

  getProducts(includeInactive = false): Observable<Product[]> {
    return this.api.get<Product[]>('/catalog/products', { includeInactive });
  }

  createProduct(payload: Partial<Product>): Observable<Product> {
    return this.api.post<Product>('/catalog/products', payload);
  }

  updateProduct(id: string, payload: Partial<Product>): Observable<Product> {
    return this.api.put<Product>(`/catalog/products/${id}`, payload);
  }

  deleteProduct(id: string): Observable<{ id: string }>{
    return this.api.delete<{ id: string }>(`/catalog/products/${id}`);
  }
}