import { Injectable } from '@angular/core';
import { Observable, from, map } from 'rxjs';
import { supabase } from './supabase.client';

export interface DailyReport {
  id: string;
  report_date: string;
  total_sales?: number;
  total_cash?: number;
  total_transfer?: number;
  total_debt?: number;
  total_cost?: number;
  gross_profit?: number;
  created_at?: string;
}

@Injectable({
  providedIn: 'root'
})
export class ReportService {
  getDailyReports(): Observable<DailyReport[]> {
    return from(
      supabase.from('daily_reports').select('*').order('report_date', { ascending: false })
    ).pipe(
      map(({ data, error }) => {
        if (error) throw error;
        return data ?? [];
      })
    );
  }
}
