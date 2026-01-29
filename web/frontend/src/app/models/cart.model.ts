import { Product } from './catalog.model';

export interface CartItem {
  product: Product;
  quantity: number;
  unit_price: number;
}