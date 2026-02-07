import { Injectable } from '@angular/core';
import { Observable, from, map } from 'rxjs';
import { InventoryAlert } from '../models/catalog.model';
import { PurchaseOrder, Supplier } from '../models/inventory.model';
import { supabase } from './supabase.client';

@Injectable({
  providedIn: 'root'
})
export class InventoryService {
  getAlerts(
    days = 7
  ): Observable<{ nearExpiry: InventoryAlert[]; lowStock: InventoryAlert[] }> {
    return from(
      Promise.all([
        supabase.rpc('get_products_near_expiry', { days_threshold: days }),
        supabase.rpc('get_low_stock_products')
      ])
    ).pipe(
      map(([nearExpiryRes, lowStockRes]) => {
        if (nearExpiryRes.error) throw nearExpiryRes.error;
        if (lowStockRes.error) throw lowStockRes.error;
        return {
          nearExpiry: (nearExpiryRes.data ?? []) as InventoryAlert[],
          lowStock: (lowStockRes.data ?? []) as InventoryAlert[]
        };
      })
    );
  }

  getSuppliers(): Observable<Supplier[]> {
    return from(
      supabase.from('suppliers').select('*').order('created_at', { ascending: false })
    ).pipe(
      map(({ data, error }) => {
        if (error) throw error;
        return data ?? [];
      })
    );
  }

  createSupplier(payload: Partial<Supplier>): Observable<Supplier> {
    return from(
      supabase.from('suppliers').insert(payload).select('*').single()
    ).pipe(
      map(({ data, error }) => {
        if (error || !data) throw error ?? new Error('Create failed');
        return data as Supplier;
      })
    );
  }

  getPurchaseOrders(): Observable<PurchaseOrder[]> {
    return from(
      supabase
        .from('purchase_orders')
        .select('*, supplier:suppliers(name), items:purchase_order_items(*)')
        .order('created_at', { ascending: false })
    ).pipe(
      map(({ data, error }) => {
        if (error) throw error;
        return (data ?? []).map((order: any) => ({
          ...order,
          supplier_name: order.supplier?.name ?? null,
          total_items: Array.isArray(order.items)
            ? order.items.reduce((sum: number, item: any) => sum + Number(item.quantity || 0), 0)
            : 0
        })) as PurchaseOrder[];
      })
    );
  }

  createPurchaseOrder(payload: {
    supplier_id?: string | null;
    warehouse?: string | null;
    notes?: string | null;
    items: Array<{ product_id: string; quantity: number; unit_price: number }>;
    order_number?: string | null;
  }): Observable<PurchaseOrder> {
    return from(
      supabase.rpc('create_purchase_order', {
        p_items: payload.items,
        p_order_number: payload.order_number ?? null,
        p_supplier_id: payload.supplier_id ?? null,
        p_warehouse: payload.warehouse ?? null,
        p_notes: payload.notes ?? null
      })
    ).pipe(
      map(({ data, error }) => {
        if (error || !data) throw error ?? new Error('Create failed');
        const order = (data as any).order ?? data;
        return order as PurchaseOrder;
      })
    );
  }

  stockIn(payload: {
    product_id: string;
    quantity: number;
    cost_price: number;
    batch_number?: string | null;
    expiry_date?: string | null;
    received_date?: string | null;
  }): Observable<unknown> {
    return from(
      supabase.rpc('stock_in', {
        p_product_id: payload.product_id,
        p_quantity: payload.quantity,
        p_cost_price: payload.cost_price,
        p_batch_number: payload.batch_number ?? null,
        p_expiry_date: payload.expiry_date ?? null,
        p_received_date: payload.received_date ?? null
      })
    ).pipe(
      map(({ data, error }) => {
        if (error) throw error;
        return data ?? {};
      })
    );
  }
}
