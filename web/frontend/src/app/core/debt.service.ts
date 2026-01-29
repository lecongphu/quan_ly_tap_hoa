import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { ApiService } from './api.service';
import { Customer, CustomerSale, DebtLine, DebtPayment } from '../models/customer.model';

@Injectable({
  providedIn: 'root'
})
export class DebtService {
  constructor(private api: ApiService) {}

  getCustomers(onlyDebt = false, includeInactive = false): Observable<Customer[]> {
    return this.api.get<Customer[]>('/debt/customers', { onlyDebt, includeInactive });
  }

  createCustomer(payload: Partial<Customer>): Observable<Customer> {
    return this.api.post<Customer>('/debt/customers', payload);
  }

  updateCustomer(id: string, payload: Partial<Customer>): Observable<Customer> {
    return this.api.put<Customer>(`/debt/customers/${id}`, payload);
  }

  deleteCustomer(id: string): Observable<{ id: string }> {
    return this.api.delete<{ id: string }>(`/debt/customers/${id}`);
  }

  getCustomerHistory(
    id: string,
    limit = 20
  ): Observable<{ sales: CustomerSale[]; payments: DebtPayment[] }> {
    return this.api.get<{ sales: CustomerSale[]; payments: DebtPayment[] }>(
      `/debt/customers/${id}/history`,
      { limit }
    );
  }

  getDebtLines(id: string): Observable<DebtLine[]> {
    return this.api.get<DebtLine[]>(`/debt/customers/${id}/debt-lines`);
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
    return this.api.post<DebtLine>(`/debt/customers/${customerId}/debt-lines`, payload);
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
    return this.api.put<DebtLine>(`/debt/debt-lines/${id}`, payload);
  }

  deleteDebtLine(id: string): Observable<{ id: string }> {
    return this.api.delete<{ id: string }>(`/debt/debt-lines/${id}`);
  }

  recordPayment(payload: {
    customer_id: string;
    amount: number;
    payment_method: 'cash' | 'transfer';
    notes?: string | null;
  }): Observable<unknown> {
    return this.api.post<unknown>('/debt/payments', payload);
  }

  updatePayment(
    id: string,
    payload: {
      amount?: number;
      payment_method?: 'cash' | 'transfer';
      notes?: string | null;
    }
  ): Observable<unknown> {
    return this.api.put<unknown>(`/debt/payments/${id}`, payload);
  }

  deletePayment(id: string): Observable<{ id: string }> {
    return this.api.delete<{ id: string }>(`/debt/payments/${id}`);
  }
}
