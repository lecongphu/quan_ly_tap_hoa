import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { ApiService } from './api.service';
import { InventoryAlert } from '../models/catalog.model';
import { PurchaseOrder, Supplier } from '../models/inventory.model';

@Injectable({
  providedIn: 'root'
})
export class InventoryService {
  constructor(private api: ApiService) {}

  getAlerts(days = 7): Observable<{ nearExpiry: InventoryAlert[]; lowStock: InventoryAlert[] }> {
    return this.api.get<{ nearExpiry: InventoryAlert[]; lowStock: InventoryAlert[] }>('/inventory/alerts', { days });
  }

  getSuppliers(): Observable<Supplier[]> {
    return this.api.get<Supplier[]>('/inventory/suppliers');
  }

  createSupplier(payload: Partial<Supplier>): Observable<Supplier> {
    return this.api.post<Supplier>('/inventory/suppliers', payload);
  }

  getPurchaseOrders(): Observable<PurchaseOrder[]> {
    return this.api.get<PurchaseOrder[]>('/inventory/purchase-orders');
  }

  createPurchaseOrder(payload: {
    supplier_id?: string | null;
    warehouse?: string | null;
    notes?: string | null;
    items: Array<{ product_id: string; quantity: number; unit_price: number }>;
  }): Observable<PurchaseOrder> {
    return this.api.post<PurchaseOrder>('/inventory/purchase-orders', payload);
  }

  stockIn(payload: {
    product_id: string;
    quantity: number;
    cost_price: number;
    batch_number?: string | null;
    expiry_date?: string | null;
    received_date?: string | null;
  }): Observable<unknown> {
    return this.api.post<unknown>('/inventory/stock-in', payload);
  }
}