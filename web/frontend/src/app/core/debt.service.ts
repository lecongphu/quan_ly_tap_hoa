import { Injectable } from '@angular/core';
import { Observable, from, map } from 'rxjs';
import { Customer, CustomerSale, DebtLine, DebtPayment } from '../models/customer.model';
import { supabase } from './supabase.client';

@Injectable({
  providedIn: 'root'
})
export class DebtService {
  getCustomers(onlyDebt = false, includeInactive = false): Observable<Customer[]> {
    let query = supabase.from('customers').select('*').order('created_at', { ascending: false });

    if (!includeInactive) {
      query = query.eq('is_active', true);
    }
    if (onlyDebt) {
      query = query.gt('current_debt', 0);
    }

    return from(query).pipe(
      map(({ data, error }) => {
        if (error) throw error;
        return data ?? [];
      })
    );
  }

  createCustomer(payload: Partial<Customer>): Observable<Customer> {
    return from(
      supabase.from('customers').insert(payload).select('*').single()
    ).pipe(
      map(({ data, error }) => {
        if (error || !data) throw error ?? new Error('Create failed');
        return data as Customer;
      })
    );
  }

  updateCustomer(id: string, payload: Partial<Customer>): Observable<Customer> {
    return from(
      supabase.from('customers').update(payload).eq('id', id).select('*').single()
    ).pipe(
      map(({ data, error }) => {
        if (error || !data) throw error ?? new Error('Update failed');
        return data as Customer;
      })
    );
  }

  deleteCustomer(id: string): Observable<{ id: string }> {
    return from(
      supabase.from('customers').update({ is_active: false }).eq('id', id).select('id').single()
    ).pipe(
      map(({ data, error }) => {
        if (error || !data) throw error ?? new Error('Delete failed');
        return { id: data.id };
      })
    );
  }

  getCustomerHistory(
    id: string,
    limit = 20,
    year?: number | null
  ): Observable<{ sales: CustomerSale[]; payments: DebtPayment[] }> {
    const range = this.getYearRange(year);
    return from(
      Promise.all([
        (() => {
          let query = supabase
            .from('sales')
            .select(
              'id, invoice_number, total_amount, discount_amount, final_amount, payment_method, payment_status, created_at, due_date'
            )
            .eq('customer_id', id)
            .order('created_at', { ascending: false })
            .limit(limit);
          if (range) {
            query = query.gte('created_at', range.start).lt('created_at', range.end);
          }
          return query;
        })(),
        (() => {
          let query = supabase
            .from('debt_payments')
            .select('id, amount, payment_method, notes, created_at')
            .eq('customer_id', id)
            .order('created_at', { ascending: false })
            .limit(limit);
          if (range) {
            query = query.gte('created_at', range.start).lt('created_at', range.end);
          }
          return query;
        })()
      ])
    ).pipe(
      map(([salesRes, paymentsRes]) => {
        if (salesRes.error) throw salesRes.error;
        if (paymentsRes.error) throw paymentsRes.error;
        return {
          sales: (salesRes.data ?? []) as CustomerSale[],
          payments: (paymentsRes.data ?? []) as DebtPayment[]
        };
      })
    );
  }

  getDebtLines(
    id: string,
    year?: number | null,
    duplicateOnly = false
  ): Observable<DebtLine[]> {
    const range = this.getYearRange(year);
    if (duplicateOnly) {
      return from(
        supabase.rpc('get_duplicate_debt_lines', {
          p_customer_id: id,
          p_year: year ?? null
        })
      ).pipe(
        map(({ data, error }) => {
          if (error) throw error;
          return (data ?? []).map((line: any) => ({
            id: line.id,
            invoice_number: line.invoice_number ?? '',
            created_at: line.created_at,
            due_date: line.due_date,
            final_amount: line.final_amount ?? 0,
            notes: line.notes ?? null,
            items: Array.isArray(line.items)
              ? line.items.map((item: any) => ({
                  quantity: item.quantity,
                  unit_price: item.unit_price,
                  subtotal: item.subtotal,
                  product_name: item.product_name ?? '',
                  unit: item.unit ?? ''
                }))
              : []
          })) as DebtLine[];
        })
      );
    }

    return from(
      (() => {
        let query = supabase
          .from('sales')
          .select(
            'id, invoice_number, created_at, due_date, final_amount, notes, payment_method, sale_items(quantity, unit_price, subtotal, product:products(name, unit))'
          )
          .eq('customer_id', id)
          .eq('payment_method', 'debt')
          .order('created_at', { ascending: false });
        if (range) {
          query = query.gte('created_at', range.start).lt('created_at', range.end);
        }
        return query;
      })()
    ).pipe(
      map(({ data, error }) => {
        if (error) throw error;
        return (data ?? []).map((sale: any) => ({
          id: sale.id,
          invoice_number: sale.invoice_number,
          created_at: sale.created_at,
          due_date: sale.due_date,
          final_amount: sale.final_amount,
          notes: sale.notes,
          items: Array.isArray(sale.sale_items)
            ? sale.sale_items.map((item: any) => ({
                quantity: item.quantity,
                unit_price: item.unit_price,
                subtotal: item.subtotal,
                product_name: item.product?.name ?? '',
                unit: item.product?.unit ?? ''
              }))
            : []
        })) as DebtLine[];
      })
    );
  }

  createDebtLine(
    customerId: string,
    payload: {
      amount: number;
      purchase_date?: string | null;
      due_date?: string | null;
      notes?: string | null;
    }
  ): Observable<DebtLine> {
    return from(
      supabase
        .from('sales')
        .insert({
          customer_id: customerId,
          total_amount: payload.amount,
          discount_amount: 0,
          final_amount: payload.amount,
          payment_method: 'debt',
          payment_status: 'unpaid',
          due_date: payload.due_date ?? null,
          notes: payload.notes ?? null,
          created_at: payload.purchase_date ?? undefined
        })
        .select('*')
        .single()
    ).pipe(
      map(({ data, error }) => {
        if (error || !data) throw error ?? new Error('Create failed');
        return data as DebtLine;
      })
    );
  }

  updateDebtLine(
    id: string,
    payload: {
      amount?: number;
      purchase_date?: string | null;
      due_date?: string | null;
      notes?: string | null;
    }
  ): Observable<DebtLine> {
    return from(
      supabase.rpc('update_debt_line', {
        p_sale_id: id,
        p_amount: payload.amount ?? null,
        p_purchase_date: payload.purchase_date ?? null,
        p_due_date: payload.due_date ?? null,
        p_notes: payload.notes ?? null
      })
    ).pipe(
      map(({ data, error }) => {
        if (error || !data) throw error ?? new Error('Update failed');
        return data as DebtLine;
      })
    );
  }

  deleteDebtLine(id: string): Observable<{ id: string }> {
    return from(
      supabase.rpc('delete_debt_line', { p_sale_id: id })
    ).pipe(
      map(({ data, error }) => {
        if (error) throw error;
        return (data ?? { id }) as { id: string };
      })
    );
  }

  recordPayment(payload: {
    customer_id: string;
    amount: number;
    payment_method: 'cash' | 'transfer';
    notes?: string | null;
  }): Observable<unknown> {
    return from(
      supabase.from('debt_payments').insert(payload).select('*').single()
    ).pipe(
      map(({ data, error }) => {
        if (error) throw error;
        return data ?? {};
      })
    );
  }

  updatePayment(
    id: string,
    payload: {
      amount?: number;
      payment_method?: 'cash' | 'transfer';
      notes?: string | null;
    }
  ): Observable<unknown> {
    return from(
      supabase.rpc('update_debt_payment', {
        p_payment_id: id,
        p_amount: payload.amount ?? null,
        p_payment_method: payload.payment_method ?? null,
        p_notes: payload.notes ?? null
      })
    ).pipe(
      map(({ data, error }) => {
        if (error) throw error;
        return data ?? {};
      })
    );
  }

  deletePayment(id: string): Observable<{ id: string }> {
    return from(
      supabase.rpc('delete_debt_payment', { p_payment_id: id })
    ).pipe(
      map(({ data, error }) => {
        if (error) throw error;
        return (data ?? { id }) as { id: string };
      })
    );
  }

  private getYearRange(
    year?: number | null
  ): { start: string; end: string } | null {
    if (!year || !Number.isFinite(year)) return null;
    const start = new Date(Date.UTC(year, 0, 1)).toISOString();
    const end = new Date(Date.UTC(year + 1, 0, 1)).toISOString();
    return { start, end };
  }
}
