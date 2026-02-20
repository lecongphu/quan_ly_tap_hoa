export interface Customer {
  id: string;
  name: string;
  phone?: string | null;
  address?: string | null;
  latitude?: number | null;
  longitude?: number | null;
  avatar_image_path?: string | null;
  current_debt?: number;
  is_active?: boolean;
  created_at?: string;
  updated_at?: string;
}

export interface CustomerImage {
  id: string;
  customer_id: string;
  image_path: string;
  note?: string | null;
  created_by?: string | null;
  is_active?: boolean;
  created_at: string;
  updated_at?: string;
}

export interface CustomerSale {
  id: string;
  invoice_number: string;
  total_amount: number;
  discount_amount?: number;
  final_amount: number;
  payment_method: string;
  payment_status?: string;
  created_at: string;
  due_date?: string | null;
}

export interface DebtPayment {
  id: string;
  amount: number;
  payment_method: string;
  notes?: string | null;
  created_at: string;
}

export interface DebtLineItem {
  product_name: string;
  unit: string;
  quantity: number;
  unit_price: number;
  subtotal: number;
}

export interface DebtLine {
  id: string;
  invoice_number: string;
  created_at: string;
  due_date?: string | null;
  final_amount: number;
  notes?: string | null;
  items: DebtLineItem[];
}
