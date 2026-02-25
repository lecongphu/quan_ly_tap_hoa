import { Injectable } from '@angular/core';
import { BehaviorSubject, from, map } from 'rxjs';
import { supabase } from './supabase.client';

export interface StoreMembership {
  store_id: string;
  store_code: string;
  store_name: string;
  is_default: boolean;
  role_name?: string | null;
}

@Injectable({
  providedIn: 'root'
})
export class StoreContextService {
  private readonly activeStoreKey = 'qlth.active_store_id';

  private storesSubject = new BehaviorSubject<StoreMembership[]>([]);
  stores$ = this.storesSubject.asObservable();

  private activeStoreSubject = new BehaviorSubject<string | null>(this.getActiveStoreId());
  activeStoreId$ = this.activeStoreSubject.asObservable();

  loadMyStores() {
    return from(supabase.rpc('get_my_stores')).pipe(
      map(({ data, error }) => {
        if (error) throw error;
        const stores = (data as StoreMembership[]) ?? [];
        this.storesSubject.next(stores);

        const current = this.getActiveStoreId();
        const selected = stores.find((s) => s.store_id === current) ?? stores.find((s) => s.is_default) ?? stores[0];
        if (selected) this.setActiveStoreId(selected.store_id);

        return stores;
      })
    );
  }

  switchActiveStore(storeId: string) {
    return from(
      supabase.rpc('set_my_default_store', { target_store: storeId })
    ).pipe(
      map(({ data, error }) => {
        if (error) throw error;
        if (!data) throw new Error('Store access denied');
        this.setActiveStoreId(storeId);
        return true;
      })
    );
  }

  getActiveStoreId(): string | null {
    return localStorage.getItem(this.activeStoreKey);
  }

  setActiveStoreId(storeId: string | null) {
    if (!storeId) {
      localStorage.removeItem(this.activeStoreKey);
      this.activeStoreSubject.next(null);
      return;
    }
    localStorage.setItem(this.activeStoreKey, storeId);
    this.activeStoreSubject.next(storeId);
  }

  clear() {
    this.storesSubject.next([]);
    this.setActiveStoreId(null);
  }
}
