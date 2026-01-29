export interface Supplier {
  id: string;
  code: string;
  name: string;
  phone?: string | null;
  email?: string | null;
  address?: string | null;
  tax_code?: string | null;
  is_active?: boolean;
  created_at?: string;
  updated_at?: string;
}

export interface PurchaseOrderItem {
  id?: string;
  product_id: string;
  quantity: number;
  unit_price: number;
  subtotal?: number;
}

export interface PurchaseOrder {
  id: string;
  order_number: string;
  supplier_id?: string | null;
  supplier_name?: string | null;
  status: string;
  total_amount: number;
  total_items?: number;
  warehouse?: string | null;
  notes?: string | null;
  created_at: string;
  created_by?: string | null;
}