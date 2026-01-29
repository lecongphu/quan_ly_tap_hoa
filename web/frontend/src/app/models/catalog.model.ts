export interface Category {
  id: string;
  name: string;
  description?: string | null;
  created_at?: string;
}

export interface Product {
  id: string;
  barcode?: string | null;
  name: string;
  category_id?: string | null;
  category_name?: string | null;
  unit: string;
  min_stock_level?: number;
  is_active?: boolean;
  created_at?: string;
  updated_at?: string;
  total_quantity?: number;
  avg_cost_price?: number | null;
  nearest_expiry_date?: string | null;
}

export interface InventoryAlert {
  product_id: string;
  product_name?: string;
  name?: string;
  batch_id?: string;
  batch_number?: string | null;
  quantity?: number;
  expiry_date?: string;
  days_until_expiry?: number;
  current_stock?: number;
  min_stock_level?: number;
  unit?: string;
}