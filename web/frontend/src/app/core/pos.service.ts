import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { ApiService } from './api.service';
import { Customer } from '../models/customer.model';

@Injectable({
  providedIn: 'root'
})
export class PosService {
  constructor(private api: ApiService) {}

  getCustomers(): Observable<Customer[]> {
    return this.api.get<Customer[]>('/pos/customers');
  }

  checkout(payload: {
    customer_id?: string | null;
    payment_method: 'cash' | 'transfer' | 'debt';
    discount_amount?: number;
    notes?: string | null;
    items: Array<{ product_id: string; quantity: number; unit_price: number }>;
  }): Observable<{ sale: unknown; items: unknown[] }> {
    return this.api.post<{ sale: unknown; items: unknown[] }>('/pos/checkout', payload);
  }
}