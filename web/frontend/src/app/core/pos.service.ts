import { Injectable } from '@angular/core';
import { Observable, from, map } from 'rxjs';
import { Customer } from '../models/customer.model';
import { supabase } from './supabase.client';

@Injectable({
  providedIn: 'root'
})
export class PosService {
  getCustomers(): Observable<Customer[]> {
    return from(
      supabase.from('customers').select('*').order('created_at', { ascending: false })
    ).pipe(
      map(({ data, error }) => {
        if (error) throw error;
        return data ?? [];
      })
    );
  }

  checkout(payload: {
    customer_id?: string | null;
    payment_method: 'cash' | 'transfer' | 'debt';
    discount_amount?: number;
    notes?: string | null;
    items: Array<{ product_id: string; quantity: number; unit_price: number }>;
  }): Observable<{ sale: unknown; items: unknown[] }> {
    return from(
      supabase.rpc('pos_checkout', {
        p_payment_method: payload.payment_method,
        p_items: payload.items,
        p_customer_id: payload.customer_id ?? null,
        p_discount_amount: payload.discount_amount ?? 0,
        p_notes: payload.notes ?? null
      })
    ).pipe(
      map(({ data, error }) => {
        if (error || !data) throw error ?? new Error('Checkout failed');
        return data as { sale: unknown; items: unknown[] };
      })
    );
  }
}
