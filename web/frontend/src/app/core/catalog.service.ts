import { Injectable } from '@angular/core';
import { Observable, from, map } from 'rxjs';
import { Category, Product } from '../models/catalog.model';
import { supabase } from './supabase.client';

@Injectable({
  providedIn: 'root'
})
export class CatalogService {
  getCategories(): Observable<Category[]> {
    return from(
      supabase.from('categories').select('*').order('name', { ascending: true })
    ).pipe(
      map(({ data, error }) => {
        if (error) throw error;
        return data ?? [];
      })
    );
  }

  getProducts(includeInactive = false): Observable<Product[]> {
    let query = supabase
      .from('products')
      .select('*, category:categories(name)')
      .order('created_at', { ascending: false });

    if (!includeInactive) {
      query = query.eq('is_active', true);
    }

    return from(
      Promise.all([
        query,
        supabase.from('current_inventory').select('*')
      ])
    ).pipe(
      map(([productsRes, inventoryRes]) => {
        if (productsRes.error) throw productsRes.error;
        if (inventoryRes.error) throw inventoryRes.error;

        const inventoryMap = new Map<string, any>();
        (inventoryRes.data ?? []).forEach((row) => {
          inventoryMap.set(row.product_id, row);
        });

        return (productsRes.data ?? []).map((product) => {
          const inventory = inventoryMap.get(product.id);
          return {
            ...product,
            category_name: product.category?.name ?? null,
            total_quantity: inventory?.total_quantity ?? 0,
            avg_cost_price: inventory?.avg_cost_price ?? null,
            nearest_expiry_date: inventory?.nearest_expiry_date ?? null
          } as Product;
        });
      })
    );
  }

  createProduct(payload: Partial<Product>): Observable<Product> {
    return from(
      supabase.from('products').insert(payload).select('*, category:categories(name)').single()
    ).pipe(
      map(({ data, error }) => {
        if (error || !data) throw error ?? new Error('Create failed');
        return {
          ...data,
          category_name: data.category?.name ?? null
        } as Product;
      })
    );
  }

  updateProduct(id: string, payload: Partial<Product>): Observable<Product> {
    return from(
      supabase
        .from('products')
        .update(payload)
        .eq('id', id)
        .select('*, category:categories(name)')
        .single()
    ).pipe(
      map(({ data, error }) => {
        if (error || !data) throw error ?? new Error('Update failed');
        return {
          ...data,
          category_name: data.category?.name ?? null
        } as Product;
      })
    );
  }

  deleteProduct(id: string): Observable<{ id: string }> {
    return from(
      supabase.from('products').update({ is_active: false }).eq('id', id).select('id').single()
    ).pipe(
      map(({ data, error }) => {
        if (error || !data) throw error ?? new Error('Delete failed');
        return { id: data.id };
      })
    );
  }
}
