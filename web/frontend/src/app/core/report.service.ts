import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { ApiService } from './api.service';

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
  constructor(private api: ApiService) {}

  getDailyReports(): Observable<DailyReport[]> {
    return this.api.get<DailyReport[]>('/reports/daily');
  }
}